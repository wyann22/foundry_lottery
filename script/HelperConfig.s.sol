// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../src/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        address coordinator_address;
        uint32 callbackGasLimit;
        uint64 subscriptionId;
        uint256 interval;
        address link;
        uint256 deployer;
    }
    NetworkConfig public currentNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            currentNetworkConfig = getSepoliaConfig();
        } else {
            currentNetworkConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                coordinator_address: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                callbackGasLimit: 500000,
                subscriptionId: 11822,
                interval: 30,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployer: vm.envUint("PRIVATE_KEY")
            });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (currentNetworkConfig.coordinator_address != address(0)) {
            return currentNetworkConfig;
        }
        vm.startBroadcast();
        VRFCoordinatorV2Mock mock = new VRFCoordinatorV2Mock(0.25 ether, 1e9);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                coordinator_address: address(mock),
                callbackGasLimit: 500000,
                subscriptionId: 0,
                interval: 30,
                link: address(link),
                deployer: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            });
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return currentNetworkConfig;
    }
}
