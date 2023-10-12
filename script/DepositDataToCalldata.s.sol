// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/*/////////////////////////////////////////////////////////////////////////////////////////
    DepositDataToCalldata.s.sol
    Foundry script for parsing a deposit_data.json file from staking-deposit-cli
        into transaction data for OperatorRegistry.addValidators()
    staking-deposit-cli: https://github.com/ethereum/staking-deposit-cli
    Foundry Json reference: https://book.getfoundry.sh/cheatcodes/parse-json

    Authored by Jack Corddry: https://github.com/corddry
    Frax Finance: https://github.com/FraxFinance

    Usage:
        1. Specify the path to your deposit_data.json in your .env as DEPOSIT_DATA_PATH
        2. $ source .env
        3. $ forge script --no-auto-detect script/DepositDataToCalldata.s.sol --sig "run(uint256 startIdx, uint256 count)" 0 50
        4. Use the final log output as data in a transaction to the frxETHMinter
        5. Test with "cd node-scripts" then "tsx validate-msig-add-validators.ts"
/////////////////////////////////////////////////////////////////////////////////////////*/

import { stdJson } from "forge-std/StdJson.sol";
import { Script } from "forge-std/Script.sol"; 
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { frxETHMinter, OperatorRegistry } from "../src/frxETHMinter.sol";


contract DepositDataToCalldata is Script, Test {
    using stdJson for string;

    OperatorRegistry.Validator[] public validators;

    function run() public { 
        this.run(0, 100000);
    }
    
    function run(uint256 startIdx, uint256 count) public { 
        console.log("startIdx: ", startIdx);
        console.log("count: ", count);
        string memory target = vm.envString("DEPOSIT_DATA_PATH");
        string memory json = vm.readFile(target);

        for(uint i = startIdx; i < (startIdx + count); i++) {
            // Build Json query string using i to access ith validator

            // EXAMPLE QUERY SYNTAX https://crates.io/crates/jsonpath-rust
            // DO NOT ADD $. HERE!!! IT will do it automatically
            string memory baseQuery = string.concat("[", vm.toString(i));

            // First query to see if there's Json at i at all
            string memory rawQuery = string.concat(baseQuery, "]");
            console.log("rawQuery: ", rawQuery);
            bytes memory raw = json.parseRaw(rawQuery);

            // Ends if the Json has ran out
            if (raw.length == 0) {
                break;
            }
            // Finish building queries for necessary deposit parameters
            string memory pkQuery = string.concat(baseQuery, "].pubkey");
            string memory sigQuery = string.concat(baseQuery, "].signature");
            string memory ddrQuery = string.concat(baseQuery, "].deposit_data_root"); 

            // Read values & parse as bytes
            bytes memory pubkey = vm.parseBytes(json.readString(pkQuery));
            bytes memory signature = vm.parseBytes(json.readString(sigQuery));
            bytes32 depDataRoot = vm.parseBytes32(json.readString(ddrQuery));

            // Log validator parameters
            emit log("\nValidator added:");
            emit log_named_uint("Index", i);
            emit log_named_bytes("Pubkey", pubkey);
            emit log_named_bytes("Signature", signature);
            emit log_named_bytes32("Deposit Data Root", depDataRoot);

            // Push validator struct onto stack
            validators.push(OperatorRegistry.Validator(
                pubkey,
                signature,
                depDataRoot
            ));
        }
        // Output the calldata for addValidators 
        emit log("\nEncoded addValidators transaction data: ");
        emit logs(abi.encodeWithSignature("addValidators((bytes,bytes,bytes32)[])", validators));
    }
}
