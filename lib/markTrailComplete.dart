import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:osmp_project/MappingSupport.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

showCompleteTrailManuallyDialog(BuildContext context, String trailName) {
  final firebaseUser = Provider.of<User>(context, listen: false);
  String userName = firebaseUser.email.toLowerCase();

  // ----
  // Show the confirmation dialog above asking the user to confirm that user really wants to mark this trail as complete
  showDialog(
    context: context,
    builder: (BuildContext context) {
      // if the user confirms then the code will read the json file with encoded locations for the trail
      // and send these to the firestore database; the cloud function will be triggered and the stats updated

      // set up an AlertDialog to confirm that user really wants to mark this trail as complete
      return AlertDialog(
        title: Text(
          'Mark the "$trailName" trail as complete?',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        content: Text(
          'Because trails get rerouted...\nEquipment fails...\n\nNote that this cannot be reversed',
          style: TextStyle(fontSize: 14, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: new BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return Scaffold(
                      body: _LoadMapDataSetComplete(userName, trailName),
                    );
                  },
                ),
              ).whenComplete(
                () => {Navigator.of(context).popUntil((route) => route.isFirst)},
              );
            },
            child: Text('Yes', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, ModalRoute.withName('/singleTrail'));
            },
            child: Text('No', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

//----
class _LoadMapDataSetComplete extends StatelessWidget {
  _LoadMapDataSetComplete(this.userName, this.trailName);
  final String userName;
  final String trailName;

  @override
  Widget build(BuildContext context) {
    // --
    // Pull the trail segment data out of assets/MapData/encoded-segments.json
    // print(' userName  <> $userName');
    // print(' trailName <> $trailName');
    String uploadDateTime = DateTime.now().toUtc().toString();

    int numFilesUploaded = 0;
    return FutureBuilder<String>(
      future: readSegmentsStringFromJson(),
      builder: (BuildContext context, AsyncSnapshot<String> jsonString) {
        if (jsonString.hasData) {
          Map<String, dynamic> jsonMapObject = jsonDecode(jsonString.data);
          jsonMapObject.forEach(
            (key, trailSeg) {
              SegmentSummary segment = SegmentSummary.fromMap(trailSeg);
              String locations = segment.encodedLocations;

              if (segment.name == trailName) {
                // print(' encoded Locations <> ${segment.segmentNameId}');
                // print('                   <> $locations');

                String encodedTrackUploadLocation = segment.segmentNameId + '_trackSeg' + '.gencoded';

                // a map for the uploaded data
                Map<String, dynamic> importedTrackMap = {
                  'originalFileName': 'manualMarkComplete',
                  'gpxDateTime': uploadDateTime,
                  'uploadDateTime': uploadDateTime,
                  'userName': userName,
                  'encodedLocation': locations,
                  'processed': false,
                };

                // do the actual upload if not empty
                if (locations.isNotEmpty) {
                  numFilesUploaded++;

                  FirebaseFirestore.instance
                      .collection('athletes')
                      .doc(userName)
                      .collection('importedData')
                      .doc(encodedTrackUploadLocation)
                      .set(importedTrackMap);
                } else {
                  print('Uploading manual activity failed: = <> $uploadDateTime <> encodedTrackUploadLocation is EMPTY');
                }
              }
            },
          );

          return _UpdateUploadStats(
            numFilesUploaded,
            userName,
            trailName,
          );
        } else {
          Center(
            child: SizedBox(
              child: CircularProgressIndicator(),
              width: 40,
              height: 40,
            ),
          );
        }

        return Center(
          child: SizedBox(
            child: CircularProgressIndicator(),
            width: 40,
            height: 40,
          ),
        );
      },
    );
  }
}

//----
class _UpdateUploadStats extends StatelessWidget {
  _UpdateUploadStats(this.numFilesUploaded, this.userName, this.trailName);
  final int numFilesUploaded;
  final String userName;
  final String trailName;

  Future<int> updateStats() async {
    DocumentSnapshot documentSnapshot =
        await FirebaseFirestore.instance.collection('athletes').doc(userName).collection('importedData').doc('UploadStats').get();
    int numFilesPreviouslyUploaded = documentSnapshot.get('numFilesUploaded');
    int totalFilesUploaded = numFilesPreviouslyUploaded + numFilesUploaded;
    print('Number of files previously uploaded = $numFilesPreviouslyUploaded');
    print('Total number of files gpx or Strava files uploaded = $totalFilesUploaded');
    Map<String, dynamic> numFilesUploadedMap = {
      'numFilesUploaded': totalFilesUploaded,
    };
    await FirebaseFirestore.instance
        .collection('athletes')
        .doc(userName)
        .collection('importedData')
        .doc('UploadStats')
        .set(numFilesUploadedMap, SetOptions(merge: true));

    return totalFilesUploaded;
  }

  @override
  Widget build(BuildContext context) {
    String action = 'Marking "$trailName" as completed';
    return FutureBuilder<int>(
      future: updateStats(),
      builder: (BuildContext context, AsyncSnapshot<int> numFilesUploaded) {
        if (numFilesUploaded.hasData && numFilesUploaded.data > 0) {
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/TopoMapPattern.png"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.grey, BlendMode.lighten),
              ),
            ),
            width: double.infinity,
            child: AlertDialog(
              title: Text(
                '"$trailName" Marked As Complete',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: new BorderRadius.circular(15)),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'OK',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        } else {
          Center(
            child: SizedBox(
              child: CircularProgressIndicator(),
              width: 40,
              height: 40,
            ),
          );
        }

        return Center(
          child: Column(
            children: [
              Spacer(
                flex: 5,
              ),
              SizedBox(
                child: CircularProgressIndicator(),
                width: 40,
                height: 40,
              ),
              Spacer(),
              Text(
                action,
                style: TextStyle(fontSize: 14, color: Colors.black),
              ),
              Spacer(
                flex: 5,
              ),
            ],
          ),
        );
      },
    );
  }
}
