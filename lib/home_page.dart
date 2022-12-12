import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:osmp_project/trail_list_page.dart';
import 'package:osmp_project/IntroPages.dart';
import 'package:provider/provider.dart';

import 'overall_status_widget.dart';

/// This is the stateful widget that the main application instantiates.
class BottomNavWidget extends StatefulWidget {
  BottomNavWidget({Key key}) : super(key: key);

  @override
  _BottomNavWidgetState createState() => _BottomNavWidgetState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _BottomNavWidgetState extends State<BottomNavWidget> {
  int _selectedIndex = 0;

  SettingsOptions settingsOptions = new SettingsOptions();

  List<Widget> _widgetOptions() => <Widget>[
        OverallStatusWidget(settingsOptions, false), // disable map button and display full map
        TrailsProgressWidget(settingsOptions),
        IntroPages(),
        SettingsPage(settingsOptions),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // if this is the first time the user has logged on (determined by whether the accessTime has
    // been set) then 'tap' the help button/menu time else show the overall completion map
    String email = context.watch<User>().email.toLowerCase();
    isAccessTimeSet(email).then(
      (retValue) {
        if (retValue == false) {
          // tap item 2 for the user, i.e. the IntroPages
          _onItemTapped(2);
        }
      },
    );

    final List<Widget> theBottomWidget = _widgetOptions();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boulder Trails Challenge - 2023'),
      ),
      body: Center(
        child: theBottomWidget[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        showUnselectedLabels: true,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
            backgroundColor: Colors.grey,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_bulleted),
            label: 'Trails',
            backgroundColor: Colors.grey,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_center_outlined),
            label: 'Intro/Help',
            backgroundColor: Colors.grey,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Import Data/Settings',
            backgroundColor: Colors.grey,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

// ----
Future<bool> isAccessTimeSet(String email) async {
  bool accessTimeSet = false;
  //DocumentSnapshot credentialsSnapshot =
  await FirebaseFirestore.instance.collection('athletes').doc(email).get().then(
    (retValue) {
      if (retValue.data().toString().contains('accessTime') == true) {
        accessTimeSet = true;
      }

      // ----
      // record the time the user has tapped something, i.e. the AccessTime
      setAccessTime(email);

      return accessTimeSet;
    },
  );

  return accessTimeSet;
}

// ----
Future<void> setAccessTime(String email) async {
  // ----
  // record the time the user accessed this data
  // - eventually want to delete inactive user accounts
  Map<String, Object> lastAccessTime = {
    'lastAccessTime': DateTime.now().toString(), // local time
    'dateTime': DateTime.now().millisecondsSinceEpoch,
  };
  Map<String, Object> accessTime = {
    'accessTime': lastAccessTime,
  };
  await FirebaseFirestore.instance
      .collection('athletes')
      .doc(email)
      .set(accessTime, SetOptions(merge: true))
      .whenComplete(() => {print('updating access time <>')});
}
