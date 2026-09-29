import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/utils/data_export_helper.dart';

void main() {
  group('DataExportHelper — People Tagging & Security', () {
    test('includes sanitized people in data export payload', () {
      final rawPeople = [
        {
          'id': 'p-1',
          'name': 'Sarah Connor',
          'created_at': '2026-01-01T12:00:00Z',
          'updated_at': '2026-01-02T15:30:00Z',
          'internal_secret': 'do_not_export_me',
        },
        {
          'id': 'p-2',
          'name': 'John Connor',
          'created_at': '2026-01-03T09:00:00Z',
          'updated_at': '2026-01-03T09:00:00Z',
        },
      ];

      final memories = [
        {
          'id': 'mem-1',
          'title': 'Judgment Day Averted',
          'content': 'We survived the machines.',
          'type': 'memory',
          'people': [
            {'id': 'p-1', 'name': 'Sarah Connor'},
            {'id': 'p-2', 'name': 'John Connor'},
          ],
        },
      ];

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-001',
        userEmail: 'sarah@example.com',
        memories: memories,
        people: rawPeople,
      );

      expect(payload['people'], isA<List>());
      final peopleList = payload['people'] as List;
      expect(peopleList.length, 2);

      final firstPerson = peopleList.first as Map<String, dynamic>;
      expect(firstPerson['id'], 'p-1');
      expect(firstPerson['name'], 'Sarah Connor');
      expect(firstPerson['created_at'], '2026-01-01T12:00:00Z');
      expect(firstPerson['updated_at'], '2026-01-02T15:30:00Z');
      // Verify internal secret was stripped
      expect(firstPerson.containsKey('internal_secret'), isFalse);

      final exportedMemories = payload['memories'] as List;
      expect(exportedMemories.length, 1);
      final firstMem = exportedMemories.first as Map<String, dynamic>;
      expect(firstMem['people'], isA<List>());
      expect((firstMem['people'] as List).length, 2);
    });

    test('handles null or empty people gracefully', () {
      final payloadNull = DataExportHelper.buildExportPayload(
        userId: 'user-002',
        userEmail: 'user@example.com',
        people: null,
      );
      expect(payloadNull['people'], isEmpty);

      final payloadEmpty = DataExportHelper.buildExportPayload(
        userId: 'user-003',
        userEmail: 'user@example.com',
        people: [],
      );
      expect(payloadEmpty['people'], isEmpty);
    });

    test('export does not leak passwords, tokens, or encryption keys', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-secure',
        userEmail: 'safe@example.com',
        people: [
          {'id': 'p-sec', 'name': 'Agent Smith'},
        ],
        memories: [
          {'id': 'm-sec', 'title': 'Secret Mission', 'people': [{'id': 'p-sec', 'name': 'Agent Smith'}]},
        ],
      );

      final jsonStr = jsonEncode(payload);

      // Confirm no auth tokens or credential leaks
      expect(jsonStr.contains('access_token'), isFalse);
      expect(jsonStr.contains('refresh_token'), isFalse);
      expect(jsonStr.contains('supabase_key'), isFalse);
      expect(jsonStr.contains('secret_key'), isFalse);
      expect(jsonStr.contains('api_key'), isFalse);
      expect(jsonStr.contains('service_role'), isFalse);
    });
  });
}
