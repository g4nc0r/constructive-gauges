# Constructive Gauges — Reference Foundry Suite

Fork tests validating the corrective scoring function from

> Ryan, K.R. (2026d) *Constructive Gauges: Remediating Parasitic Liquidity in Concentrated Liquidity Emissions*.

The contracts under `src/` are a **minimal reference implementation** of the four-factor scoring function $S_i = L_i \cdot c(w) \cdot f(t - t_i) \cdot \mathbf{1}[\tau \in [\ell, u]]$ and the accumulator required to reproduce the paper's numerical claims. Production-level concerns (keeper delegation, residual handling, MEV protection, voting, emission allocation across pools) are intentionally **out of scope**; they are orthogonal to the scoring framework and would be provided by a host protocol.

## Layout

| Path | Purpose |
|---|---|
| `src/ConcentrationMath.sol` | $c(w)$ library: capped reciprocal of range width |
| `src/FreshnessMath.sol` | $f(t - t_i)$ library: ramp + plateau + linear decay to floor |
| `src/ReferenceGauge.sol` | Minimal gauge exercising the scoring function |
| `src/interfaces/` | Minimal NFPM and CL pool interface stubs |
| `test/Math.t.sol` | Unit tests for the scoring libraries, no RPC needed |
| `test/Framework.fork.t.sol` | Fork tests against live Aerodrome Slipstream on Base |
| `test/FrameworkBSC.fork.t.sol` | Fork tests against live PancakeSwap V3 on BSC (chain without Flashblocks) |
| `test/FrameworkThena.fork.t.sol` | Fork tests against live Thena FUSION (ve(3,3) Algebra Integral) on BSC |
| `test/FrameworkRamses.fork.t.sol` | Fork tests against live Ramses V2 (ve(3,3) V3-family CL) on Arbitrum |
| `test/AerodromeGauge.fork.t.sol` | Fork measurement of the post-upgrade production gauge step function |

## Reference parameters

The reference instance in §5.1 of the paper uses:

| Parameter | Value |
|---|---|
| $c_{\max}$ | 100 |
| $w_{\text{ref}}$ | 1000 × tickSpacing |
| Warmup $W$ | 20 s |
| Freshness floor $f_0$ | 0.1 (1000 bps) |
| Decay period | 4 h |
| Minimum width | 2 × tickSpacing |

Different parameter choices can be tested by editing the constants in `ConcentrationMath.sol` and `FreshnessMath.sol` and re-running the suite; the framework's qualitative properties (monotonicity in width, monotonicity in freshness, zero out-of-range) hold under any choice satisfying the shape conditions in §3 of the paper.

## Reproduction

```bash
cd foundry
git submodule update --init --recursive

# Unit tests (no RPC needed)
forge test --match-contract MathTest -vv

# Base: Aerodrome Slipstream
BASE_RPC_URL=<your_base_rpc> forge test --match-contract FrameworkForkTest -vv

# BSC: PancakeSwap V3 (Uniswap V3-family, farm gauge)
BSC_RPC_URL=<your_bsc_rpc> forge test --match-contract FrameworkBSCForkTest -vv

# BSC: Thena FUSION (ve(3,3), Algebra Integral)
BSC_RPC_URL=<your_bsc_rpc> forge test --match-contract FrameworkThenaForkTest -vv

# Arbitrum: Ramses V2 (ve(3,3), V3-fork CL)
ARB_RPC_URL=<your_arb_rpc> forge test --match-contract FrameworkRamsesForkTest -vv
```

Any working RPC endpoint is acceptable. Public endpoints `https://mainnet.base.org`, `https://bsc-dataseed.bnbchain.org`, and `https://arb1.arbitrum.io/rpc` are sufficient; Alchemy/QuickNode/Infura endpoints work the same. Forge caches RPC responses, so repeat runs are fast.

## Test-to-claim mapping

Each test corresponds to a row in Table 2 of the paper:

