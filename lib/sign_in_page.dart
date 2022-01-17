import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:provider/provider.dart';

import 'package:osmp_project/createAccountData.dart';

class SignInPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // are we in a web browser on a desktop device or a mobile device
    // - controls padding and dot size changes for narrower screen
    bool isWebDesktop = true;
    if ((defaultTargetPlatform == TargetPlatform.android) || (defaultTargetPlatform == TargetPlatform.iOS)) {
      isWebDesktop = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Boulder Trails Challenge - 2022'),
      ),
      // don't resize when keyboard comes up on mobile
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
              ),
            ),
            TextField(
              controller: passwordController,
              enableSuggestions: false,
              autocorrect: false,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<AuthenticationService>()
                              .signIn(
                                email: emailController.text.trim().toLowerCase(),
                                password: passwordController.text.trim(),
                              )
                              .then(
                                (returnString) => signInUpAlert(context, returnString),
                              );
                        },
                        child: Text("Sign in"),
                      ),
                      SizedBox(
                        height: 20,
                        width: 70,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<AuthenticationService>()
                              .passwordReset(
                                email: emailController.text.trim(),
                              )
                              .then(
                                (returnString) => signInUpAlert(
                                  context,
                                  returnString,
                                ),
                              );
                        },
                        child: Text("Reset password"),
                      ),
                    ],
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      // attempt to register the new account
                      // - returns error if account exists or if account
                      //   name is malformed
                      registerNewAcct(
                        context,
                        emailController.text.trim().toLowerCase(),
                        passwordController.text.trim(),
                      ).then(
                        (returnString) {
                          if (returnString != validAccountRegistration)
                            // show the error string to the user
                            signInUpAlert(
                              context,
                              returnString,
                            );
                          else {
                            // set up (i.e. upload) the account data in Cloud Firestore
                            // - this can take a while so a circular progress is shown
                            createNewAcct(
                              context,
                              emailController.text.trim().toLowerCase(),
                              passwordController.text.trim(),
                            );
                          }
                        },
                      );
                    },
                    child: Text("New account"),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 30, 8, 0),
              child: Text(
                'Welcome to the Boulder Trails Challenge!\n',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            isWebDesktop
                ? Text(
                    'Boulder OSMP challenges visitors to run or hike all of the OSMP trails.',
                    textAlign: TextAlign.center,
                  )
                : Text(
                    'Boulder OSMP challenges visitors \nto run or hike all of the OSMP trails.',
                    textAlign: TextAlign.center,
                  ),
            isWebDesktop
                ? Text(
                    'This application uses imported Strava or GPX data to help you map & track your progress.',
                    textAlign: TextAlign.center,
                  )
                : Text(
                    'This application uses imported Strava or GPX data\n to help you map & track your progress.',
                    textAlign: TextAlign.center,
                  ),
            Text(
              'Happy Running!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Image(
                  image: AssetImage('assets/images/FlatIrons.jpg'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----
  Future<void> signInUpAlert(BuildContext context, String error) async {
    if (error.isNotEmpty)
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Text(
              error,
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.0,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 15.0,
                  ),
                ),
              )
            ],
          );
        },
      );
  }
}
