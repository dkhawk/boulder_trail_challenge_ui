import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:osmp_project/pair.dart';

// ----
Future<Pair<bool, DateTime>> needToUpdateStrava(String email) async {
  bool needToUpdateStrava = false;
  DateTime lastUpdateDateTime = DateTime.now();

  await isUsingStrava(email).then(
    (isUsingStrava) async {
      if (isUsingStrava) {
        // check what time Strava was last updated
        int updateAfterSecs = 7200; // update Strava if not updated within two hours
        await FirebaseFirestore.instance
            .collection('athletes')
            .doc(email)
            .collection('importedData')
            .doc('UploadStats')
            .get()
            .then(
          (docSnapshot) {
            int lastUpdateTimeMilliSeconds = docSnapshot.get('lastUpdateTime') * 1000.0;
            lastUpdateDateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdateTimeMilliSeconds);

            if (lastUpdateTimeMilliSeconds > 0.0) {
              int nowTimeMilliSeconds = DateTime.now().millisecondsSinceEpoch;
              if ((nowTimeMilliSeconds - lastUpdateTimeMilliSeconds).abs() > updateAfterSecs * 1000.0) needToUpdateStrava = true;

              print('needToUpdateStrava <> $needToUpdateStrava $lastUpdateDateTime');
              return Pair(needToUpdateStrava, lastUpdateDateTime);
            }
          },
        );
      }
    },
  );

  return Pair(needToUpdateStrava, lastUpdateDateTime);
}

// ----
Future<bool> isUsingStrava(String email) async {
  bool isUsingStrava = false;
  await FirebaseFirestore.instance.collection('athletes').doc(email).get().then(
    (docSnapshot) {
      if (docSnapshot.data().toString().contains('tokenInfo') == true) {
        Map tokenMap = docSnapshot.data()['tokenInfo'];
        if ((tokenMap['access_token'].toString().isNotEmpty) && (tokenMap['refresh_token'].toString().isNotEmpty)) {
          isUsingStrava = true;
        }
      }
      // ----
      // print('isUsingStrava <> $isUsingStrava');
      return isUsingStrava;
    },
  );

  return isUsingStrava;
}

//----
class StravaUse {
  bool offerToUpdateStrava = false;
  DateTime lastStravaUpdate = DateTime.now();
}
