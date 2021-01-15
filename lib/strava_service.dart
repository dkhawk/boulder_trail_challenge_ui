import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class StravaService {
  final FirebaseFirestore _firestore;

  StravaService(this._firestore);

  Future<void> refreshToken() async {
    var redirectUrl = 'http://localhost:5001/boulder-trail-challenge/us-central1/exchangeTokens?athleteId=dkhawk@gmail.com';
    var queryParameters = {
      'client_id': '43792',
      'response_type': 'code',
      'approval_prompt': 'force',
      'scope': 'read,activity:read',
      'redirect_uri': redirectUrl,
    };
    var url = Uri.https('www.strava.com', '/oauth/authorize', queryParameters);
    print(url);

    if (await canLaunch(url.toString())) {
      await launch(url.toString());
    } else {
      throw 'Could not launch $url';
    }
  }
}
