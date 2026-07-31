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
| **Licence** | paper PDFs and LaTeX source © K. R. Ryan, all rights reserved; companion code (`foundry/`, `reproduction/`) MIT |

**Status.** *This is a working paper.* The PDFs in `paper/` are revised preprints of the SSRN entry above and are not peer-reviewed. The Foundry verification suite for the constructive scoring function is included at `foundry/`; the reproduction scripts for the in-range probability validation are at `reproduction/`. The operational calibration dataset (the author's own positions, §6 of the paper) is not distributed.

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

## Building the papers

```bash
cd paper
xelatex constructive-gauges.tex
xelatex constructive-gauges.tex                  # second pass for cross-references

xelatex constructive-gauges-walkthrough.tex
xelatex constructive-gauges-walkthrough.tex
```

Requires `xelatex` with `texgyretermes`, `unicode-math`, `pgfplots` (≥ 1.18), `microtype`, `mdframed`, and `placeins`. Two passes resolve the bibliography and cross-references. Outputs are self-contained PDFs in `paper/`.
