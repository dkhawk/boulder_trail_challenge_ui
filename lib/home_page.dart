import 'package:flutter/material.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:osmp_project/trail_list_page.dart';
import 'package:osmp_project/IntroPages.dart';

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
