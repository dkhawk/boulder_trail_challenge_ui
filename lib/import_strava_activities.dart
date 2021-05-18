import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

// authorization on the mobile side::
import 'package:oauth2_client/access_token_response.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:oauth2_client/oauth2_client.dart';

// authorization on web side::
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:universal_html/html.dart' as html;

// ----
// globals
final String clientId = '43792';
final String secret = 'b5cc7b11df2bf0390406f4bcc88592f7944880e9';
final String tokenUrl =
    'https://www.strava.com/api/v3/oauth/token?client_id=$clientId&client_secret=$secret';
final String revokeUrl = 'https://www.strava.com/oauth/deauthorize';

// ----
// Mobile-only side client
class _StravaOAuth2ClientMobile extends OAuth2Client {
  _StravaOAuth2ClientMobile({String clientId, String secret})
      : super(
          authorizeUrl: 'https://www.strava.com/oauth/mobile/authorize',
          tokenUrl: tokenUrl,
          revokeUrl: revokeUrl,
          customUriScheme: 'myapp',
          redirectUri: 'myapp://localhost',
        );
}

// ----
// Web-side: list to the redirect url window
class _ListenWebAsync {
  final _completer = Completer<String>();
  void _finishOperation(String result) {
    _completer.complete(result);
  }

  Future<String> _listenStravaRedirectWeb(String authorizationUrlString) {
    html.window.onMessage.listen(
      (event) {
        // If the event contains the code/token it means the user is authenticated.
        if (event.data.toString().contains('code=')) {
          // print('_listenStravaRedirectWeb login event data2 <> ${event.data.toString()}');
          // print('_listenStravaRedirectWeb login event type  <> ${event.type}');

          // extract the strava code
          String code = event.data
              .toString()
              .split('&')
              .firstWhere((e) => e.startsWith('code='))
              .substring('code='.length);
          print('_listenStravaRedirectWeb strava token/code <> $code');

          // complete the future
          _finishOperation(code);
        }
      },
      cancelOnError: true,
    );

    return _completer.future;
  }
}

// ----
// Mobile and web: get credentials out of firestore if the user has
// authorized Strava at least once
Future<oauth2.Credentials> _getCredentialsFromFirestore(String userName) async {
  // get the oauth2 credentials/tokens out of firestore
  // return null if invalid or not available
  DocumentSnapshot credentialsSnapshot = await FirebaseFirestore.instance
      .collection('athletes')
      .doc(userName)
      .get();

  // token info from Firestore
  var tokenInfo = credentialsSnapshot["tokenInfo"];
  String accessToken = tokenInfo["access_token"];
  String refreshToken = tokenInfo["refresh_token"];
  int expirationInSeconds = tokenInfo["expires_at"];
  DateTime expiration = DateTime.fromMillisecondsSinceEpoch(
      (expirationInSeconds * 1000.0).round());
  print('accessToken $accessToken');

  oauth2.Credentials credentials;
  if (accessToken.isNotEmpty && (expirationInSeconds > 0)) {
    print(
        '_getCredentialsFromFirestore: using Strava credentials from firestore <>');
    print('   refreshToken $refreshToken');
    print('   expiration   $expiration');

    String emptyString = '';
    credentials = oauth2.Credentials(accessToken,
        refreshToken: refreshToken,
        idToken: emptyString,
        tokenEndpoint: Uri.parse(tokenUrl),
        scopes: ['activity:read'],
        expiration: expiration);
  } else {
    print('cannot use credentials from firestore <>');
    return credentials;
  }

  if ((credentials != null) && credentials.isExpired) {
    print('_getCredentialsFromFirestore: refreshing Strava credentials <>');
    oauth2.Credentials refreshedCredentials;
    try {
      refreshedCredentials = await credentials.refresh(
        identifier: clientId,
        secret: secret,
        basicAuth: false,
      );
    } catch (e) {
      print('failed to refresh Strava credentials <>');
      return null;
    }
    if (refreshedCredentials == null) {
      return null;
    }

    credentials = refreshedCredentials;
    await _putCredentialsIntoFirestore(
      userName,
      credentials,
    );
  }

  return credentials;
}

