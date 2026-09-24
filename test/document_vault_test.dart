import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/utils/document_expiration.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/document_type.dart';
import 'package:everkeep/providers/document_provider.dart';

import 'fakes.dart';

void main() {
  final now = DateTime(2026, 9, 25);

  group('DocumentType', () {
    test('contains all 12 initial document types with labels and emojis', () {
      expect(DocumentType.values.length, 12);
      expect(DocumentType.passport.label, 'Passport');
      expect(DocumentType.passport.emoji, '🛂');
      expect(DocumentType.nationalId.label, 'National ID');
      expect(DocumentType.nationalId.emoji, '🪪');
      expect(DocumentType.residencePermit.label, 'Residence Permit');
      expect(DocumentType.visa.label, 'Visa');
      expect(DocumentType.drivingLicense.label, 'Driving License');
      expect(DocumentType.universityCertificate.label, 'University Certificate');
      expect(DocumentType.academicDocument.label, 'Academic Document');
      expect(DocumentType.insurance.label, 'Insurance');
      expect(DocumentType.medicalDocument.label, 'Medical Document');
      expect(DocumentType.employmentDocument.label, 'Employment Document');
      expect(DocumentType.financialDocument.label, 'Financial Document');
      expect(DocumentType.other.label, 'Other');
    });

    test('fromCode resolves case-insensitively and falls back to other', () {
      expect(DocumentType.fromCode('passport'), DocumentType.passport);
      expect(DocumentType.fromCode('Passport'), DocumentType.passport);
      expect(DocumentType.fromCode('national_id'), DocumentType.nationalId);
      expect(DocumentType.fromCode('National ID'), DocumentType.nationalId);
      expect(DocumentType.fromCode('university_certificate'), DocumentType.universityCertificate);
      expect(DocumentType.fromCode('unknown_xyz'), DocumentType.other);
      expect(DocumentType.fromCode(null), DocumentType.other);
      expect(DocumentType.fromCode(''), DocumentType.other);
    });

    test('field hints and labels adapt per document type', () {
      expect(DocumentType.passport.numberLabel, 'Passport number');
      expect(DocumentType.passport.countryLabel, 'Issuing country');
      expect(DocumentType.insurance.numberLabel, 'Policy number');
      expect(DocumentType.insurance.institutionLabel, 'Insurance provider');
      expect(DocumentType.universityCertificate.institutionLabel, 'University / College');
    });
  });

  group('DocumentItem Structured Metadata', () {
    test('parses all structured fields from Supabase row', () {
      final row = {
        'id': 'doc-101',
        'title': 'Somali Passport',
        'category': 'Legal',
        'document_type': 'passport',
        'document_number': 'A1234567',
        'country': 'Somalia',
        'institution': 'Immigration Agency',
        'notes': 'Renew before December',
        'issue_date': '2020-01-15',
        'expiry_date': '2030-01-15',
        'file_path': 'user-1/documents/passport.pdf',
        'created_at': '2026-09-20T10:00:00Z',
      };

      final item = DocumentItem.fromRow(row);

      expect(item.id, 'doc-101');
      expect(item.title, 'Somali Passport');
      expect(item.documentType, 'passport');
      expect(item.typeInfo, DocumentType.passport);
      expect(item.displayType, 'Passport');
      expect(item.emoji, '🛂');
      expect(item.documentNumber, 'A1234567');
      expect(item.country, 'Somalia');
      expect(item.institution, 'Immigration Agency');
      expect(item.notes, 'Renew before December');
      expect(item.description, 'Renew before December'); // alias
      expect(item.issueDate, DateTime(2020, 1, 15));
      expect(item.expiryDate, DateTime(2030, 1, 15));
      expect(item.hasFile, isTrue);
      expect(item.hasExpiryDate, isTrue);
      expect(item.expirationStatus, DocumentExpirationStatus.valid);
    });

    test('toInsertRow serializes optional metadata cleanly', () {
      final item = DocumentItem(
        id: '',
        title: 'Degree Certificate',
        subtitle: '',
        category: 'Legal',
        documentType: 'university_certificate',
        documentNumber: 'DEG-9988',
        country: 'United Kingdom',
        institution: 'University of Oxford',
        notes: 'Graduation honors',
        issueDate: DateTime(2022, 6, 20),
      );

      final row = item.toInsertRow();

      expect(row['title'], 'Degree Certificate');
      expect(row['category'], 'Legal');
      expect(row['document_type'], 'university_certificate');
      expect(row['document_number'], 'DEG-9988');
      expect(row['country'], 'United Kingdom');
      expect(row['institution'], 'University of Oxford');
      expect(row['notes'], 'Graduation honors');
      expect(row['description'], 'Graduation honors');
      expect(row['issue_date'], '2022-06-20');
      expect(row.containsKey('expiry_date'), isFalse);
    });

    test('toUpdateRow includes updated structured fields', () {
      final item = DocumentItem(
        id: 'doc-1',
        title: 'Health Insurance',
        subtitle: '',
        category: 'Financial',
        documentType: 'insurance',
        documentNumber: 'POL-12345',
        institution: 'Allianz',
        expiryDate: DateTime(2027, 1, 1),
      );

      final row = item.toUpdateRow();

      expect(row['title'], 'Health Insurance');
      expect(row['document_type'], 'insurance');
      expect(row['document_number'], 'POL-12345');
      expect(row['institution'], 'Allianz');
      expect(row['expiry_date'], '2027-01-01');
    });

    test('copyWith properly updates metadata fields', () {
      const original = DocumentItem(
        id: '1',
        title: 'ID',
        subtitle: '',
        category: 'Legal',
      );

      final updated = original.copyWith(
        documentType: 'national_id',
        documentNumber: 'N-9988',
        country: 'Kenya',
      );

      expect(updated.documentType, 'national_id');
      expect(updated.documentNumber, 'N-9988');
      expect(updated.country, 'Kenya');
      expect(updated.title, 'ID');
    });
  });

  group('Document Expiration System (30-day threshold)', () {
    test('no expiry date produces noExpiryDate status and no expiration warning', () {
      const doc = DocumentItem(
        id: '1',
        title: 'Birth Certificate',
        subtitle: '',
        category: 'Legal',
      );
      expect(doc.hasExpiryDate, isFalse);
      expect(doc.expirationStatus, DocumentExpirationStatus.noExpiryDate);
      expect(doc.isExpiringSoon, isFalse);
      expect(doc.isExpired, isFalse);
      expect(doc.expirationNotice, 'No expiration date');
    });

    test('past expiry date produces expired status', () {
      final doc = DocumentItem(
        id: '1',
        title: 'Old Visa',
        subtitle: '',
        category: 'Legal',
        expiryDate: now.subtract(const Duration(days: 12)),
      );
      expect(doc.expirationStatus, DocumentExpirationStatus.expired);
      expect(doc.isExpired, isTrue);
      expect(doc.isExpiringSoon, isFalse);
      expect(
        DocumentExpirationHelper.descriptiveNotice(doc.expiryDate, now),
        'Expired 12 days ago',
      );
    });

    test('expiry within 30 days produces expiringSoon status', () {
      final doc = DocumentItem(
        id: '1',
        title: 'Expiring Permit',
        subtitle: '',
        category: 'Legal',
        expiryDate: now.add(const Duration(days: 21)),
      );
      expect(
        DocumentExpirationHelper.statusFor(doc.expiryDate, now: now),
        DocumentExpirationStatus.expiringSoon,
      );
      expect(
        DocumentExpirationHelper.descriptiveNotice(doc.expiryDate, now),
        'Expires in 21 days',
      );
      expect(
        DocumentExpirationHelper.shortLabel(doc.expiryDate, now),
        '21 days',
      );
    });

    test('expiry beyond 30 days produces valid status', () {
      final doc = DocumentItem(
        id: '1',
        title: 'Fresh Passport',
        subtitle: '',
        category: 'Legal',
        expiryDate: now.add(const Duration(days: 240)),
      );
      expect(
        DocumentExpirationHelper.statusFor(doc.expiryDate, now: now),
        DocumentExpirationStatus.valid,
      );
      expect(
        DocumentExpirationHelper.descriptiveNotice(doc.expiryDate, now),
        'Expires in 240 days',
      );
    });
  });

  group('DocumentProvider Filtering & Search', () {
    late FakeDocumentRepository repo;
    late DocumentProvider provider;

    final doc1 = DocumentItem(
      id: 'd1',
      title: 'Somali Passport',
      subtitle: '',
      category: 'Legal',
      documentType: 'passport',
      documentNumber: 'A1234567',
      country: 'Somalia',
      institution: 'Immigration Agency',
      expiryDate: now.add(const Duration(days: 21)), // Expiring soon
    );

    final doc2 = DocumentItem(
      id: 'd2',
      title: 'Health Insurance Policy',
      subtitle: '',
      category: 'Financial',
      documentType: 'insurance',
      documentNumber: 'POL-999',
      institution: 'Allianz Care',
      expiryDate: now.subtract(const Duration(days: 5)), // Expired
    );

    final doc3 = DocumentItem(
      id: 'd3',
      title: 'Oxford Diploma',
      subtitle: '',
      category: 'Legal',
      documentType: 'university_certificate',
      documentNumber: 'DEG-777',
      country: 'United Kingdom',
      institution: 'University of Oxford',
      // No expiry date
    );

    final doc4 = DocumentItem(
      id: 'd4',
      title: 'Driving License',
      subtitle: '',
      category: 'Legal',
      documentType: 'driving_license',
      documentNumber: 'DL-555',
      country: 'Somalia',
      expiryDate: now.add(const Duration(days: 300)), // Valid long-term
    );

    setUp(() async {
      repo = FakeDocumentRepository([doc1, doc2, doc3, doc4]);
      provider = DocumentProvider(documentRepository: repo);
      await provider.fetchDocuments();
    });

    test('filter by status: Expiring Soon, Expired, No Expiry', () {
      final expiring = provider.filterDocuments(filter: 'Expiring Soon');
      expect(expiring.length, 1);
      expect(expiring.first.title, 'Somali Passport');

      final expired = provider.filterDocuments(filter: 'Expired');
      expect(expired.length, 1);
      expect(expired.first.title, 'Health Insurance Policy');

      final noExpiry = provider.filterDocuments(filter: 'No Expiry');
      expect(noExpiry.length, 1);
      expect(noExpiry.first.title, 'Oxford Diploma');

      final all = provider.filterDocuments(filter: 'All');
      expect(all.length, 4);
    });

    test('filter by specific document type', () {
      final passports = provider.filterDocuments(documentType: 'passport');
      expect(passports.length, 1);
      expect(passports.first.title, 'Somali Passport');

      final insurances = provider.filterDocuments(documentType: 'insurance');
      expect(insurances.length, 1);
      expect(insurances.first.title, 'Health Insurance Policy');
    });

    test('search matches title, document number, country, institution, and type', () {
      // Search by country
      expect(provider.filterDocuments(query: 'Somalia').length, 2);

      // Search by institution
      expect(provider.filterDocuments(query: 'Oxford').length, 1);
      expect(provider.filterDocuments(query: 'Allianz').length, 1);

      // Search by document number
      expect(provider.filterDocuments(query: 'A1234567').length, 1);
      expect(provider.filterDocuments(query: 'POL-999').length, 1);

      // Search by document type name
      expect(provider.filterDocuments(query: 'Insurance').length, 1);
      expect(provider.filterDocuments(query: 'Diploma').length, 1);

      // No match
      expect(provider.filterDocuments(query: 'nonexistent_xyz'), isEmpty);
    });

    test('attentionDocuments surfaces expired and expiring soon items sorted by urgency', () {
      final attention = provider.attentionDocuments;
      expect(attention.length, 2);
      // Expired items come first
      expect(attention.first.isExpired, isTrue);
      expect(attention.first.title, 'Health Insurance Policy');
      // Followed by expiring soon
      expect(attention.last.isExpiringSoon, isTrue);
      expect(attention.last.title, 'Somali Passport');
    });

    test('document creation, update, and deletion update provider state', () async {
      final newDoc = DocumentItem(
        id: '',
        title: 'National ID',
        subtitle: '',
        category: 'Legal',
        documentType: 'national_id',
        documentNumber: 'NID-123456',
        country: 'Somalia',
      );

      final added = await provider.addDocument(newDoc);
      expect(added, isTrue);
      expect(provider.count, 5);
      expect(provider.filterDocuments(query: 'NID-123456').length, 1);

      final created = provider.documents.first;
      final updated = await provider.updateDocument(
        created.copyWith(title: 'Updated Somali National ID'),
      );
      expect(updated, isTrue);
      expect(provider.documents.first.title, 'Updated Somali National ID');

      final deleted = await provider.deleteDocument(created.id);
      expect(deleted, isTrue);
      expect(provider.count, 4);
    });
  });
}
