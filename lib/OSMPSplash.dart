import 'package:flutter/material.dart';
import 'package:splashscreen/splashscreen.dart';

import 'main.dart';

// Display a pretty splash screen for a few seconds
// with a circulating progress meter
class OSMPSplash extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new SplashScreen(
      seconds: 2,
      navigateAfterSeconds: new AuthenticationWrapper(),

      title: new Text(
        'Boulder OSMP Trails Challenge',
        style: new TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
      ),
      image: new Image.asset('assets/images/FlatIrons.jpg'),
      photoSize: 160.0,
      backgroundColor: Colors.white,
      loaderColor: Colors.amberAccent,
    );
  }
}