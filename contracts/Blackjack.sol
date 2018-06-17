pragma solidity ^0.4.23;

contract Blackjack {
    enum GameState { NotStarted, InProgress, Finished }
    
    GameState state = GameState.NotStarted;

    uint8 turnPointer;
    uint8 turnScore;
    
    uint8 constant playersPerTable = 3;
    
    address[playersPerTable] public players;
    uint8 numPlayers = 0;
    
    Card[] deck;
    uint8 deckTopPtr = 0;
    
    Card[] public table;
    
    uint8 _winner;
    bool _tie;
    mapping (uint8 => uint8) scores;
    
    struct Card {
        uint8 suit;
        uint8 rank;
    }
    
    // -- Events --
    
    event PlayerJoined(address player);
    event GameStarted();
    event Draws(address player, uint8 newScore);
    event Turn(address prevPlayer, address nextPlayer);
    event Tie();
    event Bust(address player);
    event Wins(address player);
    
    // --
    
    modifier onlyNotStarted() {
        require (
            state == GameState.NotStarted,
            "Action is performable only when game is not started yet"
        );
        _;
    }
    
    modifier onlyInProgress() {
        require (
            state == GameState.InProgress,
            "Action is performable only when game is in progress"
        );
        _;
    }
    
    modifier onlyFinished() {
        require (
            state == GameState.Finished,
            "Action is performable only when game is finished"
        );
        _;
    }
    
    modifier onlyTurnTaker() {
        require (
            playerJoined(msg.sender) && playerIndex(msg.sender) == turnPointer,
            "Only the player who's turn is now can do this"
        );
        _;
    }

    constructor() public {
        // Deck generation
        for (uint8 suit = 0; suit < 4; suit++) {
            for (uint8 rank = 0; rank < 9; rank++) {
                deck.push(Card({ suit: suit, rank: rank }));
            }
        }
        
        // TODO: Don't shuffle the deck in constructor, pick a random card from
        // the deck on each take() instead
        shuffleDeck();
    }
    
    function shuffleDeck() private {
        for (uint64 i = uint64(deck.length - 1); i > 0; i--) {
            uint64 index = random(i+1);   
            Card memory a = deck[index];
            deck[index] = deck[i];
            deck[i] = a;
        }
    }
    
    // TODO: Reimplement this, the source of entropy is bad
    uint64 _seed = 128;
    function random(uint64 upper) public returns (uint64 randomNumber) {
        if (upper == 0) {
            upper = 100000000;
        }
        _seed = uint64(keccak256(keccak256(blockhash(block.number), _seed), now));
        return _seed % upper;
    }
    
    function winner() onlyFinished public view returns (address) {
        if (_tie) {
            return 0x0;
        }
        
        return players[_winner];
    }
    
    function join() public onlyNotStarted {
        require (
            numPlayers < playersPerTable,
            "All seats are already taken"
        );
        
        require (
            !playerJoined(msg.sender),
            "You have already joined the game"
        );
        
        uint8 index = numPlayers;
        numPlayers++;
        players[index] = msg.sender;
        scores[index] = 0;
        
        emit PlayerJoined(msg.sender);
        
        // Start the game if all seats are taken
        if (numPlayers == playersPerTable) {
            startGame();
        }
    }
    
    function startGame() private onlyNotStarted {
        require (
            numPlayers == 3,
            "Not all seats are taken yet, wait for others to join"
        );
        
        state = GameState.InProgress;
        turnPointer = 0; // first to come in player begins playing first
        turnScore = 0;
        
        emit GameStarted();
    }
    
    function take() onlyTurnTaker onlyInProgress public returns (uint8) {
        // Take top card from the deck and place it on the table
        Card memory c = deck[deckTopPtr];
        deckTopPtr++;
        table.push(c);
        
        turnScore += scoreForRank(c.rank);
        scores[turnPointer] = turnScore;
        
        emit Draws(msg.sender, turnScore);
        
        if (turnScore == 21) {
            // We have a winner
            _winner = turnPointer;
            state = GameState.Finished;
        } else if (turnScore > 21) {
            // We have a looser
            uint8 currentScore = turnScore;
            emit Bust(msg.sender);
            nextTurn(); // modifies turnScore
            return currentScore;
        }
        
        return turnScore;
    }
    
    function nextTurn() onlyTurnTaker onlyInProgress public {
        if (allLost()) {
            // The tie case
            declareTie();
            return;
        }
        
        if (turnPointer == (numPlayers - 1)) {
            // Last turn. Winner is the first highest score
            declareWinner(computeWinner());
            return;
        }
        
        turnPointer++;
        turnScore = 0;
        
        emit Turn(players[turnPointer - 1], players[turnPointer]);
    }
    
    function declareTie() onlyInProgress private {
        state = GameState.Finished;
        _tie = true;
        emit Tie();
    }
    
    function declareWinner(uint8 winPlayerIndex) onlyInProgress private {
        state = GameState.Finished;
        _winner = winPlayerIndex;
        emit Wins(players[winPlayerIndex]);
    }
    
    function computeWinner() onlyInProgress private view returns (uint8) {
        uint8 winningScore = 0;
        uint8 candidate;
        
        for (uint8 i = 0; i < numPlayers; i++) {
            if (scores[i] > winningScore && scores[i] <= 21) {
                winningScore = scores[i];
                candidate = i;
            }
        }
        
        return candidate;
    }
    
    function whosTurn() onlyInProgress public view returns (address) {
        return players[turnPointer];
    }
    
    // -- Helpers -- //
    
    function scoreForRank(uint8 rank) private view returns (uint8) {
        require (
            rank >= 0 && rank < 9,
            "Rank must be between 0 and 8"
        );
        
        if (rank >= 0 && rank <= 4) {
            // 6 to 10 card rank case: indicies have an offset of +6
            return rank + 6;
        } else if (rank >= 5 && rank <= 7) {
            // Queen to King card rank case: indicies offset by -3
            return rank - 3;
        } else {
            // Ace case: the score is either 1 or 10, whichever fits better
            if (21 <= (turnScore + 10)) {
                return 10;
            } else {
                return 1;
            }
        }
    }
    
    function playerIndex(address _player) private view returns (int) {
        for (uint8 i = 0; i < playersPerTable; i++) {
            if (players[i] != 0x0 && players[i] == _player) {
                return i;
            }
        }
        
        return -1; // not found
    }
    
    function playerJoined(address _player) private view returns (bool) {
        return playerIndex(_player) != -1;
    }
    
    function allLost() private view returns (bool) {
        bool result = false;
        for (uint8 i = 0; i < numPlayers; i++) {
            uint8 score = scores[i];
            result = result && !(score <= 21 && score > 0);
        }
        return result;
    }
    
    // -- Utility routines -- //
    
    function getSuitString(uint8 suit) public pure returns (string) {
        require (
            suit >= 0 && suit < 4,
            "There are only 4 suites, [0,1,2,3]"
        );
        
        if (suit == 0) {
            return "Diamonds";
        } else if (suit == 1) {
            return "Spades";
        } else if (suit == 2) {
            return "Hearts";
        } else if (suit == 3) {
            return "Clubs";
        }
    }
    
    function getRankString(uint8 rank) public pure returns (string) {
        require (
            rank >= 0 && rank < 9,
            "There are only 9 ranks, 0 trough 8"
        );
        
        if (rank == 0) {
            return "6";
        } else if (rank == 1) {
            return "7";
        } else if (rank == 2) {
            return "8";
        } else if (rank == 3) {
            return "9";
        } else if (rank == 4) {
            return "10";
        } else if (rank == 5) {
            return "Jack";
        } else if (rank == 6) {
            return "Queen";
        } else if (rank == 7) {
            return "King";
        } else if (rank == 8) {
            return "Ace";
        }
    }
}
