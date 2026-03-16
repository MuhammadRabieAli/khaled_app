import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';

class ManagementTab extends StatelessWidget {
  const ManagementTab({super.key});

  Future<void> _uploadExcel(BuildContext context) async {
    // Request storage permission if needed (Android < 13)
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) return;
        }
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final excelService = Provider.of<ExcelService>(context, listen: false);
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      if (!context.mounted) return;

      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        final records = await excelService.importExcel(file);

        await dbService.clearAllData();
        await dbService.addRecords(records);

        if (!context.mounted) return;
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استيراد البيانات بنجاح')),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Hide loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خطأ'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _exportExcel(BuildContext context) async {
    // 1. Get all records
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final excelService = Provider.of<ExcelService>(context, listen: false);

    final records = await dbService.getAllRecords();
    if (records.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للتصدير')));
      return;
    }

    try {
      final fileBytes = await excelService.exportExcel(records);

      // 2. Save File
      // On Android, bytes are required for saveFile to work (it writes the file)
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان الحفظ',
        fileName: 'data_export.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
        bytes: Uint8List.fromList(fileBytes),
      );

      if (outputFile != null) {
        // Use the returned path (if valid) or assume it's saved if on Android with bytes provided
        // However, file_picker might not write it on all platforms even if bytes are passed?
        // Documentation says: "If bytes are provided, the file will be saved and the path returned."
        // But let's be safe: if path is returned, check if it exists or needs writing.
        // Actually, on Android, saveFile with bytes DOES write it.
        // But on Desktop, it might just return the path.
        // To be safe and support both:
        // If the file at `outputFile` doesn't exist or is empty (and we are not on Android/iOS where we trust the picker wrote it?), write it.
        // BUT, simplified approach:
        // On Android, we passed bytes, so it should be written.
        // On other platforms, if we want to write it manually, we can.
        // Existing code wrote it manually: `await file.writeAsBytes(fileBytes);`
        // If we write it again, it's fine unless it's a stream/content URI issue.
        // The safest fix for "bytes required on android" is just to pass bytes.
        // The existing write logic `await file.writeAsBytes(fileBytes)` might fail if `outputFile` is a content URI or not a direct path?
        // `saveFile` returns a string path.

        final file = File(outputFile);
        if (!Platform.isAndroid) {
          await file.writeAsBytes(fileBytes);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تصدير الملف بنجاح')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
    }
  }

  Future<void> _deleteData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text(
          'هل أنت متأكد من حذف جميع البيانات؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.clearAllData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف جميع البيانات')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
            child: Text(
              'لوحة التحكم',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildDashboardCard(
                  context,
                  title: 'استيراد',
                  subtitle: 'ملف إكسل بصيغة .xlsx',
                  icon: Icons.upload_file,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  iconColor: Theme.of(context).colorScheme.primary,
                  onTap: () => _uploadExcel(context),
                ),
                const SizedBox(height: 16),
                _buildDashboardCard(
                  context,
                  title: 'تصدير',
                  subtitle: 'تصدير قاعدة البيانات الحالية',
                  icon: Icons.download,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  iconColor: Theme.of(context).colorScheme.secondary,
                  onTap: () => _exportExcel(context),
                ),
                const SizedBox(height: 16),
                _buildDashboardCard(
                  context,
                  title: 'حذف الكل',
                  subtitle: 'مسح جميع البيانات من الجهاز',
                  icon: Icons.delete_forever,
                  color: Theme.of(context).colorScheme.errorContainer,
                  iconColor: Theme.of(context).colorScheme.error,
                  onTap: () => _deleteData(context),
                  isDestructive: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تعليمات هامة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionItem(
                  context,
                  'ملف الإكسل يجب أن يكون بصيغة .xlsx',
                ),
                _buildInstructionItem(
                  context,
                  'سيتم حذف البيانات القديمة عند الاستيراد.',
                ),
                const SizedBox(height: 16),
                Text(
                  'ترتيب الأعمدة في ملف الإكسل:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructionItem(context, '1. التاريخ'),
                _buildInstructionItem(context, '2. رقم البون'),
                _buildInstructionItem(context, '3. المقاول أو البيان'),
                _buildInstructionItem(context, '4. لودر التحميل'),
                _buildInstructionItem(context, '5. اسم السائق'),
                _buildInstructionItem(context, '6. رقم الوش'),
                _buildInstructionItem(context, '7. المقطورة'),
                _buildInstructionItem(context, '8. تكعيب'),
                _buildInstructionItem(context, '9. المبلغ'),
                _buildInstructionItem(context, '10. ملاحظات'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDestructive
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
