// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ShieldedETH} from "../src/ShieldedETH.sol";

contract ShieldedETHScript is Script {
    ShieldedETH public shieldedETH;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVKEY");
        vm.startBroadcast(deployerPrivateKey);

        shieldedETH = new ShieldedETH();
        console.log("ShieldedETH deployed at:", address(shieldedETH));

        vm.stopBroadcast();
    }
}
