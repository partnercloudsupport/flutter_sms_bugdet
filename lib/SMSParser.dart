import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sms/sms.dart';

import 'TransSet.dart';
import 'Transaction.dart';

/// this it put outside the class because compute() requires it
List globalReadAndParse(List<SmsMessage> messages) {
  List<Transaction> transactions = [];
  Map<DateTime, double> globalStates = {};

  DateTime date = DateTime.now();
  for (var m in messages) {
//      print([m.sender, m.date, m.body].join('\t'));

    var lines;
    if (m.body.startsWith('KONTOSTAND')) {
      var datePresplit =
          m.body.splitMapJoin(RegExp('\\.20\\d\\d'), onMatch: (m) {
//          print('match $m');
        return m.group(0) + '///';
      }, onNonMatch: (m) {
//          print('non-match $m');
        return m.toString();
      });
//        print(datePresplit);
      var dateSplit = datePresplit.split('///');
//        print(dateSplit);

      var parts = dateSplit[0].split(' ');

      try {
        var sDate = parts[3].split('.').reversed.join('-');
        date = DateTime.parse(sDate);
//          print(date);
      } on RangeError catch (e) {
        print('Exception $e in [' + parts.toString() + ']');
        print(m.body);
      }

      var iState;
      var sState = parts[2].replaceFirst(',', '.');
      if (sState.endsWith('-')) {
        iState = -double.parse(sState.substring(0, sState.length - 1));
      } else {
        iState = double.parse(sState);
      }
//          print('$date: $iState');
      globalStates[date] = iState;

      lines = dateSplit[1].split(RegExp('\\d-'));
    } else {
      lines = m.body.split(RegExp('\\d-'));
    }

    for (var l in lines) {
      var trans;
      if (l.startsWith('SEITE')) {
        l = l.split(':').sublist(1).join(' ');
        try {
          trans = Transaction.parse(date, l);
//              print(trans);
        } on FormatException {
          //skip
          print('Exception[' + l + ']');
        }
      } else {
        try {
          trans = Transaction.parse(date, l);
//              print(trans);
        } on FormatException {
          //skip
          print('Exception[' + l + ']');
        }
      }

      if (trans != null) {
        transactions.add(trans);
      }
    }
  }
  print('Parsed ${transactions.length} transactions');
  return [transactions, globalStates];
}

class SMSParser {
  Map<String, List<String>> statusList;

  Map<DateTime, double> states = {};
  List<Transaction> transactions = [];
  Map<DateTime, List<Transaction>> perMonth = {};

  SMSParser(this.statusList);

  Future<int> readAndParse(List<SmsMessage> messages) async {
    var pair = await compute(globalReadAndParse, messages);
    this.transactions = pair[0];
    this.states = pair[1]; // ugly variable passing
    return this.transactions.length;
  }

  getOrderedTransactionSetsFor(DateTime currentMonth) {
    print('this month ${currentMonth.toString()}');
    print('filtering ${this.transactions.length}');
    var transactionsThisMonth = this.transactions.where((Transaction t) {
      var date = t.date;
      if (date.year == currentMonth.year && date.month == currentMonth.month) {
        return true;
      }
      return false;
    });
    print('trans this month ${transactionsThisMonth.length}');

    Map<String, TransSet> sets = {};
    for (var t in transactionsThisMonth) {
      var code = t.note;
      for (var each in statusList.keys) {
        if (statusList[each].contains(code)) {
          code = '[$each]';
          break;
        }
      }
      sets[code] = sets[code] ?? TransSet(code);
      sets[code].add(t);
    }
    print('sets ${sets.keys.length}');

    List<TransSet> ordered = sets.values.toList();
    ordered.sort((a, b) {
      return a.total > b.total ? -1 : 1;
    });

//    for (var entry in ordered) {
//      print(
//          '${entry.data.first.date.toString()}\t${entry.total}\t${entry.code}');
//    }
    return ordered;
  }

  void saveMessages(List<SmsMessage> messages) {
    var json = [];
    for (var m in messages) {
      json.add({
        'sender': m.sender,
        'date': m.date.toString(),
        'dateSent': m.dateSent.toString(),
        'body': m.body,
        'address': m.address,
        'id': m.id,
        'threadId': m.threadId,
      });
    }
    File f = File('/storage/emulated/0/Download/sms.json');
    f.writeAsStringSync(jsonEncode(json));
  }

  void buildPerMonth() {
    print('buildPerMonth()');
    for (var t in transactions) {
      var month = DateTime(t.date.year, t.date.month, 1);
      if (perMonth[month] == null) {
        perMonth[month] = [];
      }
      perMonth[month].add(t);
    }
//    print(perMonth.keys);
//    for (var key in perMonth.keys) {
//      print(key.toString() + '\t' + perMonth[key].length.toString());
//    }
  }

  double getAverageFor(String note) {
    if (perMonth.length == 0) {
      buildPerMonth();
    }
    List<double> sumPerMonth = [];
    for (var monthData in perMonth.values) {
      double sum = 0;
      for (var t in monthData) {
        if (t.note == note) {
          sum += t.amount;
//          print(note +
//              '\t+' +
//              t.amount.toStringAsFixed(2) +
//              '\t=' +
//              sum.toStringAsFixed(2));
        }
      }
      if (sum > 0) {
        sumPerMonth.add(sum);
      }
    }

    // average of a single value is not interesting
    if (sumPerMonth.length > 1) {
      var avg =
          sumPerMonth.reduce((total, el) => total + el) / sumPerMonth.length;
//      print(
//          note + '\t' + sumPerMonth.toString() + '\t' + avg.toStringAsFixed(2));
      return avg;
    }
    return 0;
  }

  int getMonths() {
    if (perMonth.length == 0) {
      buildPerMonth();
    }
    return perMonth.keys.length;
  }

  DateTime getMonthNr(int index) {
    if (perMonth.length == 0) {
      buildPerMonth();
    }
    var pages = perMonth.keys.toList();
    pages.sort();
    return pages[index];
  }

  double getRemainingFor(DateTime month) {
    print(states);
    var statesThisMonth = states.entries.where((MapEntry<DateTime, double> el) {
      return el.key.year == month.year && el.key.month == month.month;
    }).toList();
    statesThisMonth
        .sort((MapEntry<DateTime, double> a, MapEntry<DateTime, double> b) {
      return a.key.isBefore(b.key) ? -1 : 1;
    });
    print(statesThisMonth);
    if (statesThisMonth.length > 0) {
      return statesThisMonth.last.value;
    } else {
      return 0;
    }
  }
}
