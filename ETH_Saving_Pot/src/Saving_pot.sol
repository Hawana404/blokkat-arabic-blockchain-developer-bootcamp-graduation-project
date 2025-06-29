// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ETH Saving Pot (Group Savings)
/// @author YOUR_NAME
/// @notice This contract allows a group of members to contribute ETH into a shared pot.
/// @dev Uses OpenZeppelin Ownable for access control.
contract Saving_pot is Ownable {

    /// @notice The savings goal in wei.
    uint256 public goal;

    /// @notice Total ETH contributed so far.
    uint256 public totalContributed;

    /// @notice Deadline timestamp (unix) after which the pot can be unlocked.
    uint64 public deadline;

    /// @notice True if the pot is unlocked.
    bool public unlocked;

    /// @notice Mapping to track each member's contributions.
    mapping(address => uint256) public contributions;

    /// @notice Mapping to verify if an address is a member.
    mapping(address => bool) public isMember;

    /// @notice Array of all member addresses for iteration.
    address[] public members;

    /// @notice Initializes the contract with a goal, duration, and member list.
    /// @param _goal Target amount in wei to unlock the pot.
    /// @param _durationInSeconds Duration in seconds until the pot can be unlocked.
    /// @param _members List of addresses allowed to contribute.
    constructor(
        uint256 _goal,
        uint256 _durationInSeconds,
        address[] memory _members
    ) Ownable(msg.sender) {
        goal = _goal;
        deadline = uint64(block.timestamp + _durationInSeconds);

        for (uint i = 0; i < _members.length; i++) {
            address member = _members[i];
            isMember[member] = true;
            members.push(member);
        }
    }

    /// @notice Allows a member to contribute ETH to the pot.
    /// @dev Reverts if sender is not a member, deadline passed, or pot already unlocked.
    function contribute() external payable {
        require(isMember[msg.sender], "You are not a member of this saving pot");
        require(block.timestamp < deadline, "The saving pot has ended");
        require(!unlocked, "The saving pot is already unlocked");

        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;

        if (totalContributed >= goal) {
            unlocked = true;
        }
    }

    /// @notice Unlocks the pot and refunds contributions to all members.
    /// @dev Can only be called by the owner when conditions are met.
    function unlockFunds() external onlyOwner {
        require(!unlocked, "Already unlocked");
        require(
            block.timestamp >= deadline || totalContributed >= goal,
            "Conditions not met"
        );

        unlocked = true;

        for (uint i = 0; i < members.length; i++) {
            address member = members[i];
            uint256 contribution = contributions[member];

            if (contribution > 0) {
                payable(member).transfer(contribution);
                contributions[member] = 0;
            }
        }

        totalContributed = 0;
    }

    /// @notice Withdraws all ETH in the pot to the owner.
    /// @dev Can only be called by the owner after the pot is unlocked.
    function withdraw() external onlyOwner {
        require(unlocked, "Funds not unlocked yet");

        uint256 amount = address(this).balance;
        require(amount > 0, "No ETH to withdraw");

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Transfer failed");
    }

}
