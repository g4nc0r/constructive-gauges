// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ConcentrationMath} from "../src/ConcentrationMath.sol";
import {FreshnessMath} from "../src/FreshnessMath.sol";

/**
 * @title FrameworkBSCForkTest -- Corrective scoring function on a non-Flashblocks chain
 * @notice Forks BNB Smart Chain and validates the scoring function of Ryan (2026)
 *         "Constructive Gauges" against live PancakeSwap V3 state.
 * @dev    BSC has no Flashblocks or any sub-block pre-confirmation layer (Flashblocks
 *         is deployed only on OP Stack rollups -- Base, Unichain, OP Mainnet).
 *         Reproducing the scoring function's structural claims against live BSC state
 *         demonstrates the framework is chain-architecture-independent and does not
 *         rely on the Flashblocks timing infrastructure present on the Base deployment
 *         in Framework.fork.t.sol.
 *
 *         Tests map to rows 1, 3, 4 of paper Table 2:
 *           Row 1: Tight position scores higher than wide per unit capital
 *           Row 3: Freshness decay from plateau to floor
 *           Row 4: Out-of-range position scores zero
 *
 *         Rows 2 and 5 (multi-epoch emission accumulation) require the ReferenceGauge
 *         contract's Synthetix-style accumulator, which reads the Slipstream NFPM's
 *         tickSpacing-keyed position layout; validating accumulator behaviour against
 *         a V3-layout NFPM would require a V3-specific gauge variant and is left out
 *         of scope here. The scoring math exercised by rows 1, 3, 4 is the core
 *         structural content the framework introduces.
 */
interface IPancakeV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint32 feeProtocol,
        bool unlocked
    );
    function tickSpacing() external view returns (int24);
}

interface IPancakeV3NFPM {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
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
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
}

contract FrameworkBSCForkTest is Test {
    // --- BSC mainnet addresses ---
    address constant PCS_NFPM = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address constant POOL     = 0x36696169C63e42cd08ce11f5deeBbCeBae652050; // WBNB/USDT 500
    address constant WBNB     = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT     = 0x55d398326f99059fF775485246999027B3197955;
    uint24  constant FEE      = 500;

    // Token ordering: USDT (0x55...) < WBNB (0xbb...), so token0 = USDT, token1 = WBNB
    address constant TOKEN0 = USDT;
    address constant TOKEN1 = WBNB;

    uint256 constant DECAY_PERIOD = 4 hours;

    IPancakeV3Pool pool;
    IPancakeV3NFPM nfpm;
    int24 tickSpacing;

    address alice = address(0xA11CE);

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        pool = IPancakeV3Pool(POOL);
        nfpm = IPancakeV3NFPM(PCS_NFPM);
        tickSpacing = pool.tickSpacing();

        // Both tokens are 18 decimals on BSC.
        deal(USDT, alice, 100_000e18);
        deal(WBNB, alice, 100 ether);

        vm.startPrank(alice);
        IERC20(WBNB).approve(PCS_NFPM, type(uint256).max);
        IERC20(USDT).approve(PCS_NFPM, type(uint256).max);
        vm.stopPrank();
    }

    function _align(int24 t) internal view returns (int24) {
        int24 r = t % tickSpacing;
        if (r < 0) return t - r - tickSpacing;
        return t - r;
    }

    function _mint(int24 tickLower, int24 tickUpper, uint256 usdtAmt, uint256 wbnbAmt)
        internal
        returns (uint256 tokenId, uint128 liquidity)
    {
        vm.prank(alice);
        (tokenId, liquidity,,) = nfpm.mint(
            IPancakeV3NFPM.MintParams({
                token0: TOKEN0,
                token1: TOKEN1,
                fee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: usdtAmt,
                amount1Desired: wbnbAmt,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp + 300
            })
        );
    }

    /// @notice Compute score using the paper's libraries directly, given a live PCS V3
    ///         position's geometry and liquidity.
    function _scoreOf(uint256 tokenId, uint64 depositTime) internal view returns (uint256) {
        (, , , , , int24 tl, int24 tu, uint128 liq,,,,) = nfpm.positions(tokenId);
        if (liq == 0) return 0;

        (, int24 tick,,,,,) = pool.slot0();
        bool inRange = tick >= tl && tick < tu;

        uint256 c = ConcentrationMath.concentrationFactor(tl, tu, tickSpacing);
        uint256 f = FreshnessMath.freshnessFactor(depositTime, block.timestamp, DECAY_PERIOD);

        return ConcentrationMath.emissionScore(liq, c, f, inRange);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 1: Tight position scores higher than wide per unit capital
    // ═══════════════════════════════════════════════════════════════════════════

    function test_BSC_TightRangeScoresHigher() public {
        console2.log("=== BSC ROW 1: Concentration Term ===");
        console2.log("  Chain: BSC (no Flashblocks, 0.45s native blocks)");

        (, int24 tick,,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint64 depositTime = uint64(block.timestamp);
        (uint256 tightId,) = _mint(base - tickSpacing, base + tickSpacing, 2000e18, 3 ether);
        (uint256 wideId,)  = _mint(base - 10 * tickSpacing, base + 10 * tickSpacing, 2000e18, 3 ether);

        // Warp past warmup so freshness reaches its plateau.
        vm.warp(block.timestamp + 30);

        uint256 tightScore = _scoreOf(tightId, depositTime);
        uint256 wideScore  = _scoreOf(wideId, depositTime);

        console2.log("  Tight score:", tightScore);
        console2.log("  Wide score: ", wideScore);
        require(wideScore > 0, "wide score is zero; check ranges");
        console2.log("  Ratio (tight / wide):", tightScore / wideScore);

        assertGt(tightScore, wideScore, "tight must score higher than wide on BSC");
        console2.log("  [PASS] Tight position scores higher on BSC (no Flashblocks)");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 3: Freshness decay on a BSC position
    // ═══════════════════════════════════════════════════════════════════════════

    function test_BSC_FreshnessDecay() public {
        console2.log("=== BSC ROW 3: Freshness Decay ===");

        (, int24 tick,,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint64 depositTime = uint64(block.timestamp);
        (uint256 id,) = _mint(base - tickSpacing, base + tickSpacing, 2000e18, 3 ether);

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
        console2.log("  [PASS] Freshness decay on BSC matches paper schedule");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 4: Out-of-range position scores exactly zero
    // ═══════════════════════════════════════════════════════════════════════════

    function test_BSC_OutOfRangeEarnsNothing() public {
        console2.log("=== BSC ROW 4: In-Range Indicator ===");

        (, int24 tick,,,,,) = pool.slot0();
        int24 base = _align(tick);

        // Range far above current tick (entirely token0 = USDT).
        uint64 depositTime = uint64(block.timestamp);
        (uint256 id,) = _mint(base + 1000 * tickSpacing, base + 1002 * tickSpacing, 50_000e18, 0);

        // Past warmup: freshness would be non-zero, but the indicator should force score to 0.
        vm.warp(block.timestamp + 30);

        uint256 score = _scoreOf(id, depositTime);
        console2.log("  Out-of-range score:", score);

        assertEq(score, 0, "out-of-range position must score zero on BSC");
        console2.log("  [PASS] Out-of-range scores zero on BSC");
    }
}
