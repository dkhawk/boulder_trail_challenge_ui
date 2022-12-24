import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:marquee/marquee.dart';

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

  Widget finePrintItem(String aString) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aString.isNotEmpty)
            Icon(
              Icons.wb_sunny_rounded,
              color: Colors.blueAccent,
            ),
          Text('   '),
          Flexible(
            child: Text(
              aString,
              textAlign: TextAlign.left,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _finePrintWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          textDirection: TextDirection.ltr,
          children: [
            finePrintItem(
                'The trail matching algorithm is somewhat generous: If you\'ve come within roughly 20 meters of 80% of the trail you\'ll get credit for finishing the trail.'),
            finePrintItem(
                'The matching algorithm runs in the background and may take a second or two to update the completion data.'),
            finePrintItem(
                'The algorithm will sometimes give you credit for very short nearby trails that you didn\'t run because you came within 20 meters of 80% of the nearby short trail.'),
            finePrintItem(
                'And sometimes the algorithm will miss segments and not give you credit. There\'s a little bit of rocket science baked in that occasionally misfires.'),
            finePrintItem(
                'Also, OSMP moves and renames trails periodically causing the trail matching algorithm to make mistakes. Given all this you may sometimes have to manually mark a trail complete, or backdate and reload your Strava/GPX data.'),
            finePrintItem(
                'Summiting a peak is counted if you come within about 20 meters of the peak. Moving about 1000 meters away will reset the counter so if your doing repeats each summit will get counted.'),
            finePrintItem(
                'Note that if you don\'t use this app over a period of six months we may delete your account without notice.'),
            finePrintItem('Disclaimer: This app is not associated with OSMP, Strava, Boulder Trail Runners or any other entity'),
            finePrintItem(''),
            finePrintItem('Good luck, have fun and be safe! Click "Maps", "Trails" or "Import Data/Settings" below to continue...'),
            finePrintItem(''),
            SizedBox(
              height: 30,
              child: Marquee(
                text: 'Credits: Boulder Trail Runners; DaleH; NateS; LeahW; MaryH & RichH',
                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                scrollAxis: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                blankSpace: 20.0,
                velocity: 50.0,
                startPadding: 10.0,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageDecoration = const PageDecoration(
      titleTextStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),
      bodyTextStyle: TextStyle(fontSize: 16.0),
      bodyFlex: 2,
      imageFlex: 4,
      pageColor: Colors.white,
      imagePadding: EdgeInsets.fromLTRB(15.0, 20.0, 15.0, 0.0),
    );

    const pageDecorationMobile = const PageDecoration(
      titleTextStyle: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700),
      bodyTextStyle: TextStyle(fontSize: 15.0),
      bodyFlex: 2,
      imageFlex: 2,
      pageColor: Colors.white,
      imagePadding: EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 0.0),
    );

    // are we in a web browser on a desktop device or a mobile device
    // - controls padding and dot size changes for narrower screen
    bool isWebDesktop = true;
    if ((defaultTargetPlatform == TargetPlatform.android) || (defaultTargetPlatform == TargetPlatform.iOS)) {
      isWebDesktop = false;
    }

    String welcomePageBody = isWebDesktop
        ? "This application uses imported Strava or GPX data to help you track \nyour progress on the Boulder Trails Challenge"
        : "This application uses imported Strava \n or GPX data to help you track your progress\n on the Boulder Trails Challenge";
    String trailCompletionText =
        'Blue trails have been completed;\nRed trails have not been completed yet;\nClick on a segment to display the trail name & length\n\n';
    trailCompletionText =
        trailCompletionText + 'Note that OSMP has been rerouting some trails (Anenome, Bear Canyon, Mesa ...)\n';
    trailCompletionText = trailCompletionText + 'These may not be marked complete if you run them!\n\n';
    trailCompletionText = trailCompletionText + 'You can manually mark a trail completed on the map for the trail';

    return IntroductionScreen(
      key: introKey,
      showDoneButton: false,
      globalBackgroundColor: Colors.white,
      pages: [
        PageViewModel(
          title: "Welcome to the Boulder Trails Challenge",
          body: welcomePageBody,
          image: _buildFullscreenImage('FlatIrons.jpg'),
          decoration: pageDecoration.copyWith(
            titleTextStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
            fullScreen: true,
            bodyFlex: 2,
            imageFlex: 3,
            descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 20.0),
          ),
        ),
        PageViewModel(
          title: "There are four main pages in the Boulder Trails Challenge app:",
          body: "(1) Map, (2) Trails, (3) Info/Help and (4) Import Data/Settings",
          image: _buildImage('HelpTrailsPage1.png'),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
        PageViewModel(
          title: "The Trails Page",
          body: "Filter which trails you want to see;\nShow completion maps for the trails",
          image: _buildImage('HelpTrailsPage2.png'),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
        PageViewModel(
          title: "Trail Completion Maps",
          body: trailCompletionText,
          image: _buildImage('HelpMapsPage.png'),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
        PageViewModel(
          title: "The Import Data/Settings Page",
          body:
              "Synchronize your activities with Strava or import GPX files from your computer or device\nOnly runs, walks, rides and hikes are synchronized from Strava",
          image: _buildImage('HelpSettings1.png'),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
        PageViewModel(
          title: "Import Activities from Strava",
          body:
              "A one-time Strava login and authorization is required\nThereafter clicking the 'import activities' button will read activities after the 'Start date' ",
          image: _buildImage('HelpStravaImport.png'),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
        PageViewModel(
          title: "The Import Data/Settings Page",
          body: "Optionally show the trail names on the maps or show topographical maps",
          image: _buildImage('HelpMapOptions.png'),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
        PageViewModel(
          title: "The Import Data/Settings Page",
          body:
              "Reset all of your activities so that nothing is marked as completed;\nSign out of this app (and disconnect from Strava)",
          image: _buildImage('HelpSettings2.png'),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
        PageViewModel(
          title: "The Fine Print",
          bodyWidget: _finePrintWidget(),
          // decoration: pageDecoration.copyWith(
          //   titlePadding: EdgeInsets.only(top: 30, bottom: 20),
          //   descriptionPadding: EdgeInsets.fromLTRB(16.0, 30.0, 16.0, 20.0),
          // ),
          decoration: isWebDesktop ? pageDecoration : pageDecorationMobile,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: false,
      next: const Icon(Icons.arrow_forward),
      controlsMargin: const EdgeInsets.all(2),
      controlsPadding: isWebDesktop ? const EdgeInsets.all(12.0) : const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
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
