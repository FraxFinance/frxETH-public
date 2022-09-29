// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { DepositContract } from "../src/DepositContract.sol";
import { frxETHMinter, OperatorRegistry } from "../src/frxETHMinter.sol";
import { frxETH } from "../src/frxETH.sol";
import { sfrxETH, ERC20 } from "../src/sfrxETH.sol";

contract frxETHMinterTest is Test {
    frxETH frxETHToken;
    sfrxETH sfrxETHToken;
    frxETHMinter minter;

    address constant DEPOSIT_CONTRACT_ADDRESS = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address constant FRAX_COMPTROLLER = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
    address constant FRAX_TIMELOCK = 0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA;
    bytes[5] pubKeys;
    bytes[5] sigs;
    bytes32[5] ddRoots;
    bytes[5] withdrawalCreds;

    uint32 constant REWARDS_CYCLE_LENGTH = 1000;

    function setUp() public {
        // Make sure you are forking mainnet first
        require(block.chainid == 1, 'Need to fork ETH mainnet for this test');
        
        // Set some .env variables
        // Must be done at compile time due to .env loading)
        pubKeys = [vm.envBytes("VALIDATOR_TEST_PUBKEY1"), vm.envBytes("VALIDATOR_TEST_PUBKEY2"), vm.envBytes("VALIDATOR_TEST_PUBKEY3"), vm.envBytes("VALIDATOR_TEST_PUBKEY4"), vm.envBytes("VALIDATOR_TEST_PUBKEY5")];
        sigs = [vm.envBytes("VALIDATOR_TEST_SIG1"), vm.envBytes("VALIDATOR_TEST_SIG2"), vm.envBytes("VALIDATOR_TEST_SIG3"), vm.envBytes("VALIDATOR_TEST_SIG4"), vm.envBytes("VALIDATOR_TEST_SIG5")];
        ddRoots = [vm.envBytes32("VALIDATOR_TEST_DDROOT1"), vm.envBytes32("VALIDATOR_TEST_DDROOT2"), vm.envBytes32("VALIDATOR_TEST_DDROOT3"), vm.envBytes32("VALIDATOR_TEST_DDROOT4"), vm.envBytes32("VALIDATOR_TEST_DDROOT5")];
        withdrawalCreds = [vm.envBytes("VALIDATOR_TEST_WITHDRAWAL_CREDENTIALS1"), vm.envBytes("VALIDATOR_TEST_WITHDRAWAL_CREDENTIALS2"), vm.envBytes("VALIDATOR_TEST_WITHDRAWAL_CREDENTIALS3"), vm.envBytes("VALIDATOR_TEST_WITHDRAWAL_CREDENTIALS4"), vm.envBytes("VALIDATOR_TEST_WITHDRAWAL_CREDENTIALS5")];

        // Instantiate the new contracts
        frxETHToken = new frxETH(FRAX_COMPTROLLER, FRAX_TIMELOCK);
        sfrxETHToken = new sfrxETH(ERC20(address(frxETHToken)), REWARDS_CYCLE_LENGTH);
        minter = new frxETHMinter(DEPOSIT_CONTRACT_ADDRESS, address(frxETHToken), address(sfrxETHToken), FRAX_COMPTROLLER, FRAX_TIMELOCK, withdrawalCreds[1]);
        
        // Add the new frxETHMinter as a minter for frxETH
        vm.startPrank(FRAX_COMPTROLLER);
        frxETHToken.addMinter(address(minter));
        vm.stopPrank();
    }
    
    function testAddKey() public {
        vm.startPrank(FRAX_COMPTROLLER);
        
        // Add a validator
        minter.addValidator(OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));

        vm.stopPrank();
    }

    function testBatchAdd() public {
        vm.startPrank(FRAX_COMPTROLLER);

        // Add two validators to an array
        OperatorRegistry.Validator[] memory validators = new OperatorRegistry.Validator[](2);
        validators[0] = (OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));
        validators[1] = (OperatorRegistry.Validator(pubKeys[1], sigs[1], ddRoots[1]));

        // Prep the emit for the 1st validator to be checked
        vm.expectEmit(false, false, false, true);
        emit ValidatorAdded(pubKeys[0], withdrawalCreds[0]);
        
        // Prep the emit for the 2nd validator to be checked
        vm.expectEmit(false, false, false, true);
        emit ValidatorAdded(pubKeys[1], withdrawalCreds[1]);

        // Add both validators
        minter.addValidators(validators);

        vm.stopPrank();
    }

    function testSwapValidator() public {
        vm.startPrank(FRAX_COMPTROLLER);

        // Add three validators to an array
        OperatorRegistry.Validator[] memory validators = new OperatorRegistry.Validator[](3);
        validators[0] = (OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));
        validators[1] = (OperatorRegistry.Validator(pubKeys[1], sigs[1], ddRoots[1]));
        validators[2] = (OperatorRegistry.Validator(pubKeys[2], sigs[2], ddRoots[2]));

        // Add all 3 validators
        minter.addValidators(validators);

        // Swap the 0th validator with the 2nd one
        vm.expectEmit(true, true, true, true);
        emit ValidatorsSwapped(pubKeys[0], pubKeys[2], 0, 2);
        minter.swapValidator(0, 2);

        // Check the array itself too
        (bytes memory pubKeyNew0, , , ) = minter.getValidator(0);
        (bytes memory pubKeyNew2, , , ) = minter.getValidator(2);
        assertEq(pubKeyNew0, pubKeys[2]);
        assertEq(pubKeyNew2, pubKeys[0]);

        vm.stopPrank();
    }

    function testPopValidators() public {
        vm.startPrank(FRAX_COMPTROLLER);

        // Add three validators to an array
        OperatorRegistry.Validator[] memory validators = new OperatorRegistry.Validator[](3);
        validators[0] = (OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));
        validators[1] = (OperatorRegistry.Validator(pubKeys[1], sigs[1], ddRoots[1]));
        validators[2] = (OperatorRegistry.Validator(pubKeys[2], sigs[2], ddRoots[2]));

        // Add all 3 validators
        minter.addValidators(validators);

        // Pop two of them off
        vm.expectEmit(true, false, false, true);
        emit ValidatorsPopped(2);
        minter.popValidators(2);

        // Check the array itself too
        uint256 new_length = minter.numValidators();
        assertEq(new_length, 1);

        vm.stopPrank();
    }

    function testRemoveValidatorDontCareAboutOrder() public {
        vm.startPrank(FRAX_COMPTROLLER);

        // Add five validators to an array
        OperatorRegistry.Validator[] memory validators = new OperatorRegistry.Validator[](5);
        validators[0] = (OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));
        validators[1] = (OperatorRegistry.Validator(pubKeys[1], sigs[1], ddRoots[1]));
        validators[2] = (OperatorRegistry.Validator(pubKeys[2], sigs[2], ddRoots[2]));
        validators[3] = (OperatorRegistry.Validator(pubKeys[3], sigs[3], ddRoots[3]));
        validators[4] = (OperatorRegistry.Validator(pubKeys[4], sigs[4], ddRoots[4]));

        // Add all 5 validators
        minter.addValidators(validators);

        // Get the info for the last validator (will be used later for a check)
        (bytes memory valOld4PubKey, , , ) = minter.getValidator(4);

        // Remove the validator at index 2, using the swap and pop method
        vm.expectEmit(false, false, false, true);
        emit ValidatorRemoved(pubKeys[2], 2, true);
        minter.removeValidator(2, true);

        // Check the array length to make sure it was reduced by 1
        uint256 new_length = minter.numValidators();
        assertEq(new_length, 4);

        // Check the array itself too
        // Validator at index 2 should be the one that used to be at the end (index 4)
        (bytes memory valNew2PubKey, , , ) = minter.getValidator(2);
        assertEq(valNew2PubKey, valOld4PubKey);

        vm.stopPrank();
    }

    function testRemoveValidatorKeepOrdering() public {
        vm.startPrank(FRAX_COMPTROLLER);

        // Add five validators to an array
        OperatorRegistry.Validator[] memory validators = new OperatorRegistry.Validator[](5);
        validators[0] = (OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));
        validators[1] = (OperatorRegistry.Validator(pubKeys[1], sigs[1], ddRoots[1]));
        validators[2] = (OperatorRegistry.Validator(pubKeys[2], sigs[2], ddRoots[2]));
        validators[3] = (OperatorRegistry.Validator(pubKeys[3], sigs[3], ddRoots[3]));
        validators[4] = (OperatorRegistry.Validator(pubKeys[4], sigs[4], ddRoots[4]));

        // Add all 5 validators
        minter.addValidators(validators);

        // Get the info for the 3rd and 4th validators (will be used later for a check)
        (bytes memory valOld3PubKey, , , ) = minter.getValidator(3);
        (bytes memory valOld4PubKey, , , ) = minter.getValidator(4);

        // Remove the validator at index 2, using the gassy loop method
        // This preserves the ordering
        vm.expectEmit(false, false, false, true);
        emit ValidatorRemoved(pubKeys[2], 2, false);
        minter.removeValidator(2, false);

        // Check the array length to make sure it was reduced by 1
        uint256 new_length = minter.numValidators();
        assertEq(new_length, 4);

        // Check the array itself too
        // Validator at index 3 should now be at index 2
        // Validator at index 4 should now be at index 3
        (bytes memory valNew2PubKey, , , ) = minter.getValidator(2);
        (bytes memory valNew3PubKey, , , ) = minter.getValidator(3);
        assertEq(valNew2PubKey, valOld3PubKey);
        assertEq(valNew3PubKey, valOld4PubKey);

        vm.stopPrank();
    }

    function testSubmitAndDepositEther() public {
        vm.startPrank(FRAX_COMPTROLLER);
        
        // Add a validator
        minter.addValidator(OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));

        // Give the comptroller 320 ETH
        vm.deal(FRAX_COMPTROLLER, 320 ether);

        // Deposit 16 ETH for frxETH
        vm.expectEmit(true, true, false, true);
        emit TokenMinterMinted(address(minter), FRAX_COMPTROLLER, 16 ether);
        vm.expectEmit(true, true, false, true);
        emit ETHSubmitted(FRAX_COMPTROLLER, FRAX_COMPTROLLER, 16 ether, 0);
        minter.submit{ value: 16 ether }();

        // Deposit 15 ETH for frxETH, pure send (tests receive fallback)
        vm.expectEmit(true, true, false, true);
        emit TokenMinterMinted(address(minter), FRAX_COMPTROLLER, 15 ether);
        vm.expectEmit(true, true, false, true);
        emit ETHSubmitted(FRAX_COMPTROLLER, FRAX_COMPTROLLER, 15 ether, 0);
        address(minter).call{ value: 15 ether }("");

        // Try having the validator deposit.
        // Should fail due to lack of ETH
        vm.expectRevert("Not enough ETH in contract");
        minter.depositEther(10);

        // Deposit last 1 ETH for frxETH, making the total 32.
        // Uses submitAndGive as an alternate method. Timelock will get the frxETH but the validator doesn't care
        vm.expectEmit(true, true, false, true);
        emit TokenMinterMinted(address(minter), FRAX_TIMELOCK, 1 ether);
        vm.expectEmit(true, true, false, true);
        emit ETHSubmitted(FRAX_COMPTROLLER, FRAX_TIMELOCK, 1 ether, 0);
        minter.submitAndGive{ value: 1 ether }(FRAX_TIMELOCK);
        
        // Move the 32 ETH to the validator
        minter.depositEther(10);

        // Try having the validator deposit another 32 ETH.
        // Should fail due to lack of ETH
        vm.expectRevert("Not enough ETH in contract");
        minter.depositEther(10);

        // Deposit 32 ETH for frxETH
        minter.submit{ value: 32 ether }();

        // Try having the validator deposit another 32 ETH.
        // Should fail due to lack of a free validator
        vm.expectRevert("Validator stack is empty");
        minter.depositEther(10);

        // Pause submits
        minter.togglePauseSubmits();

        // Try submitting while paused (should fail)
        vm.expectRevert("Submit is paused");
        minter.submit{ value: 1 ether }();

        // Unpause submits
        minter.togglePauseSubmits();

        // Pause validator ETH deposits
        minter.togglePauseDepositEther();

        // Try submitting while paused (should fail)
        vm.expectRevert("Depositing ETH is paused");
        minter.depositEther(10);

        // Unpause validator ETH deposits
        minter.togglePauseDepositEther();

        // Add another validator
        minter.addValidator(OperatorRegistry.Validator(pubKeys[1], sigs[1], ddRoots[1]));

        // Should finally work again
        minter.depositEther(10);

        vm.stopPrank();
    }

    function testWithheldEth() public {
        vm.startPrank(FRAX_COMPTROLLER);
        
        // Add a validator
        minter.addValidator(OperatorRegistry.Validator(pubKeys[0], sigs[0], ddRoots[0]));

        // Give the comptroller 320 ETH
        vm.deal(FRAX_COMPTROLLER, 320 ether);

        // Set the withhold ratio to 50% (5e5)
        minter.setWithholdRatio(500000);

        // Deposit 32 ETH for frxETH
        vm.expectEmit(true, true, false, true);
        emit TokenMinterMinted(address(minter), FRAX_COMPTROLLER, 32 ether);
        vm.expectEmit(true, true, false, true);
        emit ETHSubmitted(FRAX_COMPTROLLER, FRAX_COMPTROLLER, 32 ether, 16 ether);
        minter.submit{ value: 32 ether }();

        // Check that 16 ether was withheld
        assertEq(minter.currentWithheldETH(), 16 ether);

        // Try having the validator deposit.
        // Should fail due to lack of ETH because half of it was withheld
        vm.expectRevert("Not enough ETH in contract");
        minter.depositEther(10);

        // Deposit another 32 ETH for frxETH. 
        // 16 ETH will be withheld and the other 16 ETH will be available for the validator
        vm.expectEmit(true, true, false, true);
        emit TokenMinterMinted(address(minter), FRAX_COMPTROLLER, 32 ether);
        vm.expectEmit(true, true, false, true);
        emit ETHSubmitted(FRAX_COMPTROLLER, FRAX_COMPTROLLER, 32 ether, 16 ether);
        minter.submit{ value: 32 ether }();
        
        // Move the 32 ETH to the validator. Should work now because 16 + 16 = 32
        minter.depositEther(10);

        // Set the withhold ratio back to 0
        minter.setWithholdRatio(0);

        // Deposit 32 ETH for frxETH
        vm.expectEmit(true, true, false, true);
        emit TokenMinterMinted(address(minter), FRAX_COMPTROLLER, 32 ether);
        vm.expectEmit(true, true, false, true);
        emit ETHSubmitted(FRAX_COMPTROLLER, FRAX_COMPTROLLER, 32 ether, 0);
        minter.submit{ value: 32 ether }();

        // Add another validator
        minter.addValidator(OperatorRegistry.Validator(pubKeys[1], sigs[1], ddRoots[1]));

        // Move the 32 ETH to the validator. Should work immediately
        minter.depositEther(10);

        vm.stopPrank();
    }

    function testRecoverEther() public {
        vm.startPrank(FRAX_COMPTROLLER);

        // Note the starting ETH balance of the comptroller
        uint256 starting_eth = FRAX_COMPTROLLER.balance;

        // Give minter 10 eth
        vm.deal(address(minter), 10 ether);

        // Recover 5 ETH 
        vm.expectEmit(false, false, false, true);
        emit EmergencyEtherRecovered(5 ether);
        minter.recoverEther(5 ether);

        // Make sure the FRAX_COMPTROLLER got 5 ether back
        assertEq(FRAX_COMPTROLLER.balance, starting_eth + (5 ether));

        vm.stopPrank();
    }

    function testRecoverERC20() public {
        vm.startPrank(FRAX_COMPTROLLER);

        // Note the starting ETH balance of the comptroller
        uint256 starting_frxETH = frxETHToken.balanceOf(FRAX_COMPTROLLER);

        // Deposit 5 ETH for frxETH first
        vm.expectEmit(true, true, true, true);
        emit TokenMinterMinted(address(minter), FRAX_COMPTROLLER, 5 ether);
        minter.submit{ value: 5 ether }();

        // Throw the newly minted frxETH into the minter "by accident"
        frxETHToken.transfer(address(minter), 5 ether);

        // Get the intermediate frxETH balance of the comptroller
        uint256 intermediate_frxETH = frxETHToken.balanceOf(FRAX_COMPTROLLER);

        // Make sure you are back to where you started from, frxETH balance wise
        assertEq(starting_frxETH, intermediate_frxETH);

        // Recover 5 frxETH 
        vm.expectEmit(false, false, false, true);
        emit EmergencyERC20Recovered(address(frxETHToken), 5 ether);
        minter.recoverERC20(address(frxETHToken), 5 ether);

        // Get the ending frxETH balance of the comptroller
        uint256 ending_frxETH = frxETHToken.balanceOf(FRAX_COMPTROLLER);

        // Make sure the FRAX_COMPTROLLER got 5 frxETH back
        assertEq(ending_frxETH, starting_frxETH + (5 ether));

        vm.stopPrank();
    }

    event EmergencyEtherRecovered(uint256 amount);
    event EmergencyERC20Recovered(address tokenAddress, uint256 tokenAmount);
    event ETHSubmitted(address indexed sender, address indexed recipient, uint256 sent_amount, uint256 withheld_amt);
    event TokenMinterMinted(address indexed sender, address indexed to, uint256 amount);
    event ValidatorAdded(bytes pubKey, bytes withdrawalCredential);
    event ValidatorRemoved(bytes pubKey, uint256 remove_idx, bool dont_care_about_ordering);
    event ValidatorsSwapped(bytes from_pubKey, bytes to_pubKey, uint256 from_idx, uint256 to_idx);
    event ValidatorsPopped(uint256 times);
}
