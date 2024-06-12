// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Enter the lottery (pay some amount)
// Pick a random winner (Chainlink verifiable random)
// Picking process repeat every X minutes(Chainlink keepers)

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {console} from "forge-std/Script.sol";
error Raffl__SendMoreToEnterRaffle();
error Raffi__TransactionFail();
error Raffi__NotOpen();
error Raffi__UpkeepNotNeeded(
    uint256 balance,
    uint256 numPlayers,
    uint256 raffleState
);

/**
 * @title A Raffle contract
 * @author wyann22
 * @notice This contract is for creating
 * @dev This implements Chainlink VRF and Chainlink Automation
 */

contract Raffle is
    VRFConsumerBaseV2,
    ConfirmedOwner,
    AutomationCompatibleInterface
{
    /* Types */
    enum RaffleState {
        OPEN,
        CALCULATE
    }
    /* State variables*/

    // Lottery variables
    uint256 private immutable i_entranceFee; // ETH
    address payable[] private s_players;
    address payable private s_recent_winner;
    RaffleState private s_raffleState;

    // Chainlink variables
    VRFCoordinatorV2Interface private immutable i_coordinator;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private constant c_gasLane =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint64 private immutable i_subscriptionId;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffileWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        address coordinator_address,
        uint32 callbackGasLimit,
        uint64 subscriptionId,
        uint256 interval
    ) VRFConsumerBaseV2(coordinator_address) ConfirmedOwner(msg.sender) {
        i_entranceFee = entranceFee;
        i_coordinator = VRFCoordinatorV2Interface(coordinator_address);
        i_callbackGasLimit = callbackGasLimit;
        i_subscriptionId = subscriptionId;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // simulated by chainlink off-chain network
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayer = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        bool res = isOpen && timePassed && hasPlayer && hasBalance;
        return (res, "0x0");
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = this.checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffi__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        this.requestRandomWinner();

        // We don't use the performData in this example. The performData is generated by the Automation Node's call to your checkUpkeep function
    }

    function requestRandomWinner() external {
        // Will revert if subscription is not set and funded.
        s_raffleState = RaffleState.CALCULATE;
        uint256 requestId = i_coordinator.requestRandomWords(
            c_gasLane,
            i_subscriptionId,
            3,
            i_callbackGasLimit,
            1
        );
        emit RequestedRaffileWinner(requestId);
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffl__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffi__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    // callback function
    function fulfillRandomWords(
        uint256,
        uint256[] memory randomWords
    ) internal override {
        uint256 randomWinnerIndex = randomWords[0] % s_players.length;
        s_recent_winner = s_players[randomWinnerIndex];
        (bool success, ) = s_recent_winner.call{value: address(this).balance}(
            ""
        );
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        if (!success) {
            revert Raffi__TransactionFail();
        }
        emit WinnerPicked(s_recent_winner);
    }

    function getRecentWinner() public view returns (address) {
        return s_recent_winner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
