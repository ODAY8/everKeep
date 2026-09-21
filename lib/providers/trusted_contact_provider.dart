import 'package:flutter/foundation.dart';
import '../models/trusted_contact_item.dart';
import '../repositories/trusted_contact_repository.dart';

class TrustedContactProvider extends ChangeNotifier {
  final TrustedContactRepository _trustedContactRepository;

  List<TrustedContactItem> _contacts = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  TrustedContactProvider({
    TrustedContactRepository? trustedContactRepository,
  }) : _trustedContactRepository =
            trustedContactRepository ?? TrustedContactRepositoryImpl();

  List<TrustedContactItem> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _contacts.isEmpty;

  Future<void> fetchContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _contacts = await _trustedContactRepository.fetchContacts();
      _hasFetched = true;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addContact(TrustedContactItem contact) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _trustedContactRepository.addContact(contact);
      _contacts.add(added);
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

  Future<bool> removeContact(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _trustedContactRepository.removeContact(id);
      _contacts.removeWhere((c) => c.id == id);
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
}
