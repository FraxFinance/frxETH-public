// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

// import { DSTestPlus } from "solmate/test/utils/DSTestPlus.sol";
import { Test } from "forge-std/Test.sol";
import { frxETH } from "../src/frxETH.sol";
import { sfrxETH, ERC20 } from "../src/sfrxETH.sol";
import { frxETHMinter } from "../src/frxETHMinter.sol";
import { SigUtils } from "../src/Utils/SigUtils.sol";

contract xERC4626Test is Test {
    sfrxETH sfrxETHtoken;
    frxETH frxETHtoken;
    frxETHMinter frxETHMinterContract;
    SigUtils internal sigUtils_frxETH;
    SigUtils internal sigUtils_sfrxETH;

    // For EIP-712 testing
    // https://book.getfoundry.sh/tutorials/testing-eip712
    uint256 internal ownerPrivateKey;
    uint256 internal spenderPrivateKey;
    address payable internal owner;
    address internal spender;
    bytes internal WITHDRAWAL_CREDENTIALS;

    address fraxComptroller = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
    address fraxTimelock = 0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA;
    address frxETHMinterEOA = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27; // Placeholder, == timelock
    address depositContract = 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b;
    
    
    function setUp() public {
        vm.warp(0); // Fuzz fails without!!
        
        // Set the withdrawal credentials (must be done at compile time due to .env loading)
        WITHDRAWAL_CREDENTIALS = vm.envBytes("VALIDATOR_TEST_WITHDRAWAL_CREDENTIALS0");

        // Deploy frxETH, sfrxETH
        frxETHtoken = new frxETH(fraxComptroller, fraxTimelock);
        sfrxETHtoken = new sfrxETH(ERC20(address(frxETHtoken)), 1000);
        frxETHMinterContract = new frxETHMinter(depositContract, address(frxETHtoken), address(sfrxETHtoken), fraxComptroller, fraxTimelock, WITHDRAWAL_CREDENTIALS);
        
        // Add the FRAX comptroller as an EOA/Multisig frxETH minter
        vm.prank(fraxComptroller);
        frxETHtoken.addMinter(frxETHMinterEOA);

        // Add the frxETHMinter contract as another frxETH minter
        vm.prank(fraxComptroller);
        frxETHtoken.addMinter(address(frxETHMinterContract));

        // For EIP-712 testing
        sigUtils_frxETH = new SigUtils(frxETHtoken.DOMAIN_SEPARATOR());
        sigUtils_sfrxETH = new SigUtils(sfrxETHtoken.DOMAIN_SEPARATOR());
        ownerPrivateKey = 0xA11CE;
        spenderPrivateKey = 0xB0B;
        owner = payable(vm.addr(ownerPrivateKey));
        spender = payable(vm.addr(spenderPrivateKey));
        
        //emit log_timestamp(block.timestamp);
        
    }
    event log_timestamp(uint256);

    function getQuickfrxETH() public {
        // Mint an initial test amount of frxETH to the owner
        vm.prank(fraxComptroller);
        frxETHtoken.minter_mint(owner, 1 ether); // 1 frxETH
        assertEq(frxETHtoken.balanceOf(owner), 1 ether);
    }

    // EIP-712 TESTS
    // ===========================================================
    // ------------------- frxETH -------------------

    // Test the permit for frxETH
    function test_frxETH_Permit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        assertEq(frxETHtoken.allowance(owner, spender), transfer_amount);
        assertEq(frxETHtoken.nonces(owner), 1);
    }

    function test_frxETH_TransferFromLimitedPermit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        frxETHtoken.transferFrom(owner, spender, transfer_amount);

        assertEq(frxETHtoken.balanceOf(owner), 1 ether - transfer_amount);
        assertEq(frxETHtoken.balanceOf(spender), transfer_amount);
        assertEq(frxETHtoken.allowance(owner, spender), 0);
    }

    function test_frxETH_TransferFromMaxPermit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        // Permit max, but you will only use transfer_amount
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: type(uint256).max,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        frxETHtoken.transferFrom(owner, spender, transfer_amount);

        assertEq(frxETHtoken.balanceOf(owner), 1 ether - transfer_amount);
        assertEq(frxETHtoken.balanceOf(spender), transfer_amount);

        // Max allowances never decrease due to spending, per ERC20
        assertEq(frxETHtoken.allowance(owner, spender), type(uint256).max);
    }

    function testFail_frxETH_InvalidAllowance() public {
        // No fuzz needed: fixed amount
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 5e17, // only approve 0.5 here
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        frxETHtoken.transferFrom(owner, spender, 1 ether); // attempt to transfer 1 token, should fail
    }

    function testFail_frxETH_InvalidBalance(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        frxETHtoken.transferFrom(owner, spender, 2 ether); // attempt to transfer 2 tokens (owner only owns 1)
    }

    function testRevert_frxETH_ExpiredPermit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: frxETHtoken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.warp(1 days + 1 seconds); // fast forward one second past the deadline

        vm.expectRevert("ERC20Permit: expired deadline");
        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }

    function testRevert_frxETH_InvalidSigner(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: frxETHtoken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderPrivateKey, digest); // spender signs owner's approval

        vm.expectRevert("ERC20Permit: invalid signature");
        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }

    function testRevert_frxETH_InvalidNonce(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 1, // owner nonce stored on-chain is 0
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.expectRevert("ERC20Permit: invalid signature");
        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }

    function testRevert_frxETH_SignatureReplay(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.expectRevert("ERC20Permit: invalid signature");
        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }


    // ------------------- sfrxETH -------------------

    // Test the permit for sfrxETH
    function test_sfrxETH_Permit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        assertEq(sfrxETHtoken.allowance(owner, spender), transfer_amount);
        assertEq(sfrxETHtoken.nonces(owner), 1);
    }

    function test_sfrxETH_TransferFromLimitedPermit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        // Generate an initial test amount of sfrxETH to the owner
        vm.startPrank(owner);
        frxETHtoken.approve(address(sfrxETHtoken), transfer_amount);
        if (transfer_amount == 0) vm.expectRevert("ZERO_SHARES");
        sfrxETHtoken.deposit(transfer_amount, owner); // Mints sfrxETH to the owner
        if (transfer_amount == 0) return;

        assertEq(sfrxETHtoken.balanceOf(owner), transfer_amount);
        vm.stopPrank();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        sfrxETHtoken.transferFrom(owner, spender, transfer_amount);

        assertEq(sfrxETHtoken.balanceOf(owner), 0);
        assertEq(sfrxETHtoken.balanceOf(spender), transfer_amount);
        assertEq(sfrxETHtoken.allowance(owner, spender), 0);
    }

    function test_sfrxETH_TransferFromMaxPermit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        // Generate an initial test amount of sfrxETH to the owner
        vm.startPrank(owner);
        frxETHtoken.approve(address(sfrxETHtoken), transfer_amount);
        if (transfer_amount == 0) vm.expectRevert("ZERO_SHARES");
        sfrxETHtoken.deposit(transfer_amount, owner); // Mints sfrxETH to the owner
        if (transfer_amount == 0) return;
        assertEq(sfrxETHtoken.balanceOf(owner), transfer_amount);
        vm.stopPrank();

        // Permit max, but you will only use transfer_amount
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: type(uint256).max,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        sfrxETHtoken.transferFrom(owner, spender, transfer_amount);

        assertEq(sfrxETHtoken.balanceOf(owner), 0);
        assertEq(sfrxETHtoken.balanceOf(spender), transfer_amount);

        // Max allowances never decrease due to spending, per ERC20
        assertEq(sfrxETHtoken.allowance(owner, spender), type(uint256).max);
    }

    function testFail_sfrxETH_InvalidAllowance() public {
        // No fuzz needed: fixed amount

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 5e17, // approve only 0.5 tokens
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        sfrxETHtoken.transferFrom(owner, spender, 1 ether); // attempt to transfer 1 token
    }

    function testFail_sfrxETH_InvalidBalance() public {
        // No fuzz needed: fixed amount

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 2e18, // approve 2 tokens
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        frxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.prank(spender);
        frxETHtoken.transferFrom(owner, spender, 2e18); // attempt to transfer 2 tokens (owner only owns 1)
    }

    function testRevert_sfrxETH_ExpiredPermit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: sfrxETHtoken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.warp(1 days + 1 seconds); // fast forward one second past the deadline

        vm.expectRevert("PERMIT_DEADLINE_EXPIRED");
        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }

    function testRevert_sfrxETH_InvalidSigner(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: sfrxETHtoken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderPrivateKey, digest); // spender signs owner's approval

        vm.expectRevert("INVALID_SIGNER");
        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }

    function testRevert_sfrxETH_InvalidNonce(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 1, // owner nonce stored on-chain is 0
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.expectRevert("INVALID_SIGNER");
        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }

    function testRevert_sfrxETH_SignatureReplay(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: transfer_amount,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils_sfrxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );

        vm.expectRevert("INVALID_SIGNER");
        sfrxETHtoken.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
    }

    function test_DepositWithSignatureLimitedPermit(uint256 fuzz_amount) public {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
        getQuickfrxETH();

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(sfrxETHtoken),
            value: transfer_amount,
            nonce: frxETHtoken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.prank(owner);
        if (transfer_amount == 0) vm.expectRevert("ZERO_SHARES");
        sfrxETHtoken.depositWithSignature(
            transfer_amount,
            permit.owner,
            permit.deadline,
            false,
            v,
            r,
            s
        );

        assertEq(frxETHtoken.balanceOf(owner), 1 ether - transfer_amount);
        assertEq(frxETHtoken.balanceOf(address(sfrxETHtoken)), transfer_amount);

        assertEq(frxETHtoken.allowance(owner, address(sfrxETHtoken)), 0);
        if (transfer_amount != 0) assertEq(frxETHtoken.nonces(owner), 1);

        assertEq(sfrxETHtoken.balanceOf(owner), transfer_amount);
    }

    // function test_DepositWithSignatureMaxPermit(uint256 fuzz_amount) public {
    //     uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
    //     getQuickfrxETH();

    //     SigUtils.Permit memory permit = SigUtils.Permit({
    //         owner: owner,
    //         spender: address(sfrxETHtoken),
    //         value: type(uint256).max,
    //         nonce: frxETHtoken.nonces(owner),
    //         deadline: 1 days
    //     });

    //     bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

    //     vm.prank(owner);
    //     if (transfer_amount == 0) vm.expectRevert("ZERO_SHARES");
    //     sfrxETHtoken.depositWithSignature(
    //         transfer_amount,
    //         permit.owner,
    //         permit.deadline,
    //         true,
    //         v,
    //         r,
    //         s
    //     );
    //     if (transfer_amount == 0) return;

    //     assertEq(frxETHtoken.balanceOf(owner), 1 ether - transfer_amount);
    //     assertEq(frxETHtoken.balanceOf(address(sfrxETHtoken)), transfer_amount);

    //     // Max allowances never decrease due to spending, per ERC20
    //     assertEq(frxETHtoken.allowance(owner, address(sfrxETHtoken)), type(uint256).max);

    //     assertEq(frxETHtoken.nonces(owner), 1);
    //     assertEq(sfrxETHtoken.balanceOf(owner), transfer_amount);
    // }

    // function test_MintWithSignatureLimitedPermit(uint256 fuzz_amount) public {
    //     uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
    //     getQuickfrxETH();

    //     SigUtils.Permit memory permit = SigUtils.Permit({
    //         owner: owner,
    //         spender: address(sfrxETHtoken),
    //         value: transfer_amount,
    //         nonce: frxETHtoken.nonces(owner),
    //         deadline: 1 days
    //     });

    //     bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

    //     vm.prank(owner);
    //     // if (transfer_amount == 0) vm.expectRevert("ZERO_SHARES");
    //     sfrxETHtoken.mintWithSignature(
    //         transfer_amount,
    //         permit.owner,
    //         permit.deadline,
    //         false,
    //         v,
    //         r,
    //         s
    //     );
    //     // if (transfer_amount == 0) return;

    //     assertEq(frxETHtoken.balanceOf(owner), 1 ether - transfer_amount);
    //     assertEq(frxETHtoken.balanceOf(address(sfrxETHtoken)), transfer_amount);

    //     assertEq(frxETHtoken.allowance(owner, address(sfrxETHtoken)), 0);
    //     assertEq(frxETHtoken.nonces(owner), 1);

    //     assertEq(sfrxETHtoken.balanceOf(owner), transfer_amount);
    // }

    // function test_MintWithSignatureMaxPermit(uint256 fuzz_amount) public {
    //     uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under
    //     getQuickfrxETH();

    //     SigUtils.Permit memory permit = SigUtils.Permit({
    //         owner: owner,
    //         spender: address(sfrxETHtoken),
    //         value: type(uint256).max,
    //         nonce: frxETHtoken.nonces(owner),
    //         deadline: 1 days
    //     });

    //     bytes32 digest = sigUtils_frxETH.getTypedDataHash(permit);

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

    //     vm.prank(owner);
    //     sfrxETHtoken.mintWithSignature(
    //         transfer_amount,
    //         permit.owner,
    //         permit.deadline,
    //         true,
    //         v,
    //         r,
    //         s
    //     );

    //     assertEq(frxETHtoken.balanceOf(owner), 1 ether - transfer_amount);
    //     assertEq(frxETHtoken.balanceOf(address(sfrxETHtoken)), transfer_amount);

    //     assertEq(frxETHtoken.allowance(owner, address(sfrxETHtoken)), type(uint256).max);
    //     assertEq(frxETHtoken.nonces(owner), 1);

    //     assertEq(sfrxETHtoken.balanceOf(owner), transfer_amount);
    // }

    // frxETHMinter submitAndDeposit tests
    // NOTE: Need to test with a mainnet fork for this not revert
    // ===========================================================

    function test_frxETHMinter_submitAndDepositRegular(uint256 fuzz_amount) public payable {
        uint256 transfer_amount = fuzz_amount % (1 ether); // Restrict the fuzz amount to 1 ether and under

        // Make sure you have some ether first
        // By default, this contract has some, but owner does not
        address(owner).call{ value: transfer_amount }("");
        if (transfer_amount > 0) require(owner.balance > 0, "No ether. Fork mainnet or get some.");
        
        vm.prank(owner);
        if (transfer_amount == 0) vm.expectRevert("Cannot submit 0");
        frxETHMinterContract.submitAndDeposit{ value: transfer_amount }(owner);

        assertEq(frxETHtoken.balanceOf(owner), 0); // From original mint
        assertEq(frxETHtoken.allowance(owner, address(frxETHMinterContract)), 0);
        assertEq(frxETHtoken.allowance(address(frxETHMinterContract), address(sfrxETHtoken)), 0);
        assertEq(sfrxETHtoken.balanceOf(owner), transfer_amount);
    }

    // OTHER TESTS
    // ===========================================================

    function mintFXETHTo(address to, uint256 amount) public {
        vm.prank(frxETHMinterEOA);
        frxETHtoken.minter_mint(to, amount);
    }

    // Fuzz test fails here without warp(0) in setup, block.timestamp starts at 1
    /// @dev test totalAssets call before, during, and after a reward distribution that starts on cycle start
    function testTotalAssetsDuringRewardDistribution(uint128 seed, uint128 reward) public {
        uint256 combined = uint256(seed) + uint256(reward);

        unchecked {
            vm.assume(seed != 0 && reward !=0 && combined < type(uint128).max);
        }

        // Mint frxETH to this testing contract from nothing, for testing
        mintFXETHTo(address(this), combined);
        frxETHtoken.approve(address(sfrxETHtoken), combined);

        // Generate some sfrxETH to this testing contract using frxETH
        sfrxETHtoken.deposit(seed, address(this));
        require(sfrxETHtoken.totalAssets() == seed, "seed");

        // Mint frxETH "rewards" to sfrxETH. This mocks earning ETH 2.0 staking rewards.
        mintFXETHTo(address(sfrxETHtoken), reward);
        require(sfrxETHtoken.lastRewardAmount() == 0, "reward");
        require(sfrxETHtoken.totalAssets() == seed, "totalassets");
        require(sfrxETHtoken.convertToAssets(seed) == seed); // 1:1 still

        // Sync the rewards
        sfrxETHtoken.syncRewards();
        
        // After sync, everything should be the  same except lastRewardAmount
        require(sfrxETHtoken.lastRewardAmount() == reward);  
        require(sfrxETHtoken.totalAssets() == seed);
        require(sfrxETHtoken.convertToAssets(seed) == seed); // 1:1 still

        // Accrue half the rewards
        vm.warp(500);
        require(sfrxETHtoken.lastRewardAmount() == reward);  
        require(sfrxETHtoken.totalAssets() == uint256(seed) + (reward / 2));
        require(sfrxETHtoken.convertToAssets(seed) == uint256(seed) + (reward / 2)); // Half rewards added
        require(sfrxETHtoken.convertToShares(uint256(seed) + (reward / 2)) == seed); // Half rewards added

        // Accrue remaining rewards
        vm.warp(1000);
        require(sfrxETHtoken.lastRewardAmount() == reward);  
        require(sfrxETHtoken.totalAssets() == combined);
        assertEq(sfrxETHtoken.convertToAssets(seed), combined); // All rewards added
        assertEq(sfrxETHtoken.convertToShares(combined), seed);

        // Accrue all and warp ahead 2 cycles
        vm.warp(2000);
        require(sfrxETHtoken.lastRewardAmount() == reward);  
        require(sfrxETHtoken.totalAssets() == combined);
        assertEq(sfrxETHtoken.convertToAssets(seed), combined); // All rewards added
        assertEq(sfrxETHtoken.convertToShares(combined), seed);
    }

    /// @dev Test totalAssets call before, during, and after a reward distribution that starts on cycle start
    function testTotalAssetsDuringDelayedRewardDistribution(uint128 seed, uint128 reward) public {
        uint256 combined = uint256(seed) + uint256(reward);

        unchecked {
            vm.assume(seed != 0 && reward !=0 && combined < type(uint128).max);
        }

        // Mint frxETH to this testing contract from nothing, for testing
        mintFXETHTo(address(this), combined);
        frxETHtoken.approve(address(sfrxETHtoken), combined);

        // Generate some sfrxETH to this testing contract using frxETH
        sfrxETHtoken.deposit(seed, address(this));
        require(sfrxETHtoken.totalAssets() == seed, "seed");

        // Mint frxETH "rewards" to sfrxETH. This mocks earning ETH 2.0 staking rewards.
        mintFXETHTo(address(sfrxETHtoken), reward);
        require(sfrxETHtoken.lastRewardAmount() == 0, "reward");
        require(sfrxETHtoken.totalAssets() == seed, "totalassets");
        require(sfrxETHtoken.convertToAssets(seed) == seed); // 1:1 still

        // Start midway
        vm.warp(500);

        // Sync the rewards
        sfrxETHtoken.syncRewards();

        require(sfrxETHtoken.lastRewardAmount() == reward, "reward");
        require(sfrxETHtoken.totalAssets() == seed, "totalassets");
        require(sfrxETHtoken.convertToAssets(seed) == seed); // 1:1 still

        // Accrue half the rewards
        vm.warp(750);
        require(sfrxETHtoken.lastRewardAmount() == reward);  
        require(sfrxETHtoken.totalAssets() == uint256(seed) + (reward / 2));
        require(sfrxETHtoken.convertToAssets(seed) == uint256(seed) + (reward / 2)); // Half rewards added

        // Accrue remaining rewards
        vm.warp(1000);
        require(sfrxETHtoken.lastRewardAmount() == reward);  
        require(sfrxETHtoken.totalAssets() == combined);
        assertEq(sfrxETHtoken.convertToAssets(seed), combined); // All rewards added
        assertEq(sfrxETHtoken.convertToShares(combined), seed);

        // Accrue all and warp ahead past a new cycle. 
        // Variables should not change since no new rewards were added in the interim
        vm.warp(2000);
        require(sfrxETHtoken.lastRewardAmount() == reward);  
        require(sfrxETHtoken.totalAssets() == combined);
        assertEq(sfrxETHtoken.convertToAssets(seed), combined); // all rewards added
        assertEq(sfrxETHtoken.convertToShares(combined), seed);
    }

    function testTotalAssetsAfterDeposit(uint128 deposit1, uint128 deposit2) public {
        vm.assume(deposit1 != 0 && deposit2 !=0);

        // Mint frxETH to this testing contract from nothing, for testing
        uint256 combined = uint256(deposit1) + uint256(deposit2);
        mintFXETHTo(address(this), combined);

        // Generate sfrxETH to this testing contract, part 1
        frxETHtoken.approve(address(sfrxETHtoken), combined);
        sfrxETHtoken.deposit(deposit1, address(this));
        require(sfrxETHtoken.totalAssets() == deposit1);

        // Generate sfrxETH to this testing contract, part 2
        sfrxETHtoken.deposit(deposit2, address(this));

        // Make sure the sum of both deposits matches up
        assertEq(sfrxETHtoken.totalAssets(), combined);
    }

    function testTotalAssetsAfterWithdraw(uint128 deposit, uint128 withdraw) public {
        vm.assume(deposit != 0 && withdraw != 0 && withdraw <= deposit);
        
        // Mint frxETH to this testing contract from nothing, for testing
        mintFXETHTo(address(this), deposit);

        // Generate some sfrxETH to this testing contract using frxETH
        frxETHtoken.approve(address(sfrxETHtoken), deposit);
        sfrxETHtoken.deposit(deposit, address(this));
        require(sfrxETHtoken.totalAssets() == deposit);

        // Withdraw frxETH (from sfrxETH) to this testing contract
        sfrxETHtoken.withdraw(withdraw, address(this), address(this));
        require(sfrxETHtoken.totalAssets() == deposit - withdraw);
    }

    function testSyncRewardsFailsDuringCycle(uint128 seed, uint128 reward, uint256 warp) public {
        uint256 combined = uint256(seed) + uint256(reward);

        unchecked {
            vm.assume(seed != 0 && reward !=0 && combined < type(uint128).max);
        }

        // Mint frxETH to this testing contract from nothing, for testing
        mintFXETHTo(address(this), seed);
        frxETHtoken.approve(address(sfrxETHtoken), seed);

        // Generate sfrxETH to the contract
        sfrxETHtoken.deposit(seed, address(this));

        // Mint frxETH "rewards" to sfrxETH. This mocks earning ETH 2.0 staking rewards.
        mintFXETHTo(address(sfrxETHtoken), reward);

        // Sync the rewards
        // sfrxETHtoken.syncRewards();
        warp = bound(warp, 0, 999);
        vm.warp(warp);

        // Should fail because the rewards cycle hasn't ended yet
        vm.expectRevert(abi.encodeWithSignature("SyncError()"));
        sfrxETHtoken.syncRewards();
    }

    function testSyncRewardsAfterEmptyCycle(uint128 seed, uint128 reward) public {
        uint256 combined = uint256(seed) + uint256(reward);

        unchecked {
            vm.assume(seed != 0 && reward !=0 && combined < type(uint128).max);
        }

        // Mint frxETH to this testing contract from nothing, for testing
        mintFXETHTo(address(this), seed);
        frxETHtoken.approve(address(sfrxETHtoken), seed);

        // Generate sfrxETH to the contract
        sfrxETHtoken.deposit(seed, address(this));
        require(sfrxETHtoken.totalAssets() == seed, "seed");
        vm.warp(100);

        // Sync with no new rewards
        // sfrxETHtoken.syncRewards();
        assertEq(sfrxETHtoken.lastRewardAmount(), 0);  
        assertEq(sfrxETHtoken.lastSync(), 0);  
        assertEq(sfrxETHtoken.rewardsCycleEnd(), 1000);  
        assertEq(sfrxETHtoken.totalAssets(), seed);
        assertEq(sfrxETHtoken.convertToShares(seed), seed);

        // Fast forward to next cycle and add rewards
        vm.warp(1000);

        // Mint frxETH "rewards" to sfrxETH. This mocks earning ETH 2.0 staking rewards.
        mintFXETHTo(address(sfrxETHtoken), reward);

        // Sync with rewards this time
        sfrxETHtoken.syncRewards();
        assertEq(sfrxETHtoken.lastRewardAmount(), reward);  
        assertEq(sfrxETHtoken.totalAssets(), seed);
        assertEq(sfrxETHtoken.convertToShares(seed), seed);

        // Fast forward
        vm.warp(2000);

        assertEq(sfrxETHtoken.lastRewardAmount(), reward);  
        assertEq(sfrxETHtoken.totalAssets(), combined);
        assertEq(sfrxETHtoken.convertToAssets(seed), combined);
        assertEq(sfrxETHtoken.convertToShares(combined), seed);
    }

    function testSyncRewardsAfterFullCycle(uint128 seed, uint128 reward, uint128 reward2) public {
        uint256 combined1 = uint256(seed) + uint256(reward);
        uint256 combined2 = uint256(seed) + uint256(reward) + reward2;

        unchecked {
            vm.assume(seed != 0 && reward !=0 && reward2 != 0 && combined2 < type(uint128).max);
        }

        // Mint frxETH to this testing contract from nothing, for testing
        mintFXETHTo(address(this), seed);
        frxETHtoken.approve(address(sfrxETHtoken), seed);

        // Generate sfrxETH to the contract
        sfrxETHtoken.deposit(seed, address(this));
        require(sfrxETHtoken.totalAssets() == seed, "seed");
        vm.warp(100);

        // Mint frxETH "rewards" to sfrxETH. This mocks earning ETH 2.0 staking rewards.
        mintFXETHTo(address(sfrxETHtoken), reward);

        // Sync with new rewards
        assertEq(sfrxETHtoken.lastSync(), 0, 'sfrxETHtoken.lastSync');  
        assertEq(sfrxETHtoken.rewardsCycleEnd(), 1000, 'sfrxETHtoken.rewardsCycleEnd');  
        assertEq(sfrxETHtoken.totalAssets(), seed, 'sfrxETHtoken.totalAssets');
        assertEq(sfrxETHtoken.convertToShares(seed), seed, 'sfrxETHtoken.convertToShares'); // 1:1 still

        // Fast forward to next cycle and check rewards
        vm.warp(1000);
        sfrxETHtoken.syncRewards();
        assertEq(sfrxETHtoken.lastRewardAmount(), reward, 'sfrxETHtoken.lastRewardAmount [1st]');  

        // Add a second set of rewards to this cycle
        mintFXETHTo(address(sfrxETHtoken), reward2); // seed new rewards

        // Fast forward 10 cycles
        vm.warp(10000);

        // Sync the rewards
        sfrxETHtoken.syncRewards();
        assertEq(sfrxETHtoken.lastRewardAmount(), reward2, 'sfrxETHtoken.lastRewardAmount [2nd]');  
        assertEq(sfrxETHtoken.totalAssets(), combined1, 'sfrxETHtoken.totalAssets [2nd]');
        assertEq(sfrxETHtoken.convertToAssets(seed), combined1, 'sfrxETHtoken.convertToAssets [2nd]');

        // Fast forward two cycles to make sure nothing changed
        vm.warp(2000);
        assertEq(sfrxETHtoken.lastRewardAmount(), reward2, 'sfrxETHtoken.lastRewardAmount [3rd]');  
        assertEq(sfrxETHtoken.totalAssets(), combined2, 'sfrxETHtoken.totalAssets [3rd]');
        assertEq(sfrxETHtoken.convertToAssets(seed), combined2, 'sfrxETHtoken.convertToAssets [3rd]');
    }
}