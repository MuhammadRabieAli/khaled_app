import 'package:isar/isar.dart';

part 'record.g.dart';

@collection
class Record {
  Id id = Isar.autoIncrement;

  DateTime? date; // التاريخ

  @Index()
  int? receiptNumber; // رقم البون

  String? contractor; // المقاول أو البيان

  String? loader; // لودر التحميل

  String? driverName; // اسم السائق

  String? truckNumber; // رقم الوش

  String? trailerNumber; // المقطورة

  double? cube; // تكعيب

  double? amount; // المبلغ

  String? notes; // ملاحــــــظات
}
