import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:osmp_project/MappingSupport.dart';

import 'package:osmp_project/authentication_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

final String validAccountRegistration = 'validAccountRegistration';
final String finishedUploadTrailStats = 'finishedUploadTrailStats';

// ----
Future<String> registerNewAcct(
  BuildContext context,
  String accountName,
  String password,
) async {
  // see whether this account has already been set up or the account name is malformed
  // - return with error string if so
  // - code is checking only whether the account is valid and we expect this
  //   to throw a "weak-password" exception if the account is valid
  //print('registerNewAcct ====');
  try {
    await context.read<AuthenticationService>().signUp(
          email: accountName,
          password: 'dummy', // an invalid password
        );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'weak-password') {
      // String eString = e.toString();
      // String eMessage = e.message;
      // print('account registration: success: $eString');
      // print(e.code);
      // print('account registration: success: $eMessage');
    } else {
      String eString = e.toString();
      String eMessage = e.message;
      print('account registration: $eString');
      print(e.code);
      print('account registration: returning error message: $eMessage');
      return eMessage;
    }
  }
  //print('registerNewAcct success ====');

  // now that the account appears to be valid actually create the account in
  // a secondary FirebaseApp that does not have a listener attached
  // - we do not want the primary FirebaseApp to trigger the trails progress
  //   widgets until the account data has been fully uploaded to Cloud Firestore
  String secondaryFirebaseApp =
      createUniqueFirebaseAppName(accountName, password);
  FirebaseApp app = await Firebase.initializeApp(
    name: secondaryFirebaseApp,
    options: Firebase.app().options,
  );

  try {
    // Secondary FirebaseApp account creation
    await FirebaseAuth.instanceFor(app: app).createUserWithEmailAndPassword(
      email: accountName,
      password: password,
    );
  } on FirebaseAuthException catch (e) {
    String eString = e.toString();
    String eMessage = e.message;
    print('account creation: $eString');
    print(e.code);
    print('account creation: returning error message: $eMessage');

    await app.delete();
    return eMessage;
  }

  //print('account registration: validAccountRegistration');
  return validAccountRegistration;
}

// ----
Widget createNewAcct(
  BuildContext context,
  String accountName,
  String password,
) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return Scaffold(
          body: LoadSegmentsData(accountName, password,
              false /*do not reset trail data instead create new user data*/),
        );
      },
    ),
  );

  return Scaffold(body: Center(child: Text('Creating user account')));
}

