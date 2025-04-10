// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract UserRegistry is AccessControl {
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant BETTOR_ROLE = keccak256("BETTOR_ROLE");

    struct User {
        uint256 id; // Unique user ID
        address account; // User's wallet address
        string name; // User's name
        bytes32 role; // User's role (e.g., bettor, auditor)
        uint256 balance; // User's token balance
        bool active; // User's status (active/inactive)
    }

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AUDITOR_ROLE, admin);
        _grantRole(BETTOR_ROLE, admin);
    }

    uint256 private nextUserId = 1;

    event UserRegistered(uint256 userid, string name, address userAddress);
    event UserUpdated(uint256 userid, string name, address userAddress);

    mapping(uint256 => User) public users;

    function registerUser(string memory name, address userAddress, bytes32 role) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        // check if the user is already registered
        uint256 userId = nextUserId++;
        for (uint256 i = 1; i < 1000; i++) {
            if (users[i].account == userAddress) {
                revert("User already registered");
            }
        }

        users[userId] = User(userId, userAddress, name, role, 0, true);
        emit UserRegistered(userId, name, userAddress);
        return userId;
    }

    function getUser(uint256 userId) external view returns (User memory) {
        // check if the user is already registered
        if (users[userId].account == address(0)) {
            revert("User not registered");
        }
        return users[userId];
    }

    function getBalance(uint256 userId) external view returns (uint256) {
        // check if the user is already registered
        if (users[userId].account == address(0)) {
            revert("User not registered");
        }
        return users[userId].balance;
    }


    function updateUser(uint256 userId, string memory name, address userAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // check if the user is already registered
        if (users[userId].account == address(0)) {
            revert("User not registered");
        }
        // update the user details
        users[userId].name = name;
        users[userId].account = userAddress;
        emit UserUpdated(userId, name, userAddress);
    }


    function activateUser(uint256 userId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // check if the user is already active
        if (users[userId].active == true) {
            revert("User already active");
        }
        // activate the user

        users[userId].active = true;
        emit UserUpdated(userId, users[userId].name, users[userId].account);
    }

    function deactivateUser(uint256 userId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // check if the user is already active
        if (users[userId].active == true) {
            revert("User already deactivated");
        }
        // activate the user

        users[userId].active = false;
        emit UserUpdated(userId, users[userId].name, users[userId].account);
    }

    function updateRole(uint256 userId, bytes32 NEW_ROLE) external onlyRole(DEFAULT_ADMIN_ROLE) {

        if(hasRole(NEW_ROLE, users[userId].account)) {
            revert("User already has this role");
        }

        _grantRole(NEW_ROLE, users[userId].account);
        emit UserUpdated(userId, users[userId].name, users[userId].account);
    }
}