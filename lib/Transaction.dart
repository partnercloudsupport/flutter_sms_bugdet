import 'dart:convert';

class Transaction {
  final DateTime date;
  final double amount;
  String note;

  Transaction(this.date, this.amount, this.note) {
    this.note = this.note.trim();
  }

  static parse(DateTime date, String row) {
    var amountStarts = row.indexOf(RegExp('\\d+,\\d+'));
    if (amountStarts == -1) {
      throw FormatException();
    }
    var amount =
        double.parse(row.substring(amountStarts).replaceFirst(',', '.'));
    var before = row.substring(0, amountStarts).trim();
    return Transaction(date, amount, before);
  }

  String toString() {
    return jsonEncode({
      'date': date.toString(),
      'amount': amount,
      'note': note,
    });
  }
}
