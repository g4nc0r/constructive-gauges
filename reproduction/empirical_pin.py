#!/usr/bin/env python3
"""
Parquet-archive reproduction of the Lemma 3 (in-range probability) empirical
validation in section 5.2 (Empirical validation of the in-range probability
formula) of Constructive Gauges.

Reproduces section 5.2 / Appendix E.2 with the same N_s = 1500 re-anchored
short-cycle sampling and 400-node midpoint-rule Gaussian baseline, against a
top-50 Aerodrome Pool.Swap parquet archive instead of a live RPC
endpoint. The archive holds epochs 69 to 140 (December 2024 to May 2026); a
contemporaneous RPC pull recovers the same numerical results to within sampling
variation, with the short-cycle agreement and long-cycle conservative departure
preserved across pull dates per the rolling-window construction.

Manuscript anchors:
  * Lemma 3 (paper line 326): closed-form for Pbar_in(dt; a, sigma).
  * Section 5.2 (paper line 476): empirical validation against two Base CL100
    pools over a 24-hour window each.
  * Appendix E (paper line 1066): the live-RPC reproduction protocol this
    script replaces with a parquet pull.

Data source:
  a parquet archive of Aerodrome Slipstream Pool.Swap events covering the
  target pools (39.2 M rows, top-50 Aerodrome CL pools, epochs 69 to 140 in
  the runs reported by the paper), passed via --parquet. Required columns:
  pool, block_timestamp, tick.

Output:
  reproduction/output/empirical_pin_results.csv
  one row per (pool, dt_seconds, w_ticks, n_samples) cell, plus the
  Gaussian baseline and the empirical mean / sample standard deviation.

Run:
  python3 reproduction/empirical_pin.py --parquet /path/to/swaps_topN.parquet
  python3 reproduction/empirical_pin.py --parquet ... --pools 0xb2cc... 0x3f02...
  python3 reproduction/empirical_pin.py --parquet ... --window-hours 24
"""

from __future__ import annotations
import argparse
import csv
import math
import random
from pathlib import Path
from statistics import fmean, pstdev

import duckdb


# --- Constants ------------------------------------------------------------

ETA = math.log(1.0001)               # tick-to-log-price scaling, Lemma 3
N_SAMPLES = 1500                     # N_s in paper line 1068
N_MIDPOINT_NODES = 400               # midpoint-rule nodes for the Gaussian baseline
SEED = 20260510                      # programme-wide deterministic seed

DEFAULT_OUTPUT = Path(__file__).resolve().parent / "output" / "empirical_pin_results.csv"

# Default sweep: matches section 5.2 (paper line 495).
# Widths are full tick widths w; the position is half-width w/2 around tau(s).
DEFAULT_W_TICKS = [200, 500, 1000]
DEFAULT_DT_SECONDS = [
    2, 10, 30, 60, 120, 300, 600, 1800, 3600, 7200, 21600, 43200,
]

# The Aerodrome Slipstream WETH/USDC CL100 pool used as the paper's primary
# target. Second default is the next-most-active CL pool in the parquet,
# observed from a DESCRIBE pass. Both are CL100 by construction; check the
# pool's tickSpacing if you swap in a different address.
DEFAULT_POOLS = [
    "0xb2cc224c1c9fee385f8ad6a55b4d94e92359dc59",
    "0x3f0296bf652e19bca772ec3df08b32732f93014a",
]


# --- Phi (standard-normal CDF) -------------------------------------------

def Phi(z: float) -> float:
    """Standard-normal CDF via erf, math.stdlib only."""
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


# --- Data loading --------------------------------------------------------

