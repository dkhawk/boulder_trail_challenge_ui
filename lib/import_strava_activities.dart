import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' show ClientException;

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
import 'package:web_browser_detect/web_browser_detect.dart';

// Google polyline encode/decode
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

// count how many times someone has hit a peak
import 'peakCounter.dart';

// ----
// globals

// - clientID and secret:
//   n.b. : previous version(s) of clientID & secret are not valid
import 'oursecrets.dart';

final String tokenUrl = 'https://www.strava.com/api/v3/oauth/token?client_id=$clientId&client_secret=$secret';
final String revokeUrl = 'https://www.strava.com/oauth/deauthorize';

// ----
// What? No pair object in Dart? Rolling one...
class Pair<T1, T2> {
  final T1 a;
  final T2 b;

  Pair(this.a, this.b);
}

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
// currently only going to check whether popups are blocked on Safari
// - Safari does not seem to warn the user that a popup has been blocked
//   so it appears that the app has hung
// - other browsers seem to be better behaved ... weird stuff
// - other browsers act differently using the following code
bool detectPopUpBlocker() {
  final browser = Browser.detectOrNull();
  if (browser != null) {
    print('detectPopUpBlocker: running on browser <> ${browser.browser}');

    if (browser.browser.contains('Safari') == false) {
      return false;
    }

    html.WindowBase _popupWindowTest = html.window.open('', 'popupTest', 'width=100,height=100');
    if (_popupWindowTest == null) {
      return true;
    }
    try {
      _popupWindowTest.close();
      print('popups not blocked');
      return false;
    } catch (e) {
      print('popups blocked');
      return true;
    }
  }
  return false;
}

// ----
// Web-side: list to the redirect url window
class _ListenWebAsync {
  final _completer = Completer<String>();
  void _finishOperation(String result) {
    _completer.complete(result);
  }

