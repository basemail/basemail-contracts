// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "@forge-std-1.8.2/src/Script.sol";
import {console2} from "@forge-std-1.8.2/src/console2.sol";

import {BasemailAccount} from "src/BasemailAccount.sol";

contract Deploy is Script {
    function deploy() external {
        // Deploy BasemailAccount contract
        BasemailAccount basemailAccount = new BasemailAccount();
        console2.log("BasemailAccount deployed at:", address(basemailAccount));
    }
}