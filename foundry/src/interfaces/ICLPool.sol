// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal CL pool interface (Uniswap V3 / Slipstream compatible).
interface ICLPool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            bool unlocked
        );

    function token0() external view returns (address);
    function token1() external view returns (address);
    function tickSpacing() external view returns (int24);
}
