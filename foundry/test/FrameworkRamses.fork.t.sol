// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ConcentrationMath} from "../src/ConcentrationMath.sol";
import {FreshnessMath} from "../src/FreshnessMath.sol";

/**
 * @title FrameworkRamsesForkTest -- Corrective scoring function on a second ve(3,3)
 *        CL DEX on a separate non-Flashblocks chain.
 * @notice Forks Arbitrum One and validates the scoring function of Ryan (2026)
 *         "Constructive Gauges" against live Ramses V2 (Uniswap V3-family CL) state.
 * @dev    Ramses is the original Ramses-family ve(3,3) DEX on Arbitrum. Its CL
 *         implementation is a direct Uniswap V3 fork with standard NFPM interface
 *         (uint24 fee tier, V3-layout positions, uniswapV3MintCallback). Arbitrum
 *         uses Timeboost for MEV ordering (a 200ms express-lane auction), which is
 *         categorically different from Flashblocks -- Timeboost reorders within the
 *         sequencer's normal block cadence rather than broadcasting partial blocks
 *         ahead of settlement. Neither Arbitrum nor the Ramses codebase is related
 *         to Base, Aerodrome, Slipstream, or Flashblocks. Validating the scoring
 *         function here adds a second ve(3,3)-on-non-Flashblocks data point to the
 *         Thena FUSION result, spanning a different CL family (V3 vs Algebra
 *         Integral), different chain (Arbitrum vs BSC), and different codebase.
 *
 *         Contract interface verified on-chain via selector extraction from the
 *         deployed NFPM implementation (EIP-1967 proxy at
 *         0xAA277CB7914b7e5514946Da92cb9De332Ce610EF -> implementation
 *         0xac9d1dfa5483ebb06e623df31547b2a4dc8bf7ca):
 *           mint selector       0x88316456 (standard V3 with uint24 fee)
 *           positions selector  0x99fbab88 (standard V3 12-field return)
 */
interface IRamsesV2Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
    function tickSpacing() external view returns (int24);
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IRamsesNFPM {
    /// @notice Ramses uses a 12-field mint with a trailing veRamTokenId (0 = no VE
    ///         attachment). Selector 0xe6c620f0. The standard V3 11-field mint
    ///         selector 0x88316456 is present in the bytecode but reverts silently
    ///         in this deployment.
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
        uint256 veRamTokenId;
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

contract FrameworkRamsesForkTest is Test {
    address constant RAMSES_NFPM = 0xAA277CB7914b7e5514946Da92cb9De332Ce610EF;

    // Ramses V2 WETH/USDC 500-bps pool on Arbitrum (from factory.getPool)
    address constant POOL = 0x30AFBcF9458c3131A6d051C621E307E6278E4110;

    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // native USDC on Arbitrum

    uint256 constant DECAY_PERIOD = 4 hours;

    IRamsesV2Pool pool;
    IRamsesNFPM nfpm;
    int24 tickSpacing;
    uint24 fee;
    address token0;
    address token1;

    address alice = address(0xA11CE);

    function setUp() public {
        vm.createSelectFork(vm.envString("ARB_RPC_URL"));
        pool = IRamsesV2Pool(POOL);
        nfpm = IRamsesNFPM(RAMSES_NFPM);

        tickSpacing = pool.tickSpacing();
        fee = pool.fee();
        token0 = pool.token0();
        token1 = pool.token1();

        console2.log("  Pool token0:", token0);
        console2.log("  Pool token1:", token1);
        console2.log("  Fee:", uint256(fee));
        console2.log("  Tick spacing:", uint256(int256(tickSpacing)));

        // USDC on Arbitrum is 6 decimals, WETH is 18.
        deal(USDC, alice, 1_000_000e6);
        deal(WETH, alice, 1_000 ether);

        vm.startPrank(alice);
        IERC20(WETH).approve(RAMSES_NFPM, type(uint256).max);
        IERC20(USDC).approve(RAMSES_NFPM, type(uint256).max);
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
            IRamsesNFPM.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amt0,
                amount1Desired: amt1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: alice,
                deadline: block.timestamp + 300,
                veRamTokenId: 0
            })
        );
    }

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

    function test_Ramses_TightRangeScoresHigher() public {
        console2.log("=== RAMSES ROW 1: Concentration Term ===");
        console2.log("  Chain: Arbitrum One (ve(3,3), V3-family CL, no Flashblocks)");

        (, int24 tick,,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint64 depositTime = uint64(block.timestamp);

        // Pool is WETH/USDC. token0=WETH (18 dec), token1=USDC (6 dec).
        // ~2,300 USDC per 1 WETH currently; provide balanced amounts.
        (uint256 tightId,) = _mint(base - tickSpacing, base + tickSpacing, 5 ether, 12_000e6);
        (uint256 wideId,)  = _mint(base - 10 * tickSpacing, base + 10 * tickSpacing, 5 ether, 12_000e6);

        vm.warp(block.timestamp + 30);

        uint256 tightScore = _scoreOf(tightId, depositTime);
        uint256 wideScore  = _scoreOf(wideId, depositTime);

        console2.log("  Tight score:", tightScore);
        console2.log("  Wide score: ", wideScore);
        require(wideScore > 0, "wide score is zero");
        console2.log("  Ratio (tight / wide):", tightScore / wideScore);

        assertGt(tightScore, wideScore, "tight must score higher than wide on Ramses");
        console2.log("  [PASS] Tight scores higher on Ramses V2 (Arbitrum ve(3,3))");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 3: Freshness decay
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Ramses_FreshnessDecay() public {
        console2.log("=== RAMSES ROW 3: Freshness Decay ===");

        (, int24 tick,,,,,) = pool.slot0();
        int24 base = _align(tick);

        uint64 depositTime = uint64(block.timestamp);
        (uint256 id,) = _mint(base - tickSpacing, base + tickSpacing, 5 ether, 12_000e6);

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
        console2.log("  [PASS] Freshness decay on Ramses matches paper schedule");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ROW 4: Out-of-range position scores zero
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Ramses_OutOfRangeEarnsNothing() public {
        console2.log("=== RAMSES ROW 4: In-Range Indicator ===");

        (, int24 tick,,,,,) = pool.slot0();
        int24 base = _align(tick);

        // Range entirely above current tick -> provide only token0 (WETH).
        uint64 depositTime = uint64(block.timestamp);
        (uint256 id,) = _mint(
            base + 1000 * tickSpacing,
            base + 1002 * tickSpacing,
            5 ether,
            0
        );

        vm.warp(block.timestamp + 30);

        uint256 score = _scoreOf(id, depositTime);
        console2.log("  Out-of-range score:", score);

        assertEq(score, 0, "out-of-range position must score zero on Ramses");
        console2.log("  [PASS] Out-of-range scores zero on Ramses");
    }
}
