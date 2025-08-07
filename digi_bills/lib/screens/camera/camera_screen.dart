import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';

import '../../controllers/camera_controller.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late CameraController _cameraController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraController = Get.put(CameraController());
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (!_cameraController.isCameraInitialized) return;

    if (state == AppLifecycleState.inactive) {
      // Camera inactive
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize camera
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    await _cameraController.initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (!_cameraController.isCameraInitialized) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Initializing camera...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview
            _buildCameraPreview(),
            
            // Camera Controls Overlay
            _buildCameraOverlay(),
            
            // Processing Indicator
            if (_cameraController.isProcessing)
              _buildProcessingOverlay(),
          ],
        );
      }),
    );
  }

  Widget _buildCameraPreview() {
    final cameraController = _cameraController.cameraController;
    if (cameraController == null) return const SizedBox.shrink();

    return CameraPreview(cameraController);
  }

  Widget _buildCameraOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top Controls
          _buildTopControls(),
          
          // Scanning Guide
          Expanded(
            child: _buildScanningGuide(),
          ),
          
          // Bottom Controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
              shape: const CircleBorder(),
            ),
          ),
          
          const Spacer(),
          
          // Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Scan Receipt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Flash Toggle
          Obx(() {
            return IconButton(
              onPressed: _cameraController.toggleFlash,
              icon: Icon(
                _cameraController.isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
                shape: const CircleBorder(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScanningGuide() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Corner indicators
            ...List.generate(4, (index) => _buildCornerIndicator(index)),
            
            // Scanning instructions
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Position receipt within frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerIndicator(int index) {
    final positions = [
      const Alignment(-1, -1), // Top left
      const Alignment(1, -1),  // Top right
      const Alignment(-1, 1),  // Bottom left
      const Alignment(1, 1),   // Bottom right
    ];

    return Align(
      alignment: positions[index],
      child: Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery Button
          _buildControlButton(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () async {
              final imagePath = await _cameraController.pickImageFromGallery();
              if (imagePath != null) {
                _navigateToPreview(imagePath);
              }
            },
          ),
          
          // Capture Button
          _buildCaptureButton(),
          
          // Camera Switch Button
          if (_cameraController.cameras.length > 1)
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              label: 'Flip',
              onTap: _cameraController.switchCamera,
            )
          else
            const SizedBox(width: 64),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.5),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            final imagePath = await _cameraController.capturePhoto();
            if (imagePath != null) {
              _navigateToPreview(imagePath);
            }
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Capture',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPreview(String imagePath) {
    Get.toNamed('/receipt/preview', arguments: {'imagePath': imagePath});
  }
}