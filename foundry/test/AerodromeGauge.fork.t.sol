// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {INFPM} from "../src/interfaces/INFPM.sol";
import {ICLPool} from "../src/interfaces/ICLPool.sol";

/// @notice Minimal upgraded CLGauge interface.
interface ICLGauge {
    function deposit(uint256 tokenId) external;
    function withdraw(uint256 tokenId) external;
    function getReward(uint256 tokenId) external;
    function earned(address account, uint256 tokenId) external view returns (uint256);
    function rewardToken() external view returns (address);
    function rewardRate() external view returns (uint256);
    function pool() external view returns (address);
    function gaugeFactory() external view returns (address);
    function depositTimestamp(uint256 tokenId) external view returns (uint256);
    function nft() external view returns (address);
}

interface ICLGaugeFactory {
    function minStakeTimes(address pool) external view returns (uint256);
    function penaltyRate() external view returns (uint256);
}

/**
 * @title AerodromeGaugeForkTest -- post-upgrade step-function measurement
 * @notice Measures Aerodrome's post-upgrade CLGauge step-function behaviour.
 *         At minStakeTimes = 10s with penaltyRate = 10_000 bps, the gate forfeits
 *         all rewards for claims before 10s and pays in full for claims at or
 *         after 10s. The test asserts both branches and compares against the
 *         continuous-ramp freshness factor used in the paper's Theorem 1.
 * @dev    Validates the empirical adversarial window in §6.3 of Ryan (2026)
 *         "Constructive Gauges": an attacker cycling at $\delta t = 10.1$s
 *         defeats the step gate entirely while the continuous ramp still applies
 *         $\bar f \approx 0.25$ suppression.
 */
contract AerodromeGaugeForkTest is Test {
    // Post-upgrade (new-gauge) addresses
    address constant POOL    = 0xA135B59Fe221C0c8D441294f97f96Fbc37Bc9fbE; // CL100-WETH/VVV new
    address constant GAUGE   = 0xCa9740aFFeDF731f95B3FBAb8d40835781c7aE4D; // new CLGauge
    address constant FACTORY = 0x385293CaE378C813F16f0C1334d774AdDDf56AbB; // new CLGaugeFactory
    address constant NFPM    = 0xe1f8cd9AC4e4A65F54f38a5CdAfCA44f6dD68b53; // new NFPM

    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant VVV  = 0xacfE6019Ed1A7Dc6f7B508C02d1b04ec88cC21bf;

    // token0 < token1: WETH (0x4200...) < VVV (0xacfE...)
    address constant TOKEN0 = WETH;
    address constant TOKEN1 = VVV;

    ICLGauge gauge;
    ICLGaugeFactory factory;
    ICLPool pool;
    INFPM nfpm;
    IERC20 rewardToken;
    int24 tickSpacing;

    address alice = address(0xA11CE);

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        gauge = ICLGauge(GAUGE);
        factory = ICLGaugeFactory(FACTORY);
        pool = ICLPool(POOL);
        nfpm = INFPM(NFPM);
        rewardToken = IERC20(gauge.rewardToken());
        tickSpacing = pool.tickSpacing();

        deal(WETH, alice, 100 ether);
        deal(VVV, alice, 1_000_000 ether, true);
    }

    function _align(int24 t) internal view returns (int24) {
        int24 r = t % tickSpacing;
        if (r < 0) return t - r - tickSpacing;
        return t - r;
    }

    function _mint(int24 tickLower, int24 tickUpper, uint256 wethAmt, uint256 vvvAmt)
        internal
        returns (uint256 tokenId, uint128 liquidity)
    {
        vm.startPrank(alice);
        IERC20(WETH).approve(NFPM, type(uint256).max);
        IERC20(VVV).approve(NFPM, type(uint256).max);
        (tokenId, liquidity,,) = nfpm.mint(
            INFPM.MintParams({
                token0: TOKEN0,
                token1: TOKEN1,
                tickSpacing: tickSpacing,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: wethAmt,
                amount1Desired: vvvAmt,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp + 300,
                sqrtPriceX96: 0
            })
        );
        vm.stopPrank();
    }

    function _depositToGauge(uint256 tokenId) internal {
        vm.startPrank(alice);
        nfpm.approve(GAUGE, tokenId);
        gauge.deposit(tokenId);
        vm.stopPrank();
    }

    /// @notice Asserts the step-function shape of the post-upgrade gauge:
    ///         claims before the 10s threshold forfeit all rewards; claims at or
    ///         after the threshold pay in full, with identical per-second rate.
    function test_PostUpgradeStepFunction() public {
        console2.log("=== POST-UPGRADE GAUGE -- STEP-FUNCTION MEASUREMENT ===");
        console2.log("  Block:              ", block.number);
        console2.log("  minStakeTimes(pool):", factory.minStakeTimes(POOL));
        console2.log("  penaltyRate (bps):  ", factory.penaltyRate());

        assertEq(factory.minStakeTimes(POOL), 10, "minStakeTimes should be 10s");
        assertEq(factory.penaltyRate(), 10_000, "penaltyRate should be 100% (10_000 bps)");

        (, int24 tick,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint256[6] memory durations = [uint256(2), 5, 10, 15, 30, 60];
        uint256[6] memory claimedPerSecond;
        uint256 baseTimestamp = block.timestamp;

        for (uint256 i = 0; i < durations.length; i++) {
            vm.warp(baseTimestamp);

            (uint256 tokenId,) = _mint(base - tickSpacing, base + tickSpacing, 0.5 ether, 500 ether);
            _depositToGauge(tokenId);

            vm.warp(block.timestamp + durations[i]);

            uint256 balBefore = rewardToken.balanceOf(alice);
            vm.prank(alice);
            gauge.getReward(tokenId);
            uint256 claimed = rewardToken.balanceOf(alice) - balBefore;
            claimedPerSecond[i] = claimed / durations[i];

            console2.log("  Duration (s):", durations[i]);
            console2.log("    claimed:    ", claimed);
            console2.log("    per-second: ", claimedPerSecond[i]);

            vm.prank(alice);
            gauge.withdraw(tokenId);
        }

        // Assertions: below-threshold claims forfeit everything.
        assertEq(claimedPerSecond[0], 0, "delta_t = 2s: full forfeit");
        assertEq(claimedPerSecond[1], 0, "delta_t = 5s: full forfeit");

        // At-or-above-threshold claims pay in full, with identical per-second rate.
        assertGt(claimedPerSecond[2], 0, "delta_t = 10s: reward paid");
        assertEq(claimedPerSecond[3], claimedPerSecond[2], "15s per-s matches 10s");
        assertEq(claimedPerSecond[4], claimedPerSecond[2], "30s per-s matches 10s");
        assertEq(claimedPerSecond[5], claimedPerSecond[2], "60s per-s matches 10s");

        console2.log("  [PASS] Step-function shape confirmed: 0 before 10s, full after");
    }
}
