///SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console } from "forge-std/Test.sol";

import { BaseTests } from "test/helpers/BaseTests.t.sol";

contract CLCCIPExampleTest is BaseTests {

    ///@notice function test if contract send and receive the message properly (generic test)
    function test_ccipCompleteFunctionality() public {
        vm.startPrank(s_owner);

        s_example.enableChain();
        s_example.manageAllowlistSourceChain(s_chainSelector, true);
        s_example.setAllowlistSender(s_chainSelector, address(s_example));

        vm.stopPrank();

        vm.prank(s_user02);
        s_example.createStudentCrossChainProfile(s_mockMainnetAddress);
    }
}