import '../models/document_upload.dart';
import '../models/user.dart';
import '../services/user_service.dart';

abstract class UserRepository {
  Future<User> fetchUserProfile();
  Future<User> updateUserProfile(User user);
  Future<User> uploadAvatar(User user, DocumentUpload photo);
  Future<User> removeAvatar(User user);
  Future<Map<String, dynamic>> exportMyData();
  Future<void> deleteAccount();
}

class UserRepositoryImpl implements UserRepository {
  final UserService _userService;

  UserRepositoryImpl({UserService? userService})
    : _userService = userService ?? UserServiceImpl();

  @override
  Future<User> fetchUserProfile() {
    return _userService.fetchUserProfile();
  }

  @override
  Future<User> updateUserProfile(User user) {
    return _userService.updateUserProfile(user);
  }

  @override
  Future<User> uploadAvatar(User user, DocumentUpload photo) {
    return _userService.uploadAvatar(user, photo);
  }

  @override
  Future<User> removeAvatar(User user) {
    return _userService.removeAvatar(user);
  }

  @override
  Future<Map<String, dynamic>> exportMyData() {
    return _userService.exportMyData();
  }

  @override
  Future<void> deleteAccount() {
    return _userService.deleteAccount();
  }
}
