import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in the browser / mail app / viewer that handles it. Returns
/// false if nothing on the device can (or the launch fails) so the caller can
/// tell the user, instead of a tap that silently does nothing.
Future<bool> openExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
