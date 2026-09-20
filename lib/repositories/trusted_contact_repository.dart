import '../models/trusted_contact_item.dart';
import '../services/trusted_contact_service.dart';

abstract class TrustedContactRepository {
  Future<List<TrustedContactItem>> fetchContacts();
  Future<TrustedContactItem> addContact(TrustedContactItem contact);
  Future<void> removeContact(String id);
}

class TrustedContactRepositoryImpl implements TrustedContactRepository {
  final TrustedContactService _trustedContactService;

  TrustedContactRepositoryImpl({TrustedContactService? trustedContactService})
    : _trustedContactService =
          trustedContactService ?? TrustedContactServiceImpl();

  @override
  Future<List<TrustedContactItem>> fetchContacts() {
    return _trustedContactService.fetchContacts();
  }

  @override
  Future<TrustedContactItem> addContact(TrustedContactItem contact) {
    return _trustedContactService.addContact(contact);
  }

  @override
  Future<void> removeContact(String id) {
    return _trustedContactService.removeContact(id);
  }
}
