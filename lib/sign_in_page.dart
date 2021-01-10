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
      body:
      Padding(
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
                decoration: InputDecoration(
                  labelText: "Password",
                ),
              ),
              Spacer(),
              RaisedButton(
                onPressed: () {
                  context.read<AuthenticationService>().signIn(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim()
                  );
                },
                child: Text("Sign in"),
              )
            ],
          )
      ),
    );
  }
}