import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

import 'TransSet.dart';
import 'Transaction.dart';

class TransSetView extends StatefulWidget {
  final TransSet set;
  final Map<String, List<String>> statusList;
  final LocalStorage storage;

  const TransSetView({Key key, this.set, this.statusList, this.storage})
      : super(key: key);

  @override
  TransSetViewState createState() {
    return new TransSetViewState();
  }
}

class TransSetViewState extends State<TransSetView> {
  String selectedStatus;

  @override
  void initState() {
    super.initState();
    for (var each in widget.statusList.keys) {
      if (widget.statusList[each].contains(widget.set.code)) {
        selectedStatus = each;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.set.code),
          actions: <Widget>[
            Chip(label: Text(widget.set.total.toStringAsFixed(2)))
          ],
        ),
        body: Column(children: <Widget>[
          Expanded(
              child: ListView(
                  shrinkWrap: true,
                  children: widget.set.data.map((Transaction t) {
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
                  }).toList())),
          Row(
              children: widget.statusList.keys.map((status) {
            return ChoiceChip(
              label: Text(status),
              selected: selectedStatus == status,
              onSelected: (on) {
                print(status + ': ' + on.toString());
                setState(() {
                  selectedStatus = status;
                  for (var each in widget.statusList.keys) {
                    widget.statusList[each].remove(widget.set.code);
                  }
                  widget.statusList[status].add(widget.set.code);
                  print(widget.statusList.toString());
                  widget.storage.setItem('statusList', widget.statusList);
                });
              },
            );
          }).toList()),
        ]));
  }
}
