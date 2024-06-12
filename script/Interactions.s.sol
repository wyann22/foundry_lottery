// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../src/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

//import
contract ChainlinkVRFSubscription is Script {
    uint96 public constant FUND_AMOUNT = 1 ether;
    uint256 private i_deployer;

    function setDeployer(uint256 deployer) external {
        i_deployer = deployer;
    }

    function run() external returns (uint64) {
        HelperConfig networkConfigHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = networkConfigHelper
            .getConfig();
        address vrfCoordinator = config.coordinator_address;
        uint64 subId = createSubscription(vrfCoordinator);
        console.log("coordinator address: ", vrfCoordinator);
        console.log("createSubscription subId: ", subId);
        fundSubscription(vrfCoordinator, subId, config.link);
        // address contractAddress = DevOpsTools.get_most_recent_deployment(
        //     "Raffle",
        //     block.chainid
        // );
        // addConsumer(vrfCoordinator, subId, contractAddress);
        return subId;
    }

    function createSubscription(address coordinator) public returns (uint64) {
        if (i_deployer == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(i_deployer);
        }
        uint64 subId = VRFCoordinatorV2Mock(coordinator).createSubscription();
        vm.stopBroadcast();
        return subId;
    }

    function fundSubscription(
        address coordinator,
        uint64 subId,
        address link
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(coordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                coordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function addConsumer(
        address coordinator,
        uint64 subId,
        address consumer
    ) public {
        if (i_deployer == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(i_deployer);
        }
        VRFCoordinatorV2Mock(coordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }
}
