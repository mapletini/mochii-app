import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../data/audit_log_repository.dart';
import '../services/trust_fall_service.dart';

class TrustFallScreen extends StatefulWidget {
  const TrustFallScreen({required this.trustFallService, super.key});

  final TrustFallService trustFallService;

  @override
  State<TrustFallScreen> createState() => _TrustFallScreenState();
}

class _TrustFallScreenState extends State<TrustFallScreen> {
  final AuditLogRepository _auditLogRepository = AuditLogRepository();

  CameraController? _cameraController;
  Future<void>? _cameraInitialization;
  XFile? _capturedPhoto;

  bool _isUploading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _cameraInitialization = _initializeCamera();
    _retryPendingUploads(silent: true);
  }

  Future<void> _initializeCamera() async {
    final List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No camera available on this device.');
    }

    final CameraController controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
    });
  }

  Future<void> _capturePhoto() async {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final XFile photo = await controller.takePicture();
    if (!mounted) {
      return;
    }

    setState(() {
      _capturedPhoto = photo;
      _statusMessage = null;
    });
  }

  Future<void> _submitPhoto() async {
    final XFile? captured = _capturedPhoto;
    if (captured == null) {
      return;
    }

    final int auditId = await _auditLogRepository.addPendingTrustFall(
      imagePath: captured.path,
    );

    setState(() {
      _isUploading = true;
      _statusMessage = null;
    });

    final bool success = await widget.trustFallService.uploadTrustFall(
      File(captured.path),
    );

    if (success) {
      await _auditLogRepository.markUploaded(auditId);
    } else {
      await _auditLogRepository.markUploadAttemptFailed(
        auditId,
        error: 'Initial upload attempt failed',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = false;
      _statusMessage = success
          ? 'Trust Fall submitted successfully.'
          : 'Upload failed. Saved locally and queued for retry.';
    });
  }

  Future<void> _retryPendingUploads({bool silent = false}) async {
    final List<AuditLog> pendingLogs = await _auditLogRepository.getPendingLogs(
      actionType: 'trust_fall',
    );

    if (pendingLogs.isEmpty) {
      if (!mounted || silent) {
        return;
      }

      setState(() {
        _statusMessage = 'No pending uploads.';
      });
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _isUploading = true;
        _statusMessage = 'Retrying ${pendingLogs.length} pending upload(s)...';
      });
    }

    int uploadedCount = 0;

    for (final AuditLog log in pendingLogs) {
      final int? auditId = log.id;
      final String? imagePath = log.imagePath;

      if (auditId == null || imagePath == null || imagePath.isEmpty) {
        continue;
      }

      final File imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        await _auditLogRepository.markUploadAttemptFailed(
          auditId,
          error: 'Missing file at $imagePath',
        );
        continue;
      }

      final bool success = await widget.trustFallService.uploadTrustFall(
        imageFile,
        timestamp: log.timestamp,
      );

      if (success) {
        await _auditLogRepository.markUploaded(auditId);
        uploadedCount += 1;
      } else {
        await _auditLogRepository.markUploadAttemptFailed(
          auditId,
          error: 'Retry upload failed',
        );
      }
    }

    if (!mounted || silent) {
      return;
    }

    setState(() {
      _isUploading = false;
      _statusMessage = uploadedCount > 0
          ? 'Uploaded $uploadedCount pending item(s).'
          : 'Pending uploads remain. Will retry later.';
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trust Fall')),
      body: FutureBuilder<void>(
        future: _cameraInitialization,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Camera initialization failed: ${snapshot.error}'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _capturedPhoto == null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CameraPreview(_cameraController!),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_capturedPhoto!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isUploading ? null : _capturePhoto,
                  child: const Text('Capture Cage Photo'),
                ),
                if (_capturedPhoto != null) ...<Widget>[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _submitPhoto,
                    child: _isUploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Verifying...'),
                            ],
                          )
                        : const Text('Submit'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isUploading
                      ? null
                      : () {
                          _retryPendingUploads();
                        },
                  child: const Text('Retry Pending Uploads'),
                ),
                if (_statusMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_statusMessage!, textAlign: TextAlign.center),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
