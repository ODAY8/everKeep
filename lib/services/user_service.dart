import '../models/user.dart';

abstract class UserService {
  Future<User> fetchUserProfile();
  Future<User> updateUserProfile(User user);
}

class UserServiceImpl implements UserService {
  // TODO: Connect to backend API for user profile persistence

  @override
  Future<User> fetchUserProfile() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return User.defaultUser;
  }

  @override
  Future<User> updateUserProfile(User user) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: Send update payload to backend API
    return user;
  }
}
