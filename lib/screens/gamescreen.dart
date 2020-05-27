import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:literature/models/player.dart';
import 'package:literature/models/playing_cards.dart';
import 'package:literature/utils/game_communication.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:literature/components/card_deck.dart';
import 'package:literature/utils/loader.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:literature/components/player_view.dart';

class GameScreen extends StatefulWidget {
  // Game
  GameScreen({
    Key key,
    this.player,
    this.playersList,
    this.roomId
  }): super(key: key);

  ///
  /// Name of the opponent
  ///
  final Player player;

  ///
  /// List of players in the room
  ///
  List<dynamic> playersList;

  ///
  /// RoomId
  ///
  String roomId;

  // Timer
  Timer timer;

  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<PlayingCard> _cards = new List<PlayingCard>();
  List<dynamic> finalPlayersList = new List();
  bool _ready = false;
  // List<Player> teamRed = new List<Player>();
  // List<Player> teamBlue = new List<Player>();
  double radius = 150.0;
  Map<String, String> turnsMapper = new Map<String, String>();
  Set<String> selfOpponents = new Set();

  @override
  void initState() {
    super.initState();

    game.addListener(_gameScreenListener);
  }

  @override
  dispose() {
    super.dispose();
    game.removeListener(_gameScreenListener);
  }

  // Starts the timer and resets it
  // in the end.
  startTimer() {
    print("Starting the timer");
    // cancel any existing timers.
    widget.timer?.cancel();
    // This runs asynchronously.
    // Sends a message to the server automatically
    // that the user has finished his turn after 60 seconds.
    widget.timer = new Timer(Duration(seconds: 60), () {
      // send a new message to the server.
      Map turnDetails = {"name": widget.player.name, "roomId": widget.roomId};
      game.send("finished_turn", json.encode(turnDetails));
    });
  }

