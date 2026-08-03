<p align="center">
  <img src=".github/banner.jpg" alt="Constructive Gauges: concentration-weighted emission distribution for concentrated liquidity DEXs" width="100%" />
</p>

# Constructive Gauges

Paper sources for *Constructive Gauges: Remediating Parasitic Liquidity in Concentrated Liquidity Emissions* (K. R. Ryan, 2026), the protocol-side companion to *Parasitic Liquidity*.

Concentrated liquidity gauges in ve(3,3) protocols distribute voter-directed emissions via the Synthetix reward accumulator, which measures instantaneous staked liquidity rather than the sustained tradeable depth the protocol intends to incentivise. The parasitic extraction vector identified in Ryan (2026, *Parasitic Liquidity*) exploits that gap along three axes: duration, width, and utilisation. This paper proposes *constructive gauges*: a corrective scoring function in which a position's emission share is proportional to

$$S_i \;=\; L_i \cdot c(w_i) \cdot f(t - t_i) \cdot \mathbf{1}[\tau \in \text{range}_i]$$

scaling nominal liquidity by a concentration weight non-increasing in range width, a freshness weight non-increasing in time-since-rebalance, and an in-range indicator. Three theorems establish parasitic suppression, bounded legitimate-LP drag, and minimal completeness of the three-factor composition. The framework is validated against live Aerodrome Slipstream state on Base and cross-chain replications on PancakeSwap V3, Thena FUSION (BSC), and Ramses V2 (Arbitrum), with parameter calibration against an operational dataset of 94,469 rebalance events across 48 pools.

