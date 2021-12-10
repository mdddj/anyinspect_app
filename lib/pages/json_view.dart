import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_json_viewer/flutter_json_viewer.dart';

void pushToJsonView(BuildContext context, String json) {
  Navigator.push(context,
      CupertinoPageRoute(builder: (_) => JsonViewPage(jsonString: json)));
}

class JsonViewPage extends StatelessWidget {
  final String jsonString;
  const JsonViewPage({Key? key, required this.jsonString}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: JsonViewWidget(
          jsonString: jsonString,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Icon(Icons.close),
      ),
    );
  }
}

class JsonViewWidget extends StatelessWidget {
  final String jsonString;
  const JsonViewWidget({Key? key, required this.jsonString}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _isMap()
        ? SingleChildScrollView(child: JsonViewer(jsonDecode(jsonString)))
        : Text(jsonString);
  }

  /// 是否可以转换为map
  bool _isMap() {
    var r = false;
    try {
      jsonDecode(jsonString);
      r = true;
    } catch (e) {
      r = false;
    }
    return r;
  }
}
