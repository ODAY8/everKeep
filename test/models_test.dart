import 'dart:io';

import 'package:everkeep/core/config/app_info.dart';
import 'package:everkeep/core/config/app_links.dart';
import 'package:everkeep/core/utils/document_expiration.dart';
import 'package:everkeep/core/utils/greeting.dart';
import 'package:everkeep/core/utils/validators.dart';
import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/legacy_checklist.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/recent_activity.dart';
import 'package:everkeep/models/security_settings.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pure logic behind Home, Vault and Security: what counts as progress, how
/// the security score is earned, and what "recent activity" shows.
void main() {
  group('VaultSummary.fromData', () {
    VaultSummary build({
      int documents = 0,
      int accounts = 0,
      int banking = 0,
      int contacts = 0,
      int bytes = 0,
      bool verified = false,
      SecuritySettings settings = const SecuritySettings(),
    }) => VaultSummary.fromData(
      documents: documents,
      accounts: accounts,
      bankingAccounts: banking,
      trustedContacts: contacts,
      storageBytes: bytes,
      emailVerified: verified,
      settings: settings,
    );

    test('an empty account is honestly empty', () {
      final summary = build();
      expect(summary.totalItems, 0);
      expect(summary.securityScore, 0);
      expect(summary.securityScoreLabel, 'Weak — 0/100');
      expect(summary.legacyProgress, 0);
      expect(summary.storageUsedMb, 0);
    });

    test('the default (no data yet) matches an empty vault', () {
      const empty = VaultSummary();
      expect(empty.totalItems, 0);
      expect(empty.securityScore, 0);
      expect(empty.legacyProgress, 0);
    });

    test(
      'banking accounts are the vault\'s financials; the rest are passwords',
      () {
        final summary = build(accounts: 5, banking: 2);
        expect(summary.financialsCount, 2);
        expect(summary.passwordsCount, 3);
        expect(summary.accountsCount, 5);
        expect(summary.totalItems, 5);
      },
    );

    test('the security score counts safeguards that are really in place', () {
      String label({
        bool verified = false,
        int contacts = 0,
        bool protection = false,
      }) => build(
        verified: verified,
        contacts: contacts,
        settings: SecuritySettings(twoFactorEnabled: protection),
      ).securityScoreLabel;

      expect(label(), 'Weak — 0/100');
      expect(label(verified: true), 'Fair — 33/100');
      expect(label(verified: true, contacts: 1), 'Good — 67/100');
      expect(
        label(verified: true, contacts: 1, protection: true),
        'Excellent — 100/100',
      );
    });

    test('legacy progress is the share of setup steps done', () {
      double progress({
        int docs = 0,
        int accs = 0,
        int contacts = 0,
        bool verified = false,
      }) => build(
        documents: docs,
        accounts: accs,
        contacts: contacts,
        verified: verified,
      ).legacyProgress;

      expect(progress(), 0);
      expect(progress(docs: 3), 0.25);
      expect(progress(docs: 3, verified: true), 0.5);
      expect(progress(docs: 1, accs: 1, contacts: 1), 0.75);
      expect(progress(docs: 1, accs: 1, contacts: 1, verified: true), 1.0);
    });

    test(
      'withDerived recomputes score and progress after the counts change',
      () {
        final base = build(verified: true);
        expect(base.securityScore, 33);
        expect(base.legacyProgress, 0.25);

        final updated = base
            .copyWith(trustedContactsCount: 2, documentsCount: 1)
            .withDerived();
        expect(updated.securityScore, 67);
        expect(
          updated.legacyProgress,
          0.75,
        ); // email + document + trusted person
      },
    );

    test('storage is converted from bytes to megabytes', () {
      expect(build(bytes: 5 * 1024 * 1024).storageUsedMb, 5.0);
    });
  });

  group('LegacyChecklist', () {
    LegacyChecklist list({int d = 0, int a = 0, int c = 0, bool v = false}) =>
        LegacyChecklist(
          documents: d,
          accounts: a,
          trustedContacts: c,
          emailVerified: v,
        );

    test('starts at zero and asks for a document first', () {
      final checklist = list();
      expect(checklist.completed, 0);
      expect(checklist.remaining, 4);
      expect(checklist.progress, 0);
      expect(checklist.nextStep, LegacyStep.addDocument);
      expect(checklist.isComplete, isFalse);
    });

    test('the next step is the first one still to do', () {
      expect(list(d: 1).nextStep, LegacyStep.saveAccount);
      expect(list(d: 1, a: 1).nextStep, LegacyStep.addTrustedPerson);
      expect(list(d: 1, a: 1, c: 1).nextStep, LegacyStep.verifyEmail);
      // Order follows the steps, not the order they were done in.
      expect(list(a: 1, c: 1, v: true).nextStep, LegacyStep.addDocument);
    });

    test('100% is reachable, and then there is nothing left to do', () {
      final done = list(d: 1, a: 1, c: 1, v: true);
      expect(done.progress, 1.0);
      expect(done.remaining, 0);
      expect(done.isComplete, isTrue);
      expect(done.nextStep, isNull);
    });
  });

  group('buildRecentActivity', () {
    final now = DateTime(2026, 9, 21, 12);

    DocumentItem doc(String title, DateTime? at) => DocumentItem(
      id: title,
      title: title,
      subtitle: '',
      category: 'Legal',
      dateAdded: at,
    );

    test('merges everything the user added, newest first', () {
      final items = buildRecentActivity(
        documents: [doc('Old.pdf', now.subtract(const Duration(days: 9)))],
        accounts: [
          AccountItem(
            id: 'a',
            title: 'GitHub',
            subtitle: '',
            icon: Icons.key_rounded,
            color: Colors.blue,
            createdAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        contacts: [
          TrustedContactItem(
            id: 'c',
            name: 'Ada',
            relationship: 'Sibling',
            accessLevel: 'View Only',
            avatarUrl: '',
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
      );

      expect(items.map((i) => i.title), [
        'Ada added as a trusted person',
        'GitHub saved',
        'Old.pdf added',
      ]);
      expect(items.map((i) => i.kind), [
        ActivityKind.contact,
        ActivityKind.account,
        ActivityKind.document,
      ]);
    });

    test('shows only the newest few', () {
      final items = buildRecentActivity(
        documents: [
          for (var i = 0; i < 10; i++)
            doc('D$i', now.subtract(Duration(days: i))),
        ],
        accounts: const [],
        contacts: const [],
        limit: 3,
      );
      expect(items.map((i) => i.title), ['D0 added', 'D1 added', 'D2 added']);
    });

    test('leaves out items with no timestamp rather than inventing one', () {
      final items = buildRecentActivity(
        documents: [doc('Undated.pdf', null)],
        accounts: const [],
        contacts: const [],
      );
      expect(items, isEmpty);
    });

    test('nothing at all gives an empty list', () {
      expect(
        buildRecentActivity(
          documents: const [],
          accounts: const [],
          contacts: const [],
        ),
        isEmpty,
      );
    });
  });

  group('greeting and labels', () {
    test('the greeting follows the time of day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 6)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 11, 59)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 12)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 16, 59)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 17)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 23)), 'Good evening');
    });

    test('countLabel is singular for exactly one', () {
      expect(countLabel(0, 'file', 'files'), '0 files');
      expect(countLabel(1, 'file', 'files'), '1 file');
      expect(countLabel(2, 'file', 'files'), '2 files');
    });
  });

  group('AppLinks', () {
    test('only web links are accepted', () {
      expect(AppLinks.webUri('https://example.com/terms'), isNotNull);
      expect(AppLinks.webUri('http://example.com'), isNotNull);
      expect(AppLinks.webUri('  https://example.com  '), isNotNull);
      expect(AppLinks.webUri(''), isNull);
      expect(AppLinks.webUri('example.com'), isNull);
      expect(AppLinks.webUri('javascript:alert(1)'), isNull);
      expect(AppLinks.webUri('file:///etc/passwd'), isNull);
      expect(AppLinks.webUri('intent://x#Intent;end'), isNull);
    });

    test('nothing is configured by default, so no dead links are shown', () {
      // Plain `flutter test` passes no SUPPORT_EMAIL / HELP_URL.
      if (AppLinks.supportEmail.isEmpty && AppLinks.helpUrl.isEmpty) {
        expect(AppLinks.hasSupport, isFalse);
        expect(AppLinks.contactUri, isNull);
      }
    });
  });

  group('validators', () {
    test('emails', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('  a.b+tag@sub.example.com '), isTrue);
      expect(isValidEmail('nope'), isFalse);
      expect(isValidEmail('a@b'), isFalse);
      expect(isValidEmail(''), isFalse);
    });

    test('passwords', () {
      expect(validatePassword(''), 'Password is required');
      expect(validatePassword('12345'), contains('at least'));
      expect(validatePassword('123456'), isNull);
    });
  });

  group('DocumentExpirationHelper & Attention', () {
    final now = DateTime(2026, 9, 24);

    test('determines expiration statuses correctly', () {
      expect(
        DocumentExpirationHelper.statusFor(null, now: now),
        DocumentExpirationStatus.noExpiryDate,
      );
      expect(
        DocumentExpirationHelper.statusFor(DateTime(2026, 9, 20), now: now),
        DocumentExpirationStatus.expired,
      );
      expect(
        DocumentExpirationHelper.statusFor(DateTime(2026, 9, 24), now: now),
        DocumentExpirationStatus.expiringSoon,
      );
      expect(
        DocumentExpirationHelper.statusFor(DateTime(2026, 10, 15), now: now),
        DocumentExpirationStatus.expiringSoon, // 21 days (<= 30 days)
      );
      expect(
        DocumentExpirationHelper.statusFor(DateTime(2026, 12, 20), now: now),
        DocumentExpirationStatus.valid, // 87 days (> 30 days)
      );
      expect(
        DocumentExpirationHelper.statusFor(DateTime(2027, 5, 1), now: now),
        DocumentExpirationStatus.valid,
      );
    });

    test('formats short labels and descriptive notices', () {
      expect(
        DocumentExpirationHelper.shortLabel(DateTime(2026, 12, 20), now),
        '87 days',
      );
      expect(
        DocumentExpirationHelper.shortLabel(DateTime(2026, 9, 20), now),
        'Expired',
      );
      expect(
        DocumentExpirationHelper.shortLabel(DateTime(2026, 9, 25), now),
        'Tomorrow',
      );
      expect(
        DocumentExpirationHelper.descriptiveNotice(DateTime(2026, 12, 20), now),
        'Expires in 87 days',
      );
      expect(
        DocumentExpirationHelper.descriptiveNotice(DateTime(2026, 9, 21), now),
        'Expired 3 days ago',
      );
      expect(
        DocumentExpirationHelper.descriptiveNotice(DateTime(2026, 9, 24), now),
        'Expires today',
      );
    });

    test('DocumentItem computes expiration getters', () {
      final today = DateTime.now();
      final expiringDoc = DocumentItem(
        id: '1',
        title: 'Passport',
        subtitle: 'Legal',
        category: 'Legal',
        expiryDate: today.add(const Duration(days: 21)),
        issueDate: DateTime(2016, 12, 20),
      );
      expect(expiringDoc.isExpiringSoon, isTrue);
      expect(expiringDoc.isExpired, isFalse);
      expect(expiringDoc.expirationNotice, 'Expires in 21 days');
      expect(expiringDoc.toInsertRow()['issue_date'], '2016-12-20');
    });

    test('buildRecentActivity includes memories when provided', () {
      final doc = DocumentItem(
        id: 'd1',
        title: 'Passport',
        subtitle: 'Legal',
        category: 'Legal',
        dateAdded: now.subtract(const Duration(days: 2)),
      );
      final mem = MemoryItem(
        id: 'm1',
        title: 'Graduation Day',
        content: 'Finished college',
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final activity = buildRecentActivity(
        documents: [doc],
        accounts: [],
        contacts: [],
        memories: [mem],
      );

      expect(activity.length, 2);
      expect(activity.first.kind, ActivityKind.memory);
      expect(activity.first.title, 'Graduation Day added to memories');
      expect(activity.last.kind, ActivityKind.document);
    });
  });

  test('the version shown in About matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, declared, reason: 'update appVersion in app_info.dart');
  });
}
