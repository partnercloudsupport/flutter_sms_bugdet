import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:sms/sms.dart';

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
  SMSParser parser;
  List<TransSet> orderedTransactionSets = [];
  Map<String, List<String>> statusList = {
    'Food': [],
    'Car': [],
    'Entertainment': [],
    'Restaurant': [],
    'Transport': [],
    'Travel': [],
    'Children': [],
  };
  final LocalStorage storage = new LocalStorage('MyHomePage');
  PageController _controller;

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
    print(statusList);
    parser = SMSParser(statusList);
    await fetchAndParseSMS();
    _controller =
        PageController(initialPage: parser.getMonths() - 1, keepPage: true);
  }

  Future fetchAndParseSMS() async {
    orderedTransactionSets = [];
    setState(() {}); // show loading indicator

    if (parser.transactions.length == 0) {
      print('Querying SMS...');
      SmsQuery query = new SmsQuery();
      List<SmsMessage> messages = await query.querySms(kinds: [
        SmsQueryKind.Inbox,
        //SmsQueryKind.Sent
      ], address: 'IhreBank');
      print('Fetched ${messages.length}');

      int amount = await parser.readAndParse(messages);
      print('compute done $amount');
    }

    setState(() {
      orderedTransactionSets =
          parser.getOrderedTransactionSetsFor(currentMonth);
      print(orderedTransactionSets.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
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
              ? Container(
                  height: size.height - 80,
                  child: PageView.builder(
                    physics: new AlwaysScrollableScrollPhysics(),
                    controller: _controller,
                    itemCount: parser.getMonths(),
                    itemBuilder: (BuildContext context, int index) {
                      currentMonth = parser.getMonthNr(index);
                      print('** PAGE $index month ${currentMonth.toString()}');
                      return buildListView(context);
                    },
                    onPageChanged: (int index) {
                      setState(() {
                        currentMonth = parser.getMonthNr(index);
                      });
                    },
                  ))
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
              child: Wrap(children: <Widget>[
                Icon(Icons.navigate_before),
                Text('Prev Month')
              ]),
              onPressed: () {
                _controller.previousPage(
                    duration: Duration(milliseconds: 500), curve: Curves.ease);
              },
            ),
            RaisedButton(
              child: Wrap(children: <Widget>[
                Text('Next Month'),
                Icon(Icons.navigate_next),
              ]),
              onPressed: nextMonth().isBefore(DateTime.now())
                  ? () {
                      _controller.nextPage(
                          duration: Duration(milliseconds: 1000),
                          curve: Curves.ease);
                    }
                  : null,
            )
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget buildListView(context) {
    orderedTransactionSets = parser.getOrderedTransactionSetsFor(currentMonth);
    return ConstrainedBox(
        constraints: const BoxConstraints.expand(),
//        child: Expanded(
        child: ListView(
            shrinkWrap: true,
            children: orderedTransactionSets.map((set) {
              List<Widget> chips = [];
              for (var each in statusList.keys) {
                if (statusList[each].contains(set.code)) {
                  chips.add(Chip(label: Text(each)));
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
                    : Wrap(children: chips),
                trailing: Column(children: [
                  Text(
                    set.total.toStringAsFixed(2),
                    style: TextStyle(
                        fontSize: 18,
                        color: average > 0
                            ? (set.total > average ? Colors.red : Colors.green)
                            : Colors.black),
                  ),
                  Text(average > 0
                      ? (set.total / average * 100).toStringAsFixed(2) + '%'
                      : '')
                ]),
                dense: true,
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (BuildContext context) {
                    return TransSetView(
                        set: set, statusList: statusList, storage: storage);
                  }));
                  fetchAndParseSMS();
                },
              );
            }).toList()));
  }

  DateTime nextMonth() {
    return DateTime(
        currentMonth.year, currentMonth.month + 1, currentMonth.day);
  }
}
