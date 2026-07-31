#!/usr/bin/env python3
"""
Multi-window strengthening for the empirical-pin validation.

Runs the Lemma 3 in-range probability empirical-vs-Gaussian comparison across
N non-overlapping 24-hour windows uniformly spaced through the parquet's
covered time range, rather than against a single window. For each window the
script estimates sigma from the swap trace, sweeps (dt, w), records the
empirical and Gaussian Pbar_in, and finally aggregates per (pool, dt, w) cell
across windows. The aggregate output reports the median empirical, the 10th
and 90th percentile band, and the fraction of windows in which empirical
exceeds the Gaussian baseline.

Imports from empirical_pin.py rather than duplicating logic.

Run:
  python3 reproduction/empirical_pin_multiwindow.py --parquet /path/to/swaps_topN.parquet
  python3 reproduction/empirical_pin_multiwindow.py --parquet ... --n-windows 24 --n-samples 1500
"""

from __future__ import annotations
import argparse
import csv
import math
import random
from pathlib import Path
from statistics import fmean, median, pstdev

import duckdb

import empirical_pin as base


DEFAULT_PER_WINDOW_OUTPUT = (
    Path(__file__).resolve().parent / "output" / "empirical_pin_multiwindow_per_window.csv"
)
DEFAULT_SUMMARY_OUTPUT = (
    Path(__file__).resolve().parent / "output" / "empirical_pin_multiwindow_summary.csv"
)


def get_pool_time_range(
    parquet_path: Path, pool: str, con: duckdb.DuckDBPyConnection
) -> tuple[int, int]:
    pool_lc = pool.lower()
    row = con.execute(
        "SELECT MIN(block_timestamp), MAX(block_timestamp) "
        "FROM read_parquet(?) WHERE pool = ?",
        [str(parquet_path), pool_lc],
    ).fetchone()
    if row is None or row[0] is None or row[1] is None:
        raise RuntimeError(f"No rows for pool {pool_lc} in {parquet_path}")
    return int(row[0]), int(row[1])


def load_window_trace(
    parquet_path: Path,
    pool: str,
    start_ts: int,
    window_seconds: int,
    con: duckdb.DuckDBPyConnection,
) -> list[tuple[int, int]]:
    """Load a fixed [start_ts, start_ts+window_seconds] window of Swap events."""
    pool_lc = pool.lower()
    end_ts = start_ts + window_seconds
    rows = con.execute(
        """
        SELECT block_timestamp, tick
        FROM read_parquet(?)
        WHERE pool = ?
          AND block_timestamp >= ?
          AND block_timestamp < ?
        ORDER BY block_timestamp, log_index
        """,
        [str(parquet_path), pool_lc, start_ts, end_ts],
    ).fetchall()
    if not rows:
        return []
    dedup: dict[int, int] = {}
    for ts, tick in rows:
        dedup[int(ts)] = int(tick)
    sorted_ts = sorted(dedup.keys())
    return [(ts, dedup[ts]) for ts in sorted_ts]


