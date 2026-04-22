// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ConcentrationMath} from "../src/ConcentrationMath.sol";
import {FreshnessMath} from "../src/FreshnessMath.sol";

/**
 * @title Math -- Scoring-Function Library Unit Tests
 * @notice Reference values for c(w) and f(x) from Ryan (2026) "Constructive Gauges".
 * @dev    No fork required; pure library unit tests.
 */
contract MathTest is Test {
    int24 constant TS = 100; // Reference CL100 tick spacing

    // ═══════════════════════════════════════════════════════════════════════════
    // CONCENTRATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Reference values for c(w) at standard widths on a CL100 pool.
    /// @dev c(w) = min(c_max, w_ref / w) with c_max = 100, w_ref = 1000 * tickSpacing.
    function test_ConcentrationMath_Reference() public pure {
        console2.log("=== CONCENTRATION REFERENCE ===");

        // Reference width (1000 * tickSpacing): factor = 1.
        uint256 cFull = ConcentrationMath.concentrationFactor(-50_000, 50_000, TS);
        console2.log("  reference-width (100k ticks) c:", cFull);
        assertEq(cFull, 1e18, "reference-width factor = 1");

        // 20x tick spacings = 2000 ticks: factor = 100_000 / 2000 = 50.
        uint256 cWide = ConcentrationMath.concentrationFactor(0, 2000, TS);
        console2.log("  20x spacing (2000 ticks) c:   ", cWide);
        assertEq(cWide, 50e18, "20x tickSpacing factor = 50");

        // Minimum width (2x tick spacings = 200 ticks): raw factor 500, capped at 100.
        uint256 cTight = ConcentrationMath.concentrationFactor(0, 200, TS);
        console2.log("  min-width (200 ticks) c:      ", cTight);
        assertEq(cTight, 100e18, "min-width factor capped at c_max = 100");

        // Below-min width: snapped to min and capped.
        uint256 cTooNarrow = ConcentrationMath.concentrationFactor(0, 50, TS);
        console2.log("  below-min (50 ticks) c:       ", cTooNarrow);
        assertEq(cTooNarrow, 100e18, "below-min width snaps to min and caps");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FRESHNESS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Reference values for f(x) at standard times.
    /// @dev Piecewise-linear: ramp over W = 20s, then linear decay from 1 to 0.1
    ///      over a configurable decay period (4 hours here).
    function test_FreshnessMath_Reference() public pure {
        console2.log("=== FRESHNESS REFERENCE ===");

        uint256 t0 = 1_000_000;
        uint256 decayPeriod = 4 hours;

        // Warmup ramp: f(0) = 0; f(W) = 1.
        uint256 f0 = FreshnessMath.freshnessFactor(t0, t0, decayPeriod);
        uint256 fW = FreshnessMath.freshnessFactor(t0, t0 + 20, decayPeriod);
        console2.log("  f(0) bps:            ", f0);
        console2.log("  f(W=20s) bps:        ", fW);
        assertEq(f0, 0, "t=0 -> ramp value 0");
        assertEq(fW, 10_000, "t=W -> 100%");

        // Mid-decay at 2h: f ~= 55%. Exact integer value is 5513 bps.
        uint256 f2h = FreshnessMath.freshnessFactor(t0, t0 + 2 hours, decayPeriod);
        console2.log("  f(2h) bps:           ", f2h);
        assertApproxEqAbs(f2h, 5_513, 5, "t=2h mid-decay ~= 55%");

        // Just before end of decay period.
        uint256 fNearEnd = FreshnessMath.freshnessFactor(t0, t0 + 4 hours, decayPeriod);
        console2.log("  f(decayPeriod) bps:  ", fNearEnd);
        assertApproxEqAbs(fNearEnd, 1_013, 5, "t=decayPeriod close to floor");

        // Past decay end: at the floor.
        uint256 fStale = FreshnessMath.freshnessFactor(t0, t0 + 5 hours, decayPeriod);
        console2.log("  f(5h) bps (floor):   ", fStale);
        assertEq(fStale, 1_000, "t > decayPeriod -> f_0 floor");
    }

    /// @notice Rebalance-spam self-defeat (Remark 1 in the paper).
    /// @dev Under the linear ramp f(x) = x/W on [0, W], continuous rebalancing at
    ///      interval delta < W gives time-averaged freshness delta / (2W) < 1.
    ///      This test samples f at the midpoint of representative cycles.
    function test_FreshnessMath_RebalanceSpamSelfDefeat() public pure {
        console2.log("=== REBALANCE-SPAM SELF-DEFEAT ===");

        uint256 W = 20; // warmup period in seconds

        // delta = 2s (one Base block): midpoint s = 1 -> f = 1/W = 5% (500 bps).
        uint256 midShort = FreshnessMath.freshnessFactor(0, 1, W);
        console2.log("  f at midpoint of 2s cycle: ", midShort);
        assertEq(midShort, 500, "f at s=1 of 2s cycle = 5% (500 bps)");

        // delta = 10s: midpoint s = 5 -> f = 5/W = 25% (2500 bps).
        uint256 midMed = FreshnessMath.freshnessFactor(0, 5, W);
        console2.log("  f at midpoint of 10s cycle:", midMed);
        assertEq(midMed, 2_500, "f at s=5 of 10s cycle = 25% (2500 bps)");
    }
}
