//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol"; // Gives vm and console
import {frxETH} from "../src/frxETH.sol";
import {sfrxETH, ERC20} from "../src/sfrxETH.sol";
import {frxETHMinter, OperatorRegistry} from "../src/frxETHMinter.sol";

contract Deploy is Script {
    address constant OWNER_ADDRESS = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
    address constant TIMELOCK_ADDRESS = 0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA;

    address constant DEPOSIT_CONTRACT_ADDRESS = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
    bytes WITHDRAWAL_CREDENTIALS;
    uint32 constant REWARDS_CYCLE_LENGTH = 1000;

    function run() public {
        vm.startBroadcast();
        WITHDRAWAL_CREDENTIALS = vm.envBytes('VALIDATOR_MAINNET_WITHDRAWAL_CREDENTIALS');

        frxETH fe = new frxETH(OWNER_ADDRESS, TIMELOCK_ADDRESS);
        sfrxETH sfe = new sfrxETH(ERC20(address(fe)), REWARDS_CYCLE_LENGTH);
        frxETHMinter fem = new frxETHMinter(DEPOSIT_CONTRACT_ADDRESS, address(fe), address(sfe), OWNER_ADDRESS, TIMELOCK_ADDRESS, WITHDRAWAL_CREDENTIALS);
        
        // // Post deploy
        // fe.addMinter(address(fem));
        
        vm.stopBroadcast();
    }
}
