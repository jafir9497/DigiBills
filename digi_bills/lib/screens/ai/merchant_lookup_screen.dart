import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_controller.dart';
import '../../services/ai_service.dart';

class MerchantLookupScreen extends StatelessWidget {
  const MerchantLookupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final aiController = Get.put(AIController());
    final merchantNameController = TextEditingController();
    final websiteUrlController = TextEditingController();
    final brandController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Customer Care Lookup'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Status Card
            _buildAIStatusCard(aiController),
            
            const SizedBox(height: 20),
            
            // Search Form
            _buildSearchForm(
              context,
              aiController,
              merchantNameController,
              websiteUrlController,
              brandController,
            ),
            
            const SizedBox(height: 20),
            
            // Results Section
            Obx(() {
              if (aiController.isLoading) {
                return _buildLoadingSection();
              }
              
              if (aiController.contactMethods.isEmpty && 
                  aiController.currentMerchantInfo == null) {
                return _buildEmptyState();
              }
              
              return Column(
                children: [
                  // Merchant Info Section
                  if (aiController.currentMerchantInfo != null)
                    _buildMerchantInfoSection(aiController),
                  
                  const SizedBox(height: 16),
                  
                  // Contact Methods Section
                  if (aiController.contactMethods.isNotEmpty)
                    _buildContactMethodsSection(aiController),
                  
                  const SizedBox(height: 16),
                  
                  // Warranty Info Section
                  if (aiController.currentWarrantyInfo != null)
                    _buildWarrantyInfoSection(aiController),
                ];
              );
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInsightsDialog(context, aiController),
        icon: const Icon(Icons.psychology),
        label: const Text('AI Insights'),
      ),
    );
  }

  Widget _buildAIStatusCard(AIController aiController) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  aiController.isAIAvailable ? Icons.check_circle : Icons.warning,
                  color: aiController.isAIAvailable ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Service Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() => Text(
              aiController.aiAvailabilityStatus,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            )),
            if (!aiController.isAIAvailable) ...[
              const SizedBox(height: 8),
              Text(
                'Configure Firecrawl and OpenRouter API keys in app settings to enable full AI features.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchForm(
    BuildContext context,
    AIController aiController,
    TextEditingController merchantNameController,
    TextEditingController websiteUrlController,
    TextEditingController brandController,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search for Merchant Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Merchant Name Field
            TextFormField(
              controller: merchantNameController,
              decoration: const InputDecoration(
                labelText: 'Merchant/Company Name *',
                hintText: 'e.g., Best Buy, Amazon, Apple Store',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: aiController.setSearchQuery,
            ),
            
            const SizedBox(height: 16),
            
            // Website URL Field (Optional)
            TextFormField(
              controller: websiteUrlController,
              decoration: const InputDecoration(
                labelText: 'Website URL (Optional)',
                hintText: 'https://www.company.com',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: aiController.setWebsiteUrl,
            ),
            
            const SizedBox(height: 16),
            
            // Brand Field (Optional)
            TextFormField(
              controller: brandController,
              decoration: const InputDecoration(
                labelText: 'Product Brand (Optional)',
                hintText: 'e.g., Samsung, Dell, Nike',
                prefixIcon: Icon(Icons.branding_watermark),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: 20),
            
            // Search Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (merchantNameController.text.trim().isEmpty) {
                        Get.snackbar(
                          'Required Field',
                          'Please enter a merchant name',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      
                      aiController.searchMerchantInfo(
                        merchantNameController.text.trim(),
                        websiteUrl: websiteUrlController.text.trim().isEmpty 
                            ? null 
                            : websiteUrlController.text.trim(),
                        brand: brandController.text.trim().isEmpty 
                            ? null 
                            : brandController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search Contact Info'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (websiteUrlController.text.trim().isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      aiController.extractMerchantFromWebsite(
                        websiteUrlController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.web),
                    label: const Text('Extract'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Clear Button
            TextButton.icon(
              onPressed: () {
                merchantNameController.clear();
                websiteUrlController.clear();
                brandController.clear();
                aiController.clearData();
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'AI is analyzing merchant information...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This may take a few moments',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No merchant information found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a merchant name above to search for customer support contact information',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantInfoSection(AIController aiController) {
    final merchantInfo = aiController.currentMerchantInfo!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Merchant Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Merchant Name
            _buildInfoRow('Company', merchantInfo.merchantName, Icons.store),
            
            // Website
            if (merchantInfo.website.isNotEmpty)
              _buildInfoRow('Website', merchantInfo.website, Icons.link),
            
            // Support Hours
            if (merchantInfo.supportHours != null)
              _buildInfoRow('Support Hours', merchantInfo.supportHours!, Icons.schedule),
            
            // Warranty Support
            Row(
              children: [
                Icon(
                  merchantInfo.warrantySupport ? Icons.shield : Icons.shield_outlined,
                  color: merchantInfo.warrantySupport ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Warranty Support: ${merchantInfo.warrantySupport ? 'Available' : 'Not Available'}',
                  style: TextStyle(
                    color: merchantInfo.warrantySupport ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            // Categories
            if (merchantInfo.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: merchantInfo.categories.map((category) {
                  return Chip(
                    label: Text(category),
                    backgroundColor: Theme.of(Get.context!).primaryColor.withOpacity(0.1),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethodsSection(AIController aiController) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_support, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Contact Methods',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${aiController.contactMethods.length} found',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ...aiController.contactMethods.map((contact) {
              return _buildContactMethodTile(contact, aiController);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethodTile(ContactMethod contact, AIController aiController) {
    IconData iconData;
    Color iconColor;
    
    switch (contact.type.toLowerCase()) {
      case 'phone':
        iconData = Icons.phone;
        iconColor = Colors.blue;
        break;
      case 'email':
        iconData = Icons.email;
        iconColor = Colors.orange;
        break;
      case 'chat':
        iconData = Icons.chat;
        iconColor = Colors.green;
        break;
      case 'form':
        iconData = Icons.contact_page;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.contact_support;
        iconColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(iconData, color: iconColor),
        title: Text(
          contact.label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(contact.value),
        trailing: IconButton(
          icon: const Icon(Icons.launch),
          onPressed: () => aiController.launchContactMethod(contact),
          tooltip: 'Contact via ${contact.label}',
        ),
        onTap: () => aiController.launchContactMethod(contact),
      ),
    );
  }

  Widget _buildWarrantyInfoSection(AIController aiController) {
    final warrantyInfo = aiController.currentWarrantyInfo!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Warranty Claim Process',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Warranty Period and Coverage
            if (warrantyInfo.warrantyPeriod != null)
              _buildInfoRow('Warranty Period', warrantyInfo.warrantyPeriod!, Icons.schedule),
            
            if (warrantyInfo.coverage != null)
              _buildInfoRow('Coverage', warrantyInfo.coverage!, Icons.security),
            
            // Claim Steps
            if (warrantyInfo.claimProcess.steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Claim Process Steps:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...warrantyInfo.claimProcess.steps.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(Get.context!).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            // Required Documents
            if (warrantyInfo.claimProcess.requiredDocuments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Required Documents:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: warrantyInfo.claimProcess.requiredDocuments.map((doc) {
                  return Chip(
                    label: Text(doc),
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    avatar: const Icon(Icons.description, size: 16),
                  );
                }).toList(),
              ),
            ],
            
            // Timeframe
            if (warrantyInfo.claimProcess.timeframe != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow('Processing Time', warrantyInfo.claimProcess.timeframe!, Icons.timer),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showInsightsDialog(BuildContext context, AIController aiController) {
    if (aiController.currentInsights == null) {
      Get.snackbar(
        'No Insights',
        'No AI insights available. Search for a merchant first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Insights',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView(
                  children: aiController.getFormattedInsights().map((insight) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  insight['icon'],
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  insight['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...((insight['items'] as List<String>).map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontSize: 16)),
                                    Expanded(child: Text(item, style: const TextStyle(fontSize: 14))),
                                  ],
                                ),
                              );
                            }).toList()),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}