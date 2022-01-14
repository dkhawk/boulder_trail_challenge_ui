import 'package:firebase_auth/firebase_auth.dart';

// maybe replace this with flutterfire_ui ....
class AuthenticationService {
  final FirebaseAuth _firebaseAuth;

  AuthenticationService(this._firebaseAuth);

  Stream<User> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<String> signIn({String email, String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return '';
    } on FirebaseAuthException catch (e) {
      print(e.toString());
      print(e.code);
      String error = e.message;
      if (e.code == 'user-not-found') {
        error = 'No user found for that email';
      } else if (e.code == 'wrong-password') {
        error = 'Wrong password';
      }
      return error;
    }
  }

  Future<String> signUp({String email, String password}) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return '';
    } on FirebaseAuthException catch (e) {
      print(e.toString());
      print(e.code);
      String error = e.message;
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('An account already exists for that email.');
      }
      return error;
    }
  }

  Future<String> passwordReset({String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email,
      );
      return 'A password reset email has been sent to your account';
    } on FirebaseAuthException catch (e) {
      print(e.toString());
      print(e.code);
      String error = e.message;
      return error;
    }
  }
}

