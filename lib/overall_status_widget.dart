import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/MappingSupport.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:provider/provider.dart';

Future<void> setAccessTime(String email) async {
  // ----
  // record the time the user accessed this data
  // - eventually want to delete inactive user accounts
  Map<String, Object> lastAccessTime = {
    'lastAccessTime': DateTime.now().toString(), // local time
    'dateTime': DateTime.now().millisecondsSinceEpoch,
  };
  Map<String, Object> accessTime = {
    'accessTime': lastAccessTime,
  };
  await FirebaseFirestore.instance
      .collection('athletes')
      .doc(email)
      .set(accessTime, SetOptions(merge: true))
      .whenComplete(() => {print('updating access time <>')});
}

class OverallStatusWidget extends StatelessWidget {
  final SettingsOptions settingsOptions;

  OverallStatusWidget(this.settingsOptions);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();
    setAccessTime(firebaseUser.email);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('athletes').doc(firebaseUser.email).snapshots().where(
            (event) => event.data().containsKey('overallStats'),
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        if (snapshot.hasError) return LinearProgressIndicator();
        return _buildStatus(context, snapshot.data, settingsOptions);
      },
    );
  }

  Widget _buildStatus(BuildContext context, DocumentSnapshot data, SettingsOptions settingsOptions) {
    var stats = data["overallStats"];
    var percent = stats["percentDone"].toDouble();
    var completed = (stats["completedDistance"] * 0.000621371).toStringAsFixed(2);
    var total = (stats["totalDistance"] * 0.000621371).toStringAsFixed(2);
    percent = percent >= 0.98 ? 1.0 : percent;

    var progress = LinearProgressIndicator(
      value: percent,
    );

    MapData inputMapSummaryData = new MapData();
    inputMapSummaryData.isMapSummary = true;
    inputMapSummaryData.percentComplete = percent;

    final firebaseUser = context.watch<User>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5.0),
            // color: Colors.lightGreen,
            // gradient: background,
          ),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  "Overall completion: " + " " + completed + " of " + total + " miles",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.white,
                  ),
                ),
                subtitle: Text((percent * 100).toStringAsFixed(2) + "%    < " + firebaseUser.email + " >"),
                trailing: IconButton(
                  icon: Icon(
                    Icons.map,
                    color: Colors.blue,
                  ),
                  padding: EdgeInsets.all(0),
                  alignment: Alignment.centerRight,
                  onPressed: () => displayMapSummary(context, inputMapSummaryData, settingsOptions),
                ),
                onTap: () => displayMapSummary(context, inputMapSummaryData, settingsOptions),
              ),
              progress,
            ],
          )),
    );
  }
}
