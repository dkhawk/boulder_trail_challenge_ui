import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:osmp_project/MappingSupport.dart';

// ----
Widget createBasicAcctDataWidget(BuildContext context, String accountName) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return Scaffold(
          body: _LoadSegmentsData(accountName),
        );
      },
    ),
  );

  return Scaffold(body: Center(child: Text('Creating user account')));
}

//----
class _LoadSegmentsData extends StatelessWidget {
  _LoadSegmentsData(this.accountName);
  final String accountName;

  @override
  Widget build(BuildContext context) {
    // --
    // Pull the trail segment data out of assets/MapData/encoded-segments.json
    // Reformat and push into the new users account
    return FutureBuilder<String>(
      future: readSegmentsStringFromJson(),
      builder: (BuildContext context, AsyncSnapshot<String> jsonString) {
        if (jsonString.hasData) {
          Map<String, dynamic> trails = {};
          Map<String, dynamic> jsonMapObject = jsonDecode(jsonString.data);
          jsonMapObject.forEach(
            (key, trailSeg) {
              SegmentSummary segment = SegmentSummary.fromMap(trailSeg);

              String trailName = segment.name;
              String trailId = segment.trailId;
              String segId = segment.segmentNameId;
              int segLength = segment.length;

              if (trails.isNotEmpty && trails.containsKey(trailId)) {
                // print('---- updating');
                Map<String, dynamic> trailMap = trails[trailId];
                trailMap['length'] = segLength + trailMap['length'];
                List<dynamic> remainingSegs = trailMap['remaining'];
                remainingSegs.add(segId);
                trailMap['remaining'] = remainingSegs;

                //print(trailMap);
              } else {
                // print('---- creating');
                // print(trailName);
                Map<String, dynamic> trailMap = {
                  'name': trailName,
                  'percentDone': 0.0,
                  'completedDistance': 0,
                  'completed': [],
                  'remaining': [segId],
                  'length': segLength,
                };
                trails[trailId] = trailMap;
              }
            },
          );
          return _UploadMapDataToAcct(trails, accountName);
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
// upload the trails and show a simple how-to dialog when finished
class _UploadMapDataToAcct extends StatelessWidget {
  _UploadMapDataToAcct(this.trails, this.accountName);
  final String accountName;
  final Map<String, dynamic> trails;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _uploadTrailStats(trails, accountName),
      builder: (BuildContext context, AsyncSnapshot<String> completedString) {
        if (completedString.toString().isNotEmpty) {
          return _WelcomePage();
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
              Text('Creating your account'),
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

// ----
Future<String> _uploadTrailStats(
    Map<String, dynamic> trails, String accountName) async {
  //print('_uploadTrailStats ====');
  //print(trails);

  // compute totalDistance
  // - cannot do this in the firestore future set loop below...
  int totalDistance = 0;
  trails.forEach(
    (trailId, trail) {
      totalDistance += trail['length'];
    },
  );

  // create and upload the overallStats for the user
  double percentDone = 0.0;
  Map<String, Object> overallStats = {
    'completedDistance': 0,
    'percentDone': percentDone,
    'totalDistance': totalDistance,
  };
  Map<String, Object> stats = {
    'overallStats': overallStats,
  };
  await FirebaseFirestore.instance
      .collection('athletes')
      .doc(accountName)
      .set(stats);

  trails.forEach(
    (trailId, trail) async {
      await FirebaseFirestore.instance
          .collection('athletes')
          .doc(accountName)
          .collection('trailStats')
          .doc(trailId)
          .set(trail);
    },
  );

  // check for completion
  bool overallStatsIsEmpty = await FirebaseFirestore.instance
      .collection('athletes')
      .doc(accountName)
      .snapshots()
      .isEmpty;

  int trailStatsSize = 0;
  await FirebaseFirestore.instance
      .collection('athletes')
      .doc(accountName)
      .collection('trailStats')
      .get()
      .then((theCollection) => trailStatsSize = theCollection.size);

  if (!overallStatsIsEmpty && trailStatsSize == trails.length) {
    print('_uploadTrailStats ==== upload finished');
    return 'finished';
  }

  return '';
}

// ----
class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // --
    // text for how-to dialog
    String introString1 =
        'This app is designed to help you keep track of which \ntrails you have covered in the \n';
    String osmp = 'Boulder Open Space and Mountain Parks\n';
    String introString2 = ' trails challenge';

    String howtoString1 =
        'Go to the Settings Page to upload your tracks via \nStrava or ' +
            'import them using GPX files. ';
    String howtoString2 =
        'Click on the blue \'runner\' icons on the Trails List \npage to see maps of your progress. ';

      return SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Spacer(flex: 4),
            Text(
              'Welcome to the Boulder Trails Challenge!',
              style: TextStyle(fontSize: 30, color: Colors.purple),
              textAlign: TextAlign.center,
            ),
            Spacer(
              flex: 5,
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: introString1,
                    style: TextStyle(fontSize: 15, color: Colors.black),
                  ),
                  TextSpan(
                    text: osmp,
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        var url =
                            "https://bouldercolorado.gov/osmp/osmp-trail-challenge";
                        if (await canLaunch(url)) {
                          await launch(url);
                        } else {
                          print('Could not launch $url');
                        }
                      },
                  ),
                  TextSpan(
                    text: introString2,
                    style: TextStyle(fontSize: 15, color: Colors.black),
                  ),
                ],
              ),
            ),
            Spacer(
              flex: 2,
            ),
            Text(
              howtoString1,
              style: TextStyle(fontSize: 15, color: Colors.black),
              softWrap: true,
              textAlign: TextAlign.center,
            ),
            Text(
              howtoString2,
              style: TextStyle(fontSize: 15, color: Colors.black),
              softWrap: true,
              textAlign: TextAlign.center,
            ),
            Spacer(
              flex: 1,
            ),
            SizedBox(
              width: 150,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Continue..."),
                    ],
                  ),
                ),
              ),
            ),
            Spacer(
              flex: 4,
            ),
          ],
         ),
      );
  }
}