| Test | Claim validated |
|---|---|
| `test_ConcentrationMath_Reference` | $c(w)$ library produces the expected values at standard widths |
| `test_FreshnessMath_Reference` | $f(x)$ library produces the expected decay profile |
| `test_FreshnessMath_RebalanceSpamSelfDefeat` | Rebalance-spam self-defeat (Remark 1) |
| `test_TightRangeScoresHigher` | Concentration term: tight positions score higher per unit capital |
| `test_TightRangeEarnsMoreEmissions` | Emission rewards follow the scoring function, not nominal liquidity |
| `test_FreshnessDecay` | Freshness decays from 100% at $t = W$ to floor $f_0$ over the decay period |
| `test_OutOfRangeEarnsNothing` | In-range indicator strictly zeroes out-of-range positions |
| `test_GaugeEmissions_TightVsWide` | Multi-epoch accumulation preserves the tight / wide ratio under freshness decay |
| `test_PostUpgradeStepFunction` | Production gauge comparison: Aerodrome's 10s step vs the paper's continuous ramp |
| `test_BSC_TightRangeScoresHigher` | Concentration term reproduced on PancakeSwap V3 / BSC (non-Flashblocks chain) |
| `test_BSC_FreshnessDecay` | Freshness decay reproduced on PancakeSwap V3 / BSC (non-Flashblocks chain) |
| `test_BSC_OutOfRangeEarnsNothing` | In-range indicator zeroes out-of-range positions on PancakeSwap V3 / BSC |
| `test_Thena_TightRangeScoresHigher` | Concentration term reproduced on Thena FUSION (ve(3,3) Algebra Integral) on BSC |
| `test_Thena_FreshnessDecay` | Freshness decay reproduced on Thena FUSION (ve(3,3)) on BSC |
| `test_Thena_OutOfRangeEarnsNothing` | In-range indicator zeroes out-of-range positions on Thena FUSION |
| `test_Ramses_TightRangeScoresHigher` | Concentration term reproduced on Ramses V2 (ve(3,3) V3-family CL) on Arbitrum |
| `test_Ramses_FreshnessDecay` | Freshness decay reproduced on Ramses V2 (ve(3,3)) on Arbitrum |
| `test_Ramses_OutOfRangeEarnsNothing` | In-range indicator zeroes out-of-range positions on Ramses V2 |

The cross-chain fork tests (rows 10-18) exist to pre-empt the claim that the scoring function's structural properties depend on Base's Flashblocks infrastructure. Flashblocks (200-250ms sub-block pre-confirmations developed by Flashbots) is deployed only on OP Stack rollups: Base, Unichain, OP Mainnet. Neither BSC (0.45s native blocks, post-Fermi hard fork) nor Arbitrum One (Timeboost express-lane auction, which is a distinct mechanism from sub-block pre-confirmations) has Flashblocks. The scoring function exhibits the same tight-vs-wide concentration ratio, freshness decay schedule, and out-of-range zeroing across:

- PancakeSwap V3 on BSC (non-ve(3,3) farm architecture, Uniswap V3-family CL)
- Thena FUSION on BSC (ve(3,3) Velodrome/Solidly-family architecture, Algebra Integral CL)
- Ramses V2 on Arbitrum (ve(3,3) V3-family CL, independent codebase)

This spans three chains, three distinct CL implementations (Slipstream, Uniswap V3, Algebra Integral), two distinct gauge architectures (ve(3,3) and farm), and two sub-families of ve(3,3) CL DEX (Velodrome/Solidly and Ramses-family), all on chains without Flashblocks, confirming the scoring framework is independent of chain-level timing infrastructure and protocol-specific implementation choices.

Numerical values reported in the paper's Table 2 are from single-run executions against live Base mainnet state at the time of writing. Values shift between runs as pool state evolves; the qualitative claims (ordering, zero-result for out-of-range, near-equal ratios between score and emission) hold deterministically.

## Notes on scope

This reference implementation deliberately omits:

- **Rebalancing**: atomic withdraw + mint + deposit. The paper's Theorem 1 bounds parasitic extraction over arbitrary cycle times; rebalancing mechanics are orthogonal.
- **Residual handling**: the geometric residual from rebalancing (Theorem 1 of Ryan, 2026a) is an implementation concern that does not affect the scoring framework.
- **Keeper delegation, MEV protection, voting, bribing, emission allocation**: all out of scope per §1.5 of the paper.

A production gauge implementing the framework would layer these concerns over the core scoring logic; the present suite demonstrates only that the scoring function itself behaves as the theorems claim.

## Licence

MIT. See `LICENSE`.
