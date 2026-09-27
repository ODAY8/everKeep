import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/utils/data_export_helper.dart';
import 'package:everkeep/features/documents/services/ocr_service.dart';
import 'package:everkeep/models/document_item.dart';

void main() {
  group('OCR Security & Data Export Integration', () {
    test('Data export includes ocr_text for user documents', () {
      final docRow = {
        'id': 'doc-exp-1',
        'user_id': 'user-123',
        'title': 'Blood Test Results',
        'category': 'Health',
        'document_type': 'medical',
        'file_path': 'user-123/blood_test.pdf',
        'ocr_text': 'Fasting Glucose: 92 mg/dL\nCholesterol: 180 mg/dL',
      };

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-123',
        userEmail: 'patient@example.com',
        documents: [docRow],
      );

      final exportedDocs = payload['documents'] as List<dynamic>;
      expect(exportedDocs.length, 1);
      final exportedDoc = exportedDocs.first as Map<String, dynamic>;
      expect(exportedDoc['id'], 'doc-exp-1');
      expect(exportedDoc['title'], 'Blood Test Results');
      expect(exportedDoc['ocr_text'], contains('Fasting Glucose: 92 mg/dL'));
    });

    test('Data export strips authentication secrets and tokens without leaking alongside OCR text', () {
      final docRowWithSecret = {
        'id': 'doc-exp-2',
        'user_id': 'user-123',
        'title': 'Tax Document',
        'ocr_text': 'W-2 Wage and Tax Statement 2025',
        'access_token': 'secret-token-xyz',
        'service_role': 'secret-service-role-key',
        'password': 'super-secret-password',
      };

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-123',
        userEmail: 'taxpayer@example.com',
        documents: [docRowWithSecret],
      );

      final exportedDocs = payload['documents'] as List<dynamic>;
      final exportedDoc = exportedDocs.first as Map<String, dynamic>;
      expect(exportedDoc['ocr_text'], 'W-2 Wage and Tax Statement 2025');
      expect(exportedDoc.containsKey('access_token'), isFalse);
      expect(exportedDoc.containsKey('service_role'), isFalse);
      expect(exportedDoc.containsKey('password'), isFalse);
    });

    test('DocumentItem serialization maps ocr_text to database rows safely', () {
      final doc = DocumentItem(
        id: 'doc-row-test',
        title: 'Mortgage Deed',
        subtitle: 'Property · Added today',
        category: 'Property',
        filePath: 'vault/deed.pdf',
        ocrText: 'This deed of mortgage executed on 1st day of January 2026...',
      );

      final updateRow = doc.toUpdateRow();
      expect(updateRow['ocr_text'], doc.ocrText);
      expect(updateRow.containsKey('password'), isFalse);
      expect(updateRow.containsKey('token'), isFalse);

      final insertRow = doc.toInsertRow();
      expect(insertRow['ocr_text'], doc.ocrText);

      // Deserialization from DB row
      final fromDb = DocumentItem.fromRow({
        'id': 'doc-row-test',
        'title': 'Mortgage Deed',
        'category': 'Property',
        'file_path': 'vault/deed.pdf',
        'ocr_text': 'This deed of mortgage executed on 1st day of January 2026...',
      });
      expect(fromDb.ocrText, doc.ocrText);
      expect(fromDb.hasOcrText, isTrue);
    });

    test('OcrException does not log or reflect unhandled document data in error message', () {
      const exception = OcrException('Failed to process image');
      expect(exception.toString(), 'OcrException: Failed to process image');
      expect(exception.message, 'Failed to process image');
    });
  });
}
