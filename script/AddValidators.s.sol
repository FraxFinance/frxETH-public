//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol"; // Gives vm and console
import { frxETHMinter, OperatorRegistry } from "../src/frxETHMinter.sol";

contract AddValidators is Script {

    OperatorRegistry.Validator[] public vals;

    function run() public {
        vm.startBroadcast();
        frxETHMinter fem = frxETHMinter(payable(0x6421d1Ca6Cd35852362806a2Ded2A49b6fa8bEF5));
								
        vals.push(OperatorRegistry.Validator(
            vm.envBytes("VALIDATOR_GOERLI_PUBKEY1"),
            vm.envBytes("VALIDATOR_GOERLI_SIG1"),
        	vm.envBytes32("VALIDATOR_GOERLI_DDROOT1")
        ));
        
        vals.push(OperatorRegistry.Validator(
            vm.envBytes("VALIDATOR_GOERLI_PUBKEY2"),
            vm.envBytes("VALIDATOR_GOERLI_SIG2"),
        	vm.envBytes32("VALIDATOR_GOERLI_DDROOT2")
        ));

        fem.addValidators(vals);
        
        vm.stopBroadcast();
    }
}
