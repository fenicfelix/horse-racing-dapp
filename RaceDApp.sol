// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // Full ERC20
import "./HorseRegistry.sol"; // Your HorseRegistry contract
import "./UserRegistry.sol"; // Your UserRegistry contract
import "./BetRegistry.sol"; // Your UserRegistry contract

contract RaceDApp is VRFV2WrapperConsumerBase {
    ERC20 public raceToken;
    HorseRegistry public horseRegistry;

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
    uint32 constant CALLBACK_GAS_LIMIT = 200000;
    uint32 constant NUM_WORDS = 1;
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    event RaceCreated(uint256 raceId, uint256 entryFee);
    event BetPlaced(uint256 raceId, uint256 horseId, uint256 bettorId, uint256 prizePool);
    event RaceLocked(uint256 raceId);
    event RaceAudited(uint256 raceId, uint256 auditor);
    event RaceStarted(uint256 raceId, uint256 requestId);
    event RaceOutcomeFound(uint256 raceId, uint256 winningHorse);
    event RacePayoutCompleted(uint256 raceId, uint256 horseId);


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
            totalPool: 0,
            prizePool: 0,
            status: RaceStatus.OPEN,
            winningHorse: 0,
            auditor: 0
        });

        emit RaceCreated(raceId, entryFee);
    }

    function placeBet(uint256 raceId, uint bettorId, uint256 horseId) external {
        Race storage race = races[raceId];
        require(race.status == RaceStatus.OPEN, "Race not open");

        BetRegistry betRegistry = BetRegistry(msg.sender);
        ( , , , bool registered) = horseRegistry.horses(horseId);
        require(registered, "Horse not registered");

        UserRegistry userRegistry = UserRegistry(msg.sender);
        require(userRegistry.getUser(bettorId).active, "User not found");
        require(userRegistry.getUser(bettorId).active, "User not active");
        require(userRegistry.getUser(bettorId).balance > race.entryFee, "Not enough balance");

        betRegistry.placeBet(raceId, bettorId, horseId, race.entryFee);

        // increase race total pool
        race.totalPool += race.entryFee;
        race.prizePool += race.entryFee * (WINNER_PERCENTAGE / 100); // 90% of the prize pool goes to the winner
        
        emit BetPlaced(raceId, horseId, bettorId, race.prizePool);
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

    // Override the fulfillRandomWords function from VRFV2WrapperConsumerBase to handle the randomness response
    // This function is called by the VRF V2 wrapper when the randomness request is fulfilled
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

        (, , , bool registered) = horseRegistry.horses(race.winningHorse);
        BetRegistry betRegistry = BetRegistry(msg.sender);

        uint256 totalBets = betRegistry.getTotalBetsForRace(raceId); // Should be a view function

        // get the total number of bets that were placed on the winning horse
        uint256 totalWinners = 0;
        Bet[] storage bets = betRegistry.getBetsByRaceId(raceId);
        for (uint256 i = 0; i < totalBets; i++) {
            (uint256 betId, uint256 userid, uint256 horseId, uint256 amount, bool paidOut) = betRegistry.getBetsByRaceId(i);
            if (horseId == race.winningHorse && !paidOut) {
                totalWinners++;
            }
        }

        uint256 prizePool = race.prizePool;
        uint256 winningAmount = prizePool / totalWinners; // Divide the total amount by the number of winners

        
        for (uint256 i = 0; i < totalBets; i++) {
            BetRegistry bet = betRegistry.getBet(i);
            if (!bet.paidOut && bet.horseId == race.winningHorse) {
                betRegistry.payOutBet(bet.betId, winningAmount); // Payout 90% of the prize pool to the winner
                bet.BetPaidOut(bet.betId, bet.userId, bet.amount);
            }
        }

        emit RacePayoutCompleted(raceId, race.winningHorse);

    }

    function getRaceHorses(uint256 raceId) public view returns (uint256[] memory) {
        return races[raceId].horseIds;
    }

    function getRaceStatus(uint256 raceId) public view returns (RaceStatus) {
        return races[raceId].status;
    }

    function withdrawFees(address to) external { // Add ownable
        // Only the owner can withdraw fees
        raceToken.transfer(to, raceToken.balanceOf(address(this)));
    }
}
