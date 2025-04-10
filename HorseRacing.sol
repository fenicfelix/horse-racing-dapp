// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // Full ERC20
import "./HorseRegistry.sol"; // Your HorseRegistry contract

contract HorseRacing is VRFV2WrapperConsumerBase {
    ERC20 public raceToken;
    HorseRegistry public horseRegistry;

    enum RaceStatus { OPEN, LOCKED, IN_PROGRESS, COMPLETED, NULLIFIED }

    struct Race {
        uint256 entryFee;
        uint256[] horseIds;
        uint256 prizePool;
        RaceStatus status;
        uint256 winningHorse;
    }

    struct VRFRequest {
        uint256 raceId;
        bool fulfilled;
        uint256[] randomWords;
    }

    uint256 public nextRaceId = 1;
    mapping(uint256 => Race) public races;
    mapping(uint256 => VRFRequest) public vrfRequests;

    // Chainlink VRF Config
    uint32 constant CALLBACK_GAS_LIMIT = 200000;
    uint32 constant NUM_WORDS = 1;
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    event RaceCreated(uint256 raceId, uint256 entryFee);
    event HorseEntered(uint256 raceId, uint256 horseId);
    event RaceStarted(uint256 raceId, uint256 requestId);
    event RaceCompleted(uint256 raceId, uint256 winningHorse);

    constructor(
        address _vrfWrapper,
        address _linkToken,
        address _raceToken,
        address _horseRegistry
    )
        VRFV2WrapperConsumerBase(_linkToken, _vrfWrapper)
    {
        raceToken = ERC20(_raceToken);
        horseRegistry = HorseRegistry(_horseRegistry);
    }

    function createRace(uint256 entryFee) external {
        uint256 raceId = nextRaceId++;

        races[raceId] = Race({
            entryFee: entryFee,
            horseIds: new uint256[](0),
            prizePool: 0,
            status: RaceStatus.OPEN,
            winningHorse: 0
        });

        emit RaceCreated(raceId, entryFee);
    }

    function enterRace(uint256 raceId, uint256 horseId) external {
        Race storage race = races[raceId];
        require(race.status == RaceStatus.OPEN, "Race not open");

        ( , , , bool registered) = horseRegistry.horses(horseId);

        raceToken.transferFrom(msg.sender, address(this), race.entryFee);
        race.prizePool += race.entryFee;
        race.horseIds.push(horseId);

        emit HorseEntered(raceId, horseId);
    }

    function startRace(uint256 raceId) external {
        Race storage race = races[raceId];
        require(race.status == RaceStatus.OPEN, "Not open");
        require(race.horseIds.length >= 2, "Need at least 2 horses");

        race.status = RaceStatus.IN_PROGRESS;

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

        emit RaceStarted(raceId, requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        VRFRequest storage request = vrfRequests[requestId];
        require(!request.fulfilled, "Already fulfilled");

        Race storage race = races[request.raceId];
        uint256 winnerIndex = randomWords[0] % race.horseIds.length;
        race.winningHorse = race.horseIds[winnerIndex];
        race.status = RaceStatus.COMPLETED;

        request.fulfilled = true;
        request.randomWords = randomWords;

        (, , , bool registered) = horseRegistry.horses(race.winningHorse);
        raceToken.transfer(winner, (race.prizePool * 90) / 100); // Winner gets 90%

        emit RaceCompleted(request.raceId, race.winningHorse);
    }

    function getRaceHorses(uint256 raceId) public view returns (uint256[] memory) {
        return races[raceId].horseIds;
    }

    function getRaceStatus(uint256 raceId) public view returns (RaceStatus) {
        return races[raceId].status;
    }

    function withdrawFees(address to) external {
        // Only owner in full version (add Ownable)
        raceToken.transfer(to, raceToken.balanceOf(address(this)));
    }
}
