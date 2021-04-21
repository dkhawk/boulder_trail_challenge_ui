import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:osmp_project/import_activities_screen.dart';
import 'package:osmp_project/import_strava_activities.dart';
import 'package:osmp_project/createAccountData.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_platform/universal_platform.dart';

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

    // dim the Strava input button if not mobile
    bool isMobilePlatform = (UniversalPlatform.isAndroid || UniversalPlatform.isIOS);
    Color stravaImportColor = Colors.white;
    if (isMobilePlatform == false)
    {
      stravaImportColor = Colors.white70;
    }

    return Column(
      children: [
        Text(
          "Settings",
          style: SettingsPage.optionStyle,
        ),
        // Spacer(),
        // ElevatedButton(
        //   onPressed: () {
        //     _launchURL(firebaseUser.email);
        //   },
        //   child: Text("Connect with Strava"),
        // ),
        // Spacer(),
        // ElevatedButton(
        //   onPressed: () {
        //     context.read<StravaService>().refreshToken(firebaseUser.email);
        //   },
        //   child: Text("Refresh Strava token"),
        // ),
        Spacer(),
        // Strava sync only works on mobile platforms...
        ElevatedButton(
          child: Column(
            children: [
              Text('Import activities from Strava',
                style: TextStyle(color: stravaImportColor),),
              Text(
                '(Android and IOS only)',
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
            ],
          ),
          onPressed: () {
            if(isMobilePlatform) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return ImportStravaActivities();
                }),
              );
            }
          },
        ),
        Spacer(),
        ElevatedButton(
          child: Text('Import activities using GPX files'),
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
                  title: Text('Delete all activities?',
                      style: TextStyle(color: Colors.white)),
                  content: Text(
                      'This will remove all your activities from the database',
                      style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: new BorderRadius.circular(15)),
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
                      child: Text('OK', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child:
                          Text('Cancel', style: TextStyle(color: Colors.white)),
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
            // sign out of strava
            RevokeStravaAccess();
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
