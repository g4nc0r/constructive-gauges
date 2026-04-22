# Constructive Gauges

[![DOI](https://zenodo.org/badge/1217602131.svg)](https://doi.org/10.5281/zenodo.19690075)

Code, fork tests, and supplementary material for:

> Ryan, K.R. (2026d). *Constructive Gauges: Remediating Parasitic Liquidity in Concentrated Liquidity Emissions.* SSRN 6625980.

**Paper:** [`constructive-gauges.pdf`](./constructive-gauges.pdf) | [SSRN](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6625980)
**Walkthrough:** [`constructive-gauges-walkthrough.pdf`](./constructive-gauges-walkthrough.pdf) — a plain-English companion for LPs and practitioners.

## Overview

Concentrated-liquidity (CL) gauges in ve(3,3) protocols distribute voter-directed emissions via the Synthetix reward accumulator, which measures instantaneous staked liquidity rather than the sustained tradeable depth the protocol intends to incentivise. The parasitic-extraction vector identified in Ryan (2026c) exploits that gap along three axes: duration, width, and utilisation.

This paper proposes *constructive gauges*: a corrective scoring function in which a position's emission share is proportional to

$$S_i \;=\; L_i \cdot c(w_i) \cdot f(t - t_i) \cdot \mathbf{1}[\tau \in \text{range}_i]$$

scaling nominal liquidity by a concentration weight $c$ non-increasing in range width, a freshness weight $f$ non-increasing in time-since-rebalance, and an in-range indicator. Three theorems establish parasitic suppression, bounded legitimate-LP drag, and minimal completeness of the three-factor composition. The framework is validated against live Aerodrome Slipstream state on Base and cross-chain replications on PancakeSwap V3, Thena FUSION (BSC), and Ramses V2 (Arbitrum), with parameter calibration against an operational dataset of 94,469 rebalance events across 48 pools.

## Programme context

The fourth contribution in a research programme on concentrated-liquidity mechanism design:

| # | Title | SSRN |
|---|-------|------|
| I   | The Geometric Siphon: Emergent Capital Reallocation in Concentrated Liquidity Portfolios       | [6374838](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6374838) |
| II  | The Geometric Siphon II: Directional Properties                                                | [6481498](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6481498) |
| III | Parasitic Liquidity: Emission Extraction via Non-Functional Concentrated Liquidity Positions   | [6510118](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6510118) |
| IV  | **Constructive Gauges: Remediating Parasitic Liquidity in Concentrated Liquidity Emissions** | [6625980](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6625980) |

## Fork tests

The Foundry suite under [`foundry/`](./foundry/) runs against live mainnet state on three chains. No mocks. Tests exercise unmodified production contracts; the reference gauge under [`foundry/src/`](./foundry/src) implements the paper's scoring function directly on top of live NFPM state.

### Unit tests (no RPC)

```bash
cd foundry
forge test --match-contract MathTest -vv
```

| Test | Claim validated |
|------|-----------------|
| `test_ConcentrationMath_Reference`             | $c(w)$ produces the expected values at standard widths |
| `test_FreshnessMath_Reference`                 | $f(x)$ produces the expected ramp + decay profile |
| `test_FreshnessMath_RebalanceSpamSelfDefeat`   | Rebalance-spam self-defeat (Proposition 1) |

### Base: Aerodrome Slipstream

```bash
BASE_RPC_URL=<your_base_rpc> forge test \
    --match-contract 'FrameworkForkTest|AerodromeGaugeForkTest' -vv
```

| Test | Claim validated |
|------|-----------------|
| `test_TightRangeScoresHigher`           | Tight positions outscore wide per unit capital (concentration term) |
| `test_TightRangeEarnsMoreEmissions`     | Pending rewards track the score ratio (emissions follow score) |
| `test_FreshnessDecay`                   | Freshness decays from 100% at $t=W$ to $f_0$ floor |
| `test_OutOfRangeEarnsNothing`           | In-range indicator zeroes out-of-range positions |
| `test_GaugeEmissions_TightVsWide`       | Multi-epoch accumulation preserves the tight/wide ratio |
| `test_PostUpgradeStepFunction`          | Production step-gate measurement (Aerodrome post-upgrade) |

### BSC: PancakeSwap V3 + Thena FUSION

```bash
BSC_RPC_URL=<your_bsc_rpc> forge test \
    --match-contract 'FrameworkBSCForkTest|FrameworkThenaForkTest' -vv
```

| Test | Claim validated |
|------|-----------------|
| `test_BSC_TightRangeScoresHigher`       | Concentration term on PancakeSwap V3 (Uniswap V3-family, BSC, no Flashblocks) |
| `test_BSC_FreshnessDecay`               | Freshness decay on PancakeSwap V3 |
| `test_BSC_OutOfRangeEarnsNothing`       | In-range indicator on PancakeSwap V3 |
| `test_Thena_TightRangeScoresHigher`     | Concentration term on Thena FUSION (ve(3,3), Algebra Integral, BSC) |
| `test_Thena_FreshnessDecay`             | Freshness decay on Thena FUSION |
| `test_Thena_OutOfRangeEarnsNothing`     | In-range indicator on Thena FUSION |

### Arbitrum: Ramses V2

```bash
ARB_RPC_URL=<your_arb_rpc> forge test \
    --match-contract FrameworkRamsesForkTest -vv
```

| Test | Claim validated |
|------|-----------------|
| `test_Ramses_TightRangeScoresHigher`    | Concentration term on Ramses V2 (ve(3,3), V3-fork, Arbitrum, no Flashblocks) |
| `test_Ramses_FreshnessDecay`            | Freshness decay on Ramses V2 |
| `test_Ramses_OutOfRangeEarnsNothing`    | In-range indicator on Ramses V2 |

The cross-chain replications span three chains, three CL implementations (Slipstream, Uniswap V3, Algebra Integral), two gauge architectures (ve(3,3) and farm), and two ve(3,3) sub-families (Velodrome/Solidly and Ramses-family). Neither BSC nor Arbitrum has Flashblocks (deployed only on Base, Unichain, OP Mainnet). This demonstrates the framework's empirical behaviour does not depend on Base-specific timing infrastructure or any single ve(3,3) codebase.

## Layout

```
.
├── constructive-gauges.pdf / .tex              main paper
├── constructive-gauges-walkthrough.pdf / .tex  plain-English companion
├── foundry/                                    unified Foundry verification suite
│   ├── src/
│   │   ├── ConcentrationMath.sol                 c(w) library
│   │   ├── FreshnessMath.sol                     f(x) library
│   │   ├── ReferenceGauge.sol                    minimal reference gauge
│   │   └── interfaces/                           minimal Slipstream NFPM + CL pool interfaces
│   ├── test/                                     6 test contracts, 18 tests total
│   │   ├── Math.t.sol
│   │   ├── Framework.fork.t.sol                  Aerodrome Slipstream on Base
│   │   ├── AerodromeGauge.fork.t.sol             production step-gate on Base
│   │   ├── FrameworkBSC.fork.t.sol               PancakeSwap V3 on BSC
│   │   ├── FrameworkThena.fork.t.sol             Thena FUSION on BSC
│   │   └── FrameworkRamses.fork.t.sol            Ramses V2 on Arbitrum
│   ├── foundry.toml
│   ├── LICENSE
│   └── README.md
├── CITATION.cff
├── LICENSE
└── README.md
```

## Reproducing

Requires [Foundry](https://book.getfoundry.sh/) and RPC endpoints for the chains you want to exercise.

Any working RPC endpoint for each chain is sufficient. Public endpoints work for all tests:

| Chain    | Env var          | Example public endpoint            |
|----------|------------------|------------------------------------|
| Base     | `BASE_RPC_URL`   | `https://mainnet.base.org`         |
| BSC      | `BSC_RPC_URL`    | `https://bsc-dataseed.bnbchain.org` |
| Arbitrum | `ARB_RPC_URL`    | `https://arb1.arbitrum.io/rpc`     |

Forge caches RPC responses, so repeat runs are fast. Numerical values reported in Table 2 of the paper are single-run captures against live mainnet state at the time of writing and will differ on re-runs as pool state evolves; the qualitative claims (tight outscores wide, out-of-range scores zero, freshness decay schedule, multi-epoch ratio) hold deterministically.

The empirical in-range probability validation in §5.4 and the operational calibration dataset in §6 are reproducible independently of the fork suite; the paper's Appendix A documents the procedure for the former. The operational dataset is not shipped with this repository.

## Scope

The reference implementation under `foundry/src/` deliberately omits concerns that the paper classifies as out of scope (rebalancing, geometric residual handling, keeper delegation, MEV protection, voting, bribing, cross-pool emission allocation). A production gauge would layer these over the core scoring logic; the present suite demonstrates only that the scoring function itself behaves as the theorems claim.

## Citing

```bibtex
@techreport{ryan2026constructive,
  author      = {Ryan, K. R.},
  title       = {Constructive Gauges: Remediating Parasitic Liquidity in Concentrated Liquidity Emissions},
  institution = {SSRN},
  number      = {6625980},
  year        = {2026},
  url         = {https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6625980}
}
```

## Licence

Code: MIT (see [`LICENSE`](./LICENSE)). Paper: © the author, all rights reserved; canonical version on SSRN.
