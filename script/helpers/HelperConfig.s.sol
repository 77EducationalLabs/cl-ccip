// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { Vm } from "forge-std/Vm.sol";

/**
    *@title Configurations Helper
    *@notice Contract to store core information that will be used upon deployments
*/
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /**
        *@notice Struct to store base information for deployment
        * Update it with the variables you will need.
    */
    struct NetworkConfig {
        address admin;
        address multisig;
        address linkToken;
        address ccipRouter;
    }

    ///@notice Magic Number Removal
    uint256 constant LOCAL_CHAIN_ID = 31337;
    ///@notice Update with the chains you plan to use
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;

    ///@notice Local network state variables
    NetworkConfig public s_localNetworkConfig;
    ///@notice store the testnet/mainnet infos
    mapping(uint256 chainId => NetworkConfig) public s_networkConfigs;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HelperConfig__InvalidChainId();


    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() {
        ///@notice initialize Testnet/Mainnet only
        s_networkConfigs[BASE_SEPOLIA_CHAIN_ID] = getSepoliaBaseConfig();
        s_networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    /**
        *@notice Function to access chain configuration based on `chainId`
    */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    /**
        *@notice function to update information based on deployments happening on main scripts
        *@notice it will update base on chainId
    */
    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        s_networkConfigs[chainId] = networkConfig;
    }

    /**
        *@notice function to query chain information by chainId
        *@notice if it doesn't exist, it will create
    */
    function getConfigByChainId(uint256 _chainId) public returns (NetworkConfig memory) {
        if (_chainId != LOCAL_CHAIN_ID) {
            return s_networkConfigs[_chainId];
            ///@notice check for a specific part of your protocol that will not break the rest of the conditionals
        } else if(s_networkConfigs[_chainId].ccipRouter != address(0)) {
            return s_networkConfigs[_chainId];
        } else if (_chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        ///@notice update the values with the real values from the main network
        sepoliaNetworkConfig = NetworkConfig({
            ///@notice vm.envAddress("NAME_OF_THE_VARIABLE_ON_.ENV_FILE")
            admin: vm.envAddress("ADMIN_TESTNET_PUBLIC_KEY"),
            multisig: address(0),
            linkToken:  0x779877A7B0D9E8603169DdbD7836e478b4624789,
            ccipRouter:  0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
        });
    }

    function getSepoliaBaseConfig() public view returns (NetworkConfig memory sepoliaBaseNetworkConfig) {
        ///@notice update the values with the real values from the test network
        sepoliaBaseNetworkConfig = NetworkConfig({
            ///@notice vm.envAddress("NAME_OF_THE_VARIABLE_ON_.ENV_FILE")
            admin: vm.envAddress("ADMIN_TESTNET_PUBLIC_KEY"),
            multisig: address(0),
            linkToken:  0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
            ccipRouter:  0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {

        ///@notice deploy mocks, if needed. Like: Chainlink Routers, Feeds, etc.
        ///@notice add the deployed mock on the above config before calling it.
        s_localNetworkConfig = NetworkConfig({
            admin: address(77),
            multisig: address(777),
            linkToken:  address(0),
            ccipRouter:  address(0)
        });

        return s_localNetworkConfig;
    }
}