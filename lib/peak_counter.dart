import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:osmp_project/pair.dart';

import 'package:flutter/material.dart';

// ----
class DisplayPeakCounts extends StatefulWidget {
  @override
  _DisplayPeakCountsState createState() => _DisplayPeakCountsState();
}

// ----
class _DisplayPeakCountsState extends State<DisplayPeakCounts> {
  @override
  Widget build(BuildContext context) {
    final userName = context.watch<User>().email;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('athletes').doc(userName).collection('peakCounts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        if (snapshot.hasError) return LinearProgressIndicator();

        // the names and locations of the peaks we're tracking
        Map<String, Pair<double, double>> peakLocations = getStandardPeakLocations();

        // initialize counts
        Map<String, int> peakCountFromFirestore = {};
        for (var peakName in peakLocations.keys) peakCountFromFirestore[peakName] = 0;

        // see whats in firestore and update counts
        snapshot.data.docs.forEach(
          (DocumentSnapshot document) {
            for (var peak in peakLocations.keys) {
              //print(' document<><> ${document.data()}');
              if (document.data().toString().contains(peak)) peakCountFromFirestore[peak] = peakCountFromFirestore[peak] + 1;
            }
          },
        );

        return _peakCountsDisplay(context, peakCountFromFirestore);
      },
    );
  }
}

// ----
Widget _peakCountsDisplay(BuildContext context, Map<String, int> peakCountFromFirestore) {
  // alphabetical sort
  var sortedKeys = peakCountFromFirestore.keys.toList()..sort();

  List<Widget> entries = [];
  for (var peakName in sortedKeys) {
    entries.add(
      ListTile(
        title: Text(
          '$peakName',
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
        trailing: Text(
          '${peakCountFromFirestore[peakName]}',
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }

  if (entries.isEmpty)
    entries.add(Text(
      'No peaks have been summited',
      style: TextStyle(fontSize: 14, color: Colors.white),
    ));

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
        'Number of time the following peaks have been summited:',
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
      content: Container(
          width: double.minPositive,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: entries.toList(),
          )),
      backgroundColor: Colors.indigo,
      shape: RoundedRectangleBorder(borderRadius: new BorderRadius.circular(15)),
      actions: <Widget>[
        TextButton(
          child: Text(
            'Dismiss',
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}

// ----
// reset count of peaks that have been summited in firestore
Future<void> resetPeakCounts(String userName) async {
  await FirebaseFirestore.instance.collection('athletes').doc(userName).collection('peakCounts').get().then(
    (snapshot) {
      for (DocumentSnapshot doc in snapshot.docs) {
        doc.reference.delete();
      }
    },
  );
}

// ----
Map<String, Pair<double, double>> getStandardPeakLocations() {
  // the locations of the peaks we want to track
  Map<String, Pair<double, double>> peakLocations = {};
  peakLocations['Green Mountain'] = Pair(39.982142, -105.301589);
  peakLocations['Mount Sanitas'] = Pair(40.03447091426174, -105.30517419412183);
  peakLocations['Bear Peak'] = Pair(39.960538, -105.295046);
  peakLocations['South Boulder Peak'] = Pair(39.954249, -105.298993);
  peakLocations['Flagstaff Trail (highest point)'] = Pair(40.00313869797883, -105.30619418430236);
  peakLocations['Woods Quarry'] = Pair(39.985138, -105.288258);

  return peakLocations;
}

// ----
Future<void> peakCounter(List<List<num>> coordinates, String dateTimeString, String userName) async {
  // --
  // get the names and locations (lat,long) of the peaks we're tracking
  Map<String, Pair<double, double>> peakLocations = getStandardPeakLocations();
  Map<String, List<String>> peakDateTimes = {};
  for (var peakName in peakLocations.keys) {
    peakDateTimes[peakName] = [];
  }

  // will use dateTimeString plus a counter to make sure peaks are not counted twice
  String uploadDateTime = DateTime.now().toUtc().toString();
  if (dateTimeString.isEmpty) dateTimeString = uploadDateTime;

  // how close does the runner need to come to the peak to consider touching it
  // how far from the peak does the runner need to go before being able to touch it again
  double touchDist = 20.0;
  double resetDist = 1000.0;

  // initialize the number of times the peak has been touched on this run
  // and whether touching the peak needs to be reset; i.e. the runner
  // has run more than reset distance from the peak
  Map<String, int> peakCount = {};
  Map<String, bool> peakReset = {};

  for (var peakName in peakLocations.keys) {
    peakCount[peakName] = 0;
    peakReset[peakName] = true;
  }

  // using the polar coordinate flat-earth formula to calculate distances between two lat/longs
  double radius = 6371e3; // metres
  double halfPi = pi / 2.0;
  double deg2Rad = pi / 180.0;

  for (var i = 1; i < coordinates.length; i++) {
    double trackLat = coordinates[i][0];
    double trackLong = coordinates[i][1];

    for (var peakName in peakLocations.keys) {
      double peakLat = peakLocations[peakName].first;
      double peakLong = peakLocations[peakName].second;

      double a = halfPi - trackLat * deg2Rad;
      double b = halfPi - peakLat * deg2Rad;
      double u = a * a + b * b - 2 * a * b * cos(trackLong * deg2Rad - peakLong * deg2Rad);

      // distance from this peak to the track
      double distance = radius * sqrt(u.abs());

      if ((distance < touchDist) && peakReset[peakName]) {
        peakCount[peakName] = peakCount[peakName] + 1;

        // don't recount touching a peak until a given distance away
        peakReset[peakName] = false;

        // add the dateTime string if it is not already in the list
        // - the represents summiting the peak a new time
        String uniqueDateTime = dateTimeString + '_' + peakCount[peakName].toString();
        if (peakDateTimes[peakName].contains(uniqueDateTime) == false) {
          peakDateTimes[peakName].add(uniqueDateTime);
          //print(' <> $peakName has been summited in this activity <> $uniqueDateTime');
        }
      }
      if (distance > resetDist) peakReset[peakName] = true;
    }
  }

  for (var peakName in peakDateTimes.keys) {
    for (var dateTime in peakDateTimes[peakName]) {
      String peakNameAndDate = peakName + '_' + dateTime;
      Map<String, dynamic> info = {
        'PeakName': peakName,
        'uniqueDate': dateTime,
      };

      FirebaseFirestore.instance.collection('athletes').doc(userName).collection('peakCounts').doc(peakNameAndDate).set(info);
    }
  }
}
