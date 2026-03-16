import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/database_service.dart';
import '../providers/ui_provider.dart';
import '../models/record.dart';

class InsertTab extends StatefulWidget {
  const InsertTab({super.key});

  @override
  State<InsertTab> createState() => _InsertTabState();
}

class _InsertTabState extends State<InsertTab> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _receiptNumberController = TextEditingController(); // Added controller
  final _contractorController = TextEditingController();
  final _loaderController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _truckNumberController = TextEditingController();
  final _trailerNumberController = TextEditingController();
  final _cubeController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // Scroll Controllers for Table
  final _tableVerticalController = ScrollController();
  final _tableHorizontalController = ScrollController();

  // Focus Nodes
  final _contractorFocusNode = FocusNode();
  final _driverFocusNode = FocusNode();
  final _truckFocusNode = FocusNode();
  final _trailerFocusNode = FocusNode();

  DateTime? _selectedDate;

  int _lastKnownIndex = 0;

  // Search & Edit Mode State
  List<Record> _searchResults = [];
  Record? _selectedRecord;
  bool _isSearching = false;
  bool _showResultsCount = false;
  DateTime? _searchDate;
  List<String> _driverNames = [];
  List<String> _contractorNames = [];
  List<String> _truckNumbers = [];
  List<String> _trailerNumbers = [];

  @override
  void initState() {
    super.initState();
    _loadDriverNames();
    _loadContractorNames();
    _loadTruckNumbers();
    _loadTrailerNumbers();
    _loadNextReceiptNumber();
  }

  Future<void> _loadNextReceiptNumber() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final nextNumber = await db.getNextReceiptNumber();
    if (mounted && _selectedRecord == null) {
      setState(() {
        _receiptNumberController.text = nextNumber.toString();
      });
    }
  }

  Future<void> _loadDriverNames() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final names = await db.getUniqueDriverNames();
    if (mounted) {
      setState(() {
        _driverNames = names;
      });
    }
  }

  Future<void> _loadContractorNames() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final names = await db.getUniqueContractorNames();
    if (mounted) {
      setState(() {
        _contractorNames = names;
      });
    }
  }

  Future<void> _loadTruckNumbers() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final numbers = await db.getUniqueTruckNumbers();
    if (mounted) {
      setState(() {
        _truckNumbers = numbers;
      });
    }
  }

  Future<void> _loadTrailerNumbers() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final numbers = await db.getUniqueTrailerNumbers();
    if (mounted) {
      setState(() {
        _trailerNumbers = numbers;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uiProvider = Provider.of<UiProvider>(context);
    // If we switched TO this tab (index 0) from another tab, reload
    if (uiProvider.selectedIndex == 0 && _lastKnownIndex != 0) {
      _loadNextReceiptNumber();
    }
    _lastKnownIndex = uiProvider.selectedIndex;
  }

  @override
  void dispose() {
    _receiptNumberController.dispose();
    _contractorController.dispose();
    _loaderController.dispose();
    _driverNameController.dispose();
    _truckNumberController.dispose();
    _trailerNumberController.dispose();
    _cubeController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _tableVerticalController.dispose();
    _tableHorizontalController.dispose();
    _contractorFocusNode.dispose();
    _driverFocusNode.dispose();
    _truckFocusNode.dispose();
    _trailerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى اختيار تاريخ الإدخال'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final db = Provider.of<DatabaseService>(context, listen: false);

      int? receiptNumber;
      if (_receiptNumberController.text.isEmpty) {
        receiptNumber = await db.getNextReceiptNumber();
      } else {
        receiptNumber = int.tryParse(_receiptNumberController.text);
        if (receiptNumber != null) {
          final exists = await db.checkReceiptNumberExists(receiptNumber);
          if (exists) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تنبيه'),
                  content: const Text('رقم البون موجود بالفعل، يرجى تغييره'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('حسنًا'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        }
      }

      final record = Record()
        ..date = _selectedDate ?? DateTime.now()
        ..receiptNumber = receiptNumber
        ..contractor = _contractorController.text
        ..loader = _loaderController.text
        ..driverName = _driverNameController.text
        ..truckNumber = _truckNumberController.text
        ..trailerNumber = _trailerNumberController.text
        ..cube = double.tryParse(_cubeController.text) ?? 0.0
        ..amount = double.tryParse(_amountController.text) ?? 0.0
        ..notes = _notesController.text;

      await db.addRecord(record);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ السجل بنجاح')));
        _resetForm();
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _receiptNumberController.clear(); // Clear receipt number field
    _contractorController.clear();
    _loaderController.clear();
    _driverNameController.clear();
    _truckNumberController.clear();
    _trailerNumberController.clear();
    _cubeController.clear();
    _amountController.clear();
    _notesController.clear();
    setState(() {
      // _selectedDate = null; // Don't clear date
      _selectedRecord = null;
      _searchDate = null;
      _searchResults = [];
      _showResultsCount = false;
      _isSearching = false;
    });
    _loadNextReceiptNumber();
  }

  // Search method triggered by button
  void _triggerSearch() {
    setState(() {
      _showResultsCount = true;
    });
    _performSearch();
  }

  Future<void> _performSearch() async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    double? cube = double.tryParse(_cubeController.text);
    double? amount = double.tryParse(_amountController.text);

    // If search date is selected, search for that specific day
    DateTime? start;
    DateTime? end;
    if (_searchDate != null) {
      start = DateTime(_searchDate!.year, _searchDate!.month, _searchDate!.day);
      end = DateTime(
        _searchDate!.year,
        _searchDate!.month,
        _searchDate!.day,
        23,
        59,
        59,
      );
    }

    final results = await db.searchRecordsAdvanced(
      startDate: start,
      endDate: end,
      receiptNumber: _receiptNumberController.text,
      contractor: _contractorController.text,
      loader: _loaderController.text,
      driverName: _driverNameController.text,
      truckNumber: _truckNumberController.text,
      trailerNumber: _trailerNumberController.text,
      cube: cube,
      amount: amount,
      notes: _notesController.text,
    );

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = true;
      });
    }
  }

  void _populateForm(Record record) {
    setState(() {
      _selectedRecord = record;
      _receiptNumberController.text = record.receiptNumber?.toString() ?? '';
      _contractorController.text = record.contractor ?? '';
      _loaderController.text = record.loader ?? '';
      _driverNameController.text = record.driverName ?? '';
      _truckNumberController.text = record.truckNumber ?? '';
      _trailerNumberController.text = record.trailerNumber ?? '';
      _cubeController.text = record.cube?.toString() ?? '';
      _amountController.text = record.amount?.toString() ?? '';
      _notesController.text = record.notes ?? '';
      _selectedDate = record.date ?? DateTime.now();
      _showResultsCount = false;
    });
  }

  void _populateFromRecent(Record record) {
    setState(() {
      _contractorController.text = record.contractor ?? '';
      _loaderController.text = record.loader ?? '';
      _driverNameController.text = record.driverName ?? '';
      _truckNumberController.text = record.truckNumber ?? '';
      _trailerNumberController.text = record.trailerNumber ?? '';
      _cubeController.text = record.cube?.toString() ?? '';
      _amountController.text = record.amount?.toString() ?? '';
    });
  }

  Future<void> _updateRecord() async {
    if (_formKey.currentState!.validate() && _selectedRecord != null) {
      final db = Provider.of<DatabaseService>(context, listen: false);

      final updatedRecord = _selectedRecord!
        ..date = _selectedDate
        ..contractor = _contractorController.text
        ..loader = _loaderController.text
        ..driverName = _driverNameController.text
        ..truckNumber = _truckNumberController.text
        ..trailerNumber = _trailerNumberController.text
        ..cube = double.tryParse(_cubeController.text) ?? 0.0
        ..amount = double.tryParse(_amountController.text) ?? 0.0
        ..notes = _notesController.text;

      await db.updateRecord(updatedRecord);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث السجل بنجاح')));
        // Don't reset form - keep data loaded
        // _resetForm();
      }
    }
  }

  Future<void> _deleteRecord() async {
    if (_selectedRecord == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا السجل؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.deleteRecord(_selectedRecord!.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف السجل بنجاح')));
        _resetForm();
      }
    }
  }

  // Compact date dropdown widget builder
  Widget _buildDateDropdown({
    required DateTime? date,
    required void Function(DateTime) onChanged,
    bool allowEmpty = false,
  }) {
    final currentDate = date;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year
            _buildCompactDropdown(
              value: currentDate?.year,
              items: List.generate(30, (i) => 2020 + i),
              hint: 'Year',
              onChanged: (year) {
                if (year != null) {
                  final base = currentDate ?? now;
                  onChanged(
                    DateTime(
                      year,
                      base.month,
                      base.day.clamp(1, DateTime(year, base.month + 1, 0).day),
                    ),
                  );
                }
              },
            ),
            Text(
              '/',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            // Month
            _buildCompactDropdown(
              value: currentDate?.month,
              items: List.generate(12, (i) => i + 1),
              hint: 'MM',
              formatValue: (v) => '$v'.padLeft(2, '0'),
              onChanged: (month) {
                if (month != null) {
                  final base = currentDate ?? now;
                  onChanged(
                    DateTime(
                      base.year,
                      month,
                      base.day.clamp(1, DateTime(base.year, month + 1, 0).day),
                    ),
                  );
                }
              },
            ),
            Text(
              '/',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            // Day
            _buildCompactDropdown(
              value: currentDate?.day,
              items: List.generate(
                currentDate != null
                    ? DateTime(currentDate.year, currentDate.month + 1, 0).day
                    : 31,
                (i) => i + 1,
              ),
              hint: 'DD',
              formatValue: (v) => '$v'.padLeft(2, '0'),
              onChanged: (day) {
                if (day != null) {
                  final base = currentDate ?? now;
                  onChanged(DateTime(base.year, base.month, day));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDropdown({
    required int? value,
    required List<int> items,
    required void Function(int?) onChanged,
    String? hint,
    String Function(int)? formatValue,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        hint: hint != null
            ? Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        isDense: true,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: items
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(formatValue != null ? formatValue(v) : '$v'),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget? _buildResultBadge(bool isMobile, bool hasValue) {
    if (isMobile &&
        _searchResults.isNotEmpty &&
        hasValue &&
        _showResultsCount) {
      return InkWell(
        onTap: () => _showMobileResults(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_searchResults.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.list,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      );
    }
    return null;
  }

  void _showMobileResults(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '${_searchResults.length} نتائج بحث',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = _searchResults[index];
                      return InkWell(
                        onTap: () {
                          _populateForm(record);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '#${record.receiptNumber}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(record.date!),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    record.contractor ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${record.amount} ج.م',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 900;
        // Calculate bottom padding for fixed buttons
        final bottomPadding = 80.0;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Stack(
              children: [
                Positioned.fill(
                  child: !isMobile
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Right: Input Form (Now First -> Right in RTL)
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  left: 8,
                                  right: 8,
                                  top: 8,
                                  bottom: bottomPadding,
                                ),
                                child: _buildForm(isMobile: false),
                              ),
                            ),
                            // Left: Recent Records List (Excel Table) (Now Second -> Left in RTL)
                            Expanded(flex: 3, child: _buildRecentRecordsList()),
                          ],
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: bottomPadding,
                          ),
                          child: Column(
                            children: [
                              _buildForm(isMobile: true),
                              // Add extra space at bottom for FABs
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                ),
                // Fixed Bottom Buttons
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Save / Update Button
                        Expanded(
                          flex: 2,
                          child: _selectedRecord == null
                              ? ElevatedButton.icon(
                                  onPressed: _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                  icon: const Icon(Icons.save, size: 24),
                                  label: const Text(
                                    'حفظ السجل',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _updateRecord,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.update,
                                          size: 24,
                                        ),
                                        label: const Text(
                                          'تحديث',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _deleteRecord,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.errorContainer,
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 24,
                                        ),
                                        label: const Text(
                                          'حذف',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Search Button
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: _triggerSearch,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                            icon: const Icon(Icons.search, size: 24),
                            label: const Text(
                              'بحث',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (_isSearching || _selectedRecord != null) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _resetForm,
                            tooltip: 'إلغاء / مسح',
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm({required bool isMobile}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Edit Mode Indicator
          if (_selectedRecord != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 18,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'وضع التعديل - بون #${_selectedRecord!.receiptNumber}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          // Section 1: Basic Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      'بيانات السجل',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Date & Receipt
                  // Row 1: Insert Date & Search Date
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Insert Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تاريخ الإدخال',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildDateDropdown(
                              date: _selectedDate,
                              onChanged: (date) {
                                setState(() => _selectedDate = date);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Search Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تاريخ البحث',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildDateDropdown(
                              date: _searchDate,
                              allowEmpty: true,
                              onChanged: (date) {
                                setState(() {
                                  _searchDate = date;
                                  _showResultsCount = true;
                                });
                                _performSearch();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2: Bon Number (Full Width)
                  _buildTextField(
                    _receiptNumberController,
                    'رقم البون',
                    isNumber: true,
                    icon: Icons.tag,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 2),

          // Section 2: Truck Details (المركبة)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      'المركبة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSmartVehicleAutocomplete(
                          _truckNumberController,
                          'رقم الوش',
                          _truckNumbers,
                          isTruck: true,
                          isMobile: isMobile,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSmartVehicleAutocomplete(
                          _trailerNumberController,
                          'المقطورة',
                          _trailerNumbers,
                          isTruck: false,
                          isMobile: isMobile,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Section 3: Contractor & Driver Details (التفاصيل)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      'التفاصيل',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 4),
                  _buildAutocompleteTextField(
                    _contractorController,
                    'المقاول أو البيان',
                    _contractorNames,
                    focusNode: _contractorFocusNode,
                    icon: Icons.business,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _loaderController,
                          'لودر التحميل',
                          icon: Icons.construction,
                          isMobile: isMobile,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAutocompleteTextField(
                          _driverNameController,
                          'اسم السائق',
                          _driverNames,
                          focusNode: _driverFocusNode,
                          icon: Icons.person,
                          isMobile: isMobile,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Section 4: Financials & Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      'المالية والملاحظات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.attach_money,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _cubeController,
                          'تكعيب',
                          isNumber: true,
                          icon: Icons.grid_3x3,
                          isMobile: isMobile,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          _amountController,
                          'المبلغ',
                          isNumber: true,
                          icon: Icons.attach_money,
                          isMobile: isMobile,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      prefixIcon: Icon(Icons.note, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    IconData? icon,
    bool isMobile = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                size: 20,
              )
            : null,
        suffixIcon: _buildResultBadge(isMobile, controller.text.isNotEmpty),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) {
        // All fields are required except notes and receipt number
        if (label != 'ملاحظات' && label != 'رقم البون') {
          return value == null || value.isEmpty ? 'مطلوب' : null;
        }
        return null;
      },
    );
  }

  Widget _buildSmartVehicleAutocomplete(
    TextEditingController controller,
    String label,
    List<String> options, {
    required bool isTruck,
    bool isMobile = false,
  }) {
    final db = Provider.of<DatabaseService>(context, listen: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<Object>(
          textEditingController: controller,
          focusNode: isTruck ? _truckFocusNode : _trailerFocusNode,
          displayStringForOption: (option) {
            if (option is String) return option;
            if (option is Record)
              return isTruck
                  ? (option.truckNumber ?? '')
                  : (option.trailerNumber ?? '');
            return '';
          },
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Object>.empty();
            }

            final filter = textEditingValue.text.toLowerCase();
            final matchedUnique = options.where(
              (option) => option.toLowerCase().contains(filter),
            );

            // Fetch recent records for this vehicle
            final recent = isTruck
                ? await db.getRecentRecordsByTruck(textEditingValue.text)
                : await db.getRecentRecordsByTrailer(textEditingValue.text);

            return [...recent, ...matchedUnique];
          },
          onSelected: (option) async {
            if (option is Record) {
              _populateFromRecent(option);
            } else if (option is String) {
              final recent = isTruck
                  ? await db.getRecentRecordsByTruck(option)
                  : await db.getRecentRecordsByTrailer(option);
              if (recent.isNotEmpty) {
                _populateFromRecent(recent.first);
              }
            }
          },
          fieldViewBuilder:
              (context, fieldController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: fieldController,
                  focusNode: focusNode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: Icon(
                      isTruck ? Icons.numbers : Icons.local_shipping,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.7),
                      size: 20,
                    ),
                    suffixIcon: _buildResultBadge(
                      isMobile,
                      fieldController.text.isNotEmpty,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    if (_isSearching) {
                      _performSearch();
                    }
                  },
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 12.0,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: Container(
                  width: constraints.maxWidth.clamp(350.0, 600.0),
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 48),
                    itemBuilder: (BuildContext context, int index) {
                      final option = options.elementAt(index);

                      // Section Header for History (Only show if the first item is a record)
                      if (index == 0 && option is Record) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.4),
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'سجل الرحلات الأخيرة',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (option is String) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          title: Text(
                            option,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tag, size: 16),
                          ),
                          onTap: () => onSelected(option),
                        );
                      } else if (option is Record) {
                        final dateStr = option.date != null
                            ? DateFormat('MM/dd').format(option.date!)
                            : '';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          dense: true,
                          title: Text(
                            '$dateStr - ${option.contractor}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'السائق: ${option.driverName} | ${isTruck ? option.truckNumber : option.trailerNumber}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTruck ? Icons.numbers : Icons.local_shipping,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onTap: () => onSelected(option),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAutocompleteTextField(
    TextEditingController controller,
    String label,
    List<String> options, {
    required FocusNode focusNode,
    IconData? icon,
    bool isMobile = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              return const Iterable<String>.empty();
            }
            return options.where((String option) {
              return option.contains(textEditingValue.text);
            });
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: icon != null
                        ? Icon(
                            icon,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.7),
                            size: 20,
                          )
                        : null,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (options.isNotEmpty)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            tooltip: 'Show All',
                            onSelected: (String value) {
                              fieldTextEditingController.text = value;
                              if (_isSearching) {
                                _performSearch();
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return options.map((String choice) {
                                return PopupMenuItem<String>(
                                  value: choice,
                                  child: Text(choice),
                                );
                              }).toList();
                            },
                          ),
                        if (_buildResultBadge(
                              isMobile,
                              fieldTextEditingController.text.isNotEmpty,
                            ) !=
                            null)
                          _buildResultBadge(
                            isMobile,
                            fieldTextEditingController.text.isNotEmpty,
                          )!,
                      ],
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    if (_isSearching) {
                      _performSearch();
                    }
                  },
                  validator: (value) {
                    return value == null || value.isEmpty ? 'مطلوب' : null;
                  },
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<String> onSelected,
                Iterable<String> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: SizedBox(
                      width: constraints.maxWidth.clamp(350.0, 600.0),
                      height: 200.0,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return GestureDetector(
                            onTap: () {
                              onSelected(option);
                            },
                            child: ListTile(title: Text(option)),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  Widget _buildRecentRecordsList() {
    final db = Provider.of<DatabaseService>(context);

    // Determine which records to display
    final displayRecords = _isSearching ? _searchResults : null;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isSearching
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isSearching ? Icons.search : Icons.history,
                    color: _isSearching
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _isSearching
                        ? 'نتائج البحث (${_searchResults.length})'
                        : 'أحدث السجلات',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Search Button in table header (tablet only)
                ElevatedButton.icon(
                  onPressed: _triggerSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
                  ),
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text(
                    'بحث',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isSearching) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('مسح'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: displayRecords != null
                ? _buildDataTable(displayRecords)
                : FutureBuilder<List<Record>>(
                    future: db.getAllRecords(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final records = snapshot.data!;
                      if (records.isEmpty) {
                        return const Center(child: Text('لا توجد بيانات'));
                      }
                      // Reverse to show newest first
                      return _buildDataTable(records);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Record> records) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج مطابقة',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(
        context,
      ).copyWith(dividerColor: Theme.of(context).dividerColor),
      child: DataTable2(
        scrollController: _tableVerticalController,
        horizontalScrollController: _tableHorizontalController,
        columnSpacing: 12,
        horizontalMargin: 24,
        minWidth: 1000,
        showCheckboxColumn: false,
        headingRowColor: WidgetStateProperty.all(
          Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        ),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        dataRowColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.5);
          }
          return null;
        }),
        border: TableBorder(
          horizontalInside: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
        columns: const [
          DataColumn2(label: Text('م'), size: ColumnSize.S),
          DataColumn2(label: Text('التاريخ'), size: ColumnSize.M),
          DataColumn2(label: Text('رقم البون'), size: ColumnSize.S),
          DataColumn2(label: Text('المقاول'), size: ColumnSize.L),
          DataColumn2(label: Text('اللودر'), size: ColumnSize.M),
          DataColumn2(label: Text('السائق'), size: ColumnSize.M),
          DataColumn2(label: Text('رقم الوش'), size: ColumnSize.M),
          DataColumn2(label: Text('المقطورة'), size: ColumnSize.M),
          DataColumn2(label: Text('تكعيب'), numeric: true, size: ColumnSize.S),
          DataColumn2(label: Text('المبلغ'), numeric: true, size: ColumnSize.S),
          DataColumn2(label: Text('ملاحظات'), size: ColumnSize.L),
        ],
        rows: List<DataRow>.generate(records.length, (index) {
          final r = records[index];
          final isSelected = _selectedRecord?.id == r.id;
          return DataRow(
            selected: isSelected,
            onSelectChanged: (_) => _populateForm(r),
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(DateFormat('yyyy-MM-dd').format(r.date!))),
              DataCell(Text('${r.receiptNumber}')),
              DataCell(Text(r.contractor ?? '')),
              DataCell(Text(r.loader ?? '')),
              DataCell(Text(r.driverName ?? '')),
              DataCell(Text(r.truckNumber ?? '')),
              DataCell(Text(r.trailerNumber ?? '')),
              DataCell(Text('${r.cube}')),
              DataCell(Text('${r.amount}')),
              DataCell(Text(r.notes ?? '')),
            ],
          );
        }),
      ),
    );
  }
}
