// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UserRegistry.sol"; // Your UserRegistry contract

contract BetRegistry {

    struct Bet {
        uint256 id; // Name of the horse
        uint256 userId; // Speed of the horse (1-100)
        uint256 amount; // Enum value representing the breed
        bool paidOut; // Indicates if the horse is registered or not
    }

    uint256 private nextBetId = 1;

    mapping(uint256 => Bet) public bets;
    mapping(uint256 => uint256[]) public userBets; // Mapping from userId to an array of bet IDs

    event BetPlaced(uint256 betId, uint256 userId, uint256 amount);
    event BetPaidOut(uint256 betId, uint256 userId, uint256 amount);

    function placeBet(uint256 userId, uint256 amount) external returns (uint256) {
        // Perform validations
        require(UserRegistry(msg.sender).getUser(userId).active, "Invalid user");
        require(amount > 0, "Invalid bet amount");

        uint256 betId = nextBetId++;
        bets[betId] = Bet(betId, userId, amount, false);
        userBets[userId].push(betId);

        emit BetPlaced(betId, userId, amount);
        return betId;
    }

    function payOutBet(uint256 betId) external {
        Bet storage bet = bets[betId];
        require(!bet.paidOut, "Bet already paid out");

        bet.paidOut = true;
        emit BetPaidOut(betId, bet.userId, bet.amount);
    }

    function getUserBets(uint256 userId) external view returns (uint256[] memory) {
        return userBets[userId];
    }

    function getBetDetails(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }
}