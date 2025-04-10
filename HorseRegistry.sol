// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract HorseRegistry {
    // Enum to represent different horse breeds
    enum HorseBreed {
        THOROUGHBRED, // 1
        QUARTER_HORSE, // 2
        ARABIAN, // 3
        APPALOOSA, // 4
        MUSTANG // 5
    }

    // Struct to represent a horse
    // Each horse has a name, speed, breed, and registration status
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

    // Event emitted when a horse is registered
    event HorseRegistered(uint256 horseId, string name, address horseAddress, HorseBreed breed);

    // Horse registration function
    function registerHorse(string memory name, uint256 speed, HorseBreed breed) external returns (uint256) {
        // performing checks on the input parameters
        require(speed > 0 && speed <= 100, "Invalid speed");
        nextHorseId = nextHorseId++;

        // Register the horse with default status as registered
        horses[nextHorseId] = Horse(name, speed, breed, true);

        // Emit the HorseRegistered event with the horse ID, name, and owner address
        emit HorseRegistered(nextHorseId, name, msg.sender, breed);

        return nextHorseId;
    }

    // Update horse details
    function updateHorse(uint256 horseId, string memory name, uint256 speed, HorseBreed breed) external {
        // Check if the horse is registered
        require(horses[horseId].registered, "Horse not registered");

        // Update the horse details
        horses[horseId].name = name;
        horses[horseId].speed = speed;
        horses[horseId].breed = breed;

        // Emit an event to indicate that the horse has been updated
        emit HorseRegistered(horseId, name, msg.sender, breed);
    }

    // unregister a horse
    function unregisterHorse(uint256 horseId) external {
        // Check if the horse is registered
        require(horses[horseId].registered, "Horse not registered");

        // Unregister the horse by setting the registered status to false
        horses[horseId].registered = false;

        // Emit an event to indicate that the horse has been unregistered
        emit HorseRegistered(horseId, horses[horseId].name, msg.sender, horses[horseId].breed);
    }

    // reregister a horse
    function reregisterHorse(uint256 horseId) external {
        // Check if the horse is already registered
        require(!horses[horseId].registered, "Horse already registered");

        // Reregister the horse by setting the registered status to true
        horses[horseId].registered = true;

        // Emit an event to indicate that the horse has been reregistered
        emit HorseRegistered(horseId, horses[horseId].name, msg.sender, horses[horseId].breed);
    }

    // Get horse details by ID
    function getHorse(uint256 horseId) external view returns (Horse memory) {
        return horses[horseId];
    }
}
