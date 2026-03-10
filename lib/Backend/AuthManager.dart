import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//Auth Services
class AuthServices {
  //set Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  //signup Function
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final credentials = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = credentials.user;

    if(user != null) {
      _db.collection("teachers").doc(user.uid).set({"name": name, "email": email, "created_at": FieldValue.serverTimestamp(),});
    }

    return user;
  }

  //Login Function
  Future<User?> signIn({ required String email, required String password, }) async {
    final credentials = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return credentials.user;
  }

  //Logout Function
  Future<void> signOut() async {
    await _auth.signOut();
  }
}