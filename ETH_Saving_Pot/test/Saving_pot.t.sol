// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/Saving_pot.sol";

contract SavingPotTest is Test {
    Saving_pot public savingPot;
    address[] public members;

    address owner = address(0xABCD);
    address member1 = address(0x1111);
    address member2 = address(0x2222);
    address nonMember = address(0x9999);

    uint256 goal = 5 ether;
    uint256 duration = 1 days;

    function setUp() public {
        // Deploy the contract as `owner` with two members
        members.push(member1);
        members.push(member2);  

        vm.prank(owner);
        savingPot = new Saving_pot(goal, duration, members);
    }

    /// @notice Test that a whitelisted member can contribute and contribution is tracked.
    function testMemberCanContribute() public {
        vm.deal(member1, 1 ether);

        vm.prank(member1);
        savingPot.contribute{value: 1 ether}();

        assertEq(savingPot.contributions(member1), 1 ether);
        assertEq(savingPot.totalContributed(), 1 ether);
    }

    /// @notice Test that a non-member cannot contribute and transaction reverts.
    function testNonMemberCannotContribute() public {
        vm.deal(nonMember, 1 ether);

        vm.prank(nonMember);
        vm.expectRevert("You are not a member of this saving pot");
        savingPot.contribute{value: 1 ether}();
    }

    /// @notice Test that goal reaching unlocks the pot automatically.
    function testGoalReachedUnlocksPot() public {
        vm.deal(member1, goal);

        vm.prank(member1);
        savingPot.contribute{value: goal}();

        assertTrue(savingPot.unlocked());
    }

    /// @notice Test that only the owner can unlock funds manually.
    function testOnlyOwnerCanUnlockFunds() public {
        // Contribute some ether but not enough to reach goal
        vm.deal(member1, 1 ether);
        vm.prank(member1);
        savingPot.contribute{value: 1 ether}();

        // Warp time to pass deadline
        vm.warp(block.timestamp + duration + 1);

        // Try unlock with non-owner
        vm.prank(nonMember);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonMember));
        savingPot.unlockFunds();

        // Try unlock with owner
        vm.prank(owner);
        savingPot.unlockFunds();
        assertTrue(savingPot.unlocked());
    }

    /// @notice Test that only the owner can withdraw funds after unlocking.
    function testOwnerCanWithdrawAfterUnlock() public {
        vm.deal(member1, goal);
        vm.prank(member1);
        savingPot.contribute{value: goal}();

        // Pot should be unlocked now since goal is met
        assertTrue(savingPot.unlocked());

        uint256 balanceBefore = owner.balance;

        // Call withdraw as owner
        vm.prank(owner);
        savingPot.withdraw();

        uint256 balanceAfter = owner.balance;
        assertGt(balanceAfter, balanceBefore);
    }
}
