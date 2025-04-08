// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

///@notice Foundry Stuff
import {Test, console} from "forge-std/Test.sol";

///@notice Protocol Scripts
//Import the Scripts that will be used to deploy your protocol contracts E.g:
import { DeployScript } from "script/Deploy.s.sol";
import { HelperConfig } from "script/helpers/HelperConfig.s.sol";

///@notice Protocol Base Contracts
import { CLCCIPExample } from "src/CLCCIPExample.sol";

///@notice Chainlink helpers
import { CCIPLocalSimulator, LinkToken, IRouterClient, BurnMintERC677Helper } from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import { Client } from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

contract BaseTests is Test {    
    ///@notice Instantiate Protocol Contracts
    CLCCIPExample s_example;

    ///@notice Chainlink local instance
    CCIPLocalSimulator s_local;
    uint64 s_chainSelector;
    IRouterClient s_sourceRouter;
    LinkToken s_linkToken;
    BurnMintERC677Helper s_ccipBnM;

    //Addresses
    address constant s_owner = address(77);
    address constant s_user02 = address(2);
    address constant s_mockMainnetAddress = address(777);

    function setUp() public virtual {
        ///@notice Initialization of Chainlink Local
        s_local = new CCIPLocalSimulator();

        (
            s_chainSelector,
            s_sourceRouter,
            ,
            ,
            s_linkToken,
            s_ccipBnM,
        ) = s_local.configuration();

        ///@notice 2. As we are using CCIPLocalSimulator here, we will not use a script to deploy
        s_example = new CLCCIPExample(address(s_linkToken), address(s_sourceRouter), s_owner);
    }

    
}
