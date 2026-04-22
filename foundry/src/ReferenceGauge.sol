// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {INFPM} from "./interfaces/INFPM.sol";
import {ICLPool} from "./interfaces/ICLPool.sol";
import {ConcentrationMath} from "./ConcentrationMath.sol";
import {FreshnessMath} from "./FreshnessMath.sol";

/**
 * @title ReferenceGauge -- Constructive Gauges scoring-function reference
 * @notice Minimal reference gauge implementing the corrective scoring function
 *         S_i = L_i * c(w) * f(t - t_i) * 1[tau in range] from Ryan (2026)
 *         "Constructive Gauges", equation (eq:score).
 * @dev    Academic validation only. Implements exactly the scoring function and
 *         the minimal Synthetix-style accumulator required to reproduce the paper's
 *         numerical claims. Production features (keeper delegation, dust accounting,
 *         MEV protection, voting, rebalancing) are intentionally out of scope.
 *
 *         The gauge exposes a test-harness admin surface (setEmissionRate,
 *         setTotalScoreCache) with no access control. Any host-protocol deployment
 *         would wrap these behind governance.
 */
contract ReferenceGauge is IERC721Receiver {
    // ═══════════════════════════════════════════════════════════════════════════
    // IMMUTABLES
    // ═══════════════════════════════════════════════════════════════════════════

    ICLPool public immutable pool;
    INFPM public immutable nfpm;
    IERC20 public immutable emissionToken;
    int24 public immutable tickSpacing;
    uint256 public immutable decayPeriod;

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════

    struct Position {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint64 depositTime;
        uint256 rewardDebt; // rewardPerScoreStored at last update for this position
    }

    mapping(uint256 => Position) public positions;

    uint256 public emissionRate; // per-second, 1e18 scaled
    uint256 public rewardPerScoreStored; // cumulative reward per unit score (1e18)
    uint256 public lastUpdateTime;
    uint256 public totalScoreCache; // sum of scores across staked positions

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    event Deposit(uint256 indexed tokenId, address indexed owner, uint256 score);
    event Withdraw(uint256 indexed tokenId, address indexed owner, uint256 reward);
    event RewardClaim(uint256 indexed tokenId, address indexed owner, uint256 amount);

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════

    constructor(address _pool, address _nfpm, address _emissionToken, uint256 _decayPeriod) {
        pool = ICLPool(_pool);
        nfpm = INFPM(_nfpm);
        emissionToken = IERC20(_emissionToken);
        tickSpacing = ICLPool(_pool).tickSpacing();
        decayPeriod = _decayPeriod;
        lastUpdateTime = block.timestamp;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST-HARNESS ADMIN
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Set the emission rate (test harness only; no access control).
    function setEmissionRate(uint256 _rate) external {
        _updateAccumulator();
        emissionRate = _rate;
    }

    /// @notice Set the total-score cache (test harness only; no access control).
    /// @dev    Tests track which positions are staked externally and compute the
    ///         sum of their scoreOf() values, then call this to keep the accumulator
    ///         denominator accurate under freshness decay. Production gauges would
    ///         track incremental deltas on deposit/withdraw.
    function setTotalScoreCache(uint256 value) external {
        _updateAccumulator();
        totalScoreCache = value;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEWS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Instantaneous emission score of a staked position.
    function scoreOf(uint256 tokenId) public view returns (uint256) {
        Position memory p = positions[tokenId];
        if (p.liquidity == 0) return 0;

        (, int24 tick,,,,) = pool.slot0();
        bool inRange = tick >= p.tickLower && tick < p.tickUpper;
        if (!inRange) return 0;

        uint256 concFactor = ConcentrationMath.concentrationFactor(p.tickLower, p.tickUpper, tickSpacing);
        uint256 freshBps = FreshnessMath.freshnessFactor(p.depositTime, block.timestamp, decayPeriod);

        return ConcentrationMath.emissionScore(p.liquidity, concFactor, freshBps, true);
    }

    /// @notice Pending reward for a staked position.
    function pending(uint256 tokenId) external view returns (uint256) {
        Position memory p = positions[tokenId];
        if (p.owner == address(0)) return 0;
        uint256 rps = _currentRewardPerScore();
        uint256 score = scoreOf(tokenId);
        if (score == 0 || rps <= p.rewardDebt) return 0;
        return (score * (rps - p.rewardDebt)) / 1e18;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // USER ACTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Deposit an NFPM position into the gauge.
    /// @dev Enforces minimum width of 2 * tickSpacing (paper's reference parameter).
    function deposit(uint256 tokenId) external {
        require(positions[tokenId].owner == address(0), "Already deposited");

        (,,,, int24 ts, int24 tl, int24 tu, uint128 liq,,,,) = nfpm.positions(tokenId);
        require(ts == tickSpacing, "Wrong pool");
        require(tu > tl, "Invalid range");
        require(liq > 0, "No liquidity");
        require(uint256(int256(tu - tl)) >= uint256(int256(tickSpacing)) * 2, "Width below 2x tickSpacing");

        _updateAccumulator();

        nfpm.transferFrom(msg.sender, address(this), tokenId);

        positions[tokenId] = Position({
            owner: msg.sender,
            tickLower: tl,
            tickUpper: tu,
            liquidity: liq,
            depositTime: uint64(block.timestamp),
            rewardDebt: rewardPerScoreStored
        });

        emit Deposit(tokenId, msg.sender, scoreOf(tokenId));
    }

    /// @notice Claim accrued rewards without withdrawing the NFT.
    function claim(uint256 tokenId) external returns (uint256 reward) {
        Position storage p = positions[tokenId];
        require(p.owner == msg.sender, "Not owner");

        _updateAccumulator();

        uint256 score = scoreOf(tokenId);
        if (score > 0 && rewardPerScoreStored > p.rewardDebt) {
            reward = (score * (rewardPerScoreStored - p.rewardDebt)) / 1e18;
            p.rewardDebt = rewardPerScoreStored;
            if (reward > 0) emissionToken.transfer(msg.sender, reward);
        }

        emit RewardClaim(tokenId, msg.sender, reward);
    }

    /// @notice Withdraw the NFT and settle final rewards.
    function withdraw(uint256 tokenId) external returns (uint256 reward) {
        Position memory p = positions[tokenId];
        require(p.owner == msg.sender, "Not owner");

        _updateAccumulator();

        uint256 score = scoreOf(tokenId);
        if (score > 0 && rewardPerScoreStored > p.rewardDebt) {
            reward = (score * (rewardPerScoreStored - p.rewardDebt)) / 1e18;
            if (reward > 0) emissionToken.transfer(msg.sender, reward);
        }

        delete positions[tokenId];
        nfpm.transferFrom(address(this), msg.sender, tokenId);

        emit Withdraw(tokenId, msg.sender, reward);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNALS
    // ═══════════════════════════════════════════════════════════════════════════

    function _currentRewardPerScore() internal view returns (uint256) {
        if (totalScoreCache == 0) return rewardPerScoreStored;
        uint256 elapsed = block.timestamp - lastUpdateTime;
        return rewardPerScoreStored + (emissionRate * elapsed * 1e18) / totalScoreCache;
    }

    function _updateAccumulator() internal {
        rewardPerScoreStored = _currentRewardPerScore();
        lastUpdateTime = block.timestamp;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ERC721 RECEIVER
    // ═══════════════════════════════════════════════════════════════════════════

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
