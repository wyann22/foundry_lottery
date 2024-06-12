// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle, Raffl__SendMoreToEnterRaffle, Raffi__UpkeepNotNeeded, Raffi__NotOpen} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    address public PLAYER = makeAddr("player");
    uint256 public PLAYER_BALANCE = 10 ether;
    HelperConfig.NetworkConfig public networkConfig;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, networkConfig) = deployRaffle.run();
        vm.deal(PLAYER, PLAYER_BALANCE);
    }

    function testConstructor() public view {
        assert(raffle.getEntranceFee() == networkConfig.entranceFee);
        assert(raffle.getInterval() == networkConfig.interval);
    }

    function testRaffleConstructor() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffle() public {
        // test revert when not paying
        vm.expectRevert(Raffl__SendMoreToEnterRaffle.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle();
        // test player recorded
        vm.prank(PLAYER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
        // test emited event
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.RaffleEnter(PLAYER);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        //raffle.enterRaffle{value: networkConfig.entranceFee}();
        //assert(raffle.getPlayers().length == 1);
    }

    function testPerformKeepUp() public {
        // test upkeep not needed
        vm.prank(PLAYER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffi__UpkeepNotNeeded.selector,
                networkConfig.entranceFee,
                1,
                0
            )
        );
        raffle.performUpkeep("");
    }

    function testCaculateState() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        // test caculate state
        vm.prank(raffle.owner());
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        VmSafe.Log[] memory events = vm.getRecordedLogs();
        bytes32 requestId = events[1].topics[1];
        assert(requestId > 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATE);
        // test enterRaffle NotOpen error
        vm.expectRevert(Raffi__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    function testCheckUpkeep() public {
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.prank(PLAYER);
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFullfillRandomWords(uint256 randomRequestId) public skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(networkConfig.coordinator_address)
            .fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testWholeProcess() public skipFork {
        uint32 player_num = 10;
        for (uint32 i = 1; i <= player_num; i++) {
            hoax(address(uint160(i)), PLAYER_BALANCE);
            raffle.enterRaffle{value: networkConfig.entranceFee}();
        }
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        VmSafe.Log[] memory events = vm.getRecordedLogs();
        bytes32 requestId = events[1].topics[1];
        VRFCoordinatorV2Mock(networkConfig.coordinator_address)
            .fulfillRandomWords(uint256(requestId), address(raffle));
        uint256 pool_money = player_num * networkConfig.entranceFee;
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(
            raffle.getRecentWinner().balance ==
                PLAYER_BALANCE + pool_money - networkConfig.entranceFee
        );
    }
}
