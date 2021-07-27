import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:osmp_project/import_gpx_activities.dart';
import 'package:osmp_project/import_strava_activities.dart';
import 'package:osmp_project/createAccountData.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'buildDate.dart';

import 'package:provider/provider.dart';
//import 'package:url_launcher/url_launcher.dart';

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

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );
  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/TopoMapPattern.png"),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.white60, BlendMode.lighten),
        ),
      ),
      width: double.infinity,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 40.0, 10.0, 2.0),
            child: Text(
              "Settings",
              //style: SettingsPage.optionStyle,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Text(
            // Note that version and buildNumber are taken from pubspec.yaml
            "Build: ${_packageInfo.version}.${_packageInfo.buildNumber}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white,
            ),
          ),
          Text(
            // buildDateTime is imported from buildDate.dart
            "$buildDateTime",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white,
            ),
          ),
          Spacer(),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text('Import activities from Strava'),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return ImportStravaActivities();
                }),
              );
            },
          ),
          Spacer(),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text('Import activities using GPX files'),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return ImportGPXActivities();
                }),
              );
            },
          ),
          Spacer(),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: settingsOptions.displayTrailNames
                  ? Text('Disable Trail Name Display')
                  : Text('Enable Trail Name Display'),
            ),
            onPressed: () {
              setState(() => settingsOptions.displayTrailNames =
                  !settingsOptions.displayTrailNames);
            },
          ),
          Spacer(),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: settingsOptions.useTopoMaps
                  ? Text('Disable Topo Map Display')
                  : Text('Enable Topo Map Display'),
            ),
            onPressed: () {
              setState(() =>
                  settingsOptions.useTopoMaps = !settingsOptions.useTopoMaps);
            },
          ),
          Spacer(),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Text('Reset all activities: Use with caution!'),
                ],
              ),
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
                        child:
                            Text('OK', style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Cancel',
                            style: TextStyle(color: Colors.white)),
                      )
                    ],
                  );
                }),
              );
            },
          ),
          Spacer(),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text("Sign out"),
            ),
            onPressed: () {
              // sign out of strava
              revokeStravaAccess(firebaseUser.email);
              context.read<AuthenticationService>().signOut();
            },
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              firebaseUser.email,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }

  // void _launchURL(String user) async {
  //   var redirectUrl =
  //       'http://localhost:5001/boulder-trail-challenge/us-central1/exchangeTokens?athleteId=' +
  //           user;
  //   var queryParameters = {
  //     'client_id': '43792',
  //     'response_type': 'code',
  //     'approval_prompt': 'force',
  //     'scope': 'read,activity:read',
  //     'redirect_uri': redirectUrl,
  //   };
  //   var url = Uri.https('www.strava.com', '/oauth/authorize', queryParameters);
  //   print(url);
  //
  //   if (await canLaunch(url.toString())) {
  //     await launch(url.toString());
  //   } else {
  //     throw 'Could not launch $url';
  //   }
  // }
}

//----
class SettingsOptions {
  bool useTopoMaps = false;
  bool displayTrailNames = false;
  bool displaySegmentNames = false;
}
