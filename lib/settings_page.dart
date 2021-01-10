import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  static const TextStyle optionStyle =
  TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Settings", style: optionStyle,),
        RaisedButton(
          onPressed: () {
            context.read<AuthenticationService>().signOut();
          },
          child: Text("Sign out"),
        ),
      ],
    );
  }
}