def load_tick_trace(
    parquet_path: Path,
    pool: str,
    window_seconds: int,
    con: duckdb.DuckDBPyConnection,
) -> list[tuple[int, int]]:
    """
    Load Swap events for `pool` over the most recent `window_seconds` window
    present in the parquet. Returns a list of (block_timestamp, tick) tuples
    in ascending timestamp order, deduplicated to one row per timestamp via the
    earliest log_index at that timestamp.

    The tick is already decoded as a signed BIGINT in the parquet schema; no
    int24 sign extension needed at this stage.
    """
    pool_lc = pool.lower()
    max_ts_row = con.execute(
        "SELECT MAX(block_timestamp) FROM read_parquet(?) WHERE pool = ?",
        [str(parquet_path), pool_lc],
    ).fetchone()
    if max_ts_row is None or max_ts_row[0] is None:
        raise RuntimeError(f"No rows for pool {pool_lc} in {parquet_path}")
    max_ts: int = int(max_ts_row[0])
    min_ts: int = max_ts - window_seconds

    rows = con.execute(
        """
        SELECT block_timestamp, tick
        FROM read_parquet(?)
        WHERE pool = ?
          AND block_timestamp >= ?
          AND block_timestamp <= ?
        ORDER BY block_timestamp, log_index
        """,
        [str(parquet_path), pool_lc, min_ts, max_ts],
    ).fetchall()
    if not rows:
        raise RuntimeError(
            f"No swaps in [{min_ts}, {max_ts}] for pool {pool_lc}. Try a longer window."
        )
    # The tick function is piecewise-constant: each event sets the tick from
    # its block_timestamp onward. Keep the last tick at each unique timestamp
    # so the trace strictly steps forward in time.
    dedup: dict[int, int] = {}
    for ts, tick in rows:
        dedup[int(ts)] = int(tick)
    sorted_ts = sorted(dedup.keys())
    return [(ts, dedup[ts]) for ts in sorted_ts]


# --- Volatility estimation -----------------------------------------------

def estimate_sigma(trace: list[tuple[int, int]]) -> float:
    """
    Realised volatility per sqrt(second) under the Brownian log-price model.
    X(t) = tau(t) * eta. sigma = sqrt(E[(dX / sqrt(dt))^2]) across consecutive
    events with dt > 0, matching paper line 1068.
    """
    sq = 0.0
    n = 0
    for (ts0, t0), (ts1, t1) in zip(trace, trace[1:]):
        dt = ts1 - ts0
        if dt <= 0:
            continue
        dx = (t1 - t0) * ETA
        sq += (dx * dx) / dt
        n += 1
    if n == 0:
        raise RuntimeError("Trace has no positive-dt increments.")
    return math.sqrt(sq / n)


# --- Tick lookup along the trace -----------------------------------------

def tick_at(trace: list[tuple[int, int]], ts: int, lo_hint: int = 0) -> tuple[int, int]:
    """
    Piecewise-constant tick lookup at timestamp `ts`, returning (tick, idx)
    where idx is the trace index of the latest event with timestamp <= ts.
    `lo_hint` accelerates monotone scans; the loop advances from there only
    when the next event's timestamp is still <= ts.
    """
    idx = lo_hint
    n = len(trace)
    while idx + 1 < n and trace[idx + 1][0] <= ts:
        idx += 1
    return trace[idx][1], idx


def empirical_pin_one(
    trace: list[tuple[int, int]],
    start_ts: int,
    dt: int,
    half_width: int,
    half_cycle: bool = False,
) -> float:
    """
    Empirical in-range fraction for a position of half-width `half_width`
    centred at tau(start_ts), measured over [start_ts, start_ts + dt] by
    default, or over [start_ts, start_ts + dt/2] when `half_cycle=True`
    (the latter matches the prose at paper line 1068; the former matches
    eq:pin's [0, dt] integration window).
    """
    horizon = dt // 2 if half_cycle else dt
    if horizon <= 0:
        return float("nan")
    end_ts = start_ts + horizon
    centre, idx = tick_at(trace, start_ts)
    in_seconds = 0.0
    cursor_ts = start_ts
    cursor_tick = centre
    n = len(trace)
    while cursor_ts < end_ts:
        # Next change point is either the next event or the window end.
        next_ts = trace[idx + 1][0] if (idx + 1 < n) else end_ts
        if next_ts > end_ts:
            next_ts = end_ts
        if abs(cursor_tick - centre) <= half_width:
            in_seconds += (next_ts - cursor_ts)
        cursor_ts = next_ts
        if cursor_ts < end_ts and idx + 1 < n:
            idx += 1
            cursor_tick = trace[idx][1]
    return in_seconds / horizon


def empirical_pin_sweep(
    trace: list[tuple[int, int]],
    dt: int,
    w_ticks: int,
    n_samples: int,
    rng: random.Random,
    half_cycle: bool = False,
) -> tuple[float, float]:
    """
    Sample `n_samples` uniform start timestamps within the trace's interior
    (leaving enough headroom on the right for the [s, s+horizon] window),
    compute the empirical in-range fraction at each, and return (mean, sd).
    """
    if not trace:
        return float("nan"), float("nan")
    first_ts = trace[0][0]
    last_ts = trace[-1][0]
    horizon = dt // 2 if half_cycle else dt
    if last_ts - first_ts <= horizon:
        return float("nan"), float("nan")
    half_width = w_ticks // 2
    samples = []
    for _ in range(n_samples):
        s = rng.randint(first_ts, last_ts - horizon)
        samples.append(empirical_pin_one(trace, s, dt, half_width, half_cycle))
    return fmean(samples), pstdev(samples)


