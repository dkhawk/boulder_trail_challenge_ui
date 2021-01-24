import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:osmp_project/settings_page.dart';
import 'package:osmp_project/MappingSupport.dart';

/// This is the stateful widget that the main application instantiates.
class BottomNavWidget extends StatefulWidget {
  BottomNavWidget({Key key}) : super(key: key);

  @override
  _BottomNavWidgetState createState() => _BottomNavWidgetState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _BottomNavWidgetState extends State<BottomNavWidget> {
  int _selectedIndex = 0;
  static const TextStyle optionStyle =
  TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  SettingsOptions settingsOptions = new SettingsOptions();

  List<Widget> _widgetOptions() => <Widget>[
    TrailsProgressWidget(TrailStatus.inProgress, settingsOptions),
    TrailsProgressWidget(TrailStatus.completed, settingsOptions),
    SettingsPage(settingsOptions),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> theBottomWidget = _widgetOptions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boulder Trails Challenge'),
      ),
      body: Center(
        child: theBottomWidget[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'In progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.done),
            label: 'Completed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

enum TrailStatus { inProgress, completed }

class TrailsProgressWidget extends StatelessWidget {
  TrailsProgressWidget(this.trailStatus, this.settingsOptions);
  final TrailStatus trailStatus;
  final SettingsOptions settingsOptions;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Column(
      children: <Widget>[
        _buildSummary(context),
        Expanded(child: _buildTodo(context))
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('athletes')
          .doc("dkhawk@gmail.com")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return _buildStatus(context, snapshot.data, settingsOptions);
      },
    );
  }

  Widget _buildStatus(BuildContext context, DocumentSnapshot data, SettingsOptions settingsOptions) {
    var stats = data["overallStats"];
    var percent = stats["percentDone"];
    var completed = (stats["completedDistance"] * 0.000621371).toStringAsFixed(2);
    var total = (stats["totalDistance"] * 0.000621371).toStringAsFixed(2);
    percent = percent >= 0.98 ? 1.0 : percent;

    var progress = LinearProgressIndicator(
      value: percent,
    );

    MapData inputMapSummaryData = new MapData();
    inputMapSummaryData.isMapSummary = true;
    inputMapSummaryData.percentComplete = percent;

    // return Text(
    //     "Overall completion: " + (percent * 100).toStringAsFixed(2) + "%");
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5.0),
            // color: Colors.lightGreen,
            // gradient: background,
          ),
          child: Column(
            children: [
              ListTile(
                title: Text("Overall completion: " +
                    " " +
                    completed +
                    " of " +
                    total +
                    " miles"),
                subtitle: Text((percent * 100).toStringAsFixed(2) + "%"),
                trailing: IconButton(
                  icon: Icon(
                    Icons.done_all,
                    color: Colors.blue,
                  ),
                  padding: EdgeInsets.all(0),
                  alignment: Alignment.centerRight,
                  onPressed: () => displayMapSummary(context, inputMapSummaryData, settingsOptions),
                ),
              ),
              progress,
            ],
          )
      ),
    );

  }

  Widget _buildTodo(BuildContext context) {
    CollectionReference collection = FirebaseFirestore.instance
        .collection('athletes')
        .doc("dkhawk@gmail.com")
        .collection("trailStats");

    var byStatus = trailStatus == TrailStatus.inProgress
        ? collection.where("percentDone", isLessThan: 0.98)
        : collection.where("percentDone", isGreaterThanOrEqualTo: 0.98);

    return StreamBuilder<QuerySnapshot>(
      stream: byStatus.orderBy("percentDone", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return _buildTrailsList(context, snapshot.data.docs);
      },
    );
  }

  Widget _buildTrailsList(BuildContext context, List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children:
      snapshot.map((data) => _buildTrailsListItem(context, data)).toList(),
    );
  }

  Widget _buildTrailsListItem(BuildContext context, DocumentSnapshot data) {
    final trail = TrailSummary.fromSnapshot(data);
    final percent = trail.percentDone >= 0.98 ? 1.0 : trail.percentDone;
    final completedMiles =
    (trail.completedDistance * 0.000621371).toStringAsFixed(2);
    final total = (trail.length * 0.000621371).toStringAsFixed(2);

    var progress = LinearProgressIndicator(
      value: percent,
    );

    return Padding(
      key: ValueKey(trail.trailId),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5.0),
          // color: Colors.lightGreen,
          // gradient: background,
        ),
        child: Column(
          children: [
            ListTile(
              title: Text(trail.name +
                  // " (" +
                  // trail.trailId +
                  // ")" +
                  " " +
                  completedMiles +
                  " of " +
                  total +
                  " miles"),
              //trailing: Text((percent * 100).toStringAsFixed(2) + "%"),
              subtitle: Text((percent * 100).toStringAsFixed(2) + "%"),
              trailing: IconButton(
                icon: Icon(
                  Icons.directions_run_outlined,
                  color: Colors.blue,
                ),
                padding: EdgeInsets.all(0),
                alignment: Alignment.centerRight,
                onPressed: () => displayMap(context, trail, settingsOptions),
              ),
            ),
            progress,
          ],
        )
      ),
    );
  }
}

class TrailSummary {
  TrailSummary();

  String trailId = '';
  String name = '';
  int length = -1;
  int completedDistance = -1;
  var percentDone = -1.0;
  List completedSegs = [];
  List remainingSegs = [];
  DocumentReference reference;
  // completed
  // remaining

  TrailSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['length'] != null),
        assert(map['completedDistance'] != null),
        assert(map['percentDone'] != null),
        trailId = reference.id,
        name = map['name'],
        length = map['length'],
        completedDistance = map['completedDistance'],
        percentDone = map['percentDone'].toDouble(),
        completedSegs = map['completed'],
        remainingSegs = map['remaining'];

  TrailSummary.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
