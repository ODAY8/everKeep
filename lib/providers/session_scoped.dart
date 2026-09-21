import 'package:flutter/foundation.dart';

/// Strips the `Exception: ` prefix so a thrown error reads as a UI message.
String errorMessage(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

/// Lets a provider discard async results that resolve after [invalidateSession]
/// (called from each provider's `reset()` on sign-out).
///
/// Capture [sessionEpoch] before an `await` and bail out with [isStale] after
/// it — otherwise a request started by the previous user could land in the
/// next user's state.
mixin SessionScoped on ChangeNotifier {
  int _sessionEpoch = 0;

  int get sessionEpoch => _sessionEpoch;

  bool isStale(int epoch) => epoch != _sessionEpoch;

  @protected
  void invalidateSession() => _sessionEpoch++;
}
