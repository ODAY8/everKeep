import '../core/config/app_image_urls.dart';
import '../models/trusted_contact_item.dart';

abstract class TrustedContactService {
  Future<List<TrustedContactItem>> fetchContacts();
  Future<TrustedContactItem> addContact(TrustedContactItem contact);
  Future<void> removeContact(String id);
}

class TrustedContactServiceImpl implements TrustedContactService {
  final List<TrustedContactItem> _mockDatabase = const [
    TrustedContactItem(
      id: 'tc-1',
      name: 'Sarah Johnson',
      relationship: 'Spouse',
      accessLevel: 'Full Access',
      avatarUrl: AppImageUrls.trustedContact1,
    ),
    TrustedContactItem(
      id: 'tc-2',
      name: 'Michael Chen',
      relationship: 'Attorney',
      accessLevel: 'On Release',
      avatarUrl: AppImageUrls.trustedContact2,
    ),
    TrustedContactItem(
      id: 'tc-3',
      name: 'Emily Davis',
      relationship: 'Financial Advisor',
      accessLevel: 'View Only',
      avatarUrl: AppImageUrls.trustedContact3,
    ),
    TrustedContactItem(
      id: 'tc-4',
      name: 'Robert Wilson',
      relationship: 'Family Friend',
      accessLevel: 'Verification Role',
      avatarUrl: AppImageUrls.trustedContact4,
    ),
  ];

  // TODO: Connect to backend for managing trusted contacts & invitations

  @override
  Future<List<TrustedContactItem>> fetchContacts() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.from(_mockDatabase);
  }

  @override
  Future<TrustedContactItem> addContact(TrustedContactItem contact) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return contact;
  }

  @override
  Future<void> removeContact(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
