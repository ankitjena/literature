import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:literature/models/player.dart';
import 'package:literature/provider/playerlistprovider.dart';
// Game communication helper import
import 'package:literature/utils/game_communication.dart';
// Start Game page
import 'package:literature/screens/gamescreen.dart';
// Local Notification Helper
import 'package:literature/utils/local_notification_helper.dart';
import 'package:provider/provider.dart';

class WaitingPage extends StatefulWidget {
  WaitingPage({
    Key key,
    this.roomId,
  }) : super(key: key);

  ///
  /// Holds the current player
  ///
  Player currPlayer;

  ///
  ///
  //

  ///
  /// RoomId
  ///
  final String roomId;

  _WaitingPageState createState() => _WaitingPageState();
}

// Should contain a form of Room ID and
// Player name to join.
class _WaitingPageState extends State<WaitingPage> {
  final notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    ///
    /// Ask to be notified when messages related to the game
    /// are sent by the server
    ///
    game.addListener(_waitingPageListener);
    final settingsAndroid = AndroidInitializationSettings('app_icon');
    final settingsIOS = IOSInitializationSettings(
        onDidReceiveLocalNotification: (id, title, body, payload) =>
            onSelectNotification(payload));

    notifications.initialize(
        InitializationSettings(settingsAndroid, settingsIOS),
        onSelectNotification: onSelectNotification);
  }

  Future onSelectNotification(String payload) async {
    notifications.cancel(0);
  }

  @override
  void dispose() {
    game.removeListener(_waitingPageListener);
    super.dispose();
  }

  /// -------------------------------------------------------------------
  /// This routine handles all messages that are sent by the server.
  /// In this page, only the following 2 actions have to be processed
  ///  - players_list
  ///  - new_game
  /// -------------------------------------------------------------------
  _waitingPageListener(message) {
    switch (message["action"]) {

      ///
      /// Each time a new player joins, we need to
      ///   * record the new list of players
      ///   * rebuild the list of all the players
      ///
      case "joined":
        print("joined");

        final playerProvider = Provider.of<PlayerList>(context, listen: false);
        playerProvider.removeAll();
        List<Player> lp = [];
        for (var player in (message["data"])["players"]) {
          Player p;
          if ((message["data"])["lobbyLeader"]["id"] == player["id"])
            p = new Player(
                name: player["name"], id: player["id"], lobbyLeader: true);
          else
            p = new Player(name: player["name"], id: player["id"]);
          lp.add(p);
        }
        playerProvider.addPlayers(lp);

        // Push Notification Check
        if (playerProvider.players.length == 6) {
          showOngoingNotification(notifications,
              title: 'Start The Game',
              body: 'The Room is full. You can start the Game.');
        }

        break;
      // Move any waiting clients
      // to the game page.
      case "game_started":
        final playerProvider = Provider.of<PlayerList>(context, listen: false);
        Navigator.pushReplacement(
            context,
            new MaterialPageRoute(
              builder: (BuildContext context) => new GameScreen(
                player: playerProvider.currPlayer,
                playersList: playerProvider.players,
                roomId: widget.roomId
              ),
            ));
        break;
    }
  }

  /// --------------------------------------------------------------
  /// We launch a new Game, we need to:
  ///    * send the action "new_game", together with the players
  ///
  ///    * redirect to the game as we are the game initiator
  /// --------------------------------------------------------------
  _onPlayGame(context) {
    // We need to send the opponentId to initiate a new game
    game.send('start_game', widget.roomId);

    final playerProvider = Provider.of<PlayerList>(context, listen: false);
    Navigator.push(
      context,
      new MaterialPageRoute(
        builder: (BuildContext context) => new GameScreen(
          player: playerProvider.currPlayer,
          playersList: playerProvider.players,
          roomId: widget.roomId
        ),
      ),
    );
  }

  _getPlayButton(playerInfo) {
    final players = Provider.of<PlayerList>(context, listen: false);
    if (players.players.length == 2) {
      return new RaisedButton(
        onPressed: () {
          _onPlayGame(context);
        },
        child: new Text('Play'),
      );
    } else {
      return new Text("...");
    }
  }

  // ------------------------------------------------------
  /// Builds the list of players
  /// ------------------------------------------------------
  Widget _playersList() {
    ///
    /// If the user has not yet joined, do not display
    /// the list of players
    ///
    // if (game.playerName == "") {
    //   return new Container();
    // }

    ///
    /// Display the list of players.
    /// For each of them, put a Button that could be used
    /// to launch a new game, if it is an admin then only set
    /// play option.
    ///

    final currPlayer = Provider.of<PlayerList>(context).currPlayer;
    return Consumer<PlayerList>(
        builder: (BuildContext context, PlayerList value, Widget child) {
      List<Widget> children = value.players?.map((playerInfo) {
        // print(widget.currPlayer.name + " " + playerInfo["name"]);
        String name =
            (playerInfo.id == currPlayer.id) ? "You" : playerInfo.name;
        
        if (playerInfo.lobbyLeader) {
          // print(playerInfo.id);
          bool isLeader = (playerInfo.id == currPlayer.id);
          return new Card(
            elevation: 8.0,
            margin: new EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromRGBO(64, 75, 96, .5),
                gradient: LinearGradient(
                  colors: [Colors.blue[300], Colors.blue],
                ),
                border: Border.all(color: Colors.lightBlue, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.only(right: 12.0),
                  decoration: new BoxDecoration(
                    border: new Border(
                      right: new BorderSide(width: 1.0, color: Colors.black),
                    ),
                  ),
                  child: Image.asset("assets/person.png"),
                ),
                title: new Text(
                  name,
                  style: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                ),
                subtitle: new Text("[Lobby Leader]"),
                trailing: (isLeader)
                    ? _getPlayButton(playerInfo)
                    : null,
              ),  
            ),
          );
        } else {
          // print(playerInfo);
          return new Card(
            elevation: 8.0,
            margin: new EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromRGBO(64, 75, 96, .5),
                gradient: LinearGradient(
                  colors: [Colors.blue[300], Colors.blue],
                ),
                border: Border.all(color: Colors.lightBlue, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.only(right: 12.0),
                  decoration: new BoxDecoration(
                    border: new Border(
                      right: new BorderSide(width: 1.0, color: Colors.black),
                    ),
                  ),
                  child: Image.asset("assets/person.png"),
                ),
                title: new Text(
                  name,
                  style: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                ),
                subtitle: new Text(" "),
              ),
            ),
          );
        }
      })?.toList();

      return new Column(children: children);
    });
  }

  Widget roomInformation() {
    final leader = Provider.of<PlayerList>(context).getLeader();
    return Container(
      alignment: Alignment.center,
      // child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new RichText(
            text: TextSpan(
              text: 'Welcome to ',
              style: TextStyle(
                  color: Colors.black, fontSize: 16, fontFamily: 'Montserrat'),
              children: <TextSpan>[
                TextSpan(
                    text: leader.name,
                    style: TextStyle(
                        color: Colors.blue[300],
                        fontSize: 16,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold)),
                TextSpan(
                  text: '\'s room',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Montserrat'),
                )
              ],
            ),
          ),
          new Text(
            widget.roomId,
            style: new TextStyle(fontSize: 20.0, fontFamily: 'Montserrat'),
            textAlign: TextAlign.center,
          ),
          new Text(
            "Please wait for the leader to start",
            style: TextStyle(fontSize: 14.0, fontFamily: 'Montserrat'),
          )
        ],
      ),
      // ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Roles: player.name or null

    return new SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: new AppBar(
          title: new Text('Literature'),
        ),
        body: SingleChildScrollView(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              // _buildJoin(),
              roomInformation(),
              _playersList(),
            ],
          ),
        ),
      ),
    );
  }
}
