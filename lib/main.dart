import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:osmp_project/home_page.dart';
import 'package:osmp_project/sign_in_page.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TopApp());
}

class TopApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthenticationService>(
          create: (_) => AuthenticationService(FirebaseAuth.instance),
        ),
        StreamProvider(
            create: (context) =>
                context.read<AuthenticationService>().authStateChanges),
      ],
      child: MaterialApp(
        title: 'Boulder Trails Challenge - 2022',
        theme: ThemeData(
          buttonTheme: Theme.of(context).buttonTheme.copyWith(
                highlightColor: Colors.deepPurple,
              ),
          primarySwatch: Colors.deepPurple,
          textTheme: GoogleFonts.robotoTextTheme(
            Theme.of(context).textTheme,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: AuthenticationWrapper(),
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();

    if (firebaseUser != null) {
      //String userName = firebaseUser.email;
      //print('AuthenticationWrapper signed in as: $userName');
      return BottomNavWidget();
    } else {
      //print('AuthenticationWrapper signing in or registering');
      return SignInPage();
    }
  }
}
