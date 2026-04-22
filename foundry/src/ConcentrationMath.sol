// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ConcentrationMath
/// @notice Reference implementation of the concentration factor c(w) and the
///         emission score L * c * f * 1[in range] from Ryan (2026) "Constructive
///         Gauges", equation (eq:score).
/// @dev Purely functional; no state. For paper reproduction only.
library ConcentrationMath {
    uint256 internal constant MIN_CONCENTRATION = 1;   // floor at 1x for reference-width positions
    uint256 internal constant MAX_CONCENTRATION = 100; // cap (paper's c_max)
    uint256 internal constant REFERENCE_WIDTH_MULTIPLIER = 1000; // w_ref = 1000 * tickSpacing
    uint256 internal constant BPS = 10000;

    /// @notice c(w) = min(c_max, w_ref / w), with minimum width enforcement.
    /// @dev Returned as 1e18-scaled fixed point so a reference-width position has
    ///      factor = 1e18. A tight (2x tick spacing) position has factor = 500 * 1e18
    ///      pre-cap, clipped to MAX_CONCENTRATION * 1e18 = 100 * 1e18.
    function concentrationFactor(int24 tickLower, int24 tickUpper, int24 tickSpacing)
        internal
        pure
        returns (uint256 factor)
    {
        require(tickUpper > tickLower, "Invalid range");

        uint256 positionWidth = uint256(int256(tickUpper - tickLower));
        uint256 minWidth = uint256(int256(tickSpacing)) * 2;
        if (positionWidth < minWidth) positionWidth = minWidth;

        uint256 referenceWidth = uint256(int256(tickSpacing)) * REFERENCE_WIDTH_MULTIPLIER;

        factor = (referenceWidth * 1e18) / positionWidth;

        uint256 lo = MIN_CONCENTRATION * 1e18;
        uint256 hi = MAX_CONCENTRATION * 1e18;
        if (factor < lo) factor = lo;
        if (factor > hi) factor = hi;
    }

    /// @notice Emission score S = L * c * f * 1[in range].
    /// @param liquidity Position's liquidity (uint128 from NFPM)
    /// @param concFactor 1e18-scaled concentration factor
    /// @param freshBps Freshness weight in basis points (10000 = 100%)
    /// @param inRange True iff the current tick lies within the position's range
    function emissionScore(uint128 liquidity, uint256 concFactor, uint256 freshBps, bool inRange)
        internal
        pure
        returns (uint256 score)
    {
        if (!inRange || liquidity == 0) return 0;
        score = (uint256(liquidity) * concFactor / 1e18) * freshBps / BPS;
    }
}
