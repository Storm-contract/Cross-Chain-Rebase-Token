//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/Rebase-Token.sol";
import {Vault} from "../src/Vault.sol";
import {iRebaseToken} from "../src/Interfaces/iRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint256 public SEND_VALUE = 1e5;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(iRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));

        vm.stopPrank();
    }

    function addRewardToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startbalance = rebaseToken.balanceOf(user);
        console.log("Start balance: ", startbalance);
        assertEq(startbalance, amount);
        vm.warp(block.timestamp + 1 hours);
        uint256 midlBalance = rebaseToken.balanceOf(user);
        assertGt(midlBalance, startbalance);
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, midlBalance);

        assertApproxEqAbs(endBalance - midlBalance, midlBalance - startbalance, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();
        vm.warp(block.timestamp + time);
        uint256 balanceAfterTime = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterTime - depositAmount);
        vm.prank(owner);

        addRewardToVault(balanceAfterTime - depositAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance, balanceAfterTime);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 uwer2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(uwer2Balance, 0);

        vm.prank(owner);
        rebaseToken.setIntersetRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setIntersetRate(newInterestRate);
    }

    function testCannotCallMint() public {
        // Deposit funds
        vm.startPrank(user);
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.expectRevert();
        rebaseToken.mint(user, SEND_VALUE, interestRate);
        vm.stopPrank();
    }

    function testCannotCallBurn() public {
        // Deposit funds
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.burn(user, SEND_VALUE);
        vm.stopPrank();
    }

    function testGetPrincipalAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principalBalanceOf(user), amount);
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principalBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateOnlyDecrease.selector);
        rebaseToken.setIntersetRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }

    function testTransferFrom(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 uwer2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(uwer2Balance, 0);

        vm.prank(owner);
        rebaseToken.setIntersetRate(4e10);
        vm.prank(user);
        rebaseToken.approve(user, amountToSend); 

        vm.prank(user);
        rebaseToken.transferFrom(user, user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
    }
}

