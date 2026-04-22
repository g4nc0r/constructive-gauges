// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ConcentrationMath} from "../src/ConcentrationMath.sol";
import {FreshnessMath} from "../src/FreshnessMath.sol";

/**
 * @title FrameworkThenaForkTest -- Corrective scoring function on a ve(3,3) CL DEX
 *        on a non-Flashblocks chain.
 * @notice Forks BNB Smart Chain and validates the scoring function of Ryan (2026)
 *         "Constructive Gauges" against live Thena FUSION (Algebra Integral) state.
 * @dev    Thena is a Velodrome/Solidly-family ve(3,3) DEX on BSC. Its concentrated-
 *         liquidity pools use Algebra Integral, which has dynamic fees (no fee tier
 *         at mint time) and uses `algebraMintCallback` in place of the V3 callback.
 *         BSC has no Flashblocks or sub-block pre-confirmation layer (deployed only
 *         on OP Stack rollups). Reproducing the scoring function's structural claims
 *         here demonstrates the framework applies to a ve(3,3) CL architecture that
 *         is neither Slipstream nor Uniswap V3, on a chain without Flashblocks.
 */
interface IAlgebraPool {
    // Thena's deployed Algebra Integral pools return pluginConfig as uint16, not
    // uint8 (the stock Algebra struct). Decoding as uint8 overflows and reverts.
    function globalState() external view returns (
        uint160 price,
        int24 tick,
        uint16 lastFee,
        uint16 pluginConfig,
        uint16 communityFee,
        bool unlocked
    );
    function tickSpacing() external view returns (int24);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @notice Minimal Thena/Algebra NFPM interface derived from the deployed bytecode
///         at 0xa51ADb08Cbe6Ae398046A23bec013979816B77Ab. Uses the 10-field
///         fee-less mint signature (selector 0x9cc1a283) and 11-field positions()
///         return (selector 0x99fbab88, no tickSpacing/deployer fields).
interface IAlgebraNFPM {
    struct MintParams {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
}

contract FrameworkThenaForkTest is Test {
    address constant THENA_NFPM = 0xa51ADb08Cbe6Ae398046A23bec013979816B77Ab;

    // USDT/WBNB Thena FUSION (Algebra) pool
    address constant POOL = 0xD405b976Ac01023c9064024880999fC450A8668b;

    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    uint256 constant DECAY_PERIOD = 4 hours;

    IAlgebraPool pool;
    IAlgebraNFPM nfpm;
    int24 tickSpacing;
    address token0;
    address token1;

    address alice = address(0xA11CE);

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        pool = IAlgebraPool(POOL);
        nfpm = IAlgebraNFPM(THENA_NFPM);

        tickSpacing = pool.tickSpacing();
        token0 = pool.token0();
        token1 = pool.token1();

        console2.log("  Pool token0:", token0);
        console2.log("  Pool token1:", token1);
        console2.log("  Tick spacing:", uint256(int256(tickSpacing)));

        // Both USDT and WBNB are 18 decimals on BSC.
        deal(USDT, alice, 1_000_000e18);
        deal(WBNB, alice, 1_000 ether);

        vm.startPrank(alice);
        IERC20(WBNB).approve(THENA_NFPM, type(uint256).max);
        IERC20(USDT).approve(THENA_NFPM, type(uint256).max);
        vm.stopPrank();
    }

    function _align(int24 t) internal view returns (int24) {
        int24 r = t % tickSpacing;
        if (r < 0) return t - r - tickSpacing;
        return t - r;
    }

    function _mint(int24 tickLower, int24 tickUpper, uint256 amt0, uint256 amt1)
        internal
        returns (uint256 tokenId, uint128 liquidity)
    {
        vm.prank(alice);
        (tokenId, liquidity,,) = nfpm.mint(
            IAlgebraNFPM.MintParams({
                token0: token0,
                token1: token1,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amt0,
                amount1Desired: amt1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp + 300
            })
        );
    }

    function _scoreOf(uint256 tokenId, uint64 depositTime) internal view returns (uint256) {
        (, , , , int24 tl, int24 tu, uint128 liq,,,,) = nfpm.positions(tokenId);
        if (liq == 0) return 0;

        (, int24 tick,,,,) = pool.globalState();
        bool inRange = tick >= tl && tick < tu;

        uint256 c = ConcentrationMath.concentrationFactor(tl, tu, tickSpacing);
        uint256 f = FreshnessMath.freshnessFactor(depositTime, block.timestamp, DECAY_PERIOD);

        return ConcentrationMath.emissionScore(liq, c, f, inRange);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 1: Tight position scores higher than wide per unit capital
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Thena_TightRangeScoresHigher() public {
        console2.log("=== THENA ROW 1: Concentration Term ===");
        console2.log("  Chain: BSC (ve(3,3), Algebra Integral, no Flashblocks)");

        (, int24 tick,,,,) = pool.globalState();
        int24 base = _align(tick);

        uint64 depositTime = uint64(block.timestamp);

        // USDT/WBNB ordering: USDT=token0, WBNB=token1. ~600 USDT per 1 WBNB.
        // Provide balanced amounts for the tick width.
        (uint256 tightId,) = _mint(base - tickSpacing, base + tickSpacing, 10_000e18, 15 ether);
        (uint256 wideId,)  = _mint(base - 10 * tickSpacing, base + 10 * tickSpacing, 10_000e18, 15 ether);

        vm.warp(block.timestamp + 30);

        uint256 tightScore = _scoreOf(tightId, depositTime);
        uint256 wideScore  = _scoreOf(wideId, depositTime);

        console2.log("  Tight score:", tightScore);
        console2.log("  Wide score: ", wideScore);
        require(wideScore > 0, "wide score is zero");
        console2.log("  Ratio (tight / wide):", tightScore / wideScore);

        assertGt(tightScore, wideScore, "tight must score higher than wide on Thena");
        console2.log("  [PASS] Tight scores higher on Thena FUSION (ve(3,3), non-Flashblocks)");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 3: Freshness decay
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Thena_FreshnessDecay() public {
        console2.log("=== THENA ROW 3: Freshness Decay ===");

        (, int24 tick,,,,) = pool.globalState();
        int24 base = _align(tick);

        uint64 depositTime = uint64(block.timestamp);
        (uint256 id,) = _mint(base - tickSpacing, base + tickSpacing, 10_000e18, 15 ether);

        vm.warp(block.timestamp + 30);
        uint256 fresh = _scoreOf(id, depositTime);

        vm.warp(block.timestamp + 2 hours);
        uint256 halfDecay = _scoreOf(id, depositTime);

        vm.warp(block.timestamp + 3 hours);
        uint256 stale = _scoreOf(id, depositTime);

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
        console2.log("  [PASS] Freshness decay on Thena matches paper schedule");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 4: Out-of-range position scores zero
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Thena_OutOfRangeEarnsNothing() public {
        console2.log("=== THENA ROW 4: In-Range Indicator ===");

        (, int24 tick,,,,) = pool.globalState();
        int24 base = _align(tick);

        // Range entirely above current tick -> provide only token0 (USDT).
        uint64 depositTime = uint64(block.timestamp);
        (uint256 id,) = _mint(
            base + 1000 * tickSpacing,
            base + 1002 * tickSpacing,
            50_000e18,
            0
        );

        vm.warp(block.timestamp + 30);

        uint256 score = _scoreOf(id, depositTime);
        console2.log("  Out-of-range score:", score);

        assertEq(score, 0, "out-of-range position must score zero on Thena");
        console2.log("  [PASS] Out-of-range scores zero on Thena");
    }
}
