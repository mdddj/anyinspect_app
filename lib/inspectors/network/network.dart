import 'dart:convert';
import 'dart:ui';
import 'package:anyinspect_app/pages/json_view.dart';
import 'package:anyinspect_client/anyinspect_client.dart';
import 'package:anyinspect_ui/anyinspect_ui.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import 'network_record.dart';

class NetworkInspector extends StatefulWidget {
  final AnyInspectPlugin plugin;

  const NetworkInspector(
    this.plugin, {
    Key? key,
  }) : super(key: key);

  @override
  State<NetworkInspector> createState() => _NetworkInspectorState();
}

class _NetworkInspectorState extends State<NetworkInspector>
    with AnyInspectPluginEventListener {
  final List<NetworkRecord> _records = [];
  List<String> _igList = [];

  NetworkRecord? _selectedRecord;

  @override
  void initState() {
    widget.plugin.addEventListener(this);
    super.initState();
    loadIgSuffixList();
  }

  @override
  void dispose() {
    widget.plugin.removeEventListener(this);
    super.dispose();
  }

  // 加载忽略后缀列表
  void loadIgSuffixList() {
    Hive.openBox('setting').then((value) {
      final _str = value.get('ig_suffix_str').toString();
      if (_str.isNotEmpty) {
        final _arr = _str.split(',');
        if (_arr.isNotEmpty) {
          _igList = _arr;
        }
      }
    });
  }

  // 判断是不是需要被忽略的uri
  bool _isIgSuffix(String uri) {
    var _r = false;
    for (var element in _igList) {
      final _index = uri.lastIndexOf(element);
      if (_index >= 0) {
        _r = true;
        continue;
      }
    }
    return _r;
  }

  @override
  void onEvent(AnyInspectPluginEvent event) {
    if (event.name == 'request') {
      _onRequest(NetworkRecordRequest.fromJson(event.arguments));
    } else if (event.name == 'response') {
      _onResponse(NetworkRecordResponse.fromJson(event.arguments));
    }
  }

  void _onRequest(NetworkRecordRequest request) {
    NetworkRecord record = NetworkRecord(
      id: request.requestId,
      request: request,
    );
    final uri = record.request?.uri;
    final _isIgUri = _isIgSuffix(uri ?? '');
    if (!_isIgUri) {
      _records.add(record);
      setState(() {});
    }
  }

  void _onResponse(NetworkRecordResponse response) {
    int recordIndex = _records.indexWhere((e) => e.id == response.requestId);
    if (recordIndex != -1) {
      _records[recordIndex].response = response;
      setState(() {});
    }
  }

  List<DataColumn> _buildDataColumns() {
    return const [
      DataColumn(
        label: Text('Uri'),
      ),
      DataColumn(
        label: Text('Status'),
      ),
      DataColumn(
        label: Text('Duration'),
      ),
      DataColumn(
        label: Text('Timestamp'),
      ),
    ];
  }

  List<DataRow> _buildDataRows() {
    List<DataRow> rows = [];
    for (var record in _records) {
      NetworkRecordRequest request = record.request!;
      NetworkRecordResponse? response = record.response;

      TextStyle defaultTextStyle = TextStyle(
        color: Theme.of(context).textTheme.bodyText2!.color!,
      );

      if (response != null && response.statusCode >= 400) {
        defaultTextStyle = defaultTextStyle.copyWith(color: Colors.red);
      }

      List<DataCell> cells = [
        DataCell(
          Builder(
            builder: (_) {
              Color bgColor = Colors.black;
              switch (request.method.toLowerCase()) {
                case 'post':
                  bgColor = const Color(0xff49cc90);
                  break;
                case "get":
                  bgColor = const Color(0xff61affe);
                  break;
                case "put":
                  bgColor = const Color(0xfffca130);
                  break;
                case "delete":
                  bgColor = const Color(0xfff93e3e);
                  break;
                case "head":
                  bgColor = const Color(0xff9012fe);
                  break;
                case "patch":
                  bgColor = const Color(0xff50e3c2);
                  break;
                case "disabled":
                  bgColor = const Color(0xffebebeb);
                  break;
                case "options":
                  bgColor = const Color(0xff0d5aa7);
                  break;
              }

              var showUri = request.uri
                  .replaceAll('https://${request.headers['host'] ?? ''}', '');
              return Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.only(
                      left: 4,
                      right: 4,
                      top: 2,
                      bottom: 2,
                    ),
                    child: Text(
                      request.method,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      showUri,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: defaultTextStyle,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        DataCell(
          Builder(
            builder: (_) {
              if (response != null) {
                return Text(
                  '${response.statusCode}',
                  style: defaultTextStyle,
                );
              }
              return const Text(
                'fetching...',
                style: TextStyle(color: Colors.teal),
              );
            },
          ),
        ),
        DataCell(
          Builder(
            builder: (_) {
              if (response != null) {
                Duration duration = Duration(
                  milliseconds: response.timeStamp - request.timeStamp,
                );
                return Text(
                  '${duration.inMilliseconds} ms',
                  style: defaultTextStyle.copyWith(
                      color: _getMillisecondsColors(duration.inMilliseconds)),
                );
              }
              return Container();
            },
          ),
        ),
        DataCell(
          Text(
            DateFormat('HH:mm:ss').format(
              DateTime.fromMillisecondsSinceEpoch(request.timeStamp),
            ),
            style: defaultTextStyle,
          ),
        ),
      ];

      DataRow dataRow = DataRow(
        selected: _selectedRecord?.id == record.id,
        onSelectChanged: (bool? selected) {
          if (selected != null && selected) {
            _selectedRecord = record;
          }
          setState(() {});
        },
        cells: cells,
      );
      rows.add(dataRow);
    }
    return rows;
  }

  // 根据请求耗时显示对应的颜色
  Color _getMillisecondsColors(int milliseconds) {
    Color color = Colors.green;
    if (milliseconds >= 2000 && milliseconds < 10000) {
      color = Colors.orange;
    } else if (milliseconds >= 10000) {
      color = Colors.red;
    }
    return color;
  }

  Widget _buildSelectedRecordViewer(BuildContext context) {
    NetworkRecordRequest request = _selectedRecord!.request!;
    NetworkRecordResponse? response = _selectedRecord!.response;

    ///从uri中获取参数

    String queryMapString = '';
    var queryMap = {};
    try {
      final uriContent = Uri.decodeComponent(request.uri);
      final uri = Uri.dataFromString(uriContent);
      queryMap = uri.queryParameters;
      queryMapString = jsonEncode(queryMap);
    } catch (e, s) {
      print(e);
      print(s);
    }

    return DataViewer(
      children: [
        DataViewerSection(
          title: const Text('General'),
          children: [
            DataViewerItem(
              title: const Text('Request URL'),
              detailText: SelectableText(
                Uri.decodeComponent(request.uri),
                onTap: () {
                  _copy(Uri.decodeComponent(request.uri));
                },
              ),
            ),
            DataViewerItem(
              title: const Text('Request Method'),
              detailText: SelectableText(request.method),
            ),
            if (response != null)
              DataViewerItem(
                title: const Text('Status Code'),
                detailText: SelectableText(
                  '${response.statusCode}',
                  style: TextStyle(
                      color: response.statusCode != 200
                          ? Colors.red
                          : Colors.green,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        DataViewerSection(
          title: const Text('Request Headers'),
          children: [
            for (var key in (request.headers.keys))
              DataViewerItem(
                title: SelectableText(key),
                detailText: SelectableText(
                  '${request.headers[key]}',
                  onTap: () {
                    _copy(request.headers[key]);
                  },
                ),
              ),
          ],
        ),
        DataViewerSection(
          title: _jsonTitle(queryMapString, 'Request Body'),
          children: [
            if (request.body != null && request.body.toString().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(width: .5, color: Colors.green))),
                child: JsonViewWidget(
                  jsonString: request.body.toString(),
                ),
              ),
            if (queryMap.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: JsonViewWidget(
                  jsonString: queryMapString,
                ),
              )

            // Padding(
            //   padding: const EdgeInsets.all(14.0),
            //   child: SelectableText(
            //     queryMapString,
            //     onTap: (){
            //       _copy(queryMapString);
            //     },
            //   ),
            // )
          ],
        ),
        if (response != null)
          DataViewerSection(
            title: const Text('Response Headers'),
            children: [
              for (var key in (response.headers.keys))
                DataViewerItem(
                  title: SelectableText(key),
                  detailText: SelectableText(
                    '${response.headers[key]}',
                    onTap: () {
                      _copy(response.headers[key]);
                    },
                  ),
                ),
            ],
          ),
        if (response != null)
          DataViewerSection(
            title: _jsonTitle(response.body, 'Response Body'),
            children: [
              if (response.body != null)
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: JsonViewWidget(
                    jsonString: response.body,
                  ),
                )
              // Padding(
              //   padding: const EdgeInsets.all(14),
              //   child: SelectableText(
              //     response.body,
              //     onTap: (){
              //       _copy(response.body);
              //     },
              //   ),
              // ),
            ],
          ),
      ],
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showMessage('复制成功');
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _jsonTitle(
    String json,
    String title,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
                onPressed: () {
                  _copy(json);
                },
                icon: const Icon(
                  Icons.copy,
                  size: 14,
                  color: Colors.blue,
                )),
            IconButton(
                onPressed: () {
                  pushToJsonView(context, json);
                },
                icon: const Icon(Icons.code_rounded,
                    size: 14, color: Colors.blue))
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Inspector(
          child: SizedBox(
            height: double.infinity,
            child: DataTable(
              initialColumnWeights: const [3, 1, 1, 1],
              columns: _buildDataColumns(),
              rows: _buildDataRows(),
            ),
          ),
          detailView: _selectedRecord == null
              ? null
              : _buildSelectedRecordViewer(context),
        ),
        floatingActionButton: CircleAvatar(
          backgroundColor: Colors.black12,
          child: IconButton(
              onPressed: () {
                _records.clear();
                setState(() {});
              },
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.red,
              )),
        ));
  }
}
