//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

error Raffle__NotEnoughETH();
error Raffle__TransferFailed();
error Raffle__NotOpen();

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

    // Lotery variable
    address payable s_recentWinner;
    State private s_state;

    // Events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_state = State.OPEN;
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

    function requestRandomWinner() external {
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint256 randomWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[randomWinner];
        s_recentWinner = recentWinner;
        (bool sent, ) = recentWinner.call{value: address(this).balance}("");

        if (!sent) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
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
        bytes calldata /* checkData */
    )
        external
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {}

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
