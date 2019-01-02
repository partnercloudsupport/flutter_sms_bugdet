import 'package:flutter/material.dart';

import 'TransSet.dart';
import 'Transaction.dart';

class TransSetView extends StatelessWidget {
  final TransSet set;

  const TransSetView({Key key, this.set}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(set.code),
          actions: <Widget>[Chip(label: Text(set.total.toStringAsFixed(2)))],
        ),
        body: Column(children: <Widget>[
          Expanded(
              child: ListView(
                  shrinkWrap: true,
                  children: set.data.map((Transaction t) {
                    return ListTile(
                      leading: Chip(
                        label: Text(t.date.toString().substring(0, 10)),
                      ),
                      title: Text(
                        t.note,
                        style: Theme.of(context).textTheme.title,
                      ),
                      trailing: Text(t.amount.toStringAsFixed(2)),
                      dense: true,
                    );
                  }).toList()))
        ]));
  }
}
