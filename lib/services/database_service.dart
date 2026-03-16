import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/record.dart';

class DatabaseService {
  late Isar _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([RecordSchema], directory: dir.path);
  }

  Future<void> addRecord(Record record) async {
    await _isar.writeTxn(() async {
      await _isar.records.put(record);
    });
  }

  Future<void> addRecords(List<Record> records) async {
    await _isar.writeTxn(() async {
      await _isar.records.putAll(records);
    });
  }

  Future<List<Record>> getAllRecords() async {
    return await _isar.records
        .where()
        .sortByDateDesc()
        .thenByReceiptNumberDesc()
        .findAll();
  }

  Future<void> updateRecord(Record record) async {
    await _isar.writeTxn(() async {
      await _isar.records.put(record);
    });
  }

  Future<void> deleteRecord(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.records.delete(id);
    });
  }

  Future<void> clearAllData() async {
    await _isar.writeTxn(() async {
      await _isar.records.clear();
    });
  }

  Future<int> getNextReceiptNumber() async {
    final lastRecord = await _isar.records
        .where()
        .sortByReceiptNumberDesc()
        .findFirst();
    return (lastRecord?.receiptNumber ?? 0) + 1;
  }

  Future<bool> checkReceiptNumberExists(int receiptNumber) async {
    final count = await _isar.records
        .filter()
        .receiptNumberEqualTo(receiptNumber)
        .count();
    return count > 0;
  }

  Future<List<Record>> getRecentRecordsByTruck(String truckNumber) async {
    return await _isar.records
        .filter()
        .truckNumberStartsWith(truckNumber, caseSensitive: false)
        .sortByDateDesc()
        .limit(5)
        .findAll();
  }

  Future<List<Record>> getRecentRecordsByTrailer(String trailerNumber) async {
    return await _isar.records
        .filter()
        .trailerNumberStartsWith(trailerNumber, caseSensitive: false)
        .sortByDateDesc()
        .limit(5)
        .findAll();
  }

  Future<List<Record>> searchRecords(String query) async {
    if (query.isEmpty) {
      return getAllRecords();
    }

    // Existing global search implementation remains for backward compatibility or if needed
    return await _isar.records
        .filter()
        .contractorContains(query, caseSensitive: false)
        .or()
        .loaderContains(query, caseSensitive: false)
        .or()
        .driverNameContains(query, caseSensitive: false)
        .or()
        .truckNumberContains(query, caseSensitive: false)
        .or()
        .trailerNumberContains(query, caseSensitive: false)
        .or()
        .notesContains(query, caseSensitive: false)
        .sortByDateDesc()
        .thenByReceiptNumberDesc()
        .findAll();
  }

  Future<List<Record>> searchRecordsAdvanced({
    DateTime? startDate,
    DateTime? endDate,
    String? receiptNumber, // Changed to String for partial match
    String? contractor,
    String? loader,
    String? driverName,
    String? truckNumber,
    String? trailerNumber,
    double? cube,
    double? amount,
    String? notes,
  }) async {
    return await _isar.records
        .filter()
        .optional(
          startDate != null && endDate != null,
          (q) => q.dateBetween(startDate!, endDate!),
        )
        .optional(receiptNumber != null && receiptNumber.isNotEmpty, (q) {
          // Partial integer match (StartsWith logic)
          final numPrefix = int.tryParse(receiptNumber!);
          if (numPrefix != null) {
            return q.group((g) {
              var query = g.receiptNumberEqualTo(numPrefix);

              // Generate ranges: 12 -> 120-129, 1200-1299, etc.
              int start = numPrefix;
              int end = numPrefix;
              // Limit deep level to avoid infinite loop, e.g. up to 1 billion
              // 10 digits max for 32-bit int, let's go safe.
              for (int i = 0; i < 9; i++) {
                if (start > 2147483647 ~/ 10) break; // Avoid overflow
                start = start * 10;
                end = end * 10 + 9;
                query = query.or().receiptNumberBetween(start, end);
              }
              return query;
            });
          } else {
            // If not a number, maybe return nothing or ignore
            return q
                .receiptNumberIsNull(); // Effectively no match for text in int field
          }
        })
        .optional(
          contractor != null && contractor.isNotEmpty,
          (q) => q.contractorContains(contractor!, caseSensitive: false),
        )
        .optional(
          loader != null && loader.isNotEmpty,
          (q) => q.loaderContains(loader!, caseSensitive: false),
        )
        .optional(
          driverName != null && driverName.isNotEmpty,
          (q) => q.driverNameContains(driverName!, caseSensitive: false),
        )
        .optional(
          truckNumber != null && truckNumber.isNotEmpty,
          (q) => q.truckNumberContains(truckNumber!, caseSensitive: false),
        )
        .optional(
          trailerNumber != null && trailerNumber.isNotEmpty,
          (q) => q.trailerNumberContains(trailerNumber!, caseSensitive: false),
        )
        .optional(cube != null, (q) => q.cubeEqualTo(cube!))
        .optional(amount != null, (q) => q.amountEqualTo(amount!))
        .optional(
          notes != null && notes.isNotEmpty,
          (q) => q.notesContains(notes!, caseSensitive: false),
        )
        .sortByDateDesc()
        .thenByReceiptNumberDesc()
        .findAll();
  }

  Future<List<String>> getUniqueDriverNames() async {
    final records = await _isar.records
        .where()
        .distinctByDriverName()
        .findAll();

    final names = records
        .map((r) => r.driverName)
        .where((n) => n != null && n.isNotEmpty)
        .cast<String>()
        .toList();

    names.sort();
    return names;
  }

  Future<List<String>> getUniqueContractorNames() async {
    final records = await _isar.records
        .where()
        .distinctByContractor()
        .findAll();

    final names = records
        .map((r) => r.contractor)
        .where((n) => n != null && n.isNotEmpty)
        .cast<String>()
        .toList();

    names.sort();
    return names;
  }

  Future<List<String>> getUniqueTruckNumbers() async {
    final records = await _isar.records
        .where()
        .distinctByTruckNumber()
        .findAll();
    final numbers = records
        .map((r) => r.truckNumber)
        .where((n) => n != null && n.isNotEmpty)
        .cast<String>()
        .toList();
    numbers.sort();
    return numbers;
  }

  Future<List<String>> getUniqueTrailerNumbers() async {
    final records = await _isar.records
        .where()
        .distinctByTrailerNumber()
        .findAll();
    final numbers = records
        .map((r) => r.trailerNumber)
        .where((n) => n != null && n.isNotEmpty)
        .cast<String>()
        .toList();
    numbers.sort();
    return numbers;
  }
}
