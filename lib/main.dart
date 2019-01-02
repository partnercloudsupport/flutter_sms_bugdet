import 'package:flutter/material.dart';
import 'package:sms/sms.dart';

import 'TransSet.dart';
import 'TransSetView.dart';
import 'Transaction.dart';

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
  DateTime currentMonth = DateTime.now();
  Map<DateTime, double> states = {};
  List<Transaction> transactions = [];
  List<TransSet> orderedTransactionSets = [];

  @override
  void initState() {
    super.initState();
    initAsyncState();
  }

  void initAsyncState() async {
    fetchAndParseSMS();
  }

  void fetchAndParseSMS() async {
    transactions = [];
    orderedTransactionSets = [];
    setState(() {}); // show loading indicator

    SmsQuery query = new SmsQuery();
    List<SmsMessage> messages = await query.querySms(kinds: [
      SmsQueryKind.Inbox,
      //SmsQueryKind.Sent
    ], address: 'IhreBank');
    print(messages.length.toString() + ' ' + currentMonth.toString());

    DateTime date;
    for (var m in messages) {
//      print([m.sender, m.date, m.body].join('\t'));

      var lines;
      if (m.body.startsWith('KONTOSTAND')) {
        var datePresplit =
            m.body.splitMapJoin(RegExp('\\.20\\d\\d'), onMatch: (m) {
          print('match $m');
          return m.group(0) + '///';
        }, onNonMatch: (m) {
          print('non-match $m');
          return m.toString();
        });
        print(datePresplit);
        var dateSplit = datePresplit.split('///');
        print(dateSplit);

        var parts = dateSplit[0].split(' ');

        try {
          var sDate = parts[3].split('.').reversed.join('-');
          date = DateTime.parse(sDate);
          print(date);
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
        this.states[date] = iState;

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
          } on FormatException catch (e) {
            //skip
            print('Exception[' + l + ']');
          }
        } else {
          try {
            trans = Transaction.parse(date, l);
//              print(trans);
          } on FormatException catch (e) {
            //skip
            print('Exception[' + l + ']');
          }
        }

        print(date.year.toString() +
            ' ' +
            currentMonth.year.toString() +
            ' ' +
            date.month.toString() +
            ' ' +
            currentMonth.month.toString());
        if (trans != null &&
            date.year == currentMonth.year &&
            date.month == currentMonth.month) {
          print(trans);
          this.transactions.add(trans);
        }
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
      print(
          '${entry.data.first.date.toString()}\t${entry.total}\t${entry.code}');
    }

    setState(() {
      orderedTransactionSets = ordered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentMonth.year.toString() +
            '-' +
            currentMonth.month.toString().padLeft(2, '0')),
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
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (BuildContext context) {
                              return TransSetView(set: set);
                            }));
                          },
                        );
                      }).toList()))
              : Center(child: CircularProgressIndicator())
        ],
      ),
//      floatingActionButton: FloatingActionButton(
//        onPressed: _incrementCounter,
//        tooltip: 'Increment',
//        child: Icon(Icons.add),
//      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            RaisedButton(
              child: Text('Prev Month'),
              onPressed: () {
//              setState(() {
                currentMonth = DateTime(currentMonth.year,
                    currentMonth.month - 1, currentMonth.day);
                fetchAndParseSMS();
//              });
              },
            ),
            RaisedButton(
              child: Text('Next Month'),
              onPressed: () {
//              setState(() {
                currentMonth = DateTime(currentMonth.year,
                    currentMonth.month + 1, currentMonth.day);
                fetchAndParseSMS();
//              });
              },
            )
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
