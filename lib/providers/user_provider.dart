import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';
import 'session_scoped.dart';

class UserProvider extends ChangeNotifier with SessionScoped {
  final UserRepository _userRepository;

  /// Null until someone signs in — the signed-in user is pushed in via
  /// [setUser] (see SessionCoordinator), never assumed.
  User? _user;
  bool _isLoading = false;
  String? _error;

  UserProvider({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepositoryImpl();

  User? get user => _user;
  String get displayName => _user?.name ?? 'User';
  String get displayEmail => _user?.email ?? '';
  String get firstName => displayName.split(' ').first;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUserProfile() async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _userRepository.fetchUserProfile();
      if (isStale(epoch)) return;
      _user = fetched;
    } catch (e) {
      if (isStale(epoch)) return;
      _error = errorMessage(e);
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateUserProfile(User updatedUser) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _userRepository.updateUserProfile(updatedUser);
      if (isStale(epoch)) return false;
      _user = saved;
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _error = errorMessage(e);
      return false;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }

  /// Forgets the previous user (called on sign-out).
  void reset() {
    invalidateSession();
    _user = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
