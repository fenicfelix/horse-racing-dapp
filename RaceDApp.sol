// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./HorseRegistry.sol";
import "./UserRegistry.sol";
import "./BetRegistry.sol";
import "./RacingToken.sol";

contract RaceDApp is VRFV2WrapperConsumerBase {
    ERC20 public raceToken;
    HorseRegistry public horseRegistry;
    UserRegistry public userRegistry;
    BetRegistry public betRegistry;

    uint256 constant public WINNER_PERCENTAGE = 90; // 90% of the prize pool goes to the winner

    enum RaceStatus { OPEN, LOCKED, AUDITED, IN_PROGRESS, OUTCOME_FOUND, COMPLETED, NULLIFIED }

    struct Race {
        uint256 entryFee;
        uint256[] horseIds;
        uint256 totalPool;
        uint256 prizePool;
        RaceStatus status;
        uint256 winningHorse;
        uint256 auditor;
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
    uint32 constant CALLBACK_GAS_LIMIT = 300000;
    uint32 constant NUM_WORDS = 1;
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    event RaceCreated(uint256 raceId, uint256 entryFee);
    event BetPlaced(uint256 raceId, uint256 bettorId, uint256 horseId);
    event RaceLocked(uint256 raceId);
    event RaceAudited(uint256 raceId, uint256 auditor);
    event RaceStarted(uint256 raceId, uint256 requestId);
    event RaceOutcomeFound(uint256 raceId, uint256 winningHorse);
    event RacePayoutCompleted(uint256 raceId, uint256 horseId);

    address constant LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepolia Testnet LINK token address
    address constant VRF_WRAPPER_ADDRESS = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46; // Sepolia Testnet VRF Wrapper address

    constructor(
        address _raceToken,
        address _horseRegistry,
        address _userRegistry,
        address _betRegistry
    ) VRFV2WrapperConsumerBase(LINK_ADDRESS, VRF_WRAPPER_ADDRESS) {
        raceToken = ERC20(_raceToken);
        horseRegistry = HorseRegistry(_horseRegistry);
        userRegistry = UserRegistry(_userRegistry);
        betRegistry = BetRegistry(_betRegistry);
    }


    function createRace(uint256 entryFee) external {
        uint256 raceId = nextRaceId++;

        races[raceId] = Race({
            entryFee: entryFee,
            horseIds: new uint256[](0),
            totalPool: 0,
            prizePool: 0,
            status: RaceStatus.OPEN,
            winningHorse: 0,
            auditor: 0
        });

        emit RaceCreated(raceId, entryFee);
    }

    function placeBet(uint256 raceId, uint256 bettorId, uint256 horseId) external {
        Race storage race = races[raceId];
        require(race.status == RaceStatus.OPEN, "Race not open");

        (, , , bool registered) = horseRegistry.horses(horseId);
        require(registered, "Horse not registered");

        address bettorAddress = userRegistry.getUser(bettorId).account;
        require(userRegistry.getUser(bettorId).active, "User not found or inactive");
        require(bettorAddress.balance > race.entryFee, "Not enough balance in contract");
        require(raceToken.transferFrom(msg.sender, address(this), race.entryFee), "Token transfer failed");

        
        betRegistry.recordBet(raceId, bettorId, horseId, race.entryFee);

        race.totalPool += race.entryFee;
        race.prizePool += (race.entryFee * WINNER_PERCENTAGE) / 100;
        race.horseIds.push(horseId);

        emit BetPlaced(raceId, bettorId, horseId);
    }

    function lockRace(uint256 raceId) public {
        require(races[raceId].status == RaceStatus.OPEN, "Can not lock the bets for this race");

        races[raceId].status = RaceStatus.LOCKED;
        emit RaceLocked(raceId);
    }

    function auditRace(uint256 raceId, uint256 userId) public {
        Race storage race = races[raceId];
        require(race.status == RaceStatus.LOCKED, "The race can not be audited");
        require(race.horseIds.length >= 2, "The race needs at least two players.");

        uint256 totalPool = betRegistry.getBetsByRaceId(raceId).length * race.entryFee;
        require(totalPool == race.totalPool, "Total pool does not match the bets placed");

        race.status = RaceStatus.AUDITED;
        race.auditor = userId;
        emit RaceAudited(raceId, userId);
    }

    function startRace(uint256 raceId) external {
        Race storage race = races[raceId];
        require(race.status == RaceStatus.AUDITED, "Race is not audited");
        require(race.horseIds.length >= 2, "The race can not be started");

        race.status = RaceStatus.IN_PROGRESS;

        uint256 requestId = requestRandomness(
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS
        );

        // Make VRF Request
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
        race.status = RaceStatus.OUTCOME_FOUND;

        request.fulfilled = true;
        request.randomWords = randomWords;

        emit RaceOutcomeFound(request.raceId, race.winningHorse);
    }

    function performPayout(uint256 raceId) public {
        Race storage race = races[raceId];
        require(race.winningHorse != 0, "No winning horse set");
        
        // Verify winning horse is registered
        (, , , bool registered) = horseRegistry.horses(race.winningHorse);
        require(registered, "Winning horse not registered");

        betRegistry = BetRegistry(msg.sender);
        BetRegistry.Bet[] memory bets = betRegistry.getBetsByRaceId(raceId);
        
        // First pass: Count winners and validate
        uint256 totalWinners;
        for (uint256 i = 0; i < bets.length; i++) {
            if (bets[i].horseId == race.winningHorse) {
                require(!bets[i].paidOut, "Bet already paid out");
                totalWinners++;
            }
        }
        
        require(totalWinners > 0, "No winning bets");
        uint256 prizePerWinner = race.prizePool / totalWinners;

        // Second pass: Execute payouts
        for (uint256 i = 0; i < bets.length; i++) {
            if (bets[i].horseId == race.winningHorse) {
                betRegistry.payOutBet(bets[i].id, prizePerWinner);
            }
        }

        race.prizePool = 0; // Clear the prize pool
        emit RacePayoutCompleted(raceId, race.winningHorse);
    }

    function getRaceHorses(uint256 raceId) public view returns (uint256[] memory) {
        return races[raceId].horseIds;
    }

    function getRaceStatus(uint256 raceId) public view returns (RaceStatus) {
        return races[raceId].status;
    }

    function withdrawFees(address to) external payable { // Add ownable
        raceToken.transfer(to, raceToken.balanceOf(address(this)));
    }
}
