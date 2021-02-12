import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:osmp_project/MappingSupport.dart';

// ----
Future<void> createBasicAcctData(String accountName) async {
  //print('createBasicAcctData: creating basic account');

  // create the trailStats collection and upload it to Firestore
  createTrailStatsMap().then(
    (trails) => uploadTrailStats(trails, accountName),
  );

  // create overallStats for the user
  Map<String, Object> overallStats = {
    'completedDistance': 0,
    'percentDone': 0.0,
    'totalDistance': 247602,
  };
  Map<String, Object> stats = {
    'overallStats': overallStats,
  };
  FirebaseFirestore.instance.collection('athletes').doc(accountName).set(stats);
}

// ----
Future<Map<String, dynamic>> createTrailStatsMap() async {
  Map<String, dynamic> trails = {};
  await FirebaseFirestore.instance.collection('segments').get().then(
    (querySnapshot) {
      querySnapshot.docs.forEach(
        (document) {
          SegmentSummary segment = SegmentSummary.fromSnapshot(document);

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
    },
  );

  return trails;
}

// ----
Future<void> uploadTrailStats(
    Map<String, dynamic> trails, String accountName) async {
  //print('uploadTrails ==========');
  //print(trails);

  //put things here:
  trails.forEach(
    (trailId, trail) {
      FirebaseFirestore.instance
          .collection('athletes')
          .doc(accountName)
          .collection('trailStats')
          .doc(trailId)
          .set(trail);
    },
  );
}