# --- Gaussian baseline ---------------------------------------------------

def gaussian_pin(dt: float, a: float, sigma: float, n_nodes: int = N_MIDPOINT_NODES) -> float:
    """
    Closed-form Gaussian in-range probability from equation 12 of the paper
    (Lemma 3), via midpoint-rule integration on s in (0, dt]:

        Pbar_in(dt; a, sigma)
            = (1 / dt) * integral_0^dt [2 Phi(a * eta / (sigma * sqrt(s))) - 1] ds.

    a is the half-width in ticks (so a = w / 2 for the script's w-grid).
    The integrand approaches 1 as s -> 0+ (Phi(+inf) = 1 yields 2*1 - 1 = 1),
    so the midpoint rule with n_nodes ~ 400 is well-conditioned.
    """
    h = dt / n_nodes
    acc = 0.0
    for k in range(n_nodes):
        s = (k + 0.5) * h
        z = (a * ETA) / (sigma * math.sqrt(s))
        acc += (2.0 * Phi(z) - 1.0)
    return acc / n_nodes


# --- Main ----------------------------------------------------------------

def run(
    parquet: Path,
    pools: list[str],
    window_seconds: int,
    dt_grid: list[int],
    w_grid: list[int],
    n_samples: int,
    output_path: Path,
    seed: int,
    half_cycle: bool = False,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    con = duckdb.connect()
    with output_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "pool", "window_seconds", "n_events", "sigma_per_sqrt_s",
            "dt_seconds", "w_ticks",
            "n_samples", "pin_empirical_mean", "pin_empirical_sd",
            "pin_gaussian", "delta_empirical_minus_gaussian",
        ])
        for pool in pools:
            print(f"[{pool}] loading {window_seconds // 3600} h window...", flush=True)
            trace = load_tick_trace(parquet, pool, window_seconds, con)
            sigma = estimate_sigma(trace)
            n_events = len(trace)
            print(
                f"[{pool}] {n_events} events, sigma = {sigma:.4e} per sqrt(s).",
                flush=True,
            )
            for dt in dt_grid:
                for w in w_grid:
                    emp_mean, emp_sd = empirical_pin_sweep(trace, dt, w, n_samples, rng, half_cycle)
                    a = w / 2.0
                    th = gaussian_pin(float(dt), a, sigma)
                    writer.writerow([
                        pool, window_seconds, n_events, f"{sigma:.6e}",
                        dt, w,
                        n_samples,
                        f"{emp_mean:.6f}", f"{emp_sd:.6f}",
                        f"{th:.6f}", f"{(emp_mean - th):.6f}",
                    ])
            print(f"[{pool}] done.", flush=True)
    print(f"Wrote {output_path}", flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument(
        "--parquet", type=Path, required=True,
        help="Parquet archive of Aerodrome Slipstream Pool.Swap events "
             "(columns: pool, block_timestamp, tick).",
    )
    p.add_argument("--pools", nargs="+", default=DEFAULT_POOLS)
    p.add_argument(
        "--window-hours", type=int, default=24,
        help="Trace window per pool. Paper uses 24 h; the parquet archive supports months.",
    )
    p.add_argument("--dt-grid", type=int, nargs="+", default=DEFAULT_DT_SECONDS)
    p.add_argument("--w-grid", type=int, nargs="+", default=DEFAULT_W_TICKS)
    p.add_argument("--n-samples", type=int, default=N_SAMPLES)
    p.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    p.add_argument("--seed", type=int, default=SEED)
    p.add_argument(
        "--full-cycle", action="store_true",
        help="Integrate empirical over [s, s+dt] (eq:pin convention) instead "
             "of the published [s, s+dt/2] convention from paper line 1068. "
             "The default reproduces Figure 1's empirical curve; setting this "
             "flag gives an apples-to-apples integration window vs the "
             "Gaussian baseline but does not reproduce the published numbers.",
    )
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run(
        parquet=args.parquet,
        pools=[p.lower() for p in args.pools],
        window_seconds=args.window_hours * 3600,
        dt_grid=sorted(args.dt_grid),
        w_grid=sorted(args.w_grid),
        n_samples=args.n_samples,
        output_path=args.output,
        seed=args.seed,
        half_cycle=not args.full_cycle,
    )
