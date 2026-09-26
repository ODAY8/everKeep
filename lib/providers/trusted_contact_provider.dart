import 'package:flutter/foundation.dart';
import '../models/trusted_contact_item.dart';
import '../repositories/trusted_contact_repository.dart';
import 'session_scoped.dart';

class TrustedContactProvider extends ChangeNotifier with SessionScoped {
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
  int get count => _contacts.length;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _contacts.isEmpty;

  Future<void> fetchContacts() async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _trustedContactRepository.fetchContacts();
      if (isStale(epoch)) return;
      _contacts = fetched;
      _hasFetched = true;
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

  Future<bool> addContact(TrustedContactItem contact) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _trustedContactRepository.addContact(contact);
      if (isStale(epoch)) return false;
      _contacts.add(added);
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

  Future<bool> updateContact(TrustedContactItem contact) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _trustedContactRepository.updateContact(contact);
      if (isStale(epoch)) return false;
      final index = _contacts.indexWhere((c) => c.id == saved.id);
      if (index != -1) _contacts[index] = saved;
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

  Future<bool> removeContact(String id) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _trustedContactRepository.removeContact(id);
      if (isStale(epoch)) return false;
      _contacts.removeWhere((c) => c.id == id);
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

  /// Drops everything held for the previous user (called on sign-out).
  void reset() {
    invalidateSession();
    _contacts = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    notifyListeners();
  }
}
