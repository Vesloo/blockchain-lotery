//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Imports
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

// Errors
error Raffle__NotEnoughETH();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle_UpkeepError(uint256 balance, uint256 nb_players, uint256 state);

/**
 * @title Raffle Casino
 * @author Wesley Pigny
 * @notice Raffle is a decentralized lottery where the winner is chosen randomly like a casino.
 * @dev This implements chainlink VRF v2 and chainlink keeper.
 */
abstract contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    // Type declarations
    enum State {
        OPEN,
        CALCULATING
    }

    // State variables
    address payable[] public s_players;
    uint256 public immutable i_entranceFee;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    // Lottery variable
    address payable s_recentWinner;
    State private s_state;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    // Events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_state = State.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    // We want the user to enter the raffle.
    function enter() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETH();
        }
        if (s_state != State.OPEN) {
            revert Raffle__NotOpen();
        }

        // We want to add the address of the caller to the list of participants.
        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle_UpkeepError(
                address(this).balance,
                s_players.length,
                uint256(s_state)
            );
        }

        s_state = State.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev This is the checkUpkeep method
     * This method look at the "upkeepNeeded" and return true
     * The following should be true in order to return true.
     * 1. Our time interval should have passed
     * 2. We need to have at least one player in the Raffle and have some ETH
     * 3. Our subscription is funded with LINK
     * 4. The lotery should be in an active state
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = s_state == State.OPEN;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint256 randomWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[randomWinner];
        s_recentWinner = recentWinner;
        s_state = State.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool sent, ) = recentWinner.call{value: address(this).balance}("");

        if (!sent) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    // View / pure functions
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getState() public view returns (State) {
        return s_state;
    }

    function getTotalPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getNbWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }
}
