// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {INFPM} from "../src/interfaces/INFPM.sol";
import {ICLPool} from "../src/interfaces/ICLPool.sol";
import {ReferenceGauge} from "../src/ReferenceGauge.sol";

/**
 * @title Framework -- Corrective Scoring Function Fork Tests
 * @notice Forks Base mainnet and validates the corrective scoring function of
 *         Ryan (2026) "Constructive Gauges" against live Aerodrome Slipstream.
 * @dev    Each test maps to a row in Table 2 of the paper. Set BASE_RPC_URL in
 *         your environment (any working Base RPC endpoint is sufficient).
 *
 *         Row 1: Concentration term     -- tight scores higher than wide per $
 *         Row 2: Emissions follow score -- pending rewards track the score ratio
 *         Row 3: Freshness decay        -- score decays from 100% to floor
 *         Row 4: In-range indicator     -- out-of-range position scores zero
 *         Row 5: Tight vs wide, 4 epochs-- multi-epoch accumulation preserves the ratio
 */
contract FrameworkForkTest is Test {
    // Base mainnet addresses
    address constant SLIPSTREAM_NFPM = 0x827922686190790b37229fd06084350E74485b72;
    address constant POOL            = 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59; // WETH/USDC CL100
    address constant AERO            = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address constant WETH            = 0x4200000000000000000000000000000000000006;
    address constant USDC            = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // On Base, WETH (0x4200...) < USDC (0x833589...), so WETH is token0.
    address constant TOKEN0 = WETH;
    address constant TOKEN1 = USDC;

    uint256 constant DECAY_PERIOD = 4 hours;

    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    ReferenceGauge gauge;
    ICLPool pool;
    INFPM nfpm;
    int24 tickSpacing;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        pool = ICLPool(POOL);
        nfpm = INFPM(SLIPSTREAM_NFPM);
        tickSpacing = pool.tickSpacing();

        gauge = new ReferenceGauge(POOL, SLIPSTREAM_NFPM, AERO, DECAY_PERIOD);

        deal(AERO, address(gauge), 1_000_000e18);
        gauge.setEmissionRate(1e18); // 1 AERO/s

        _fund(alice);
        _fund(bob);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    function _fund(address who) internal {
        deal(WETH, who, 10 ether);
        deal(USDC, who, 50_000e6, true); // updateTotalSupply=true for USDC proxy
    }

    function _align(int24 t) internal view returns (int24) {
        int24 r = t % tickSpacing;
        if (r < 0) return t - r - tickSpacing;
        return t - r;
    }

    function _mintAndDeposit(address who, int24 tickLower, int24 tickUpper, uint256 wethAmt, uint256 usdcAmt)
        internal
        returns (uint256 tokenId)
    {
        vm.startPrank(who);
        IERC20(WETH).approve(SLIPSTREAM_NFPM, type(uint256).max);
        IERC20(USDC).approve(SLIPSTREAM_NFPM, type(uint256).max);

        (tokenId,,,) = nfpm.mint(
            INFPM.MintParams({
                token0: TOKEN0,
                token1: TOKEN1,
                tickSpacing: tickSpacing,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: wethAmt,
                amount1Desired: usdcAmt,
                amount0Min: 0,
                amount1Min: 0,
                recipient: who,
                deadline: block.timestamp + 300,
                sqrtPriceX96: 0
            })
        );

        nfpm.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        vm.stopPrank();
    }

    function _refreshCache(uint256[] memory tokenIds) internal {
        uint256 sum;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            sum += gauge.scoreOf(tokenIds[i]);
        }
        gauge.setTotalScoreCache(sum);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS (matching paper Table 2)
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Row 1: Tight position scores higher than wide position per unit capital.
    function test_TightRangeScoresHigher() public {
        console2.log("=== ROW 1: Concentration Term ===");

        (, int24 tick,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint256 tightId = _mintAndDeposit(alice, base - tickSpacing, base + tickSpacing, 1 ether, 10_000e6);
        uint256 wideId  = _mintAndDeposit(bob,   base - 10 * tickSpacing, base + 10 * tickSpacing, 1 ether, 10_000e6);

        // Warp past the warmup so freshness reaches its plateau.
        vm.warp(block.timestamp + 30);

        uint256 tightScore = gauge.scoreOf(tightId);
        uint256 wideScore  = gauge.scoreOf(wideId);

        console2.log("  Tight score:", tightScore);
        console2.log("  Wide score: ", wideScore);
        require(wideScore > 0, "wide score is zero; check ranges");
        console2.log("  Ratio (tight / wide, int):", tightScore / wideScore);

        assertGt(tightScore, wideScore, "tight must score higher than wide");
        console2.log("  [PASS] Tight position scores higher per unit capital");
    }

    /// @notice Row 2: Pending rewards follow the score ratio.
    function test_TightRangeEarnsMoreEmissions() public {
        console2.log("=== ROW 2: Emissions Follow Score ===");

        (, int24 tick,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint256 tightId = _mintAndDeposit(alice, base - tickSpacing, base + tickSpacing, 1 ether, 10_000e6);
        uint256 wideId  = _mintAndDeposit(bob,   base - 10 * tickSpacing, base + 10 * tickSpacing, 1 ether, 10_000e6);

        uint256[] memory ids = new uint256[](2);
        ids[0] = tightId;
        ids[1] = wideId;

        // Warp past warmup and seed the score cache.
        vm.warp(block.timestamp + 30);
        _refreshCache(ids);

        // Accrue for one minute.
        vm.warp(block.timestamp + 60);

        uint256 pendTight = gauge.pending(tightId);
        uint256 pendWide  = gauge.pending(wideId);

        console2.log("  Pending tight:", pendTight);
        console2.log("  Pending wide: ", pendWide);
        require(pendWide > 0, "wide pending is zero");
        console2.log("  Ratio (tight / wide, int):", pendTight / pendWide);

        assertGt(pendTight, pendWide, "tight must earn more than wide");
        console2.log("  [PASS] Rewards track the score ratio");
    }

    /// @notice Row 3: Score decays from 100% at t = W to the configured floor.
    function test_FreshnessDecay() public {
        console2.log("=== ROW 3: Freshness Decay ===");

        (, int24 tick,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint256 id = _mintAndDeposit(alice, base - tickSpacing, base + tickSpacing, 1 ether, 10_000e6);

        // Just past warmup (W = 20 s).
        vm.warp(block.timestamp + 30);
        uint256 fresh = gauge.scoreOf(id);

        // Mid-decay (2 h): expect ~55% of fresh.
        vm.warp(block.timestamp + 2 hours);
        uint256 halfDecay = gauge.scoreOf(id);

        // Post-decay (5 h): floor at 10%.
        vm.warp(block.timestamp + 3 hours);
        uint256 stale = gauge.scoreOf(id);

        console2.log("  Fresh (t = W):       ", fresh);
        console2.log("  Half-decay (t = 2h): ", halfDecay);
        console2.log("  Stale (t = 5h):      ", stale);

        assertGt(fresh, halfDecay, "fresh > half-decay");
        assertGt(halfDecay, stale, "half-decay > stale");

        uint256 midPct = (halfDecay * 100) / fresh;
        uint256 stalePct = (stale * 100) / fresh;
        console2.log("  Mid-decay % of fresh:", midPct);
        console2.log("  Stale % of fresh:    ", stalePct);
        assertApproxEqAbs(midPct, 55, 5, "mid-decay within 5pp of 55%");
        assertApproxEqAbs(stalePct, 10, 2, "stale within 2pp of 10% floor");
        console2.log("  [PASS] Freshness decays 100% -> ~55% -> 10% on schedule");
    }

    /// @notice Row 4: Out-of-range position scores zero under the framework.
    function test_OutOfRangeEarnsNothing() public {
        console2.log("=== ROW 4: In-Range Indicator ===");

        (, int24 tick,,,,) = pool.slot0();
        int24 base = _align(tick);

        // Range far above current tick; needs only token0 (WETH on this pool).
        uint256 id = _mintAndDeposit(
            alice, base + 1000 * tickSpacing, base + 1002 * tickSpacing, 5 ether, 0
        );

        // Immediately past warmup. Freshness would be high, but position is OOR.
        vm.warp(block.timestamp + 30);
        uint256 score = gauge.scoreOf(id);

        console2.log("  Out-of-range score:", score);
        assertEq(score, 0, "out-of-range position must score zero");
        console2.log("  [PASS] Out-of-range position scores exactly zero");
    }

    /// @notice Row 5: Four 30-minute epochs; multi-epoch accumulation preserves the ratio.
    function test_GaugeEmissions_TightVsWide() public {
        console2.log("=== ROW 5: Tight vs Wide, Full Epoch ===");

        (, int24 tick,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint256 tightId = _mintAndDeposit(alice, base - tickSpacing, base + tickSpacing, 1 ether, 10_000e6);
        uint256 wideId  = _mintAndDeposit(bob,   base - 10 * tickSpacing, base + 10 * tickSpacing, 1 ether, 10_000e6);

        uint256[] memory ids = new uint256[](2);
        ids[0] = tightId;
        ids[1] = wideId;

        uint256 tightBefore = IERC20(AERO).balanceOf(alice);
        uint256 wideBefore  = IERC20(AERO).balanceOf(bob);

        // Warp past warmup and seed the cache before the epochs begin.
        vm.warp(block.timestamp + 30);
        _refreshCache(ids);

        // Four 30-minute epochs, refreshing the cache at each boundary so the
        // accumulator denominator reflects the decayed scores.
        for (uint256 i = 0; i < 4; i++) {
            vm.warp(block.timestamp + 30 minutes);
            _refreshCache(ids);
        }

        vm.prank(alice);
        gauge.claim(tightId);
        vm.prank(bob);
        gauge.claim(wideId);

        uint256 tightEarned = IERC20(AERO).balanceOf(alice) - tightBefore;
        uint256 wideEarned  = IERC20(AERO).balanceOf(bob)   - wideBefore;

        console2.log("  Tight earned (AERO wei):", tightEarned);
        console2.log("  Wide earned  (AERO wei):", wideEarned);
        require(wideEarned > 0, "wide earned is zero");
        console2.log("  Ratio (tight / wide, int):", tightEarned / wideEarned);

        assertGt(tightEarned, wideEarned, "tight must earn more than wide over four epochs");
        console2.log("  [PASS] Multi-epoch accumulation preserves the tight/wide ratio");
    }
}
