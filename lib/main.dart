import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sms/sms.dart';

class Transaction {
  final DateTime date;
  final double amount;
  final String note;

  Transaction(this.date, this.amount, this.note);

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

class TransSet {
  final String code;
  List<Transaction> data = [];

  TransSet(this.code);

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

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<DateTime, double> states = {};
  List<Transaction> transactions = [];
  List<TransSet> orderedTransactionSets = [];

  @override
  void initState() {
    super.initState();
    initAsyncState();
  }

  void initAsyncState() async {
    SmsQuery query = new SmsQuery();
    List<SmsMessage> messages = await query.querySms(kinds: [
      SmsQueryKind.Inbox,
      //SmsQueryKind.Sent
    ], address: 'IhreBank');
    print(messages.length);

    var prevMonth = (DateTime.now().month - 1);
    if (prevMonth == 0) {
      prevMonth = 12;
    }

    DateTime date;
    for (var m in messages) {
      print([m.sender, m.date, m.body].join('\t'));
      var lines = m.body.split('-');
      print(lines);

      for (var l in lines) {
        if (l.startsWith('KONTOSTAND')) {
          var parts = l.split(' ');
          date = DateTime.parse(parts[3].split('.').reversed.join('-'));

          if (date.month != prevMonth) {
            break;
          }

          var iState = double.parse(parts[2].replaceFirst(',', '.'));
          print('$date: $iState');
          this.states[date] = iState;
          try {
            var trans = Transaction.parse(date, parts.sublist(4).join(' '));
            print(trans);
            this.transactions.add(trans);
          } on FormatException catch (e) {
            //skip
          }
        } else {
          if (l.startsWith('SEITE')) {
            l = l.split(':').sublist(1).join(' ');
            try {
              var trans = Transaction.parse(date, l);
              print(trans);
              this.transactions.add(trans);
            } on FormatException catch (e) {
              //skip
            }
          } else {
            try {
              var trans = Transaction.parse(date, l);
              print(trans);
              this.transactions.add(trans);
            } on FormatException catch (e) {
              //skip
            }
          }
        }
      }

      // break again from outside loop
      if (date.month != prevMonth) {
        break;
      }
    }

    Map<String, TransSet> sets = {};
    for (var t in transactions) {
      var code = t.note;
      sets[code] = sets[code] ?? TransSet(code);
      sets[code].add(t);
    }

    List<TransSet> ordered = sets.values.toList();
    ordered.sort((a, b) {
      return a.total > b.total ? -1 : 1;
    });

    for (var entry in ordered) {
      print('${entry.total}\t${entry.code}');
    }

    setState(() {
      orderedTransactionSets = ordered;
    });
  }

  void _incrementCounter() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          orderedTransactionSets.length > 0
              ? Expanded(
                  child: ListView(
                      shrinkWrap: true,
                      children: orderedTransactionSets.map((set) {
                        return ListTile(
                          leading: Chip(
                            label: Text(set.data.length.toString()),
                          ),
                          title: Text(
                            set.code,
                            style: Theme.of(context).textTheme.title,
                          ),
                          trailing: Text(set.total.toStringAsFixed(2)),
                          dense: true,
                        );
                      }).toList()))
              : CircularProgressIndicator()
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
