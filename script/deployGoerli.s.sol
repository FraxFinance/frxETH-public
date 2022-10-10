//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol"; // Gives vm and console
import {frxETH} from "../src/frxETH.sol";
import {sfrxETH, ERC20} from "../src/sfrxETH.sol";
import {frxETHMinter, OperatorRegistry} from "../src/frxETHMinter.sol";

contract Deploy is Script {
    // Combo
    address constant OWNER_ADDRESS = 0x3CE4d19C155D977B04C8560Ed1Cc9C6F38Ee3d32;
    address constant TIMELOCK_ADDRESS = 0xf4E1d185666a624099298FcC42C50ba662DC7e52;

    // // TRAVIS'S UI TESTS
    // address constant OWNER_ADDRESS = 0x4600D3b12c39AF925C2C07C487d31D17c1e32A35; // Ropsten[0], but on Goerli
    // address constant TIMELOCK_ADDRESS = 0xBA079bE8f77c8c989cC5A575e8fd010EFc8EE484; // Ropsten[1], but on Goerli

    address constant DEPOSIT_CONTRACT_ADDRESS = 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b; //TESTNET
    bytes WITHDRAWAL_CREDENTIALS;
    uint32 constant REWARDS_CYCLE_LENGTH = 604800;

    function run() public {
        vm.startBroadcast();
        WITHDRAWAL_CREDENTIALS = vm.envBytes('VALIDATOR_TEST_WITHDRAWAL_CREDENTIALS0');

        frxETH fe = new frxETH(OWNER_ADDRESS, TIMELOCK_ADDRESS);
        sfrxETH sfe = new sfrxETH(ERC20(address(fe)), REWARDS_CYCLE_LENGTH);
        frxETHMinter fem = new frxETHMinter(DEPOSIT_CONTRACT_ADDRESS, address(fe), address(sfe), OWNER_ADDRESS, TIMELOCK_ADDRESS, WITHDRAWAL_CREDENTIALS);
        
        // Post deploy
        // fe.addMinter(address(fem));
        
        vm.stopBroadcast();
    }
}