  _gameScreenListener(message) {
    switch(message["action"]) {
      // Gets cards from the server.
      case "pre_game_data":
        List cards = (message["data"])["cards"];
        List players = (message["data"]["playersWithTeamIds"]);
        // Add to _cards list in the state
        cards.forEach((card) {
          _cards.add(new PlayingCard(
            cardSuit: EnumToString.fromString(CardSuit.values, card["suit"]),
            cardType: EnumToString.fromString(CardType.values ,card["card"]),
            name: widget.player.name,
            opened: false)
          );
        });
        // Assign red and blue teams
        // players.forEach((player) {
        //   if (player["teamIdentifier"] == "red") {
        //     // team_red.add(p);
        //     teamRed.add(
        //       new Player(
        //         name: player["name"],
        //         id: player["id"],
        //         teamIdentifier: player["teamIdentifier"]
        //       )
        //     );
        //   } 
        //   else teamBlue.add(
        //     new Player(
        //       name: player["name"],
        //       id: player["id"],
        //       teamIdentifier: player["teamIdentifier"]
        //     )
        //   );
        // });
        // Override playersList.
        finalPlayersList = players;
        // build a map of players and turns.
        finalPlayersList.forEach((player) {
          turnsMapper.putIfAbsent(player["name"], () => "waiting");
          // Sets the current player team.
          if (player["name"] == widget.player.name) {
            widget.player.teamIdentifier = player["teamIdentifier"];
          }
        });
        // set opponents of that player.
        finalPlayersList.forEach((player) {
          if (player["teamIdentifier"] != widget.player.teamIdentifier) {
            selfOpponents.add(player["name"]);
          }
        });
        // Force rebuild
        setState(() { _ready = true; });
        break;
      case "make_move":
        print("Listening");
        var name = message["data"]["playerName"];
        // set turnsMapper value as true.
        // and force rebuild.
        // turnsMapper[name] = "true";
        turnsMapper.forEach((key, value) {
          if (key == name) {
            turnsMapper[key] = "hasTurn";
          } else turnsMapper[key] = "waiting";
        });
        // Starts the timer.
        // startTimer();
        setState(() {});
        break;
      // Please check if you have this card.
      // Cause someone requested it from you.
      case "send_card_on_request":
        var name = message["data"]["recipient"];
        // return early.
        if (name == widget.player.name) {
          // You're the recipient.
          print("YOU ARE THE RECIPIENT");
          var cardSuit = message["data"]["cardSuit"],
            cardType = message["data"]["cardType"];
          bool haveCard = _cards.any((card) {
            return (EnumToString.parse(card.cardSuit) == cardSuit
              &&
              EnumToString.parse(card.cardType) == cardType
            );
          });
          // Ideally, update the arena here.
          if (haveCard == false) {
            print("No such card");
          } else {
            print("I have it");
          }
          // Send message that will transfer card.
          // from -> recipient.
          Map cardTransferDetails = { 
            "cardSuit": cardSuit,
            "cardType": cardType,
            "from": widget.player.name,
            "recipient": message["data"]["inquirer"],
            "roomId": widget.roomId,
            "result": haveCard == false ? "false" : "true"
          };
          game.send("card_transfer", json.encode(cardTransferDetails));
        }
        break;
      case "card_transfer_result":
        var recipient = message["data"]["recipient"];
        var transferFrom = message["data"]["inquirer"];
        var result = message["data"]["result"];
        var cardSuit = message["data"]["cardSuit"];
        var cardType = message["data"]["cardType"];
        if (recipient == widget.player.name || transferFrom == widget.player.name) {
          if (result == "true" && transferFrom == widget.player.name) {
            // remove the card from the current person.
            for (var i=0; i < _cards.length; i++) {
              if (EnumToString.parse(_cards[i].cardSuit) == cardSuit && EnumToString.parse(_cards[i].cardType) == cardType) {
                _cards.remove(_cards[i]);
                break;
              }
            }
            _cards.forEach((card) {
              print(card.cardType);
            });
            // Force rebuild
            setState(() {
              _cards = _cards;           
            });
          } else if (result == "true" && recipient == widget.player.name) {
            // add the resulting card to this person.
            _cards.add(
              new PlayingCard(
                cardSuit: EnumToString.fromString(CardSuit.values, cardSuit),
                cardType: EnumToString.fromString(CardType.values, cardType),
                name: null
              ),
            );
            // Force rebuild
            setState(() {
              _cards = _cards;           
            });
          } else {
            // result is false, just update that wrong guess,
            // end turn here. (important).
            Map turnDetails = {"name": widget.player.name, "roomId": widget.roomId};
            game.send("finished_turn", json.encode(turnDetails));
            setState(() {});
          }
        } else {
          // We get here if this player does not take place in the whole 
          // transaction. Just update the arena that x asked y about z card.
          // and the result is r.
        }
        break;
      default:
        print("Default case");
        break;
    }
  }


  void callback() {
    print("Cancelling the timer");
    widget.timer?.cancel();
    // cancels the timer.
    // Force rebuild.
    Map turnDetails = {"name": widget.player.name, "roomId": widget.roomId};
    game.send("finished_turn", json.encode(turnDetails));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return new SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        // Disable going to the waiting page
        // cause there won't be any forwarding
        // from there on.
        // appBar: new AppBar(),
        appBar: AppBar(
          title: new Text("Literature"),
          leading: new Container(),
          backgroundColor: Colors.lightBlue[800],
        ),
        body:  _ready ? SlidingUpPanel(
          body: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget> [
              new Container(
                height: MediaQuery.of(context).size.height*0.95,
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(
                  image: new DecorationImage(
                    // We can add random game mats
                    // as per store purchases of the user.
                    image: new ExactAssetImage("assets/game_mat_royale.jpg"),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, left: 5.0, right: 5.0),
                  child: new PlayerView(
                    containerHeight: MediaQuery.of(context).size.height*0.95,
                    containerWidth: MediaQuery.of(context).size.width,
                    currPlayer: widget.player,
                    finalPlayersList: finalPlayersList,
                    turnsMapper: turnsMapper,
                    selfOpponents: selfOpponents,
                    roomId: widget.roomId,
                    cards: _cards,
                    callback: this.callback
                  ),
                ),
              ),
              // Allocate bottom with a few spaces.
            ]
          ),
          panel: new Container(
            alignment: Alignment.bottomCenter,
            child: CardDeck(cards: _cards, containerHeight: MediaQuery.of(context).size.height-467)
          ),
        ) :
        Container(
          width: double.infinity,
          height: double.infinity,
          child: Loader(),
        ),
      ),
    );
  }
}