// ----
// Mobile and web: put the Strava oauth2 credentials/tokens into firestore
Future _putCredentialsIntoFirestore(
  String userName,
  oauth2.Credentials credentials,
) async {
  //   - note that credentials.expiration is a DateTime while expiration is stored
  //     in firestore as seconds since epoch
  int expirationInSeconds =
      (credentials.expiration.millisecondsSinceEpoch / 1000.0).round();

  // empty/invalid tokens
  if (credentials.accessToken.isEmpty || credentials.refreshToken.isEmpty) {
    print(
        '_putCredentialsIntoFirestore: putting dummy/invalid Strava credentials into firestore <>');
    expirationInSeconds = -1;
  }

  Map<String, Object> tokens = {
    'access_token': credentials.accessToken,
    'expires_at': expirationInSeconds,
    'expires_in': -1, // not used
    'refresh_token': credentials.refreshToken,
    'token_type': 'Bearer',
  };
  Map<String, Object> tokenInfo = {
    'tokenInfo': tokens,
  };

  FirebaseFirestore.instance
      .collection('athletes')
      .doc(userName)
      .set(tokenInfo, SetOptions(merge: true))
      .whenComplete(() => print(
          '_putCredentialsIntoFirestore: put Strava credentials into firestore <>'));
}

// ----
// Either load an OAuth2 client from saved credentials or authenticate a new one.
// Note that first time authentication is different for web and mobile platforms
Future<oauth2.Client> _getAuthClient(
  String userName,
  bool mustHaveAccount,
) async {
  // reload Strava credentials from firestore if they're available
  // - will refresh credentials if necessary
  oauth2.Credentials existingCredentials =
      await _getCredentialsFromFirestore(userName);
  if (existingCredentials != null) {
    // create the Client
    return oauth2.Client(
      existingCredentials,
      identifier: clientId,
      secret: secret,
    );
  }

  // Don't want to ask the user to log into Strava when deactivating an account
  // if they haven't already logged in and created the authorization tokens
  if (mustHaveAccount == true) {
    return null;
  }

  // ----
  // There are no credentials in firestore so ask the user to authorize Strava
  //
  // Two very different flows to get initial auth code from Strava
  // depending on whether web or mobile app.  After the initial authorization
  // occurs then web and mobile token refresh and Strava data extraction
  // are identical
  oauth2.Client oauth2Client;

  // ---- Web authorization
  if (UniversalPlatform.isWeb) {
    print('_getAuthClient: creating new Strava credentials: web <>');

    final authorizeUrlWeb = Uri.parse('https://www.strava.com/oauth/authorize');
    final tokenUrlWeb = Uri.parse(tokenUrl);
    // print('oauth2.AuthorizationCodeGrant:');
    // print('   authorizeUrl ${authorizeUrlWeb.toString()}');
    // print('   tokenUrl     ${tokenUrlWeb.toString()}');

    // If we don't have OAuth2 credentials yet, we need to get the resource owner
    // to authorize us.
    var grant = oauth2.AuthorizationCodeGrant(
      clientId,
      authorizeUrlWeb,
      tokenUrlWeb,
      secret: secret,
    );

    // the URL on the authorization server
    // (authorizationEndpoint with some additional query parameters)
    final currentWebUri = Uri.base;
    final redirectWebUrl = Uri(
      host: currentWebUri.host,
      scheme: currentWebUri.scheme,
      port: currentWebUri.port,
      path: '/static.html',
    );

    Uri authorizationUrl = grant.getAuthorizationUrl(
      redirectWebUrl,
      scopes: ['activity:read'],
    );

    // Launch a separate window for Strava and listen for the redirect that
    // contains the code; extract the code
    html.WindowBase _popupWindowWeb = html.window.open(
      authorizationUrl.toString(),
      "Strava Auth",
      "width=800, height=900, scrollbars=yes",
    );
    String stravaUserCode = await _ListenWebAsync()
        ._listenStravaRedirectWeb(authorizationUrl.toString());
    print('Strava userCode <> $stravaUserCode');

    // close the separate Strava window
    if (_popupWindowWeb != null) {
      _popupWindowWeb.close();
      _popupWindowWeb = null;
    }

    // authorize Strava for web using code
    Map<String, String> stravaCodeMap = {
      'code': stravaUserCode,
    };

    try {
      oauth2Client = await grant.handleAuthorizationResponse(stravaCodeMap);
      print(
          'webAuthorization: grant.handleAuthorizationResponse got oauth2.Client for initial authentication <>');
    } catch (e) {
      print(
          'webAuthorization: grant.handleAuthorizationResponse threw exception <> ${e.data.toString()}');
      return null;
    }
  } // end web authorization

  // ---- Mobile authorization
  if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
    print('_getAuthClient: creating new Strava credentials: mobile <>');

    _StravaOAuth2ClientMobile stravaClient = _StravaOAuth2ClientMobile(
      clientId: clientId,
      secret: secret,
    );

    // knock out any existing tokens in local storage
    OAuth2Helper oAuth2HelperCleaner = OAuth2Helper(stravaClient,
        grantType: OAuth2Helper.AUTHORIZATION_CODE,
        clientId: clientId,
        clientSecret: secret,
        scopes: ['activity:read']);
    await oAuth2HelperCleaner.removeAllTokens();

    // start grabbing the tokens from Strava
    OAuth2Helper oAuth2Helper = OAuth2Helper(stravaClient,
        grantType: OAuth2Helper.AUTHORIZATION_CODE,
        clientId: clientId,
        clientSecret: secret,
        scopes: ['activity:read']);

    // take a look at the token
    // - returns a previously acquired token or gets a new one if necessary
    // - mobile tokens are stored (not in Firebase) but in local secure storage
    AccessTokenResponse tknResp;
    try {
      tknResp = await oAuth2Helper.getToken();
    } catch (e) {
      print(
          'mobileAuthorization: oAuth2Helper.getToken threw exception <> ${e.data.toString()}');
      return null;
    }

    print('_getAuthClient: mobileAuthorization: got tknResp <>');
    String accessToken = tknResp.accessToken;
    String refreshToken = tknResp.refreshToken;
    DateTime expiration = tknResp.expirationDate;

    // int expirationInMilliSeconds = expiration.millisecondsSinceEpoch;
    // print('   accessToken  <> $accessToken');
    // print('   refreshToken <> $refreshToken');
    // print('   expiration   <> $expirationInMilliSeconds  $expiration');

    // Create the more generic oauth2 credentials and client that
    // are used by both web and mobile platforms
    String emptyString = '';
    oauth2.Credentials credentials = oauth2.Credentials(accessToken,
        refreshToken: refreshToken,
        idToken: emptyString,
        tokenEndpoint: Uri.parse(tokenUrl),
        scopes: ['activity:read'],
        expiration: expiration);

    try {
      oauth2Client = oauth2.Client(
        credentials,
        identifier: clientId,
        secret: secret,
      );
      print(
          'mobileAuthorization: created oauth2.Client for initial authentication <>');
    } catch (e) {
      print(
          'mobileAuthorization: oauth2.Client threw exception <> ${e.data.toString()}');
      return null;
    }
  } // end mobile authorization

  if (oauth2Client == null) {
    return null;
  }

  // String accessToken = oauth2Client.credentials.accessToken;
  // String idToken = oauth2Client.credentials.idToken;
  // String refreshToken = oauth2Client.credentials.refreshToken;
  // DateTime dateTime = oauth2Client.credentials.expiration;
  // int expirationInMilliSeconds =
  //     oauth2Client.credentials.expiration.millisecondsSinceEpoch;
  // print('   accessToken  <> $accessToken');
  // print('   idToken      <> $idToken');
  // print('   refreshToken <> $refreshToken');
  // print('   expiration   <> $expirationInMilliSeconds  $dateTime');

  // upload the initial strava token info into firestore
  await _putCredentialsIntoFirestore(
    userName,
    oauth2Client.credentials,
  );

  return oauth2Client;
}

