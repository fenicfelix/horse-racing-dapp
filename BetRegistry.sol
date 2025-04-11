// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UserRegistry.sol"; // Your UserRegistry contract
import "./HorseRegistry.sol"; // Your UserRegistry contract

contract BetRegistry {

    struct Bet {
        uint256 id; // Name of the horse
        uint256 raceId; // Race ID associated with the bet
        uint256 userId; // User ID associated with the bet
        uint256 horseId; // Horse ID associated with the bet
        uint256 amount; // Bet amount
        bool paidOut; // Indicates if the horse is registered or not
    }

    uint256 private nextBetId = 1;

    mapping(uint256 => Bet) public bets;
    mapping(uint256 => uint256) public raceBetCount; // raceId → count
    mapping(uint256 => uint256[]) private raceToBetIds;
    mapping(uint256 => uint256[]) public userBets; // Mapping from userId to an array of bet IDs
    mapping(bytes32 => uint256[]) private raceHorseToBetIds;  // Composite key → betIds

    event BetPlaced(uint256 betId, uint256 userId, uint256 amount);
    event BetPaidOut(uint256 betId, uint256 userId, uint256 amount);

    function recordBet(uint256 raceId, uint256 userId, uint256 horseId, uint256 amount) external returns (uint256) {
        uint256 betId = nextBetId++;
        bets[betId] = Bet(raceId, betId, userId, horseId, amount, false);
        userBets[userId].push(betId);

        emit BetPlaced(betId, userId, amount);
        return betId;
    }

    function getUserBets(uint256 userId) external view returns (uint256[] memory) {
        return userBets[userId];
    }

    function getBetDetails(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }

    function getUser(uint256 userId) external view returns (UserRegistry.User memory) {
        return UserRegistry(msg.sender).getUser(userId);
    }

    function getBetsByRaceId(uint256 raceId) external view returns (Bet[] memory) {
        uint256[] storage betIds = raceToBetIds[raceId];
        Bet[] memory raceBets = new Bet[](betIds.length);
        
        for (uint256 i = 0; i < betIds.length; i++) {
            raceBets[i] = bets[betIds[i]];
        }
        
        return raceBets;
    }

    // Now this becomes O(1)
    function getTotalBetsForRace(uint256 raceId) external view returns (uint256) {
        return raceBetCount[raceId];
    }
}