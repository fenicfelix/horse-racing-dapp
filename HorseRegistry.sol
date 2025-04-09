// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract HorseRegistry {
    enum HorseBreed { THOROUGHBRED, QUARTER_HORSE, ARABIAN, APPALOOSA, MUSTANG }

    struct Horse {
        string name;
        address owner;
        uint256 speed;
        HorseBreed breed;
        bool registered;
    }

    uint256 public nextHorseId = 1;
    mapping(uint256 => Horse) public horses;

    event HorseRegistered(uint256 horseId, string name, address owner, HorseBreed breed);

    function registerHorse(string memory name, uint256 speed, HorseBreed breed) external returns (uint256) {
        require(speed > 0 && speed <= 100, "Invalid speed");
        uint256 horseId = nextHorseId++;

        horses[horseId] = Horse(name, msg.sender, speed, breed, true);
        emit HorseRegistered(horseId, name, msg.sender, breed);

        return horseId;
    }

    function getHorse(uint256 horseId) external view returns (Horse memory) {
        return horses[horseId];
    }
}
