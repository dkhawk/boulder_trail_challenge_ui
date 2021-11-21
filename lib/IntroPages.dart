import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

class IntroPages extends StatefulWidget {
  @override
  _IntroPagesState createState() => _IntroPagesState();
}

class _IntroPagesState extends State<IntroPages> {
  final introKey = GlobalKey<IntroductionScreenState>();

  void _onIntroEnd(context) {}

  Widget _buildFullscreenImage(String imageName) {
    return Image.asset(
      'assets/images/$imageName',
      fit: BoxFit.cover,
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
    );
  }

  Widget _buildImage(String imageName, [double width = 1000]) {
    return Image.asset('assets/images/$imageName', width: width);
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 16.0);

    const pageDecoration = const PageDecoration(
      titleTextStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      bodyFlex: 2,
      imageFlex: 4,
      pageColor: Colors.white,
      imagePadding: EdgeInsets.fromLTRB(15.0, 20.0, 15.0, 0.0),
    );

    // are we in a web browser on a desktop device or a mobile device
    // - controls padding and dot size changes for narrower screen
    bool isWebDesktop = true;
    if ((defaultTargetPlatform == TargetPlatform.android) ||
        (defaultTargetPlatform == TargetPlatform.iOS)) {
      isWebDesktop = false;
    }

    String trailCompletionText = 'Blue trails have been completed;\nRed trails have not been completed yet;\nClick on a segment to display the trail name\n\n';
    trailCompletionText = trailCompletionText + 'Note that OSMP has been rerouting some trails (Anenome, Bear Canyon, Mesa ...)\nThese may not be marked complete if you run or hike them!';

    return IntroductionScreen(
      key: introKey,
      showDoneButton: false,
      globalBackgroundColor: Colors.white,
      pages: [
        PageViewModel(
          title: "Welcome to the Boulder Trail Challenge",
          body:
              "This application uses imported Strava or GPX data to help you track \nyour progress on the Boulder Trail Challenge",
          image: _buildFullscreenImage('FlatIrons.jpg'),
          decoration: pageDecoration.copyWith(
            titleTextStyle:
                TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
            fullScreen: true,
            bodyFlex: 2,
            imageFlex: 3,
            descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 20.0),
          ),
        ),
        PageViewModel(
          title:
              "There are three main pages in the Boulder Trails Challenge app:",
          body: "(1) Trails, (2) Info/Help and (3) Import Data/Settings",
          image: _buildImage('HelpTrailsPage1.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "The Trails Page",
          body:
              "Filter which trails you want to see;\nShow completion maps for the trails",
          image: _buildImage('HelpTrailsPage2.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Trail Completion Maps",
          body: trailCompletionText,
          image: _buildImage('HelpMapsPage.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "The Import Data/Settings Page",
          body:
              "Synchronize your activities with Strava or import GPX files from your computer or device\nOnly runs, walks and hikes are syncronized from Strava",
          image: _buildImage('HelpSettings1.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Import Activities from Strava",
          body:
              "A one-time Strava login and authorization is required\nThereafter clicking the 'import activities' button will read activities after the 'Start date' ",
          image: _buildImage('HelpStravaImport.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "The Import Data/Settings Page",
          body:
              "Optionally show trail & segment names on the maps or show topographical maps",
          image: _buildImage('HelpMapOptions.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "The Import Data/Settings Page",
          body:
              "Reset all of your activities so that nothing is marked as completed;\nSign out of this app (and disconnect from Strava)",
          image: _buildImage('HelpSettings2.png'),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: false,
      next: const Icon(Icons.arrow_forward),
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: isWebDesktop
          ? const EdgeInsets.all(12.0)
          : const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: isWebDesktop
          ? const DotsDecorator(
              size: Size(10.0, 10.0),
              color: Color(0xFFBDBDBD),
              activeSize: Size(22.0, 10.0),
              activeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
              ),
            )
          : const DotsDecorator(
              size: Size(5.0, 5.0),
              color: Color(0xFFBDBDBD),
              activeSize: Size(10.0, 5.0),
              activeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
              ),
              spacing: EdgeInsets.all(4.0),
            ),
      dotsContainerDecorator: const ShapeDecoration(
        color: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
    );
  }
}
