import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/mapping_support.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:osmp_project/strava_utils.dart';
import 'package:provider/provider.dart';

import 'package:osmp_project/import_strava_activities.dart';

class OverallStatusWidget extends StatefulWidget {
  final SettingsOptions settingsOptions;
  final StravaUse stravaUse;
  final bool allowUserToDisplayMapUsingButton;
  OverallStatusWidget(this.settingsOptions, this.stravaUse, this.allowUserToDisplayMapUsingButton);

  @override
  State<OverallStatusWidget> createState() => _OverallStatusWidgetState();
}

class _OverallStatusWidgetState extends State<OverallStatusWidget> {
  @override
  Widget build(BuildContext context) {
    final email = context.watch<User>().email.toLowerCase();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('athletes').doc(email).snapshots().where(
            (event) => event.data().containsKey('overallStats'),
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        if (snapshot.hasError) return LinearProgressIndicator();
        return _buildStatus(context, email, snapshot.data, widget.settingsOptions, widget.stravaUse);
      },
    );
  }

  Widget _buildStatus(
      BuildContext context, String email, DocumentSnapshot data, SettingsOptions settingsOptions, StravaUse stravaUse) {
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

    // print('last Strava update time <> ${settingsOptions.lastStravaUpdate}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5.0),
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
                subtitle: Text((percent * 100).toStringAsFixed(2) + "%    < " + email + " >"),
                trailing: widget.allowUserToDisplayMapUsingButton
                    ? IconButton(
                        icon: Icon(
                          Icons.map,
                          color: Colors.blue,
                        ),
                        padding: EdgeInsets.all(0),
                        alignment: Alignment.centerRight,
                        onPressed: widget.allowUserToDisplayMapUsingButton
                            ? () => displayMapSummary(context, inputMapSummaryData, settingsOptions)
                            : null,
                      )
                    : Visibility(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return Scaffold(
                                    body: ImportStrava(
                                      email,
                                      stravaUse.lastStravaUpdate,
                                    ),
                                  );
                                },
                              ),
                            );
                            stravaUse.offerToUpdateStrava = false;
                            setState(() {});
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Update Strava'),
                              Icon(
                                Icons.update,
                              )
                            ],
                          ),
                        ),
                        visible: stravaUse.offerToUpdateStrava,
                      ),
                onTap: widget.allowUserToDisplayMapUsingButton
                    ? () => displayMapSummary(context, inputMapSummaryData, settingsOptions)
                    : null,
              ),
              progress,
              if (widget.allowUserToDisplayMapUsingButton == false)
                Expanded(
                  child: LoadDisplayMapSummaryData(inputMapSummaryData, settingsOptions),
                ),
            ],
          )),
    );
  }
}
