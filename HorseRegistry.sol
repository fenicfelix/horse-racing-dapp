// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract HorseRegistry {
    
    enum HorseBreed {
        THOROUGHBRED, // 1
        QUARTER_HORSE, // 2
        ARABIAN, // 3
        APPALOOSA, // 4
        MUSTANG // 5
    }

    struct Horse {
        string name; // Name of the horse
        uint256 speed; // Speed of the horse (1-100)
        HorseBreed breed; // Enum value representing the breed
        bool registered; // Indicates if the horse is registered or not
    }
    
    uint256 private nextHorseId = 1;
    
    mapping(uint256 => Horse) public horses;
    
    event HorseRegistered(uint256 horseId, string name, address horseAddress, HorseBreed breed);
    
    function registerHorse(string memory name, uint256 speed, HorseBreed breed) external returns (uint256) {
        
        require(speed > 0 && speed <= 100, "Invalid speed");
        uint256 horseId = nextHorseId++;
        
        horses[horseId] = Horse(name, speed, breed, true);
        
        emit HorseRegistered(horseId, name, msg.sender, breed);

        return horseId;
    }

    // Update horse details
    function updateHorse(uint256 horseId, string memory name, uint256 speed, HorseBreed breed) external {
        
        require(horses[horseId].registered, "Horse not registered");
        
        horses[horseId].name = name;
        horses[horseId].speed = speed;
        horses[horseId].breed = breed;

        // Emit an event to indicate that the horse has been updated
        emit HorseRegistered(horseId, name, msg.sender, breed);
    }
    
    function unregisterHorse(uint256 horseId) external {
        
        require(horses[horseId].registered, "Horse not registered");
        
        horses[horseId].registered = false;
        
        emit HorseRegistered(horseId, horses[horseId].name, msg.sender, horses[horseId].breed);
    }
    
    function reregisterHorse(uint256 horseId) external {
        
        require(!horses[horseId].registered, "Horse already registered");
        
        horses[horseId].registered = true;
        
        emit HorseRegistered(horseId, horses[horseId].name, msg.sender, horses[horseId].breed);
    }
    
    function getHorse(uint256 horseId) external view returns (Horse memory) {
        return horses[horseId];
    }
}
