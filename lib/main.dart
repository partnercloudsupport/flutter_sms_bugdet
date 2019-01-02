import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

import 'SMSParser.dart';
import 'TransSet.dart';
import 'TransSetView.dart';

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
  List<TransSet> orderedTransactionSets = [];
  Map<String, List<String>> statusList = {
    'Food': [],
    'Car': [],
    'Entertainment': [],
    'Restaurant': [],
  };
  final LocalStorage storage = new LocalStorage('MyHomePage');
  SMSParser parser;

  @override
  void initState() {
    super.initState();
    initAsyncState();
  }

  void initAsyncState() async {
    await storage.ready;
    Map<String, dynamic> data = storage.getItem('statusList');
    for (var each in data.keys) {
      for (var item in data[each]) {
        statusList[each].add(item);
      }
    }
    fetchAndParseSMS();
  }

  void fetchAndParseSMS() async {
    orderedTransactionSets = [];
    setState(() {}); // show loading indicator

    if (parser == null) {
      parser = SMSParser(statusList);
      await parser.readAndParse();
    }

    setState(() {
      orderedTransactionSets =
          parser.getOrderedTransactionSetsFor(currentMonth);
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
                        var chips;
                        for (var each in statusList.keys) {
                          if (statusList[each].contains(set.code)) {
                            chips = Chip(label: Text(each));
                          }
                        }

                        var average = parser.getAverageFor(set.code);

                        return ListTile(
                          leading: Chip(
                            label: Text(set.data.length.toString()),
                          ),
                          title: Text(
                            set.code,
                            style: Theme.of(context).textTheme.subtitle,
                          ),
                          subtitle: average > 0
                              ? Text('avg: ' + average.toStringAsFixed(2))
                              : null,
                          trailing: Column(children: [
                            Text(
                              set.total.toStringAsFixed(2),
                              style: TextStyle(
                                  fontSize: 18,
                                  color: average > 0
                                      ? (set.total > average
                                          ? Colors.red
                                          : Colors.green)
                                      : Colors.black),
                            ),
                            Text(average > 0
                                ? (set.total / average * 100)
                                        .toStringAsFixed(2) +
                                    '%'
                                : '')
                          ]),
                          dense: true,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (BuildContext context) {
                              return TransSetView(
                                  set: set,
                                  statusList: statusList,
                                  storage: storage);
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
