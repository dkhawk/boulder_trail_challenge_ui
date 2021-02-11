import 'package:flutter/material.dart';
import 'package:osmp_project/authentication_service.dart';
import 'package:provider/provider.dart';

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
                                  password: passwordController.text.trim())
                              .then((returnString) =>
                                  _signInUpAlert(context, returnString));
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
                              .passwordReset(email: emailController.text.trim())
                              .then((returnString) =>
                                  _signInUpAlert(context, returnString));
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
                              password: passwordController.text.trim())
                          .then((returnString) =>
                              _signInUpAlert(context, returnString));
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
}

// ----
Future<void> _signInUpAlert(BuildContext context, String error) async {
  if (error.isNotEmpty)
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: 450.0),
          child: Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    error,
                    style: TextStyle(fontSize: 15),
                    softWrap: true,
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
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
                ),
                SizedBox(
                  height: 15,
                ),
              ],
            ),
          ),
        );
      },
    );
}
