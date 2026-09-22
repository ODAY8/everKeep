import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../routing/app_router.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/trusted_contact_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vault_provider.dart';

/// Keeps the app's providers consistent with who is signed in.
///
/// - On sign-in it hands the authenticated user to [UserProvider] and loads
///   everything the dashboard shows.
/// - On sign-out it resets every user-scoped provider, so the next person to
///   sign in on this device can't see the previous user's data.
/// - It feeds live document/account counts into [VaultProvider] so the vault
///   totals match the lists they summarise.
///
/// A plain class (no widgets) so it can be unit-tested; [SessionSync] wires
/// it into the tree.
class SessionCoordinator {
  final AuthProvider auth;
  final UserProvider user;
  final VaultProvider vault;
  final DocumentProvider documents;
  final AccountProvider accounts;
  final TrustedContactProvider contacts;
  final SettingsProvider settings;

  /// Called once when the user arrives from a password-reset email link, so the
  /// app can show the "choose a new password" screen.
  final VoidCallback? onPasswordRecovery;

  bool _wasAuthenticated;
  bool _recoveryHandled = false;

  SessionCoordinator({
    required this.auth,
    required this.user,
    required this.vault,
    required this.documents,
    required this.accounts,
    required this.contacts,
    required this.settings,
    this.onPasswordRecovery,
  }) : _wasAuthenticated = auth.isAuthenticated {
    auth.addListener(_onAuthChanged);
    documents.addListener(_syncVaultCounts);
    accounts.addListener(_syncVaultCounts);
    contacts.addListener(_syncVaultCounts);
    if (_wasAuthenticated) _onSignedIn();
  }

  void dispose() {
    auth.removeListener(_onAuthChanged);
    documents.removeListener(_syncVaultCounts);
    accounts.removeListener(_syncVaultCounts);
    contacts.removeListener(_syncVaultCounts);
  }

  void _onAuthChanged() {
    if (auth.recoveryPending) {
      if (!_recoveryHandled) {
        _recoveryHandled = true;
        onPasswordRecovery?.call();
      }
    } else {
      _recoveryHandled = false;
    }

    final isAuthenticated = auth.isAuthenticated;
    if (isAuthenticated == _wasAuthenticated) return;
    _wasAuthenticated = isAuthenticated;

    if (isAuthenticated) {
      _onSignedIn();
    } else {
      _onSignedOut();
    }
  }

  void _onSignedIn() {
    // Show the signed-in identity straight away (id, email and the name given
    // at sign-up come with the session), then load the real profile row, which
    // may hold a newer name, phone and avatar.
    user.setUser(auth.currentUser);

    // Each provider catches its own errors, so these are safe to fire and
    // forget; screens show a retry if one fails.
    unawaited(user.fetchUserProfile());
    unawaited(vault.fetchVaultSummary());
    unawaited(settings.fetchSecuritySettings());
    unawaited(documents.fetchDocuments());
    unawaited(accounts.fetchAccounts());
    unawaited(contacts.fetchContacts());
  }

  void _onSignedOut() {
    user.reset();
    vault.reset();
    documents.reset();
    accounts.reset();
    contacts.reset();
    settings.reset();
  }

  void _syncVaultCounts() {
    vault.updateLiveCounts(
      documents: documents.hasFetched ? documents.count : null,
      accounts: accounts.hasFetched ? accounts.count : null,
      banking: accounts.hasFetched ? accounts.bankingCount : null,
      contacts: contacts.hasFetched ? contacts.count : null,
    );
  }
}

/// Owns a [SessionCoordinator] for the lifetime of the app. Place it below
/// the providers it coordinates.
class SessionSync extends StatefulWidget {
  final Widget child;

  const SessionSync({super.key, required this.child});

  @override
  State<SessionSync> createState() => _SessionSyncState();
}

class _SessionSyncState extends State<SessionSync> {
  late final SessionCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = SessionCoordinator(
      auth: context.read<AuthProvider>(),
      user: context.read<UserProvider>(),
      vault: context.read<VaultProvider>(),
      documents: context.read<DocumentProvider>(),
      accounts: context.read<AccountProvider>(),
      contacts: context.read<TrustedContactProvider>(),
      settings: context.read<SettingsProvider>(),
      onPasswordRecovery: () => AppRouter.navigatorKey.currentState?.pushNamed(
        AppRouter.resetPassword,
      ),
    );
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
