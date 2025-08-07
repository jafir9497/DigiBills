import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/warranty_controller.dart';
import '../../models/warranty.dart';

class WarrantyListScreen extends StatelessWidget {
  const WarrantyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final warrantyController = Get.put(WarrantyController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranties'),
        actions: [
          IconButton(
            onPressed: warrantyController.refreshWarranties,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          _buildStatisticsCards(warrantyController),
          
          // Filters
          _buildFilters(warrantyController),
          
          // Warranty List
          Expanded(
            child: _buildWarrantyList(warrantyController),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/warranty/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Warranty'),
      ),
    );
  }

  Widget _buildStatisticsCards(WarrantyController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final stats = controller.statistics;
        if (stats == null) return const SizedBox.shrink();

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total',
                    value: stats.totalWarranties.toString(),
                    icon: Icons.shield,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Active',
                    value: stats.activeWarranties.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Expiring Soon',
                    value: stats.expiringSoonWarranties.toString(),
                    icon: Icons.warning,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Expired',
                    value: stats.expiredWarranties.toString(),
                    icon: Icons.expired,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(WarrantyController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              return DropdownButtonFormField<String>(
                value: controller.selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: controller.getCategoryOptions().map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.setSelectedCategory(value);
                  }
                },
              );
            }),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Obx(() {
              return DropdownButtonFormField<String>(
                value: controller.selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: controller.getStatusOptions().map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.setSelectedStatus(value);
                  }
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyList(WarrantyController controller) {
    return Obx(() {
      if (controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final warranties = controller.getFilteredWarranties();

      if (warranties.isEmpty) {
        return _buildEmptyState();
      }

      return RefreshIndicator(
        onRefresh: controller.refreshWarranties,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: warranties.length,
          itemBuilder: (context, index) {
            final warranty = warranties[index];
            return _buildWarrantyCard(warranty, controller);
          },
        ),
      );
    });
  }

  Widget _buildWarrantyCard(Warranty warranty, WarrantyController controller) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Get.toNamed('/warranty/details', arguments: {'warranty': warranty}),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warranty.productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (warranty.brand != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            warranty.brand!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: warranty.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: warranty.statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      warranty.status.displayName,
                      style: TextStyle(
                        color: warranty.statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expires: ${warranty.formattedWarrantyEndDate}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    warranty.formattedDaysUntilExpiry,
                    style: TextStyle(
                      color: warranty.statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (warranty.category != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      warranty.category!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Get.toNamed(
                      '/warranty/edit',
                      arguments: {'warranty': warranty},
                    ),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  if (warranty.claimStatus == ClaimStatus.none)
                    TextButton.icon(
                      onPressed: () => _showClaimDialog(warranty, controller),
                      icon: const Icon(Icons.report_problem, size: 16),
                      label: const Text('Claim'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showDeleteDialog(warranty, controller),
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No warranties found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first warranty to get started',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/warranty/add'),
            icon: const Icon(Icons.add),
            label: const Text('Add Warranty'),
          ),
        ],
      ),
    );
  }

  void _showClaimDialog(Warranty warranty, WarrantyController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('File Warranty Claim'),
        content: Text(
          'Would you like to file a warranty claim for ${warranty.productName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.updateWarrantyClaim(
                warrantyId: warranty.id,
                claimStatus: ClaimStatus.pending,
                claimDetails: WarrantyClaim(
                  claimNumber: 'CLM-${DateTime.now().millisecondsSinceEpoch}',
                  claimDate: DateTime.now(),
                  issueDescription: 'Warranty claim filed through Digi Bills',
                ),
              );
            },
            child: const Text('File Claim'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Warranty warranty, WarrantyController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Warranty'),
        content: Text(
          'Are you sure you want to delete the warranty for ${warranty.productName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteWarranty(warranty.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}