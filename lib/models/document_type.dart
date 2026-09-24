import 'package:flutter/material.dart';

/// The structured document types supported across EverKeep.
/// Acts as the single source of truth for document classification,
/// icons, emojis, default categories, and field hints.
enum DocumentType {
  passport(
    code: 'passport',
    label: 'Passport',
    emoji: '🛂',
    icon: Icons.badge_outlined,
    defaultCategory: 'Legal',
    numberHint: 'e.g. A1234567',
    numberLabel: 'Passport number',
    countryLabel: 'Issuing country',
    institutionLabel: 'Issuing authority',
  ),
  nationalId(
    code: 'national_id',
    label: 'National ID',
    emoji: '🪪',
    icon: Icons.credit_card_rounded,
    defaultCategory: 'Legal',
    numberHint: 'e.g. ID-987654321',
    numberLabel: 'ID number',
    countryLabel: 'Country of issue',
    institutionLabel: 'Issuing authority',
  ),
  residencePermit(
    code: 'residence_permit',
    label: 'Residence Permit',
    emoji: '🏠',
    icon: Icons.apartment_rounded,
    defaultCategory: 'Legal',
    numberHint: 'e.g. RP-456789',
    numberLabel: 'Permit number',
    countryLabel: 'Host country',
    institutionLabel: 'Immigration authority',
  ),
  visa(
    code: 'visa',
    label: 'Visa',
    emoji: '✈️',
    icon: Icons.flight_takeoff_rounded,
    defaultCategory: 'Legal',
    numberHint: 'e.g. V-12345678',
    numberLabel: 'Visa number',
    countryLabel: 'Destination country',
    institutionLabel: 'Embassy / Consulate',
  ),
  drivingLicense(
    code: 'driving_license',
    label: 'Driving License',
    emoji: '🚗',
    icon: Icons.directions_car_outlined,
    defaultCategory: 'Legal',
    numberHint: 'e.g. DL-88776655',
    numberLabel: 'License number',
    countryLabel: 'Issuing country/state',
    institutionLabel: 'Licensing authority',
  ),
  universityCertificate(
    code: 'university_certificate',
    label: 'University Certificate',
    emoji: '🎓',
    icon: Icons.school_outlined,
    defaultCategory: 'Legal',
    numberHint: 'e.g. Degree / Diploma #',
    numberLabel: 'Certificate number',
    countryLabel: 'Country',
    institutionLabel: 'University / College',
  ),
  academicDocument(
    code: 'academic_document',
    label: 'Academic Document',
    emoji: '📜',
    icon: Icons.menu_book_outlined,
    defaultCategory: 'Legal',
    numberHint: 'e.g. Student / Record ID',
    numberLabel: 'Document reference',
    countryLabel: 'Country',
    institutionLabel: 'School / Institution',
  ),
  insurance(
    code: 'insurance',
    label: 'Insurance',
    emoji: '🛡️',
    icon: Icons.health_and_safety_outlined,
    defaultCategory: 'Financial',
    numberHint: 'e.g. POL-98765432',
    numberLabel: 'Policy number',
    countryLabel: 'Coverage country',
    institutionLabel: 'Insurance provider',
  ),
  medicalDocument(
    code: 'medical_document',
    label: 'Medical Document',
    emoji: '🏥',
    icon: Icons.medical_services_outlined,
    defaultCategory: 'Medical',
    numberHint: 'e.g. Record / Patient #',
    numberLabel: 'Record number',
    countryLabel: 'Country',
    institutionLabel: 'Hospital / Clinic / Doctor',
  ),
  employmentDocument(
    code: 'employment_document',
    label: 'Employment Document',
    emoji: '💼',
    icon: Icons.work_outline_rounded,
    defaultCategory: 'Financial',
    numberHint: 'e.g. Employee ID or Contract #',
    numberLabel: 'Reference / Contract #',
    countryLabel: 'Country of employment',
    institutionLabel: 'Employer / Company',
  ),
  financialDocument(
    code: 'financial_document',
    label: 'Financial Document',
    emoji: '💳',
    icon: Icons.account_balance_outlined,
    defaultCategory: 'Financial',
    numberHint: 'e.g. Account or Reference #',
    numberLabel: 'Account / Reference #',
    countryLabel: 'Country',
    institutionLabel: 'Bank / Financial institution',
  ),
  other(
    code: 'other',
    label: 'Other',
    emoji: '📄',
    icon: Icons.description_outlined,
    defaultCategory: 'Other',
    numberHint: 'e.g. Document number (optional)',
    numberLabel: 'Document number',
    countryLabel: 'Country',
    institutionLabel: 'Institution / Organization',
  );

  final String code;
  final String label;
  final String emoji;
  final IconData icon;
  final String defaultCategory;
  final String numberHint;
  final String numberLabel;
  final String countryLabel;
  final String institutionLabel;

  const DocumentType({
    required this.code,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.defaultCategory,
    required this.numberHint,
    required this.numberLabel,
    required this.countryLabel,
    required this.institutionLabel,
  });

  /// Resolves a [DocumentType] from a string code or label (case-insensitive).
  /// Falls back to [DocumentType.other] if not recognized.
  static DocumentType fromCode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DocumentType.other;
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    for (final type in DocumentType.values) {
      if (type.code == normalized) return type;
      if (type.label.toLowerCase() == raw.trim().toLowerCase()) return type;
    }
    // Also try fuzzy matching
    if (normalized.contains('passport')) return DocumentType.passport;
    if (normalized.contains('national') || normalized.contains('id_card')) return DocumentType.nationalId;
    if (normalized.contains('residence')) return DocumentType.residencePermit;
    if (normalized.contains('visa')) return DocumentType.visa;
    if (normalized.contains('license') || normalized.contains('driving')) return DocumentType.drivingLicense;
    if (normalized.contains('university') || normalized.contains('degree') || normalized.contains('diploma')) {
      return DocumentType.universityCertificate;
    }
    if (normalized.contains('academic') || normalized.contains('school') || normalized.contains('transcript')) {
      return DocumentType.academicDocument;
    }
    if (normalized.contains('insurance') || normalized.contains('policy')) return DocumentType.insurance;
    if (normalized.contains('medical') || normalized.contains('health') || normalized.contains('vaccine')) {
      return DocumentType.medicalDocument;
    }
    if (normalized.contains('employment') || normalized.contains('work') || normalized.contains('salary') || normalized.contains('contract')) {
      return DocumentType.employmentDocument;
    }
    if (normalized.contains('financial') || normalized.contains('bank') || normalized.contains('tax')) {
      return DocumentType.financialDocument;
    }
    return DocumentType.other;
  }
}
