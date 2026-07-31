# Reproduction: in-range probability validation

Scripts and outputs behind the empirical validation of the Gaussian in-range
probability (Lemma 3, §5.2, Appendix E of the paper). This folder concerns
only the tick-trace validation; the §6 operational calibration dataset is a
separate, private dataset and is not distributed.

## Contents

- `empirical_pin.py` — parquet-archive port of Appendix E's live-RPC
  protocol: one 24-hour window per pool, `N_s = 1500` sampled starting
  blocks, 400-node midpoint-rule Gaussian baseline.
- `empirical_pin_multiwindow.py` — the same protocol across non-overlapping
  24-hour windows uniformly spaced through the archive's span (24 windows on
  the WETH/USDC CL100 pool, 23 on the VIRTUAL/WETH CL100 pool in the runs
  the paper reports).
- `output/empirical_pin_multiwindow_per_window.csv` — one row per
  (pool, window, δt, w) cell.
- `output/empirical_pin_multiwindow_summary.csv` — per (pool, δt, w)
  aggregates across windows.

The summary CSV is the source of the Appendix E claims: empirical in-range
probability exceeds the Gaussian baseline in 87.5% or more of windows at
every δt ≥ 1 h slice at the minimum-width setting (w = 200); the median
empirical-minus-Gaussian gap grows from +0.02 at 1 h to +0.16 at 12 h on the
less volatile pool and from +0.16 to +0.24 on the more volatile pool; and
short cycles (δt ≤ 20 s) agree to better than three-decimal precision in
every window.

## Data requirement

Both scripts require a parquet archive of Aerodrome Slipstream Pool `Swap`
events covering the target pools, with columns `pool`, `block_timestamp`,
and `tick`, passed via `--parquet`. The archive used for the published runs
covers the top-50 Aerodrome CL pools over epochs 69 to 140 (December 2024 to
May 2026) and is not distributed with this repository. The live-RPC protocol
in Appendix E reproduces the single-window check without any archive.

## Run

```bash
python3 empirical_pin.py --parquet /path/to/swaps.parquet
python3 empirical_pin_multiwindow.py --parquet /path/to/swaps.parquet
```

Results are deterministic under the default seed (20260510). Per the paper,
a single-window run completes in under a minute per pool on a standard
workstation.
