import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/MappingSupport.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:provider/provider.dart';

class TrailProgressListWidget extends StatelessWidget {
  TrailProgressListWidget({Key key, this.progressFilterValue: 'All', this.settingsOptions}) : super(key: key);

  final SettingsOptions settingsOptions;
  final String progressFilterValue;

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();

    CollectionReference trailCollection = FirebaseFirestore.instance
        .collection('athletes')
        .doc(firebaseUser.email)
        .collection("trailStats");

    return StreamBuilder<QuerySnapshot>(
      stream: trailCollection.orderBy("name").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        var docs = snapshot.data.docs;
        return _buildTrailsList(
            context,
            docs
        );
      },
    );
  }

  Widget _buildTrailsList(BuildContext context, List<DocumentSnapshot> snapshot) {
    var trails = snapshot.map((data) => TrailSummary.fromSnapshot(data)).toList();
    trails.retainWhere((trail) => matchesFilter(trail));

    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: trails.map((trail) => _buildTrailsListItem(context, trail)).toList(),
    );
  }

  bool matchesFilter(TrailSummary trail) {
    // Just shoot me!  Use enum values or something.  Not strings!
    if (progressFilterValue == 'In progress' && trail.percentDone >= 0.99999) {
      return false;
    } else if (progressFilterValue == 'Completed' && trail.percentDone < 0.99999) {
      return false;
    }
    return true;
  }

  Widget _buildTrailsListItem(BuildContext context, TrailSummary trail) {
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
          )),
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

  TrailSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['length'] != null),
        assert(map['completedDistance'] != null),
        assert(map['percentDone'] != null),
        trailId = reference.id,
        name = map['name'],
        length = map['length'],
        completedDistance = map['completedDistance'],
        percentDone = map['percentDone'].toDouble() >= 0.95 ? 1.0 : map['percentDone'].toDouble(),
        completedSegs = map['completed'],
        remainingSegs = map['remaining'];

  TrailSummary.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
