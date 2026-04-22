// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title FreshnessMath
/// @notice Reference implementation of the freshness weight f(x) from Ryan (2026)
///         "Constructive Gauges". Piecewise-linear: ramp from 0 to 1 over the
///         warmup W, plateau at 1, then linear decay to floor f_0 over the configured
///         decay period.
/// @dev Paper reference parameters: W = 20s, f_0 = 0.1, decay period = 4 hours.
library FreshnessMath {
    uint256 internal constant BPS = 10000;
    uint256 internal constant FLOOR_BPS = 1000; // f_0 = 0.1 in BPS
    uint256 internal constant WARMUP = 20;      // W = 20 seconds

    /// @notice f(x) in basis points.
    /// @param lastRebalanceTime Timestamp of deposit or last rebalance
    /// @param currentTime Current block.timestamp
    /// @param decayPeriod Seconds over which freshness decays from 1 to f_0
    function freshnessFactor(uint256 lastRebalanceTime, uint256 currentTime, uint256 decayPeriod)
        internal
        pure
        returns (uint256 freshBps)
    {
        if (currentTime <= lastRebalanceTime) return 0;
        if (decayPeriod == 0) return BPS;

        uint256 elapsed = currentTime - lastRebalanceTime;

        // Warmup ramp: 0 -> BPS linearly over WARMUP seconds.
        if (elapsed < WARMUP) {
            return (elapsed * BPS) / WARMUP;
        }

        // Post-warmup decay from BPS to FLOOR_BPS over decayPeriod.
        uint256 sinceRamp = elapsed - WARMUP;
        if (sinceRamp >= decayPeriod) return FLOOR_BPS;

        uint256 range = BPS - FLOOR_BPS;
        uint256 decay = (range * sinceRamp) / decayPeriod;
        freshBps = BPS - decay;
    }
}