// ----
class ImportStravaActivities extends StatefulWidget {
  @override
  _ImportStravaActivitiesState createState() => _ImportStravaActivitiesState();
}

// ----
class _ImportStravaActivitiesState extends State<ImportStravaActivities> {
  DateTime selectedStartDate = DateTime(2021, 1, 1);
  bool userChangedStartDate = false;

  // ----
  // Pop up a date picker to allow the user to select the
  // starting date 'selectedStartDate'
  // (i.e. the date after which all Strava activities will be uploaded)
  Future<void> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedStartDate)
      userChangedStartDate = true;
    setState(() {
      selectedStartDate = picked;
    });
  }

  // ----
  // Get the starting date out of Firestore
  // - if not valid then use the default 'selectedStartDate'
  Future<void> _updateStartDate(String userName) async {
    // do not use the date in Firestore if the user has manually changed the date
    if (userChangedStartDate == false) {
      // pull the date out of Firestore
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('athletes')
          .doc(userName)
          .collection('importedData')
          .doc('UploadStats')
          .get();
      int updateTimeSeconds = documentSnapshot.get('lastUpdateTime');
      if (updateTimeSeconds > 0) {
        // convert from seconds to a DateTime
        int millisecondsSinceEpoch = (updateTimeSeconds * 1000.0).round();
        DateTime newSelectedStartDate =
            DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
        if (newSelectedStartDate != selectedStartDate) {
          setState(() {
            selectedStartDate = newSelectedStartDate;
          });
        }
      }
    }
  }

  // ----
  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();
    String userName = firebaseUser.email;

    // check when the user last updated
    _updateStartDate(userName);

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
            Spacer(
              flex: 4,
            ),
            Image(
              image: AssetImage('assets/images/Strava.png'),
              width: 140,
              height: 140,
            ),
            Spacer(
              flex: 4,
            ),
            ElevatedButton(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    Text('Press here to import activities from Strava'),
                    Text(
                      'Activities from the start date until today will be imported',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return Scaffold(
                        body: _ImportStrava(
                          userName,
                          selectedStartDate,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            Spacer(),
            ElevatedButton(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    Text('Start date: (press to change)'),
                    Text(
                      '${DateFormat.yMMMEd().format(selectedStartDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
              onPressed: () => _selectDate(context),
            ),
            Spacer(
              flex: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ----
class _ImportStrava extends StatefulWidget {
  _ImportStrava(this.userName, this.selectedStartDate);
  final userName;
  final selectedStartDate;

  @override
  _ImportStravaState createState() =>
      _ImportStravaState(userName, selectedStartDate);
}

// ----
class _ImportStravaState extends State<_ImportStrava> {
  _ImportStravaState(this.userName, this.selectedStartDate);
  final userName;
  final selectedStartDate;

  int numFilesUploaded = 0;
  bool tokenIsValid = false;

  // ----
  Future<String> _getActivities(userName) async {
    // will set 'tokenIsValid' to false if something goes wrong
    tokenIsValid = true;

    print('_getActivities <>');
    oauth2.Client client;

    // ----
    // Try to build a valid oauth2.Client that will be used to authenticate
    // with Strava via oauth2. The client will make authorized HTTP requests
    // to Strava using the users credentials.
    //
    // Either get Strava authorization from Firebase if the user has already
    // given authorization or go to Strava and request auth codes/tokens
    //   Note that the initial authorization process is very different on
    //   web and mobile platforms... code in _getAuthClient handles this
    try {
      bool mustHaveAccount = false;
      print('_getActivities: _getAuthClient <>');
      client = await _getAuthClient(userName, mustHaveAccount);
      print('_getActivities: _getAuthClient done <>');
    } catch (e) {
      tokenIsValid = false;
      print(
          '_getActivities: _getAuthClient threw exception <> ${e.data.toString()}');
    }

    // exit early if could not create a valid oauth2.Client
    if (client == null) {
      print('_getActivities: _getAuthClient client is null <>');
      tokenIsValid = false;
    }

    // pull activities out of Strava using HTTP requests
    // - activities are page by page, the Google encoded paths are extracted
    //   and uploaded to Firestore
    if (tokenIsValid) {
      int _pageNumber = 1;
      int _perPage = 20; // Number of activities retrieved per http request
      var _nowTime = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      var _afterTime =
          (selectedStartDate.millisecondsSinceEpoch / 1000).round();

      print('_getActivities: Pulling Strava data from <> $selectedStartDate');
      bool isRetrieveDone = false;
      do {
        // List of activities for the athlete
        final String reqActivities =
            'https://www.strava.com/api/v3/athlete/activities' +
                '?before=$_nowTime&after=$_afterTime&page=$_pageNumber&per_page=$_perPage';
        var activities;
        try {
          activities = await client.read(Uri.parse(reqActivities));
        } catch (e) {
          tokenIsValid = false;
          print(
              '_getActivities: client.read threw exception <> ${e.data.toString()}');
        }

        // keep track of how many activities so we can move to the next Strava page
        // and get more if necessary
        int _nbActivity = 0;
        if (tokenIsValid) {
          // decode the activities
          var jsonActivities = json.decode(activities);
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

            // do the actual upload to the cloud/firestore
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
            print('Pulling Strava data <> isRetrieveDone');
            isRetrieveDone = true;
          } else {
            // Move to the next page
            print('next page');
            _pageNumber++;
          }
        }
      } while (!isRetrieveDone & tokenIsValid);

      print(
          '_getActivities: Number of Strava files uploaded = $numFilesUploaded');
    }

    // get and update the number of files uploaded
    // - this is used to trigger the cloud script that processes the uploaded files
    if (tokenIsValid) {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('athletes')
          .doc(userName)
          .collection('importedData')
          .doc('UploadStats')
          .get();
      int numFilesPreviouslyUploaded = documentSnapshot.get('numFilesUploaded');
      int totalFilesUploaded = numFilesPreviouslyUploaded + numFilesUploaded;
      // print(
      //     'Number of files previously uploaded = $numFilesPreviouslyUploaded');
      // print(
      //     'Total number of files gpx or Strava files uploaded = $totalFilesUploaded');

      // keep track in firestore of when this upload occurred
      int updateTimeSeconds =
          (DateTime.now().millisecondsSinceEpoch / 1000.0).round();

      Map<String, dynamic> numFilesUploadedMap = {
        'numFilesUploaded': totalFilesUploaded,
        'lastUpdateTime': updateTimeSeconds,
      };
      await FirebaseFirestore.instance
          .collection('athletes')
          .doc(userName)
          .collection('importedData')
          .doc('UploadStats')
          .set(numFilesUploadedMap, SetOptions(merge: true));
    }

    return 'done';
  }

  // ----
  // Tell the user how many activities were uploaded
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
Future<void> revokeStravaAccess(String userName) async {
  print('revokeStravaAccess: removing strava tokens <>');

  oauth2.Client client;
  try {
    // don't try to revoke strava access if the user has not set up
    // strava access
    bool mustHaveAccount = true;
    client = await _getAuthClient(userName, mustHaveAccount);
    print('revokeStravaAccess:: _getAuthClient done <>');
  } catch (e) {
    print(
        'revokeStravaAccess:: _getAuthClient threw exception <> ${e.data.toString()}');
  }

  if (client != null) {
    String accessToken = client.credentials.accessToken;
    Uri revokeUri = Uri.parse(revokeUrl + '?access_token=$accessToken');

    // print('revokeStravaAccess:: revokeUri <> $revokeUri');
    await client.post(revokeUri);
  }

  // knock out any existing tokens in local storage - mobile only
  if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
    _StravaOAuth2ClientMobile stravaClient = _StravaOAuth2ClientMobile(
      clientId: clientId,
      secret: secret,
    );
    OAuth2Helper oAuth2HelperCleaner = OAuth2Helper(stravaClient,
        grantType: OAuth2Helper.AUTHORIZATION_CODE,
        clientId: clientId,
        clientSecret: secret,
        scopes: ['activity:read']);
    await oAuth2HelperCleaner.removeAllTokens();
  }

  // in any case wipe out whatever credentials are in firestore
  String emptyString = '';
  DateTime expiration = DateTime.now();
  oauth2.Credentials deadCredentials = oauth2.Credentials(emptyString,
      refreshToken: emptyString,
      idToken: emptyString,
      tokenEndpoint: Uri.parse(tokenUrl),
      scopes: ['activity:read'],
      expiration: expiration);

  await _putCredentialsIntoFirestore(userName, deadCredentials);

  // reset the Uploadstats
  int totalFilesUploaded = 0;
  int updateTimeSeconds = -1;
  Map<String, dynamic> numFilesUploadedMap = {
    'numFilesUploaded': totalFilesUploaded,
    'lastUpdateTime': updateTimeSeconds,
  };
  await FirebaseFirestore.instance
      .collection('athletes')
      .doc(userName)
      .collection('importedData')
      .doc('UploadStats')
      .set(numFilesUploadedMap);
}
