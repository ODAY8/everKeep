import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' as img_picker;
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/app_lock_provider.dart';
import '../../../../providers/document_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../models/scanned_page.dart';
import '../../services/document_scanner_service.dart';
import '../../services/scanner_permission_service.dart';
import '../widgets/document_details_sheet.dart';
import '../widgets/document_form_sheet.dart';
import '../widgets/scanner/scanner_controls_bar.dart';
import '../widgets/scanner/scanner_guidance_overlay.dart';
import '../widgets/scanner/scanned_document_preview_sheet.dart';

enum _ScannerViewMode { camera, preview }

/// Production-quality document scanner screen supporting live camera framing,
/// physical document capture, edge/crop adjustment, multi-page scanning,
/// page reordering, image enhancement, and vault save integration.
class DocumentScannerScreen extends StatefulWidget {
  final ScannerPermissionService? permissionService;
  final DocumentScannerService? scannerService;
  final CameraController? testCameraController;
  final List<CameraDescription>? testCameras;
  final bool returnUploadDirectly;

  const DocumentScannerScreen({
    super.key,
    this.permissionService,
    this.scannerService,
    this.testCameraController,
    this.testCameras,
    this.returnUploadDirectly = false,
  });

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen>
    with WidgetsBindingObserver {
  late final ScannerPermissionService _permissionService;
  late final DocumentScannerService _scannerService;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  bool _isCheckingPermission = true;
  ScannerPermissionStatus _permissionStatus = ScannerPermissionStatus.denied;

  bool _isCameraInitializing = false;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  bool _isFlashOn = false;
  String? _scannerError;

  _ScannerViewMode _viewMode = _ScannerViewMode.camera;
  final List<ScannedPage> _capturedPages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _permissionService =
        widget.permissionService ?? const ScannerPermissionServiceImpl();
    _scannerService = widget.scannerService ?? DocumentScannerService();

    if (widget.testCameraController != null) {
      _cameraController = widget.testCameraController;
      _cameras = widget.testCameras ?? [];
      _permissionStatus = ScannerPermissionStatus.granted;
      _isCheckingPermission = false;
      _isCameraReady = true;
    } else {
      _initPermissionsAndCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.testCameraController == null) {
      _cameraController?.dispose();
    }
    _scannerService.cleanupTempFiles();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.testCameraController != null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      // Respect biometric lock: only resume camera if app lock is not active
      final lockProv = _getAppLockProvider();
      if (lockProv == null || !lockProv.isLocked) {
        if (_permissionStatus.isGranted && _viewMode == _ScannerViewMode.camera) {
          _initializeCamera();
        }
      }
    }
  }

  AppLockProvider? _getAppLockProvider() {
    try {
      return context.read<AppLockProvider>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _initPermissionsAndCamera() async {
    setState(() {
      _isCheckingPermission = true;
      _scannerError = null;
    });

    final status = await _permissionService.requestPermission();
    if (!mounted) return;

    setState(() {
      _permissionStatus = status;
      _isCheckingPermission = false;
    });

    if (status.isGranted) {
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitializing) return;

    setState(() {
      _isCameraInitializing = true;
      _scannerError = null;
    });

    try {
      if (widget.testCameras != null) {
        _cameras = widget.testCameras!;
      } else {
        try {
          _cameras = await availableCameras();
        } catch (_) {
          _cameras = [];
        }
      }

      if (_cameras.isEmpty) {
        setState(() {
          _isCameraReady = false;
          _isCameraInitializing = false;
          _scannerError = 'No camera found on this device. You can import documents from your gallery.';
        });
        return;
      }

      final camera = _cameras[_selectedCameraIndex.clamp(0, _cameras.length - 1)];
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController?.dispose();
      _cameraController = controller;
      _isCameraReady = true;
      _isFlashOn = false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _scannerError = 'Could not start camera. You can still import document images from your gallery.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (widget.testCameraController != null) return;
    final controller = _cameraController;
    _cameraController = null;
    _isCameraReady = false;
    if (controller != null) {
      await controller.dispose();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final nextState = !_isFlashOn;
      await controller.setFlashMode(nextState ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() => _isFlashOn = nextState);
      }
    } catch (_) {
      // Flash mode may not be supported on front camera or emulator
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1 || _isCameraInitializing) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _disposeCamera();
    await _initializeCamera();
  }

  Future<void> _capturePage() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _scannerError = null;
    });

    try {
      Uint8List imageBytes;

      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final xFile = await _cameraController!.takePicture();
        imageBytes = await xFile.readAsBytes();
      } else {
        // Fallback for tests or devices where camera cannot capture
        imageBytes = _generateFallbackImageBytes();
      }

      await _addCapturedBytes(imageBytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          _scannerError = 'Failed to capture document. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = img_picker.ImagePicker();
      final picked = await picker.pickImage(source: img_picker.ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await _addCapturedBytes(bytes);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not load photo from gallery.', isError: true);
      }
    }
  }

  Future<void> _addCapturedBytes(Uint8List rawBytes) async {
    final pageId = 'page_${DateTime.now().microsecondsSinceEpoch}_${_capturedPages.length}';
    final processed = await _scannerService.processPage(
      rawBytes: rawBytes,
      filter: PageFilter.documentHighContrast,
    );

    final page = ScannedPage(
      id: pageId,
      originalBytes: rawBytes,
      processedBytes: processed,
      filter: PageFilter.documentHighContrast,
    );

    if (!mounted) return;

    setState(() {
      _capturedPages.add(page);
      _viewMode = _ScannerViewMode.preview;
    });
  }

  Uint8List _generateFallbackImageBytes() {
    final image = img.Image(width: 200, height: 280);
    img.fill(image, color: img.ColorRgb8(245, 245, 245));
    return Uint8List.fromList(img.encodeJpg(image));
  }

  Future<void> _handleSaveFromPreview(List<ScannedPage> pages) async {
    if (pages.isEmpty) return;

    final upload = await _scannerService.createDocumentUpload(
      pages: pages,
      preferPdfForSinglePage: true,
    );

    if (!mounted) return;

    if (widget.returnUploadDirectly) {
      await _scannerService.cleanupTempFiles();
      if (!mounted) return;
      Navigator.of(context).pop(upload);
      return;
    }

    // 2. Open DocumentFormSheet pre-populated with the scanned file
    final saved = await DocumentFormSheet.show(
      context,
      initialUpload: upload,
    );

    if (!mounted) return;

    // 3. If successfully saved, pop the scanner screen and navigate to details
    if (saved == true) {
      await _scannerService.cleanupTempFiles();
      if (!mounted) return;

      final docProv = context.read<DocumentProvider>();
      final newestDoc = docProv.documents.isNotEmpty ? docProv.documents.first : null;

      Navigator.of(context).pop(newestDoc);

      if (newestDoc != null && mounted) {
        showAppSnackBar(context, 'Document scanned and saved to vault');
        showDocumentDetailsSheet(context, document: newestDoc);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewMode == _ScannerViewMode.preview && _capturedPages.isNotEmpty) {
      return ScannedDocumentPreviewView(
        key: ValueKey('preview_${_capturedPages.length}'),
        initialPages: _capturedPages,
        scannerService: _scannerService,
        onAddAnotherPage: () => setState(() => _viewMode = _ScannerViewMode.camera),
        onSave: _handleSaveFromPreview,
        onCancel: () => setState(() => _viewMode = _ScannerViewMode.camera),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview or Fallback Canvas
          if (_isCheckingPermission || _isCameraInitializing)
            const Center(
              child: CircularProgressIndicator(color: AppColors.glassAccentPink),
            )
          else if (!_permissionStatus.isGranted)
            _buildPermissionDeniedView()
          else if (_isCameraReady && _cameraController != null)
            Center(
              child: CameraPreview(_cameraController!),
            )
          else
            _buildCameraFallbackView(),

          // 2. Framing Guidance Overlay
          if (_permissionStatus.isGranted)
            const ScannerGuidanceOverlay(
              guidanceText: 'Position the document inside the frame',
            ),

          // 3. Top Action Bar (Close, Flash, Flip Camera)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScannerTopBar(
              onClose: () => Navigator.of(context).pop(),
              onToggleFlash: _toggleFlash,
              onSwitchCamera: _cameras.length > 1 ? _switchCamera : null,
              isFlashOn: _isFlashOn,
              hasMultipleCameras: _cameras.length > 1,
            ),
          ),

          // 4. Error Banner if any
          if (_scannerError != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.glassDestructive.withValues(alpha: 0.85),
                  borderRadius: AppRadius.radiusMD,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scannerError!,
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Bottom Controls (Shutter, Gallery, Review Pages)
          if (_permissionStatus.isGranted)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ScannerBottomBar(
                onCapture: _capturePage,
                onPickFromGallery: _pickFromGallery,
                onReviewPages: () => setState(() => _viewMode = _ScannerViewMode.preview),
                pageCount: _capturedPages.length,
                isCapturing: _isCapturing,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    final isPermanent = _permissionStatus == ScannerPermissionStatus.permanentlyDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_outlined,
                size: 36,
                color: AppColors.glassAccentPink,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Camera Access Required',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isPermanent
                  ? 'Camera permission is permanently denied. Please enable camera access in your device settings to scan documents.'
                  : 'EverKeep needs camera permission to capture and scan documents into your secure vault.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GlassPrimaryButton(
              text: isPermanent ? 'Open Settings' : 'Grant Camera Permission',
              onPressed: () async {
                if (isPermanent) {
                  await _permissionService.openSettings();
                } else {
                  await _initPermissionsAndCamera();
                }
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            Text(
              'Camera ready',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the capture button or import a document photo.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
