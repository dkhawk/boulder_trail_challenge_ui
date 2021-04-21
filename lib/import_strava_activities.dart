import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:oauth2_client/access_token_response.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:oauth2_client/oauth2_client.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oauth2_client/oauth2_response.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

class StravaOAuth2Client extends OAuth2Client {
  StravaOAuth2Client({String clientId, String secret})
      : super(
          authorizeUrl:
              'https://www.strava.com/oauth/mobile/authorize', //Your service's authorization url'
          tokenUrl:
              'https://www.strava.com/api/v3/oauth/token?client_id=$clientId&client_secret=$secret', //Your service access token url
          revokeUrl: 'https://www.strava.com/oauth/deauthorize',

          customUriScheme: 'myapp',
          redirectUri: 'myapp://localhost',
        );
}

// ----
class ImportStravaActivities extends StatefulWidget {
  @override
  _ImportStravaActivitiesState createState() => _ImportStravaActivitiesState();
}

// ----
class _ImportStravaActivitiesState extends State<ImportStravaActivities> {
  DateTime selectedStartDate = DateTime(2021, 1, 1);

  // ----
  Future<void> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate,
      firstDate: DateTime(2021, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedStartDate)
      setState(() {
        selectedStartDate = picked;
      });
  }

  // ----
  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();
    String userName = firebaseUser.email;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Import Strava Activities'),
          ],
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Spacer(),
            Image(
              image: AssetImage('assets/images/Strava.png'),
              width: 140,
              height: 140,
            ),
            Spacer(
              flex: 2,
            ),
            ElevatedButton(
              child: Column(
                children: [
                  Text('Press here to import activities from Strava'),
                  Text(
                    'Activities from the start date until today will be imported',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return Scaffold(
                        body: _importStrava(
                          userName,
                          selectedStartDate,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            ElevatedButton(
              child: Column(
                children: [
                  Text('Start date: (press to change)'),
                  Text(
                    '${DateFormat.yMMMEd().format(selectedStartDate)}',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ],
              ),
              onPressed: () => _selectDate(context),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}

// ----
class _importStrava extends StatefulWidget {
  _importStrava(this.userName, this.selectedStartDate);
  final userName;
  final selectedStartDate;

  @override
  _importStravaState createState() =>
      _importStravaState(userName, selectedStartDate);
}

// ----
class _importStravaState extends State<_importStrava> {
  _importStravaState(this.userName, this.selectedStartDate);
  final userName;
  final selectedStartDate;

  int numFilesUploaded = 0;
  bool tokenIsValid = false;

  // ----
  Future<String> _getActivities(userName) async {
    String clientId = '43792';
    String secret = 'b5cc7b11df2bf0390406f4bcc88592f7944880e9';

    StravaOAuth2Client stravaClient = StravaOAuth2Client(
      clientId: clientId,
      secret: secret,
    );

    OAuth2Helper oAuth2Helper = OAuth2Helper(stravaClient,
        grantType: OAuth2Helper.AUTHORIZATION_CODE,
        clientId: clientId,
        clientSecret: secret,
        scopes: ['activity:read']);

    // take a look at the token
    // - returns a previously acquired token or gets a new one if necessary
    AccessTokenResponse tknResp = await oAuth2Helper.getToken();

    // if token is valid
    if (tknResp.isValid()) {
      tokenIsValid = true;

      // print('token: status  ${tknResp.httpStatusCode}');
      // print('       error   ${tknResp.error}');
      // print('       expires ${tknResp.expirationDate}');
      // print('       type    ${tknResp.tokenType}');
      // print('       accessT ${tknResp.accessToken}');

      AccessTokenResponse tknResp2 = await oAuth2Helper.getToken();

      // the athlete:
      const String reqAthlete = 'https://www.strava.com/api/v3/athlete';
      var _athlete = await oAuth2Helper.get(reqAthlete);
      //print('AthleteBody: ${_athlete.body}');

      int _pageNumber = 1;
      int _perPage = 20; // Number of activities retrieved per http request
      var _nowTime = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      var _afterTime =
          (selectedStartDate.millisecondsSinceEpoch / 1000).round();

      bool isRetrieveDone = false;
      do {
        // List of activities for the athlete
        final String reqActivities =
            'https://www.strava.com/api/v3/athlete/activities' +
                '?before=$_nowTime&after=$_afterTime&page=$_pageNumber&per_page=$_perPage';

        var activities = await oAuth2Helper.get(reqActivities);

        // keep track of how many activities so we can move to the next page
        // and get more if necessary
        int _nbActivity = 0;
        if (activities.statusCode == 200) {
          // decode the activities
          var jsonActivities = json.decode(activities.body);
          jsonActivities.forEach((activitySummary) {
            // the encoded polyline for this activity
            Map<String, dynamic> theActivityMap = activitySummary['map'];

            // a map for the Cloud storage data
            String uploadDateTime = DateTime.now().toUtc().toString();
            Map<String, dynamic> importedTrackMap = {
              'originalFileName': activitySummary['external_id'],
              'gpxDateTime': activitySummary['start_date_local'],
              'uploadDateTime': uploadDateTime,
              'userName': userName,
              'encodedLocation': theActivityMap['summary_polyline'],
              'processed': false,
            };

            // do the actual upload to the cloud
            String encodedTrackUploadLocation =
                activitySummary['external_id'] + '.gencoded';
            numFilesUploaded++;
            print(
                'Uploading file: = $numFilesUploaded <> ${activitySummary['start_date_local']} <> $encodedTrackUploadLocation');

            FirebaseFirestore.instance
                .collection('athletes')
                .doc(userName)
                .collection('importedData')
                .doc(encodedTrackUploadLocation)
                .set(importedTrackMap);

            _nbActivity++;
          });

          // are we done with all the pages?
          if (_nbActivity < _perPage) {
            print('isRetrieveDone');
            isRetrieveDone = true;
          } else {
            // Move to the next page
            print('next page');
            _pageNumber++;
          }
        } else {
          // ----
          print('Activities info found an error!!');
          isRetrieveDone = true;
        }
      } while (!isRetrieveDone);
    } else {
      tokenIsValid = false;
      print('token: false status  ${tknResp.httpStatusCode}');
    }

    print('Number of Strava files uploaded = $numFilesUploaded');

    // get and update the number of files uploaded
    // - this is used to trigger the cloud script that processes the uploaded files
    if(tokenIsValid) {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('athletes')
          .doc(userName)
          .collection('importedData')
          .doc('UploadStats')
          .get();
      int numFilesPreviouslyUploaded = documentSnapshot.get('numFilesUploaded');
      int totalFilesUploaded = numFilesPreviouslyUploaded + numFilesUploaded;
      print(
          'Number of files previously uploaded = $numFilesPreviouslyUploaded');
      print(
          'Total number of files gpx or Strava files uploaded = $totalFilesUploaded');
      Map<String, dynamic> numFilesUploadedMap = {
        'numFilesUploaded': totalFilesUploaded,
      };
      await FirebaseFirestore.instance
          .collection('athletes')
          .doc(userName)
          .collection('importedData')
          .doc('UploadStats')
          .set(numFilesUploadedMap);
    }

    return 'done';
  }

  // ----
  Widget _numFilesAlertWidget(BuildContext context) {
    String stravaText =
        numFilesUploaded.toString() + ' activities synchronized';
    if (tokenIsValid == false) stravaText = 'Strava authorization failed';

    return AlertDialog(
      title: Text('Strava Activity Synchronization',
          style: TextStyle(fontSize: 20, color: Colors.white)),
      content: Text(
        stravaText,
        style: TextStyle(fontSize: 15, color: Colors.white),
      ),
      backgroundColor: Colors.deepPurple,
      shape:
          RoundedRectangleBorder(borderRadius: new BorderRadius.circular(15)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('OK', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // ----
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getActivities(userName),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        List<Widget> children;
        if (snapshot.hasData && (snapshot.data == 'done')) {
          print('Strava activities: snapshot.hasData and done');
          return _numFilesAlertWidget(context);
        } else {
          return Center(
            child: Column(
              children: [
                Spacer(
                  flex: 5,
                ),
                SizedBox(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  width: 40,
                  height: 40,
                ),
                Spacer(),
                Text('Importing Strava activities...',
                    style: TextStyle(color: Colors.black, fontSize: 12.0)),
                Spacer(
                  flex: 5,
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

// ----
Future<void> RevokeStravaAccess() async {
  // Strava input is only valid on mobile platforms
  if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
    String clientId = '43792';
    String secret = 'b5cc7b11df2bf0390406f4bcc88592f7944880e9';

    StravaOAuth2Client stravaClient = StravaOAuth2Client(
      clientId: clientId,
      secret: secret,
    );
    OAuth2Helper oAuth2Helper = OAuth2Helper(stravaClient,
        grantType: OAuth2Helper.AUTHORIZATION_CODE,
        clientId: clientId,
        clientSecret: secret,
        scopes: ['activity:read']);

    AccessTokenResponse tknResp = await oAuth2Helper.getTokenFromStorage();
    if (tknResp != null && tknResp.isValid()) {
      print('RevokeStravaAccess: removing strava tokens');

      if (tknResp.httpStatusCode != 200)
        print(
            'RevokeStravaAccess():: httpStatusCode ERROR <getTokenFromStorage> ${tknResp
                .httpStatusCode}');

      // print('tokenFromStorage: status  ${tknResp.httpStatusCode}');
      // print('                  error   ${tknResp.error}');
      // print('                  expires ${tknResp.expirationDate}');
      // print('                  type    ${tknResp.tokenType}');
      // print('                  accessT ${tknResp.accessToken}');

      // Hack: Strava requires the deauthorize token to be called 'access_token' rather than just 'token'
      // so we add a bit-o-string to the revokeUrl
      stravaClient.revokeUrl =
      'https://www.strava.com/oauth/deauthorize?access_token=${tknResp
          .accessToken}';

      OAuth2Response oAuth2Response =
      await stravaClient.revokeAccessToken(tknResp);

      if (oAuth2Response.httpStatusCode != 200)
        print(
            'RevokeStravaAccess():: httpStatusCode ERROR <revokeAccessToken> ${oAuth2Response
                .httpStatusCode}');

      // expect httpStatusCode = 200 'ok'
      //        httpStatusCode = 400 is 'bad request'
      //        httpStatusCode = 401 is 'unauthorized'
      //
      // print('oAuth2Response ${oAuth2Response.httpStatusCode}');
      // print('oAuth2Response ${oAuth2Response.errorDescription}');
      // print('oAuth2Response ${oAuth2Response.error}');
    } else {
      print('RevokeStravaAccess: no strava access token found');
    }

    // knock everything out of storage
    oAuth2Helper.removeAllTokens();
  }
}
