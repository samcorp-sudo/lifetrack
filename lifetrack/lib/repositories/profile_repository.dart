import 'package:firebase_auth/firebase_auth.dart';

class ProfileRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    await user.updateDisplayName(displayName.trim());
    await user.reload();
  }

  Future<void> signOut() => _auth.signOut();
}
