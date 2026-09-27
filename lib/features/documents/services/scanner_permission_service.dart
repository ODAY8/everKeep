import 'package:permission_handler/permission_handler.dart';

/// Camera permission state for document scanner.
enum ScannerPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unsupported;

  bool get isGranted => this == ScannerPermissionStatus.granted;
}

abstract class ScannerPermissionService {
  Future<ScannerPermissionStatus> checkPermission();
  Future<ScannerPermissionStatus> requestPermission();
  Future<bool> openSettings();
}

class ScannerPermissionServiceImpl implements ScannerPermissionService {
  const ScannerPermissionServiceImpl();

  @override
  Future<ScannerPermissionStatus> checkPermission() async {
    try {
      final status = await Permission.camera.status;
      return _mapStatus(status);
    } catch (_) {
      return ScannerPermissionStatus.unsupported;
    }
  }

  @override
  Future<ScannerPermissionStatus> requestPermission() async {
    try {
      final status = await Permission.camera.request();
      return _mapStatus(status);
    } catch (_) {
      return ScannerPermissionStatus.unsupported;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  ScannerPermissionStatus _mapStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return ScannerPermissionStatus.granted;
      case PermissionStatus.denied:
        return ScannerPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return ScannerPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return ScannerPermissionStatus.restricted;
      case PermissionStatus.provisional:
        return ScannerPermissionStatus.granted;
    }
  }
}
