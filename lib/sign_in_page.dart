import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:provider/provider.dart';

import 'package:osmp_project/createAccountData.dart';

class SignInPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Boulder Trails Challenge'),
      ),
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
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                              )
                              .then(
                                (returnString) =>
                                    signInUpAlert(context, returnString),
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
                      context
                          .read<AuthenticationService>()
                          .signUp(
                            email: emailController.text.trim(),
                            password: passwordController.text.trim(),
                          )
                          .then(
                        (returnString) {
                          if (returnString.isNotEmpty)
                            signInUpAlert(context, returnString);
                          else
                            createBasicAcctData(emailController.text.trim())
                                .whenComplete(
                              () => signInUpAlert(
                                context,
                                'Your account has been set up',
                              ),
                            );
                        },
                      );
                    },
                    child: Text("New account"),
                  ),
                ],
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
            content: Text(error),
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