def run(
    parquet: Path,
    pools: list[str],
    n_windows: int,
    window_seconds: int,
    dt_grid: list[int],
    w_grid: list[int],
    n_samples: int,
    seed: int,
    half_cycle: bool,
    per_window_output: Path,
    summary_output: Path,
) -> None:
    per_window_output.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    con = duckdb.connect()

    # Per-window CSV: one row per (window, pool, dt, w).
    per_window_rows: list[dict] = []

    for pool in pools:
        min_ts, max_ts = get_pool_time_range(parquet, pool, con)
        span = max_ts - min_ts
        if span < window_seconds:
            raise RuntimeError(
                f"Pool {pool} has only {span/86400:.1f} days of data; "
                f"can't fit a {window_seconds//3600}-hour window."
            )
        # N uniformly-spaced non-overlapping window starts.
        usable = span - window_seconds
        if n_windows == 1:
            starts = [min_ts]
        else:
            stride = usable / (n_windows - 1)
            starts = [int(min_ts + i * stride) for i in range(n_windows)]
        print(
            f"[{pool}] {span/86400:.1f} days of data, "
            f"{n_windows} windows × {window_seconds//3600} h, "
            f"stride = {(starts[1]-starts[0])/86400:.1f} days "
            f"(non-overlapping = {(starts[1]-starts[0]) >= window_seconds}).",
            flush=True,
        )
        for w_idx, start_ts in enumerate(starts):
            trace = load_window_trace(parquet, pool, start_ts, window_seconds, con)
            if len(trace) < 100:
                print(
                    f"[{pool}] window {w_idx} ({start_ts}): only {len(trace)} events, skipping.",
                    flush=True,
                )
                continue
            try:
                sigma = base.estimate_sigma(trace)
            except RuntimeError as e:
                print(f"[{pool}] window {w_idx}: {e}; skipping.", flush=True)
                continue
            for dt in dt_grid:
                for w in w_grid:
                    emp_mean, emp_sd = base.empirical_pin_sweep(
                        trace, dt, w, n_samples, rng, half_cycle=half_cycle
                    )
                    a = w / 2.0
                    th = base.gaussian_pin(float(dt), a, sigma)
                    per_window_rows.append({
                        "pool": pool,
                        "window_id": w_idx,
                        "window_start_ts": start_ts,
                        "window_seconds": window_seconds,
                        "n_events": len(trace),
                        "sigma_per_sqrt_s": sigma,
                        "dt_seconds": dt,
                        "w_ticks": w,
                        "n_samples": n_samples,
                        "pin_empirical_mean": emp_mean,
                        "pin_empirical_sd": emp_sd,
                        "pin_gaussian": th,
                        "delta_empirical_minus_gaussian": emp_mean - th,
                    })
            print(f"[{pool}] window {w_idx}/{n_windows-1} done ({len(trace)} events, sigma={sigma:.3e}).", flush=True)

    # Write per-window CSV.
    if per_window_rows:
        with per_window_output.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(per_window_rows[0].keys()))
            writer.writeheader()
            for row in per_window_rows:
                writer.writerow({
                    k: (f"{v:.6e}" if k == "sigma_per_sqrt_s"
                        else f"{v:.6f}" if isinstance(v, float) and not math.isnan(v)
                        else v)
                    for k, v in row.items()
                })
        print(f"\nWrote per-window CSV: {per_window_output}", flush=True)

    # Aggregate per (pool, dt, w).
    summary_rows: list[dict] = []
    grouped: dict[tuple[str, int, int], list[dict]] = {}
    for row in per_window_rows:
        key = (row["pool"], row["dt_seconds"], row["w_ticks"])
        grouped.setdefault(key, []).append(row)

    for (pool, dt, w), rows in sorted(grouped.items()):
        emp_means = [r["pin_empirical_mean"] for r in rows
                     if not math.isnan(r["pin_empirical_mean"])]
        gausses = [r["pin_gaussian"] for r in rows
                   if not math.isnan(r["pin_gaussian"])]
        deltas = [r["delta_empirical_minus_gaussian"] for r in rows
                  if not math.isnan(r["delta_empirical_minus_gaussian"])]
        sigmas = [r["sigma_per_sqrt_s"] for r in rows]
        if not emp_means:
            continue
        emp_sorted = sorted(emp_means)
        delta_sorted = sorted(deltas)
        n = len(emp_means)
        p10_idx = max(0, int(0.10 * n))
        p90_idx = min(n - 1, int(0.90 * n))
        n_emp_gt_gauss = sum(1 for d in deltas if d > 0)
        summary_rows.append({
            "pool": pool,
            "dt_seconds": dt,
            "w_ticks": w,
            "n_windows": n,
            "sigma_median": median(sigmas),
            "sigma_min": min(sigmas),
            "sigma_max": max(sigmas),
            "pin_empirical_median": median(emp_means),
            "pin_empirical_p10": emp_sorted[p10_idx],
            "pin_empirical_p90": emp_sorted[p90_idx],
            "pin_gaussian_median": median(gausses),
            "delta_median": median(deltas),
            "delta_p10": delta_sorted[p10_idx],
            "delta_p90": delta_sorted[p90_idx],
            "frac_windows_emp_exceeds_gauss": n_emp_gt_gauss / n,
        })

    if summary_rows:
        with summary_output.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(summary_rows[0].keys()))
            writer.writeheader()
            for row in summary_rows:
                writer.writerow({
                    k: (f"{v:.6e}" if k.startswith("sigma_")
                        else f"{v:.6f}" if isinstance(v, float)
                        else v)
                    for k, v in row.items()
                })
        print(f"Wrote summary CSV: {summary_output}", flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument(
        "--parquet", type=Path, required=True,
        help="Parquet archive of Aerodrome Slipstream Pool.Swap events "
             "(columns: pool, block_timestamp, tick).",
    )
    p.add_argument("--pools", nargs="+", default=base.DEFAULT_POOLS[:1])
    p.add_argument(
        "--n-windows", type=int, default=24,
        help="Number of uniformly-spaced 24-h windows across the parquet's time range.",
    )
    p.add_argument("--window-hours", type=int, default=24)
    p.add_argument("--dt-grid", type=int, nargs="+", default=base.DEFAULT_DT_SECONDS)
    p.add_argument("--w-grid", type=int, nargs="+", default=base.DEFAULT_W_TICKS)
    p.add_argument("--n-samples", type=int, default=base.N_SAMPLES)
    p.add_argument("--seed", type=int, default=base.SEED)
    p.add_argument(
        "--full-cycle", action="store_true",
        help="Integrate empirical over [s, s+dt] instead of the published [s, s+dt/2].",
    )
    p.add_argument("--per-window-output", type=Path, default=DEFAULT_PER_WINDOW_OUTPUT)
    p.add_argument("--summary-output", type=Path, default=DEFAULT_SUMMARY_OUTPUT)
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run(
        parquet=args.parquet,
        pools=[p.lower() for p in args.pools],
        n_windows=args.n_windows,
        window_seconds=args.window_hours * 3600,
        dt_grid=sorted(args.dt_grid),
        w_grid=sorted(args.w_grid),
        n_samples=args.n_samples,
        seed=args.seed,
        half_cycle=not args.full_cycle,
        per_window_output=args.per_window_output,
        summary_output=args.summary_output,
    )
