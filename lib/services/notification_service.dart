import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/routing/app_router.dart';
import '../features/documents/presentation/widgets/document_details_sheet.dart';
import '../models/document_item.dart';
import '../providers/document_provider.dart';
import '../widgets/feedback.dart';

/// Reminder categories for document expiration.
enum DocumentReminderType {
  /// 30 days before expiration date (matches DocumentExpirationHelper.defaultExpiringSoonDays).
  expiringSoon30Days(daysBefore: 30, code: 1),

  /// 7 days before expiration date.
  expiringSoon7Days(daysBefore: 7, code: 2),

  /// On the calendar day of expiration.
  expiredDayOf(daysBefore: 0, code: 3);

  final int daysBefore;
  final int code;

  const DocumentReminderType({required this.daysBefore, required this.code});
}

/// Represents a computed document expiration reminder.
@immutable
class DocumentReminder {
  final int id;
  final String documentId;
  final DocumentReminderType type;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;

  const DocumentReminder({
    required this.id,
    required this.documentId,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentReminder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          documentId == other.documentId &&
          type == other.type &&
          scheduledAt == other.scheduledAt;

  @override
  int get hashCode => Object.hash(id, documentId, type, scheduledAt);
}

/// Abstract adapter to decouple notification delivery for unit testing and platform abstraction.
abstract class NotificationPluginAdapter {
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  });

  Future<bool?> requestPermissions();

  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();

  Future<List<PendingNotificationRequest>> pendingNotificationRequests();

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails();
}

/// Production implementation of [NotificationPluginAdapter] wrapping [FlutterLocalNotificationsPlugin].
class FlutterLocalNotificationsAdapter implements NotificationPluginAdapter {
  final FlutterLocalNotificationsPlugin _plugin;

  FlutterLocalNotificationsAdapter({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    try {
      return await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool?> requestPermissions() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
        androidScheduleMode: androidScheduleMode,
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        // Fall back gracefully to inexact scheduling on Android 13/14+ without requiring special system permission
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            notificationDetails,
            uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
        } catch (inner) {
          debugPrint('zonedSchedule fallback error: $inner');
        }
      } else {
        debugPrint('zonedSchedule PlatformException: $e');
      }
    } catch (e, stack) {
      debugPrint('zonedSchedule error: $e\n$stack');
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (_) {
      return null;
    }
  }
}

/// Record of a scheduled notification in the fake adapter.
class FakeScheduledNotification {
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails notificationDetails;
  final String? payload;

  FakeScheduledNotification({
    required this.id,
    this.title,
    this.body,
    required this.scheduledDate,
    required this.notificationDetails,
    this.payload,
  });
}

/// Fake adapter for fast, deterministic unit and widget testing.
class FakeNotificationPluginAdapter implements NotificationPluginAdapter {
  final Map<int, FakeScheduledNotification> scheduledNotifications = {};
  bool isInitialized = false;
  bool permissionsRequested = false;
  bool permissionsGranted = true;
  DidReceiveNotificationResponseCallback? onNotificationResponse;
  NotificationAppLaunchDetails? launchDetails;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    isInitialized = true;
    onNotificationResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<bool?> requestPermissions() async {
    permissionsRequested = true;
    return permissionsGranted;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  }) async {
    scheduledNotifications[id] = FakeScheduledNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    scheduledNotifications.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduledNotifications.clear();
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return scheduledNotifications.values
        .map(
          (s) => PendingNotificationRequest(
            s.id,
            s.title,
            s.body,
            s.payload,
          ),
        )
        .toList();
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    return launchDetails;
  }

  void simulateNotificationTap(String payload) {
    onNotificationResponse?.call(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      ),
    );
  }
}

/// Service managing local document expiration notifications.
class NotificationService {
  static NotificationService? _instance;

  static NotificationService get instance =>
      _instance ??= NotificationService();

  @visibleForTesting
  static void setInstance(NotificationService? service) {
    _instance = service;
  }

  final NotificationPluginAdapter _adapter;
  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _hasRequestedPermission = false;
  void Function(String documentId)? _onDocumentTap;
  String? _pendingDocumentId;

  static const String documentChannelId = 'document_expiration_channel';
  static const String documentChannelName = 'Document Expiration Reminders';
  static const String documentChannelDescription =
      'Reminders for documents that are expiring soon or have expired.';

  NotificationService({NotificationPluginAdapter? adapter})
      : _adapter = adapter ?? FlutterLocalNotificationsAdapter();

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  String? get pendingDocumentId => _pendingDocumentId;

  /// Sets the pending document ID for delayed navigation (e.g. during cold start).
  void setPendingDocumentId(String? documentId) {
    _pendingDocumentId = documentId;
  }

  /// Consumes and clears any pending document ID.
  String? consumePendingDocumentId() {
    final id = _pendingDocumentId;
    _pendingDocumentId = null;
    return id;
  }

