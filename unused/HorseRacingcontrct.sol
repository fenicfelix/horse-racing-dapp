// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HorseRacing is VRFV2WrapperConsumerBase, Ownable {
    // Enums for state management
    enum RaceStatus {
        OPEN,
        REGISTRATION_CLOSED,
        IN_PROGRESS,
        COMPLETED,
        CANCELLED
    }

    enum HorseBreed {
        THOROUGHBRED,
        QUARTER_HORSE,
        ARABIAN,
        APPALOOSA,
        MUSTANG
    }

    enum TrackCondition {
        FAST,
        GOOD,
        SLOW,
        HEAVY
    }

    event RaceCreated(uint256 raceId, uint256 entryFee, uint256 maxHorses);
    event HorseRegistered(
        uint256 raceId,
        uint256 horseId,
        string name,
        HorseBreed breed
    );
    event RaceStatusChanged(uint256 raceId, RaceStatus newStatus);
    event RaceStarted(uint256 raceId, uint256 requestId);
    event RaceCompleted(uint256 raceId, uint256 winningHorse);

    struct Horse {
        string name;
        address owner;
        uint256 speed; // 1-100 rating
        HorseBreed breed;
        bool registered;
    }

    struct Race {
        uint256 entryFee;
        uint256 prizePool;
        uint256 maxHorses;
        uint256[] horseIds;
        RaceStatus status;
        TrackCondition trackCondition;
        uint256 winningHorse;
        uint256 startTime;
    }

    struct VRFRequest {
        uint256 raceId;
        bool fulfilled;
        uint256[] randomWords;
    }

    // Sepolia Testnet addresses
    address constant LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant VRF_WRAPPER_ADDRESS = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    uint32 constant CALLBACK_GAS_LIMIT = 200000;
    uint32 constant NUM_WORDS = 1;
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    uint256 private nextRaceId = 1;
    uint256 private nextHorseId = 1;

    mapping(uint256 => Race) public races;
    mapping(uint256 => Horse) public horses;
    mapping(uint256 => VRFRequest) public vrfRequests;

    constructor() 
        VRFV2WrapperConsumerBase(LINK_ADDRESS, VRF_WRAPPER_ADDRESS)
        Ownable(msg.sender)
    {}

    function createRace(
        uint256 _entryFee,
        uint256 _maxHorses,
        TrackCondition _trackCondition
    ) external onlyOwner {
        nextRaceId = nextRaceId++;
        races[nextRaceId] = Race({
            entryFee: _entryFee,
            prizePool: 0,
            maxHorses: _maxHorses,
            horseIds: new uint256[](0),
            status: RaceStatus.OPEN,
            trackCondition: _trackCondition,
            winningHorse: 0,
            startTime: 0
        });

        emit RaceCreated(nextRaceId, _entryFee, _maxHorses);
        emit RaceStatusChanged(nextRaceId, RaceStatus.OPEN);
    }

    function registerHorse(
        uint256 raceId,
        string memory name,
        uint256 speed,
        HorseBreed breed
    ) external payable {
        require(raceId < nextRaceId, "Invalid race ID");
        Race storage race = races[raceId];
        require(race.status == RaceStatus.OPEN, "Registration closed");
        require(msg.value == race.entryFee, "Incorrect entry fee");
        require(race.horseIds.length < race.maxHorses, "Race full");
        require(speed > 0 && speed <= 100, "Invalid speed rating");

        nextHorseId = nextHorseId++;
        horses[nextHorseId] = Horse({
            name: name,
            owner: msg.sender,
            speed: speed,
            breed: breed,
            registered: true
        });

        race.horseIds.push(nextHorseId);
        race.prizePool += msg.value;

        emit HorseRegistered(raceId, nextHorseId, name, breed);
    }

    function startRace(uint256 raceId) external onlyOwner {
        require(raceId < nextRaceId, "Invalid race ID");
        Race storage race = races[raceId];
        require(race.status == RaceStatus.OPEN, "Race not open");
        require(race.horseIds.length >= 2, "Need at least 2 horses");

        race.status = RaceStatus.IN_PROGRESS;
        race.startTime = block.timestamp;
        
        uint256 requestId = requestRandomness(
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS
        );

        vrfRequests[requestId] = VRFRequest({
            raceId: raceId,
            fulfilled: false,
            randomWords: new uint256[](0)
        });

        emit RaceStatusChanged(raceId, RaceStatus.IN_PROGRESS);
        emit RaceStarted(raceId, requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(vrfRequests[requestId].raceId != 0, "Request not found");
        require(!vrfRequests[requestId].fulfilled, "Request already fulfilled");

        uint256 raceId = vrfRequests[requestId].raceId;
        Race storage race = races[raceId];
        
        // Calculate track modifier (0.8x - 1.2x effect on speed)
        uint256 trackModifier = getTrackModifier(race.trackCondition);
        
        uint256 totalWeightedSpeed;
        for (uint256 i = 0; i < race.horseIds.length; i++) {
            uint256 adjustedSpeed = (horses[race.horseIds[i]].speed * trackModifier) / 100;
            totalWeightedSpeed += adjustedSpeed;
        }

        uint256 weightedRandom = randomWords[0] % totalWeightedSpeed;
        uint256 cumulativeSpeed;
        uint256 winningIndex;

        for (uint256 i = 0; i < race.horseIds.length; i++) {
            uint256 adjustedSpeed = (horses[race.horseIds[i]].speed * trackModifier) / 100;
            cumulativeSpeed += adjustedSpeed;
            if (weightedRandom < cumulativeSpeed) {
                winningIndex = i;
                break;
            }
        }

        race.winningHorse = race.horseIds[winningIndex];
        race.status = RaceStatus.COMPLETED;
        vrfRequests[requestId].fulfilled = true;
        vrfRequests[requestId].randomWords = randomWords;

        // Distribute prize (90% to winner, 10% to house)
        uint256 prize = (race.prizePool * 90) / 100;
        payable(horses[race.winningHorse].owner).transfer(prize);

        emit RaceStatusChanged(raceId, RaceStatus.COMPLETED);
        emit RaceCompleted(raceId, race.winningHorse);
    }

    function getTrackModifier(TrackCondition condition) internal pure returns (uint256) {
        if (condition == TrackCondition.FAST) return 120; // 1.2x speed boost
        if (condition == TrackCondition.GOOD) return 100; // Normal speed
        if (condition == TrackCondition.SLOW) return 90;  // 0.9x speed
        return 80; // TrackCondition.HEAVY: 0.8x speed
    }

    function cancelRace(uint256 raceId) external onlyOwner {
        require(raceId < nextRaceId, "Invalid race ID");
        Race storage race = races[raceId];
        require(race.status == RaceStatus.OPEN, "Race already started");
        
        race.status = RaceStatus.CANCELLED;
        
        // Refund all participants
        for (uint256 i = 0; i < race.horseIds.length; i++) {
            payable(horses[race.horseIds[i]].owner).transfer(race.entryFee);
        }
        
        emit RaceStatusChanged(raceId, RaceStatus.CANCELLED);
    }

    function getRaceHorses(uint256 raceId) public view returns (uint256[] memory) {
        return races[raceId].horseIds;
    }

    function getRaceStatus(uint256 raceId) public view returns (RaceStatus) {
        return races[raceId].status;
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }

    function withdrawEth() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}