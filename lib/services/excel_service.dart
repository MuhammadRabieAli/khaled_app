import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';

class ExcelService {
  static const List<String> requiredHeaders = [
    'التاريخ',
    'رقم البون',
    'المقاول أو البيان',
    'لودر التحميل',
    'اسم السائق',
    'رقم الوش',
    'المقطورة',
    'تكعيب',
    'المبلغ',
    'ملاحــــــظات',
  ];

  Future<List<Record>> importExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];

    if (sheet == null) {
      throw Exception('ملف الإكسل فارغ');
    }

    // Validate headers
    final headers = sheet.rows.first
        .map((e) => e?.value?.toString() ?? '')
        .toList();
    _validateHeaders(headers);

    final records = <Record>[];
    // Skip header row
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => cell?.value == null)) continue;

      try {
        records.add(_parseRow(row));
      } catch (e) {
        print('Error parsing row $i: $e');
        // Continue parsing other rows or throw? User said "Handle empty cells gracefully"
      }
    }

    return records;
  }

  void _validateHeaders(List<String> headers) {
    // Basic validation: check if required headers exist.
    // The user explicitly requested to NOT validate column names, trusting the order.
    // However, we should still ensure there are enough columns to parse correctly.
    if (headers.length < requiredHeaders.length) {
      // Just log a warning or still throw? If missing columns, index access in _parseRow returns null,
      // which might be okay ("Cells may be empty"), but if entire columns are missing, data is likely wrong.
      // Let's keep the length check as a sanity check for now, but relax the name check.
      throw Exception(
        'عدد الأعمدة غير صحيح. يجب أن يحتوي الملف على ${requiredHeaders.length} أعمدة على الأقل.',
      );
    }

    // Name validation loop removed per user request.
    /*
    for (var i = 0; i < requiredHeaders.length; i++) {
      if (headers[i].trim() != requiredHeaders[i]) {
        throw Exception(
          'اسم العمود غير صحيح في الموضع ${i + 1}. المتوقع: "${requiredHeaders[i]}", الموجود: "${headers[i]}"',
        );
      }
    }
    */
  }

  Record _parseRow(List<Data?> row) {
    // Helper to safely get value by index
    CellValue? getValue(int index) {
      if (index >= row.length) return null;
      return row[index]?.value;
    }

    // Parse Date
    DateTime? date;
    final dateVal = getValue(0);
    if (dateVal is DateCellValue) {
      date = DateTime(dateVal.year, dateVal.month, dateVal.day);
    } else if (dateVal is TextCellValue) {
      // Try parsing text date if necessary, e.g. yyyy-MM-dd
      try {
        date = DateTime.parse(dateVal.value.toString());
      } catch (_) {}
    }

    // Parse Receipt Number
    int? receiptNumber;
    final receiptVal = getValue(1);
    if (receiptVal is IntCellValue) {
      receiptNumber = receiptVal.value;
    } else if (receiptVal is TextCellValue) {
      receiptNumber = int.tryParse(receiptVal.value.toString());
    } else if (receiptVal is DoubleCellValue) {
      receiptNumber = receiptVal.value.toInt();
    }

    // Parse Amounts (Double)
    double? getDouble(int index) {
      final val = getValue(index);
      if (val is DoubleCellValue) return val.value;
      if (val is IntCellValue) return val.value.toDouble();
      if (val is TextCellValue) return double.tryParse(val.value.toString());
      return null;
    }

    // Parse Strings
    String? getString(int index) {
      final val = getValue(index);
      return val?.toString();
    }

    return Record()
      ..date = date
      ..receiptNumber = receiptNumber
      ..contractor = getString(2)
      ..loader = getString(3)
      ..driverName = getString(4)
      ..truckNumber = getString(5)
      ..trailerNumber = getString(6)
      ..cube = getDouble(7)
      ..amount = getDouble(8)
      ..notes = getString(9);
  }

  Future<List<int>> exportExcel(List<Record> records) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Write Headers
    sheet.appendRow(requiredHeaders.map((e) => TextCellValue(e)).toList());

    // Write Data
    for (final record in records) {
      sheet.appendRow([
        record.date != null
            ? DateCellValue(
                year: record.date!.year,
                month: record.date!.month,
                day: record.date!.day,
              )
            : null,
        record.receiptNumber != null
            ? IntCellValue(record.receiptNumber!)
            : null,
        record.contractor != null ? TextCellValue(record.contractor!) : null,
        record.loader != null ? TextCellValue(record.loader!) : null,
        record.driverName != null ? TextCellValue(record.driverName!) : null,
        record.truckNumber != null ? TextCellValue(record.truckNumber!) : null,
        record.trailerNumber != null
            ? TextCellValue(record.trailerNumber!)
            : null,
        record.cube != null ? DoubleCellValue(record.cube!) : null,
        record.amount != null ? DoubleCellValue(record.amount!) : null,
        record.notes != null ? TextCellValue(record.notes!) : null,
      ]);
    }

    return excel.encode() ?? [];
  }
}
