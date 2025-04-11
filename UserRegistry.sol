// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract UserRegistry is AccessControl {
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant BETTOR_ROLE = keccak256("BETTOR_ROLE");

    struct User {
        uint256 id;
        address account;
        string name;
        bytes32 role;
        bool active;
    }

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AUDITOR_ROLE, admin);
        _grantRole(BETTOR_ROLE, admin);
    }

    uint256 private nextUserId = 1;

    mapping(uint256 => User) public users;

    event UserRegistered(uint256 userId);

    function registerUser(string memory name, address userAddress, bytes32 role) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // check if the user is already registered
        uint256 userId = nextUserId++;
        for (uint256 i = 1; i < 1000; i++) {
            if (users[i].account == userAddress) {
                revert("User already registered");
            }
        }

        users[userId] = User(userId, userAddress, name, role, true);

        emit UserRegistered(userId);
    }

    function getUser(uint256 userId) external view returns (User memory) {
        // check if the user is already registered
        if (users[userId].account == address(0)) {
            revert("User not registered");
        }
        return users[userId];
    }
}