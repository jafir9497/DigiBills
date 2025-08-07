import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';

import '../../controllers/camera_controller.dart';
import '../../services/ocr_service.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({super.key});

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final _cameraController = Get.find<CameraController>();
  final _arguments = Get.arguments as Map<String, dynamic>;
  
  late String _imagePath;
  ReceiptOCRResult? _ocrResult;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _imagePath = _arguments['imagePath'] as String;
    _processImage();
  }

  Future<void> _processImage() async {
    try {
      setState(() => _isProcessing = true);
      
      final result = await _cameraController.processReceiptImage(_imagePath);
      
      setState(() {
        _ocrResult = result;
        _isProcessing = false;
      });
      
    } catch (e) {
      setState(() => _isProcessing = false);
      
      Get.snackbar(
        'Processing Error',
        'Failed to process receipt image',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        actions: [
          if (!_isProcessing && _ocrResult != null)
            TextButton(
              onPressed: _navigateToEdit,
              child: const Text('Edit'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview
          Expanded(
            flex: 2,
            child: _buildImagePreview(),
          ),
          
          // Processing/Results Section
          Expanded(
            flex: 3,
            child: _buildResultsSection(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(_imagePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isProcessing
              ? _buildProcessingWidget()
              : _ocrResult != null
                  ? _buildResultsWidget()
                  : _buildErrorWidget(),
        ),
      ),
    );
  }

  Widget _buildProcessingWidget() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Processing receipt...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Extracting text and analyzing content',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsWidget() {
    final result = _ocrResult!;
    final parsedData = result.parsedData;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence Score
          _buildConfidenceIndicator(result.confidence),
          
          const SizedBox(height: 16),
          
          // Extracted Information
          Text(
            'Extracted Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Merchant Name
          if (parsedData.merchantName != null)
            _buildInfoRow('Merchant', parsedData.merchantName!),
          
          // Receipt Number
          if (parsedData.receiptNumber != null)
            _buildInfoRow('Receipt #', parsedData.receiptNumber!),
          
          // Date
          if (parsedData.date != null)
            _buildInfoRow('Date', _formatDate(parsedData.date!)),
          
          // Total Amount
          if (parsedData.totalAmount != null)
            _buildInfoRow('Total', '${parsedData.currency} ${parsedData.totalAmount!.toStringAsFixed(2)}'),
          
          // Tax Amount
          if (parsedData.taxAmount != null)
            _buildInfoRow('Tax', '${parsedData.currency} ${parsedData.taxAmount!.toStringAsFixed(2)}'),
          
          // Items
          if (parsedData.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Items (${parsedData.items.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...parsedData.items.take(3).map((item) => 
              _buildItemRow(item.name, item.price, parsedData.currency)
            ),
            if (parsedData.items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${parsedData.items.length - 3} more items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
          
          const SizedBox(height: 16),
          
          // Raw Text (collapsible)
          ExpansionTile(
            title: const Text('Raw Extracted Text'),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.rawText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Colors.red,
        ),
        SizedBox(height: 16),
        Text(
          'Processing Failed',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.red,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Unable to extract text from the image. Please try again with better lighting.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildConfidenceIndicator(double confidence) {
    final percentage = (confidence * 100).round();
    final color = confidence >= 0.8 
        ? Colors.green 
        : confidence >= 0.6 
            ? Colors.orange 
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confidence >= 0.8 
                ? Icons.check_circle 
                : confidence >= 0.6 
                    ? Icons.warning 
                    : Icons.error,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Confidence: $percentage%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String name, double price, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$currency ${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _cameraController.clearCapture();
                Get.back();
              },
              child: const Text('Retake'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing || _ocrResult == null
                  ? null
                  : _navigateToEdit,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _navigateToEdit() {
    if (_ocrResult != null) {
      Get.toNamed('/receipt/edit', arguments: {
        'imagePath': _imagePath,
        'ocrResult': _ocrResult,
      });
    }
  }
}