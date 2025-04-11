// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract HorseRegistry {
    // Enum to represent different horse breeds
    enum HorseBreed {
        THOROUGHBRED,
        QUARTER_HORSE,
        ARABIAN,
        APPALOOSA,
        MUSTANG
    }
    
    struct Horse {
        string name; // Name of the horse
        uint256 speed; // Speed of the horse (1-100)
        HorseBreed breed; // Enum value representing the breed
        bool registered; // Indicates if the horse is registered or not
    }

    // Mapping to store horse details by their ID
    uint256 private nextHorseId = 1;

    // Mapping from horse ID to Horse struct
    mapping(uint256 => Horse) public horses;

    event HorseRegistered(uint256 horseId);

    // Horse registration function
    function registerHorse(string memory name, uint256 speed, HorseBreed breed) external returns (uint256) {
        // performing checks on the input parameters
        require(speed > 0 && speed <= 100, "Speed must be between 0 and 100");
        uint256 horseId = nextHorseId++;

        // Register the horse with default status as registered
        horses[horseId] = Horse(name, speed, breed, true);

        emit HorseRegistered(horseId);

        return horseId;
    }

    // Get horse details by ID
    function getHorse(uint256 horseId) external view returns (Horse memory) {
        return horses[horseId];
    }
}
