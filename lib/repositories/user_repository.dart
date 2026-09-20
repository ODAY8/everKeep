import '../models/user.dart';
import '../services/user_service.dart';

abstract class UserRepository {
  Future<User> fetchUserProfile();
  Future<User> updateUserProfile(User user);
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
}