//----
class LoadSegmentsData extends StatelessWidget {
  LoadSegmentsData(this.accountName, this.password, this.resettingData);
  final String accountName;
  final String password;
  final bool resettingData;

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
          return _UploadMapDataToAcct(
              trails, accountName, password, resettingData);
        }
        return Center(
          child: SizedBox(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
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
  _UploadMapDataToAcct(
      this.trails, this.accountName, this.password, this.resettingData);
  final String accountName;
  final String password;
  final bool resettingData;
  final Map<String, dynamic> trails;

  @override
  Widget build(BuildContext context) {
    String userAction = 'Creating your account';
    if (resettingData) userAction = 'Resetting your activities';

    return FutureBuilder<String>(
      future: _uploadTrailStats(trails, accountName, password, resettingData),
      builder: (BuildContext context, AsyncSnapshot<String> completedString) {
        if (completedString.hasData &&
            completedString.data.toString() == finishedUploadTrailStats) {
          // After all data has been uploaded to Cloud Firestore sign
          // into the user's account

          // print('signing in on real acct ==== ');
          if (resettingData == false) {
            context.read<AuthenticationService>().signIn(
                  email: accountName,
                  password: password,
                );
          }
          // show a welcome/reset page with basic instructions
          return _WelcomePage(resettingData);
        }
        return Center(
          child: Column(
            children: [
              Spacer(
                flex: 5,
              ),
              SizedBox(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                width: 40,
                height: 40,
              ),
              Spacer(),
              Text(userAction),
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
  Map<String, dynamic> trails,
  String accountName,
  String password,
  bool resettingData,
) async {
  // print('_uploadTrailStats ====');
  //print(trails);

  // Get the secondary FirebaseApp and associated FirebaseFirestore
  // used during account registration
  List<FirebaseApp> firebaseapps = Firebase.apps;
  FirebaseFirestore firestoreSecondary;
  String secondaryFirebaseApp;

  if (resettingData) {
    firestoreSecondary = FirebaseFirestore.instance;
  } else {
    secondaryFirebaseApp = createUniqueFirebaseAppName(accountName, password);
    for (int iApp = 0; iApp < firebaseapps.length; iApp++) {
      if (firebaseapps[iApp].name == secondaryFirebaseApp)
        firestoreSecondary =
            FirebaseFirestore.instanceFor(app: firebaseapps[iApp]);
    }
  }

  // print('_uploadTrailStats compute totalDistance ====');
  // compute totalDistance
  // - cannot do this in the firestore future set loop below...
  int totalDistance = 0;
  trails.forEach(
    (trailId, trail) {
      totalDistance += trail['length'];
    },
  );

  // create and upload the overallStats and dummy Strava tokens for the user
  double percentDone = 0.0;
  String emptyString = '';
  Map<String, Object> overallStats = {
    'completedDistance': 0,
    'percentDone': percentDone,
    'totalDistance': totalDistance,
  };

  Map<String, Object> statsMap = {
    'overallStats': overallStats,
  };

  await firestoreSecondary
      .collection('athletes')
      .doc(accountName)
      .set(statsMap, SetOptions(merge: true))
      .whenComplete(
          () => print('_uploadTrailStats ==== overallStats whenComplete'));

  // if creating a new user set up empty token info
  if (resettingData == false) {
    Map<String, Object> tokens = {
      'access_token': emptyString,
      'expires_at': -1,
      'expires_in': -1,
      'refresh_token': emptyString,
      'token_type': 'Bearer',
    };
    Map<String, Object> tokensMap = {
      'tokenInfo': tokens,
    };
    await firestoreSecondary
        .collection('athletes')
        .doc(accountName)
        .set(tokensMap, SetOptions(merge: true))
        .whenComplete(
            () => print('_uploadTrailStats ==== tokenInfo whenComplete'));
  }

  // upload the trail stats
  trails.forEach(
    (trailId, trail) async {
      await firestoreSecondary
          .collection('athletes')
          .doc(accountName)
          .collection('trailStats')
          .doc(trailId)
          .set(trail)
          .whenComplete(() => print('    uploaded trail $trailId'));
    },
  );
  // print('_uploadTrailStats ==== trailStats finished');

  await firestoreSecondary
      .collection('athletes')
      .doc(accountName)
      .collection('completed')
      .get()
      .then((snapshot) {
    for (DocumentSnapshot doc in snapshot.docs) {
      doc.reference.delete();
    }
  });
  // print('_uploadTrailStats ==== deleted completed segments');

  // keep track of how many gpx files the user has uploaded
  // - when this is updated this triggers a cloud function to process the data
  Map<String, Object> uploadStats = {
    'numFilesUploaded': 0,
  };
  await firestoreSecondary
      .collection('athletes')
      .doc(accountName)
      .collection('importedData')
      .doc('UploadStats')
      .set(uploadStats, SetOptions(merge: true))
      .whenComplete(() => print('    uploaded UploadStats'));

  // flush local cache
  await firestoreSecondary.waitForPendingWrites();

  // sign out of the all FirebaseApps
  if (resettingData == false) {
    for (int iApp = 0; iApp < firebaseapps.length; iApp++) {
      await FirebaseAuth.instanceFor(app: firebaseapps[iApp]).signOut();
    }

    // Get rid of the Secondary FirebaseApp
    for (int iApp = 0; iApp < firebaseapps.length; iApp++) {
      if (firebaseapps[iApp].name == secondaryFirebaseApp)
        await firebaseapps[iApp].delete();
    }
  }

  //print('_uploadTrailStats returning finishedUploadTrailStats ====');
  return finishedUploadTrailStats;
}

// ----
class _WelcomePage extends StatelessWidget {
  _WelcomePage(this.resettingData);
  final bool resettingData;
  @override
  Widget build(BuildContext context) {
    // --
    // text for how-to dialog
    String welcomeString = 'Welcome to the Boulder Trails Challenge!';
    if (resettingData)
      welcomeString =
          'Your Activity Data For The \nBoulder Trails Challenge Has Been Reset';
    String introString1 =
        'This app is designed to help you keep track of which \ntrails you have covered in the \n';
    String osmp = 'Boulder Open Space and Mountain Parks\n';
    String introString2 = ' trails challenge';

    String howtoString1 =
        'Go to the Settings Page to upload your tracks via \nStrava or ' +
            'import them using GPX files. ';
    String howtoString2 =
        'Click on the blue \'runner\' icons on the Trails List \npage to see maps of your progress. ';

    //print('_WelcomePage ====');
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Spacer(flex: 4),
          Text(
            welcomeString,
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

// ----
String createUniqueFirebaseAppName(String accountName, String password) {
  String createUniqueFirebaseAppName =
      'secondaryFirebaseApp' + accountName + password;
  return createUniqueFirebaseAppName;
}