| | |
|---|---|
| **Author** | K. R. Ryan, independent researcher |
| **Contact** | [gancor.xyz](https://gancor.xyz) · ORCID [0009-0004-6295-7040](https://orcid.org/0009-0004-6295-7040) |
| **Paper DOI** | [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19690075.svg)](https://doi.org/10.5281/zenodo.19690075) |
| **SSRN** | [6625980](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6625980) |
| **Licence** | paper PDFs and LaTeX source © K. R. Ryan, all rights reserved; companion code (`foundry/`, `lean/`, `reproduction/`) MIT |

**Status.** *This is a working paper.* The PDFs in `paper/` are revised preprints of the SSRN entry above and are not peer-reviewed. The Foundry verification suite for the constructive scoring function is included at `foundry/`; the reproduction scripts for the in-range probability validation are at `reproduction/`; a Lean 4 formalisation of the theorem layer is at `lean/`. The operational calibration dataset (the author's own positions, §6 of the paper) is not distributed.

## The papers

The repository carries two companion documents at `paper/`:

- **`constructive-gauges.pdf`**: the full technical paper with theorems, proofs, and parameter calibration.
- **`constructive-gauges-walkthrough.pdf`**: a plain-English companion for LPs and protocol practitioners, intended to make the core proposal legible without the formal scaffolding.

## Programme context

This is the fourth contribution in a research programme on concentrated liquidity mechanism design.

| | Where | Status |
|---|---|---|
| The Geometric Siphon (Paper I): Emergent Capital Reallocation in Concentrated Liquidity Portfolios | [SSRN 6374838](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6374838) | Live preprint |
| The Geometric Siphon II: Directional Properties | [SSRN 6481498](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6481498) | Live preprint |
| Parasitic Liquidity: Emission Extraction via Non-Functional Concentrated Liquidity Positions | [SSRN 6510118](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6510118) | Live preprint |
| Constructive Gauges (this paper) | [SSRN 6625980](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6625980) | Live preprint, revised working paper here |

The Geometric Siphon papers characterise the geometric residual that arises on LP rebalancing under shared depositor balances. *Parasitic Liquidity* analyses the emission-side analogue, where staked positions accrue gauge rewards without providing tradeable depth. *Constructive Gauges* presents the protocol-side response, replacing $L_i$ in the gauge formula with a scoring function that conditions emission accrual on duration, width, and tradeable-depth provision.

## Citation

```bibtex
@techreport{ryan2026constructive,
  author      = {Ryan, K. R.},
  title       = {Constructive Gauges: Remediating Parasitic Liquidity
                 in Concentrated Liquidity Emissions},
  institution = {SSRN},
  number      = {6625980},
  year        = {2026},
  doi         = {10.2139/ssrn.6625980},
  url         = {https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6625980}
}
```

A `CITATION.cff` with the same metadata is included at the repository root.

## Layout

```
.
├── paper/
│   ├── constructive-gauges.tex                  paper source
│   ├── constructive-gauges.pdf                  compiled PDF
│   ├── constructive-gauges-walkthrough.tex      walkthrough source
│   └── constructive-gauges-walkthrough.pdf      compiled walkthrough PDF
├── foundry/                                     Foundry verification suite (fork tests)
├── lean/                                        Lean 4 formalisation of the theorem layer
│   ├── ConstructiveGauges/                      Defs.lean + eight theorem files
│   ├── AxiomCheck.lean                          45 axiom checks
│   └── README.md                                coverage map and scope caveats
├── reproduction/
│   ├── empirical_pin.py                         parquet-archive port of the Appendix E protocol
│   ├── empirical_pin_multiwindow.py             multi-window extension (Appendix E)
│   └── output/                                  window-level and aggregate results
├── .github/
│   └── banner.jpg
├── CITATION.cff
├── LICENSE
└── README.md
```

The operational rebalance dataset used for §6 calibration is the author's own position history and is not distributed; see `reproduction/README.md` for what is and is not reproducible from public data.

## Lean formalisation

[`lean/`](./lean/) machine-checks the theorem layer in Lean 4 against mathlib. Coverage is Lemma 1's pointwise in-range law together with the two monotonicity conditions the Chebyshev step consumes; Lemma 2 as an explicit finite-$N$ concentration bound rather than an asymptotic statement; Theorems 1 and 2 in full on the mean-field reduced revenue functionals, exactly and with no error term; Corollaries 1 and 2 as limits of the closed-form freshness average, and Corollary 3 with both envelopes of the range-tracking bracket; Theorem 3's short-cycle and out-of-range rows as iffs, with the width arbitrage row sharpened; and Propositions 1 and 2 in full. Chebyshev's anti-monotone inequality is proved here in integral form, mathlib carrying only the finite-sum version.

The mean-field substitution itself is not carried through symbolically: it is taken as the definition of the reduced functionals, which makes Theorems 1 and 2 exact and confines the $O(N^{-1/2})$ bookkeeping to the concentration lemma. Lemma 2's positive-dependence variant, the Brownian price process as a process, and the empirical layer are also outside scope. The full coverage map, the sharpened reading of Theorem 3's width arbitrage row, and the scope caveats are in [`lean/README.md`](./lean/README.md). The formalisation covers the idealised real-arithmetic and mean-field model of the paper; the Foundry suite remains the check against the accumulator's actual arithmetic on live chain state, and `reproduction/` remains the check of Lemma 1's Gaussian model against realised tick paths.

```bash
cd lean
lake exe cache get   # one-off, fetches prebuilt mathlib (several GB)
lake build

# axiom audit: 45 checks, propext / Classical.choice / Quot.sound only, no sorry
lake env lean AxiomCheck.lean
```

## Building the papers

```bash
cd paper
xelatex constructive-gauges.tex
xelatex constructive-gauges.tex                  # second pass for cross-references

xelatex constructive-gauges-walkthrough.tex
xelatex constructive-gauges-walkthrough.tex
```

Requires `xelatex` with `texgyretermes`, `unicode-math`, `pgfplots` (≥ 1.18), `microtype`, `mdframed`, and `placeins`. Two passes resolve the bibliography and cross-references. Outputs are self-contained PDFs in `paper/`.
