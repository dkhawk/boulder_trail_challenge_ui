import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  static const TextStyle optionStyle =
  TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Settings", style: optionStyle,),
        Spacer(),
        RaisedButton(
          onPressed: () {
            _launchURL();
          },
          child: Text("Connect with Strava"),
        ),
        Spacer(),
        RaisedButton(
          onPressed: () {
            context.read<AuthenticationService>().signOut();
          },
          child: Text("Sign out"),
        ),
      ],
    );
  }

  void _launchURL() async {
    var myUrlBase = Uri.base;
    var redirectUrl = 'http://localhost:5001/boulder-trail-challenge/us-central1/exchangeTokens?athleteId=dkhawk@gmail.com';
    var rUrl = Uri.encodeFull(redirectUrl);
    var queryParameters = {
      'client_id': '43792',
      'response_type': 'code',
      'approval_prompt': 'force',
      'scope': 'read,activity:read',
      'redirect_uri': redirectUrl,
    };
    var url = Uri.https('www.strava.com', '/oauth/authorize', queryParameters);
    print(url);

    // var response = await http.get(uri, headers: {
    //   HttpHeaders.authorizationHeader: 'Token $token',
    //   HttpHeaders.contentTypeHeader: 'application/json',
    // });
    // print(rUrl);
    // var url = 'https://www.strava.com/oauth/authorize?client_id=43792&response_type=code&approval_prompt=force&scope=read&approval_prompt=force&redirect_uri=${rUrl}';
    // print(url);
    if (await canLaunch(url.toString())) {
      await launch(url.toString());
    } else {
      throw 'Could not launch $url';
    }
  }
}
