import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/profile_repository.dart';

class ProfileService {
  ProfileService({ProfileRepository? repository})
      : _repository = repository ?? ProfileRepository();

  final ProfileRepository _repository;

  User? get currentUser => _repository.currentUser;

  Future<User?> getCurrentProfile() async {
    await _repository.reloadUser();
    return _repository.currentUser;
  }

  Future<void> updateDisplayName(String displayName) =>
      _repository.updateDisplayName(displayName);

  Future<void> signOut() => _repository.signOut();
}
