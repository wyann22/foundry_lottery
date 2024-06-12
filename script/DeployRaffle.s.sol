// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ChainlinkVRFSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run()
        external
        returns (Raffle, HelperConfig.NetworkConfig memory)
    {
        HelperConfig networkConfigHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = networkConfigHelper
            .getConfig();
        uint64 subscriptionId = config.subscriptionId;
        ChainlinkVRFSubscription subscriptionHelper = new ChainlinkVRFSubscription();
        subscriptionHelper.setDeployer(config.deployer);
        if (subscriptionId == 0) {
            subscriptionId = subscriptionHelper.createSubscription(
                config.coordinator_address
            );
            subscriptionHelper.fundSubscription(
                config.coordinator_address,
                subscriptionId,
                config.link
            );
        }
        console.log("create subsription:", subscriptionId);
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.coordinator_address,
            config.callbackGasLimit,
            subscriptionId,
            config.interval
        );
        vm.stopBroadcast();
        subscriptionHelper.addConsumer(
            config.coordinator_address,
            subscriptionId,
            address(raffle)
        );
        return (raffle, config);
    }
}
