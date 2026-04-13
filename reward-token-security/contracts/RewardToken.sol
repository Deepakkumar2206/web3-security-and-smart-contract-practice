// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RewardToken
 * @dev SpinBattles reward token for battle winners
 *
 * Security improvements added:
 * - Prevent winner from being overwritten once set
 * - Restrict verifier changes to owner
 * - Prevent zero-address winner/verifier assignment
 * - Enforce maximum reward per battle
 * - Enforce daily claim limit
 * - Enforce total reward pool cap
 * - Validate balances before transfers
 */
contract RewardToken is ERC20, Ownable {
    // Mapping to track which address claimed rewards for each battle
    mapping(bytes32 => address) public claimedRewards;

    // Maximum token claim limit per battle
    uint256 public constant MAX_REWARD_PER_BATTLE = 1000 * 10 ** 18;

    // Daily token limit per address
    uint256 public constant DAILY_CLAIM_LIMIT = 2000 * 10 ** 18;

    // Global cap on all rewards distributed through the contract
    uint256 public constant MAX_TOTAL_REWARDS = 500000 * 10 ** 18;

    // Total tokens already distributed by the contract
    uint256 public totalRewarded;

    // Tracks the amount withdrawn by each address on the current day
    mapping(address => uint256) public dailyClaimed;

    // Tracks the day of the last withdrawal for each address
    mapping(address => uint256) public lastClaimDay;

    // The verifier is the only address allowed to approve battle results
    address public verifier;

    // Maps each battleId to the approved winner's address
    mapping(bytes32 => address) public approvedWinners;

    // Events
    event RewardClaimed(address indexed player, bytes32 indexed battleId, uint256 amount);
    event RewardDistributed(address indexed player, uint256 amount);
    event BattleWinnerSet(bytes32 indexed battleId, address indexed winner);
    event VerifierUpdated(address indexed oldVerifier, address indexed newVerifier);

    constructor() ERC20("SpinBattles Reward", "SBR") Ownable(msg.sender) {
        // Mint initial supply to contract owner
        _mint(msg.sender, 1_000_000 * 10 ** decimals());

        // Owner is the verifier by default
        verifier = msg.sender;
    }

    /**
     * @dev Only the verifier address can call this function
     * Winner can only be set once per battle
     */
    function setBattleWinner(bytes32 battleId, address winner) external {
        require(msg.sender == verifier, "Only verifier can set winners");
        require(winner != address(0), "Winner cannot be zero address");
        require(approvedWinners[battleId] == address(0), "Winner already set");

        approvedWinners[battleId] = winner;
        emit BattleWinnerSet(battleId, winner);
    }

    /**
     * @dev Owner can update verifier if needed
     */
    function setVerifier(address newVerifier) external onlyOwner {
        require(newVerifier != address(0), "Verifier cannot be zero address");

        address oldVerifier = verifier;
        verifier = newVerifier;

        emit VerifierUpdated(oldVerifier, newVerifier);
    }

    /**
     * @dev Claim reward for a battle
     */
    function claimReward(bytes32 battleId, uint256 amount) external {
        // Check if reward already claimed
        require(claimedRewards[battleId] == address(0), "Reward already claimed");

        // Verify caller is the approved winner
        require(approvedWinners[battleId] == msg.sender, "Caller is not the approved winner");

        // Validate amount
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= MAX_REWARD_PER_BATTLE, "Amount exceeds max reward per battle");

        // Enforce total reward cap
        require(totalRewarded + amount <= MAX_TOTAL_REWARDS, "Reward pool exceeded");

        // Verify owner has enough balance
        require(balanceOf(owner()) >= amount, "Insufficient owner balance");

        // Reset the daily limit if the player is claiming on a new day
        uint256 today = block.timestamp / 1 days;
        if (lastClaimDay[msg.sender] < today) {
            dailyClaimed[msg.sender] = 0;
            lastClaimDay[msg.sender] = today;
        }

        // Enforce daily claim limit
        require(
            dailyClaimed[msg.sender] + amount <= DAILY_CLAIM_LIMIT,
            "Daily claim limit exceeded"
        );

        // Update state before transfer
        claimedRewards[battleId] = msg.sender;
        dailyClaimed[msg.sender] += amount;
        totalRewarded += amount;

        _transfer(owner(), msg.sender, amount);

        emit RewardClaimed(msg.sender, battleId, amount);
    }

    /**
     * @dev Distribute rewards to multiple players
     * Only owner can call this
     */
    function distributeRewards(
        address[] calldata players,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(players.length == amounts.length, "Arrays length mismatch");
        require(players.length > 0, "Empty arrays not allowed");

        uint256 totalToDistribute = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            require(players[i] != address(0), "Player cannot be zero address");
            require(amounts[i] > 0, "Amount must be greater than zero");
            require(amounts[i] <= MAX_REWARD_PER_BATTLE, "Amount exceeds max reward per battle");

            totalToDistribute += amounts[i];
        }

        // Enforce total pool cap
        require(totalRewarded + totalToDistribute <= MAX_TOTAL_REWARDS, "Reward pool exceeded");

        // Verify owner balance before any transfer
        require(balanceOf(owner()) >= totalToDistribute, "Insufficient owner balance");

        for (uint256 i = 0; i < players.length; i++) {
            totalRewarded += amounts[i];
            _transfer(owner(), players[i], amounts[i]);
            emit RewardDistributed(players[i], amounts[i]);
        }
    }

    /**
     * @dev Returns the address that claimed the reward for a given battle.
     * Returns address(0) if the reward has not been claimed yet.
     */
    function isRewardClaimed(bytes32 battleId) external view returns (address) {
        return claimedRewards[battleId];
    }
}