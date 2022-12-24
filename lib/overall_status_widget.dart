import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/mapping_support.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:provider/provider.dart';

class OverallStatusWidget extends StatelessWidget {
  final SettingsOptions settingsOptions;
  final bool allowUserToDisplayMapUsingButton;
  OverallStatusWidget(this.settingsOptions, this.allowUserToDisplayMapUsingButton);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('athletes').doc(firebaseUser.email.toLowerCase()).snapshots().where(
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
                  onPressed: allowUserToDisplayMapUsingButton
                      ? () => displayMapSummary(context, inputMapSummaryData, settingsOptions)
                      : null,
                ),
                onTap: allowUserToDisplayMapUsingButton
                    ? () => displayMapSummary(context, inputMapSummaryData, settingsOptions)
                    : null,
              ),
              progress,
              if (allowUserToDisplayMapUsingButton == false)
                Expanded(
                  child: LoadDisplayMapSummaryData(inputMapSummaryData, settingsOptions),
                ),
            ],
          )),
    );
  }
}