  /// Configures and initializes local notification scheduling.
  Future<void> initialize({
    void Function(String documentId)? onDocumentTap,
  }) async {
    _onDocumentTap = onDocumentTap;

    _ensureTimezoneInitialized();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _adapter.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          handleNotificationTap(payload);
        }
      },
    );

    _isInitialized = true;

    // Check if the app was launched by tapping a notification
    final launchDetails = await _adapter.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload != null) {
      final payload = launchDetails!.notificationResponse!.payload!;
      if (payload.isNotEmpty) {
        handleNotificationTap(payload);
      }
    }
  }

  void _ensureTimezoneInitialized() {
    try {
      tz.initializeTimeZones();
      final localName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        // Fallback to UTC if timezone name is an abbreviation or not found
      }
    } catch (_) {
      // Timezone initialization safety catch
    }
  }

  /// Requests notification permission once without spamming the user.
  Future<bool> requestPermissionsIfNeeded() async {
    if (_hasRequestedPermission) return true;
    _hasRequestedPermission = true;
    try {
      final granted = await _adapter.requestPermissions();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enables or disables expiration reminders. When disabled, cancels all scheduled reminders.
  Future<void> setEnabled(bool enabled, {List<DocumentItem>? currentDocuments}) async {
    _isEnabled = enabled;
    if (!enabled) {
      await cancelAll();
    } else if (currentDocuments != null && currentDocuments.isNotEmpty) {
      await reconcileDocumentReminders(currentDocuments);
    }
  }

  /// Calculates a stable, deterministic 32-bit positive integer ID for a document reminder.
  static int notificationIdFor(String documentId, int reminderCode) {
    var hash = 0x811c9dc5;
    for (final unit in documentId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    hash ^= (reminderCode * 0x45d9f3b);
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
    return hash;
  }

  /// Computes the valid, upcoming expiration reminders for [document].
  ///
  /// Reminders occurring in the past relative to [now] are excluded.
  List<DocumentReminder> calculateReminders(DocumentItem document, {DateTime? now}) {
    final expiry = document.expiryDate;
    if (expiry == null) return const [];

    final current = now ?? DateTime.now();
    final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
    final reminders = <DocumentReminder>[];

    for (final type in DocumentReminderType.values) {
      final scheduledDate = expiryDate.subtract(Duration(days: type.daysBefore));
      // Schedule reminder for 9:00 AM local time on target day
      final scheduledAt = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9,
        0,
      );

      // Past notification times must never be scheduled
      if (scheduledAt.isBefore(current)) {
        continue;
      }

      final id = notificationIdFor(document.id, type.code);
      final title = switch (type) {
        DocumentReminderType.expiredDayOf => 'Document expired',
        DocumentReminderType.expiringSoon30Days => 'Document expiring soon',
        DocumentReminderType.expiringSoon7Days => 'Document expiring soon',
      };

      final body = switch (type) {
        DocumentReminderType.expiredDayOf => 'Your ${document.title} expired today.',
        DocumentReminderType.expiringSoon30Days =>
          'Your ${document.title} expires in 30 days.',
        DocumentReminderType.expiringSoon7Days =>
          'Your ${document.title} expires in 7 days.',
      };

      reminders.add(
        DocumentReminder(
          id: id,
          documentId: document.id,
          type: type,
          title: title,
          body: body,
          scheduledAt: scheduledAt,
          payload: document.id,
        ),
      );
    }

    return reminders;
  }

  /// Schedules all upcoming expiration reminders for [document].
  Future<void> scheduleDocumentReminders(
    DocumentItem document, {
    DateTime? now,
  }) async {
    if (!_isInitialized || !_isEnabled || document.expiryDate == null) return;

    // Cancel old reminders first to ensure clean state
    await cancelDocumentReminders(document.id);

    final reminders = calculateReminders(document, now: now);
    if (reminders.isEmpty) return;

    // Request permissions if not yet requested
    await requestPermissionsIfNeeded();

    const androidDetails = AndroidNotificationDetails(
      documentChannelId,
      documentChannelName,
      channelDescription: documentChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    for (final reminder in reminders) {
      final scheduledTZ = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
      await _adapter.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        scheduledTZ,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.payload,
      );
    }
  }

  /// Cancels all scheduled expiration reminders for [documentId].
  Future<void> cancelDocumentReminders(String documentId) async {
    if (!_isInitialized) return;
    for (final type in DocumentReminderType.values) {
      final id = notificationIdFor(documentId, type.code);
      await _adapter.cancel(id);
    }
  }

  /// Reconciles all document reminders against the provided list of documents.
  ///
  /// Cancels orphaned or changed reminders and schedules missing reminders.
  Future<void> reconcileDocumentReminders(
    List<DocumentItem> documents, {
    DateTime? now,
  }) async {
    if (!_isInitialized || !_isEnabled) return;

    // For every document, refresh its reminders
    for (final doc in documents) {
      if (doc.expiryDate != null) {
        await scheduleDocumentReminders(doc, now: now);
      } else {
        await cancelDocumentReminders(doc.id);
      }
    }
  }

  /// Cancels all scheduled notifications across the app.
  Future<void> cancelAll() async {
    if (!_isInitialized) return;
    await _adapter.cancelAll();
  }

  /// Handles user tapping a notification.
  void handleNotificationTap(String payload) {
    if (_onDocumentTap != null) {
      _onDocumentTap!(payload);
    } else {
      _pendingDocumentId = payload;
    }
  }

  /// Opens the document details sheet for [documentId] if found, or displays a friendly error.
  void openDocumentById(String documentId) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) {
      _pendingDocumentId = documentId;
      return;
    }

    final docProv = context.read<DocumentProvider>();
    if (!docProv.hasFetched && docProv.isLoading) {
      _pendingDocumentId = documentId;
      return;
    }

    final document =
        docProv.documents.where((d) => d.id == documentId).firstOrNull;

    if (document != null) {
      showDocumentDetailsSheet(context, document: document);
    } else {
      showAppSnackBar(
        context,
        'That document couldn\'t be found.',
        isError: true,
      );
    }
  }
}
