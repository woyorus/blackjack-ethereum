pragma solidity ^0.4.23;

contract Blackjack {
    bool gameStarted = false;
    bool gameFinished = false;

    uint8 turnPointer;
    bool turnInProgress;
    uint8 turnScore = 0;
    
    uint8 constant playersPerTable = 3;
    
    address[playersPerTable] public players;
    uint8 numPlayers = 0;
    
    Card[] deck;
    uint8 deckTopPtr = 0;
    
    Card[] public table;
    
    uint8 _winner;
    bool _tie;
    mapping (uint8 => uint8) scores;
    
    event PlayerJoined(address player);
    event GameStarted();
    event Draws(address player, Card card);
    event Turn(address prevPlayer, address nextPlayer);
    event Tie();
    event Wins(address player);
    
    struct Card {
        uint8 suit;
        uint8 rank;
    }

    constructor() public {
        // Deck generation
        for (uint8 suit = 0; suit < 4; suit++) {
            for (uint8 rank = 0; rank < 9; rank++) {
                deck.push(Card({ suit: suit, rank: rank }));
            }
        }
        
        // TODO: Shuffle the deck
    }
    
    function winner() public view returns (address) {
        require (
            gameFinished,
            "The game is not finished yet"
        );
        
        if (_tie) {
            return 0x0;
        }
        
        return players[_winner];
    }
    
    function join() public {
        require (
            !gameStarted,
            "Game is already started"
        );
        
        require (
            numPlayers < playersPerTable,
            "All seats are occupied, start the game"
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
    }

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
    
    function scoreForRank(uint8 rank) public view returns (uint8) {
        require (
            rank >= 0 && rank < 9,
            "Rank must be between 0 and 8"
        );
        
        if (rank >= 0 && rank <= 4) {
            // There's an offset by six between card index and it's actual rank
            return rank + 6; 
        } else if (rank == 5) { // jack
            return 2;
        } else if (rank == 6) { // queen
            return 3;
        } else if (rank == 7) { // king
            return 4;
        } else { // ace
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
    
    function startGame() public {
        require (
            !gameStarted,
            "Game already started"
        );
        
        require (
            numPlayers == 3,
            "Not all seats are taken yet, wait for others to join"
        );
        
        require (
            msg.sender == players[0],
            "Only the person who created the game can start it."
        );
        
        gameStarted = true;
        
        turnPointer = 0;
        turnInProgress = true;
        
        emit GameStarted();
    }
    
    function more() public returns (uint8) {
        require (
            gameStarted,
            "Game is not started yet"
        );
        
        require (
            turnInProgress,
            "Turn is not in progress"
        );
        
        require (
            playerJoined(msg.sender) && playerIndex(msg.sender) == turnPointer,
            "Only the player who's turn is now can do this"
        );
        
        // Take top card from the deck and place it on the table
        Card memory c = deck[deckTopPtr];
        deckTopPtr++;
        table.push(c);
        
        turnScore += scoreForRank(c.rank);
        scores[turnPointer] = turnScore;
        
        emit Draws(msg.sender, c);
        
        if (turnScore == 21) {
            // We have a winner
            _winner = turnPointer;
            gameFinished = true;
        } else if (turnScore > 21) {
            // We have a looser
            nextTurn();
        }
        
        return turnScore;
    }
    
    function nextTurn() public {
        require (
            gameStarted,
            "Game is not started yet"
        );
        
        require (
            turnInProgress,
            "Turn is not in progress"
        );
        
        require (
            playerJoined(msg.sender) && playerIndex(msg.sender) == turnPointer,
            "Only the player who's turn is now can do this"
        );
        
        require (
            !gameFinished,
            "Game is already finished"
        );
        
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
    
    function declareTie() private {
        gameFinished = true;
        _tie = true;
        emit Tie();
    }
    
    function declareWinner(uint8 winPlayerIndex) private {
        _winner = winPlayerIndex;
        gameFinished = true;
        emit Wins(players[winPlayerIndex]);
    }
    
    function computeWinner() private view returns (uint8) {
        uint8 winningScore = 0;
        uint8 candidate;
        
        for (uint8 i = 0; i < numPlayers; i++) {
            if (scores[i] > winningScore) {
                winningScore = scores[i];
                candidate = i;
            }
        }
        
        return candidate;
    }
    
    function allLost() private view returns (bool) {
        bool result = true;
        for (uint8 i = 0; i < numPlayers; i++) {
            result = result && scores[i] <= 21;
        }
    }
    
    function whosTurn() public view returns (address) {
        require (
            gameStarted,
            "Game is not started yet"
        );
        
        require (
            turnInProgress,
            "Turn is not in progress"
        );
        
        return players[turnPointer];
    }
}
