import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  User? _user = User.defaultUser;
  bool _isLoading = false;
  String? _error;

  UserProvider({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepositoryImpl();

  User? get user => _user;
  String get displayName => _user?.name ?? 'User';
  String get displayEmail => _user?.email ?? '';
  String get firstName => (_user?.name ?? 'User').split(' ').first;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _userRepository.fetchUserProfile();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserProfile(User updatedUser) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _userRepository.updateUserProfile(updatedUser);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }
}