  Future<String> _listenStravaRedirectWeb(String authorizationUrlString) {
    // close out if user hasn't logged in after so many seconds
    // - prevents hang; posts error message to user
    Future.delayed(Duration(seconds: 60)).then(
      (value) => {
        if (_completer.isCompleted == false) _finishOperation('Error: Login timed out'),
      },
    );

    html.window.onMessage.listen(
      (event) {
        // If the event contains the code/token it means the user is authenticated
        // - but may not have given activity read access
        String eventDataString = event.data.toString();
        if (eventDataString.contains('code=')) {
          // print(
          //     '_listenStravaRedirectWeb login event data2 <> $eventDataString');

          // did user give activity read access
          String code = '';
          if (eventDataString.contains('activity:read_all')) {
            // if yes, then extract the strava code
            code = eventDataString.split('&').firstWhere((e) => e.startsWith('code=')).substring('code='.length);
            print('_listenStravaRedirectWeb strava token/code <> $code');
          }

          // complete the future
          // - an empty, non-null string indicates failure/improper access rights
          _finishOperation(code);
        }
        if (eventDataString.contains('access_denied')) {
          _finishOperation('Error: Access denied');
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
// Returns a pair containing the credentials and an optional error message
Future<Pair<oauth2.Credentials, String>> _getCredentialsFromFirestore(String userName) async {
  // get the oauth2 credentials/tokens out of firestore
  DocumentSnapshot credentialsSnapshot = await FirebaseFirestore.instance.collection('athletes').doc(userName).get();

  if (credentialsSnapshot.data().toString().contains('tokenInfo') == false) {
    return Pair(null, 'Error: No strava tokenInfo');
  }

  // token info from Firestore
  var tokenInfo = credentialsSnapshot["tokenInfo"];
  String accessToken = tokenInfo["access_token"];
  String refreshToken = tokenInfo["refresh_token"];
  int expirationInSeconds = tokenInfo["expires_at"];
  DateTime expiration = DateTime.fromMillisecondsSinceEpoch((expirationInSeconds * 1000.0).round());
  print('accessToken $accessToken');

  oauth2.Credentials credentials;
  if (accessToken.isNotEmpty && (expirationInSeconds > 0)) {
    print('_getCredentialsFromFirestore: attempting to use Strava credentials from firestore <>');
    print('   refreshToken $refreshToken');
    print('   expiration   $expiration');

    String emptyString = '';
    credentials = oauth2.Credentials(accessToken,
        refreshToken: refreshToken,
        idToken: emptyString,
        tokenEndpoint: Uri.parse(tokenUrl),
        scopes: ['activity:read_all'],
        expiration: expiration);

    print('_getCredentialsFromFirestore: using credentials from firestore <>');
  } else {
    print('_getCredentialsFromFirestore: cannot use credentials from firestore <>');
    return Pair(credentials, '');
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
    } on StateError {
      print('failed to refresh Strava credentials StateError <>');
      return Pair(null, 'Error: Failed to refresh Strava credentials due to StateError');
    } on oauth2.AuthorizationException {
      print('failed to refresh Strava credentials AuthorizationException <>');
      return Pair(null, 'Error: Failed to refresh Strava credentials due to AuthorizationException');
    } catch (e) {
      print('failed to refresh Strava credentials <>');
      return Pair(null, 'Error: Failed to refresh Strava credentials');
    }
    if (refreshedCredentials == null) {
      return Pair(null, 'Error: Refreshed Strava credentials are empty');
    }

    credentials = refreshedCredentials;
    await _putCredentialsIntoFirestore(
      userName,
      credentials,
    );
  }

  return Pair(credentials, '');
}

// ----
// Mobile and web: put the Strava oauth2 credentials/tokens into firestore
Future _putCredentialsIntoFirestore(
  String userName,
  oauth2.Credentials credentials,
) async {
  //   - note that credentials.expiration is a DateTime while expiration is stored
  //     in firestore as seconds since epoch
  int expirationInSeconds = (credentials.expiration.millisecondsSinceEpoch / 1000.0).round();

  // empty/invalid tokens
  if (credentials.accessToken.isEmpty || credentials.refreshToken.isEmpty) {
    print('_putCredentialsIntoFirestore: putting dummy/invalid Strava credentials into firestore <>');
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
      .whenComplete(() => print('_putCredentialsIntoFirestore: put Strava credentials into firestore <>'));
}

// ----
// Either load an OAuth2 client from saved credentials or authenticate a new one.
// Note that first time authentication is different for web and mobile platforms
// Returns a pair containing the auth client and an optional error message
Future<Pair<oauth2.Client, String>> _getAuthClient(
  String userName,
  bool mustHaveAccount,
) async {
  String errorString = '';
  // reload Strava credentials from firestore if they're available
  // - will refresh credentials if necessary
  print('_getCredentialsFromFirestore:');
  Pair<oauth2.Credentials, String> existingCredentials = await _getCredentialsFromFirestore(userName);
  print('_getCredentialsFromFirestore: return error string: ${existingCredentials.b}');

  if (existingCredentials.a != null) {
    print('strava existingCredentials.a != null');
    // create the Client
    oauth2.Client theClient;
    try {
      theClient = oauth2.Client(
        existingCredentials.a,
        identifier: clientId,
        secret: secret,
      );
    } on FormatException {
      theClient = null;
      print('_getAuthClient: FormatException <>');
    } on oauth2.AuthorizationException {
      theClient = null;
      print('_getAuthClient: AuthorizationException <>');
    } on oauth2.ExpirationException {
      theClient = null;
      print('_getAuthClient: ExpirationException <>');
    }

    // test whether the client is valid by accessing the athlete
    if (theClient != null) {
      print('theClient != null');
      final String theAthlete = 'https://www.strava.com/api/v3/athlete';
      await theClient.read(Uri.parse(theAthlete)).catchError((e) {
        print('_getAuthClient: theClient.read could not get theAuthAthlete');
        theClient = null;
      });
    }

    // the client appears valid so return it
    // - else try to log in to Strava again below
    if (theClient != null) {
      print('_getAuthClient: returning oauth2 client using firestore creds <>');
      return Pair(theClient, '');
    }
  } else {
    print('strava existingCredentials.a == null');
  }

  // Don't want to ask the user to log into Strava when deactivating an account
  // if they haven't already logged in and created the authorization tokens
  if (mustHaveAccount == true) {
    return Pair(null, '');
  }

  // ----
  // There are no credentials in firestore (or they've been rejected) so ask
  // the user to authorize Strava
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

    print('strava grant <> ${grant.toString()}');

    // the URL on the authorization server
    // (authorizationEndpoint with some additional query parameters)
    final redirectWebUrl = Uri.parse('https://bouldertrailchallenge.com/static.html');
    //print('Strava redirectWebUrl <> $redirectWebUrl');

    Uri authorizationUrl = grant.getAuthorizationUrl(
      redirectWebUrl,
      scopes: ['activity:read_all'],
    );

    print('strava '
        'authorizationUrl <> ${authorizationUrl.toString()}');

    // warn user that popups are blocked
    // - currently only for Safari
    if (detectPopUpBlocker()) {
      String longString = 'Error: Please temporarily disable the pop-up blocker in your web browser.\n\n';
      longString = longString + 'For iPhone/Safari: go to Settings/Safari/Block Pop-ups';
      return Pair(null, longString);
    }

    // Launch a separate window for Strava and listen for the redirect that
    // contains the code; extract the code
    html.WindowBase _popupWindowWeb = html.window.open(
      authorizationUrl.toString(),
      "StravaAuth",
      "width=800, height=900, scrollbars=yes",
    );
    String stravaUserCode = await _ListenWebAsync()._listenStravaRedirectWeb(authorizationUrl.toString());
    print('Strava userCode <> $stravaUserCode');

    // close the separate Strava window
    if (_popupWindowWeb != null) {
      _popupWindowWeb.close();
      _popupWindowWeb = null;
    }

    if (stravaUserCode.startsWith('Error:')) {
      print('Strava authentication error <> $stravaUserCode');
      return Pair(null, stravaUserCode);
    }

    // make sure we got an auth code
    if (stravaUserCode.isEmpty) {
      return Pair(null, 'Error: Strava user code is empty');
    }

    // authorize Strava for web using code
    Map<String, String> stravaCodeMap = {
      'code': stravaUserCode,
    };

    try {
      oauth2Client = await grant.handleAuthorizationResponse(stravaCodeMap);
      print('webAuthorization: grant.handleAuthorizationResponse got oauth2.Client for initial authentication <>');
    } on oauth2.AuthorizationException {
      print('webAuthorization: grant.handleAuthorizationResponse AuthorizationException <> ');
      return Pair(null, 'Error: Strava web AuthorizationException');
    } catch (e) {
      print('webAuthorization: grant.handleAuthorizationResponse threw exception <> ${e.data.toString()}');
      return Pair(null, 'Error: Strava web threw exception');
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
        grantType: OAuth2Helper.AUTHORIZATION_CODE, clientId: clientId, clientSecret: secret, scopes: ['activity:read_all']);
    await oAuth2HelperCleaner.removeAllTokens();

    // start grabbing the tokens from Strava
    OAuth2Helper oAuth2Helper = OAuth2Helper(stravaClient,
        grantType: OAuth2Helper.AUTHORIZATION_CODE, clientId: clientId, clientSecret: secret, scopes: ['activity:read_all']);

    // take a look at the token
    // - returns a previously acquired token or gets a new one if necessary
    // - mobile tokens are stored (not in Firebase) but in local secure storage
    AccessTokenResponse tknResp;
    try {
      tknResp = await oAuth2Helper.getToken();
    } catch (e) {
      print('mobileAuthorization: oAuth2Helper.getToken threw exception <> ${e.data.toString()}');
      return Pair(null, 'Error: Strava get token mobile threw exception');
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
        scopes: ['activity:read_all'],
        expiration: expiration);

    try {
      oauth2Client = oauth2.Client(
        credentials,
        identifier: clientId,
        secret: secret,
      );
      print('mobileAuthorization: created oauth2.Client for initial authentication <>');
    } catch (e) {
      print('mobileAuthorization: oauth2.Client threw exception <> ${e.data.toString()}');
      return Pair(null, 'Error: Strava client mobile threw exception');
    }
  } // end mobile authorization

  if (oauth2Client == null) {
    return Pair(null, 'Error: Strava client is empty');
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

  return Pair(oauth2Client, errorString);
}

// ----
class ImportStravaActivities extends StatefulWidget {
  @override
  _ImportStravaActivitiesState createState() => _ImportStravaActivitiesState();
}

// ----
class _ImportStravaActivitiesState extends State<ImportStravaActivities> {
  DateTime selectedStartDate = DateTime(2022, 1, 1);
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
    if (picked != null && picked != selectedStartDate) userChangedStartDate = true;
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
        DateTime newSelectedStartDate = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
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
            Text('Powered by Strava'),
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
  _ImportStravaState createState() => _ImportStravaState(userName, selectedStartDate);
}

// ----
class _ImportStravaState extends State<_ImportStrava> {
  _ImportStravaState(this.userName, this.selectedStartDate);
  final userName;
  final selectedStartDate;

  int numFilesUploaded = 0;
  int numSkippedActivities = 0;
  bool tokenIsValid = false;
  String stravaErrorMsg = '';

  // ----
  String _interpolateLocations(String summaryPolyline, String dateTimeString, String userName) {
    // 1) take a Google encoded polyline 'summaryPolyline'
    // 2) expand to lat & longs
    // 3) do simple interpolation between points if distance is too large
    // 4) return Google encoded polyline that includes interpolated points

    List<List<num>> trackPoints = decodePolyline(summaryPolyline);
    List<List<num>> interpolatedTrackPoints = [];

    // using the polar coordinate flat-earth formula to calculate distances between two lat/longs
    double radius = 6371e3; // metres
    double halfPi = pi / 2.0;
    double deg2Rad = pi / 180.0;

    for (int trackPointId = 0; trackPointId < (trackPoints.length - 1); trackPointId++) {
      interpolatedTrackPoints.add(trackPoints[trackPointId]);

      // convert to radians
      double lat1rad = trackPoints[trackPointId].first * deg2Rad;
      double lat2rad = trackPoints[trackPointId + 1].first * deg2Rad;

      double long1rad = trackPoints[trackPointId].last * deg2Rad;
      double long2rad = trackPoints[trackPointId + 1].last * deg2Rad;

      double a = halfPi - lat1rad;
      double b = halfPi - lat2rad;
      double u = a * a + b * b - 2 * a * b * cos(long1rad - long2rad);
      double distance = radius * sqrt(u.abs());
      //print('  trackPointID  dist <> $trackPointId $distance');

      // interpolate if distance is greater than 2x this (meters)
      double maxDist = 12.5;

      // simple fast dumb linear interpolation... duh
      int numInterpPoints = (distance / maxDist).floor();
      if (numInterpPoints > 1) {
        // print(' trackPointID <> $trackPointId');
        // print('   point1 <> ${trackPoints[trackPointId].first}  ${trackPoints[trackPointId].last}');
        // print('   point2 <> ${trackPoints[trackPointId + 1].first}  ${trackPoints[trackPointId + 1].last}');

        double deltaLat = (lat2rad - lat1rad) / numInterpPoints;
        double deltaLong = (long2rad - long1rad) / numInterpPoints;

        for (int i = 1; i < numInterpPoints; i++) {
          double lat = (lat1rad + i * deltaLat) / deg2Rad;
          double long = (long1rad + i * deltaLong) / deg2Rad;

          //print('      interp <> $lat $long');
          interpolatedTrackPoints.add([lat, long]);
        }
      }
    }
    interpolatedTrackPoints.add(trackPoints.last);

    // count how many times the track crosses a peak
    peakCounter(interpolatedTrackPoints, dateTimeString, userName);

    print('   trackPoints -> interpolatedTrackPoints lengths <> ${trackPoints.length} ${interpolatedTrackPoints.length}');
    String encodedLine = encodePolyline(interpolatedTrackPoints);

    //print(' encoded line <> $encodedLine');
    return encodedLine;
  }

  // ----
  Future<String> _getActivities(userName) async {
    // will set 'tokenIsValid' to false if something goes wrong
    tokenIsValid = true;

    print('_getActivities <>');
    // auth client and optional error message
    Pair<oauth2.Client, String> client = Pair(null, '');

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
      print('_getActivities: _getAuthClient threw exception <> ${e.data.toString()}');
    }

    // exit early if could not create a valid oauth2.Client
    if (client.a == null) {
      print('_getActivities: _getAuthClient client is null <>');
      tokenIsValid = false;
      stravaErrorMsg = client.b;
    }
    if (client.b.isNotEmpty) {
      print('_getActivities: _getAuthClient Error message: ${client.b} <>');
    }

    // pull activities out of Strava using HTTP requests
    // - activities are page by page, the Google encoded paths are extracted
    //   and uploaded to Firestore
    if (tokenIsValid) {
      int _pageNumber = 1;
      int _perPage = 20; // Number of activities retrieved per http request
      var _nowTime = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      var _afterTime = (selectedStartDate.millisecondsSinceEpoch / 1000).round();

      print('_getActivities: Pulling Strava data from <> $selectedStartDate');
      bool isRetrieveDone = false;
      do {
        // List of activities for the athlete
        final String reqActivities = 'https://www.strava.com/api/v3/athlete/activities' +
            '?before=$_nowTime&after=$_afterTime&page=$_pageNumber&per_page=$_perPage';
        var activities;
        try {
          activities = await client.a.read(Uri.parse(reqActivities));
        } on ClientException catch (error) {
          tokenIsValid = false;
          print('_getActivities: client.read threw ClientException <> ${error.message}');
        } catch (error) {
          tokenIsValid = false;
          print('_getActivities: client.read threw exception <> ${error.data.toString()}');
        }

        // keep track of how many activities so we can move to the next Strava page
        // and get more if necessary
        int _nbActivityThisPage = 0;
        int _nbActivitySkippedThisPage = 0;
        if (tokenIsValid) {
          // decode the activities
          var jsonActivities = json.decode(activities);
          jsonActivities.forEach(
            (activitySummary) {
              // what kind of activity is this
              String activityType = activitySummary['type'];
              String activityDate = activitySummary['start_date']; // gmt

              // parse & stringify activity date to move to standard format
              String dateTimeString = DateTime.parse(activityDate).toString();
              print(' strava activityDate <> $activityDate $dateTimeString');

              // the map that includes the encoded polyline for this activity
              Map<String, dynamic> theActivityMap = activitySummary['map'];
              String summaryPolyline = theActivityMap['summary_polyline'];

              print(
                  'Activity type <<>> $activityType :: numFilesUploaded = $numFilesUploaded numSkippedActivities = $numSkippedActivities');
              if (((activityType == 'Run') || (activityType == 'Hike') || (activityType == 'Walk') || (activityType == 'Ride')) &&
                  (summaryPolyline != null) &&
                  summaryPolyline.isNotEmpty) {
                // interpolate between the 'summary_polyline' points that Strava gives us
                // - the 'summary_polyline' does not contain all the gpx data points; for example
                //   a long straight segment is given as only the start/stop locations and this
                //   causes the route matching routine to fail
                String interpolatedLocations = _interpolateLocations(summaryPolyline, dateTimeString, userName);

                // a map for the Cloud storage data
                String uploadDateTime = DateTime.now().toUtc().toString();
                Map<String, dynamic> importedTrackMap = {
                  'originalFileName': activitySummary['external_id'],
                  'gpxDateTime': activitySummary['start_date_local'], // local time
                  'uploadDateTime': uploadDateTime,
                  'userName': userName,
                  //'encodedLocation': theActivityMap['summary_polyline'],
                  'encodedLocation': interpolatedLocations,
                  'processed': false,
                };

                // do the actual upload to the cloud/firestore
                String encodedTrackUploadLocation = activitySummary['external_id'] + '.gencoded';
                numFilesUploaded++;
                print(
                    'Uploading file: = $numFilesUploaded <> ${activitySummary['start_date_local']} <> $encodedTrackUploadLocation');

                FirebaseFirestore.instance
                    .collection('athletes')
                    .doc(userName)
                    .collection('importedData')
                    .doc(encodedTrackUploadLocation)
                    .set(importedTrackMap);

                _nbActivityThisPage++;
              } else {
                if ((summaryPolyline == null) || summaryPolyline.isEmpty)
                  print('Skipping empty/null summaryPolyline! <>');
                else
                  print('Skipping $activityType activity! <>');
                _nbActivitySkippedThisPage++;

                numSkippedActivities++;
              }
            },
          );

          // are we done with all the pages?
          if ((_nbActivityThisPage + _nbActivitySkippedThisPage) < _perPage) {
            print('Pulling Strava data <> isRetrieveDone');
            isRetrieveDone = true;
          } else {
            // Move to the next page
            print('next page: $_pageNumber');
            _pageNumber++;
          }
        }
      } while (!isRetrieveDone & tokenIsValid);

      print('_getActivities: Number of Strava files uploaded = $numFilesUploaded');
    }

    // get and update the number of files uploaded
    // - this is used to trigger the cloud script that processes the uploaded files
    if (numFilesUploaded > 0) {
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
      int updateTimeSeconds = (DateTime.now().millisecondsSinceEpoch / 1000.0).round();

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
    String stravaText1 = numFilesUploaded.toString() + ' run, hike, walk or ride activities synchronized\n';
    stravaText1 = stravaText1 + numSkippedActivities.toString() + ' other activities skipped';
    if (tokenIsValid == false) {
      stravaText1 = 'Strava authorization failed or synchronization failed';
      if (stravaErrorMsg.isNotEmpty) stravaText1 = stravaText1 + '\n' + stravaErrorMsg;
    }

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
        title: Text('Strava Activity Synchronization', style: TextStyle(fontSize: 20, color: Colors.white)),
        content: Text(
          stravaText1,
          style: TextStyle(fontSize: 15, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: new BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ----
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getActivities(userName),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.hasData && (snapshot.data == 'done')) {
          //print('Strava activities: snapshot.hasData and done');
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
                Text('Importing Strava activities...', style: TextStyle(color: Colors.black, fontSize: 12.0)),
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

  Pair<oauth2.Client, String> client = Pair(null, '');
  try {
    // don't try to revoke strava access if the user has not set up
    // strava access
    bool mustHaveAccount = true;
    client = await _getAuthClient(userName, mustHaveAccount);
    print('revokeStravaAccess:: _getAuthClient done <>');
  } catch (e) {
    print('revokeStravaAccess:: _getAuthClient threw exception <> ${e.data.toString()}');
  }

  if (client.a != null) {
    String accessToken = client.a.credentials.accessToken;
    Uri revokeUri = Uri.parse(revokeUrl + '?access_token=$accessToken');

    // print('revokeStravaAccess:: revokeUri <> $revokeUri');
    await client.a.post(revokeUri);
  }

  // knock out any existing tokens in local storage - mobile only
  if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
    _StravaOAuth2ClientMobile stravaClient = _StravaOAuth2ClientMobile(
      clientId: clientId,
      secret: secret,
    );
    OAuth2Helper oAuth2HelperCleaner = OAuth2Helper(stravaClient,
        grantType: OAuth2Helper.AUTHORIZATION_CODE, clientId: clientId, clientSecret: secret, scopes: ['activity:read_all']);
    await oAuth2HelperCleaner.removeAllTokens();
  }

  // in any case wipe out whatever credentials are in firestore
  String emptyString = '';
  DateTime expiration = DateTime.now();
  oauth2.Credentials deadCredentials = oauth2.Credentials(emptyString,
      refreshToken: emptyString,
      idToken: emptyString,
      tokenEndpoint: Uri.parse(tokenUrl),
      scopes: ['activity:read_all'],
      expiration: expiration);

  await _putCredentialsIntoFirestore(userName, deadCredentials);

  // reset the Uploadstats
  int totalFilesUploaded = 0;
  //int updateTimeSeconds = -1;
  Map<String, dynamic> numFilesUploadedMap = {
    'numFilesUploaded': totalFilesUploaded,
    //'lastUpdateTime': updateTimeSeconds,
  };
  await FirebaseFirestore.instance
      .collection('athletes')
      .doc(userName)
      .collection('importedData')
      .doc('UploadStats')
      .set(numFilesUploadedMap, SetOptions(merge: true));
}
