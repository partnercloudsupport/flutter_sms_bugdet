import 'Transaction.dart';

class TransSet {
  String code;
  List<Transaction> data = [];

  TransSet(this.code) {
    this.code = this.code.trim();
  }

  void add(Transaction t) {
    data.add(t);
  }

  double get total {
    var sum = 0.0;
    for (var t in data) {
      sum += t.amount;
    }
    return sum;
  }
}
