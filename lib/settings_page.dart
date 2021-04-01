import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:osmp_project/import_activities_screen.dart';
import 'package:osmp_project/strava_service.dart';
import 'package:osmp_project/createAccountData.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage(this.settingsOptions);
  final SettingsOptions settingsOptions;

  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  @override
  _SettingsPageState createState() => _SettingsPageState(settingsOptions);
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsPageState(this.settingsOptions);
  final SettingsOptions settingsOptions;

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();

    return Column(
      children: [
        Text(
          "Settings",
          style: SettingsPage.optionStyle,
        ),
        Spacer(),
        ElevatedButton(
          onPressed: () {
            _launchURL(firebaseUser.email);
          },
          child: Text("Connect with Strava"),
        ),
        Spacer(),
        ElevatedButton(
          onPressed: () {
            context.read<StravaService>().refreshToken(firebaseUser.email);
          },
          child: Text("Refresh Strava token"),
        ),
        Spacer(),
        ElevatedButton(
          child: Text('Import old activities using GPX files'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return ImportActivitiesScreen();
              }),
            );
          },
        ),
        Spacer(),
        ElevatedButton(
          child: settingsOptions.displayTrailNames
              ? Text('Disable Trail Name Display')
              : Text('Enable Trail Name Display'),
          onPressed: () {
            setState(() => settingsOptions.displayTrailNames =
                !settingsOptions.displayTrailNames);
          },
        ),
        Spacer(),
        ElevatedButton(
          child: settingsOptions.useTopoMaps
              ? Text('Disable Topo Map Display')
              : Text('Enable Topo Map Display'),
          onPressed: () {
            setState(() =>
                settingsOptions.useTopoMaps = !settingsOptions.useTopoMaps);
          },
        ),
        Spacer(),
        ElevatedButton(
          child: Column(
            children: [
              Text('Reset all activities: Use with caution!'),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                return AlertDialog(
                  title: Text('Delete all activities?'),
                  content: Text(
                      'This will remove all your activities from the database'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) {
                            return Scaffold(
                              body: LoadSegmentsData(firebaseUser.email, '',
                                  true /*reset trail data*/),
                            );
                          }),
                        ).whenComplete(() => Navigator.of(context).pop());
                      },
                      child: Text('OK'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    )
                  ],
                );
              }),
            );
          },
        ),
        Spacer(),
        ElevatedButton(
          onPressed: () {
            context.read<AuthenticationService>().signOut();
          },
          child: Text("Sign out"),
        ),
        Spacer(),
      ],
    );
  }

  void _launchURL(String user) async {
    var redirectUrl =
        'http://localhost:5001/boulder-trail-challenge/us-central1/exchangeTokens?athleteId=' +
            user;
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

//----
class SettingsOptions {
  bool useTopoMaps = false;
  bool displayTrailNames = false;
  bool displaySegmentNames = false;
}
