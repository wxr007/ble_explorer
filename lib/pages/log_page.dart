import 'package:flutter/material.dart';
import '../data_center.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final TextEditingController _bluetoothLogController = TextEditingController();
  final TextEditingController _baseStationLogController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bluetoothLogController.text = DataCenter().getBluetoothLogsText();
    _baseStationLogController.text = DataCenter().getBaseStationLogsText();

    // 监听日志更新
    DataCenter().bluetoothLogStream.listen((log) {
      if (mounted) {
        setState(() {
          _bluetoothLogController.text = DataCenter().getBluetoothLogsText();
          _scrollToBottom(_bluetoothLogController);
        });
      }
    });

    DataCenter().baseStationLogStream.listen((log) {
      if (mounted) {
        setState(() {
          _baseStationLogController.text = DataCenter().getBaseStationLogsText();
          _scrollToBottom(_baseStationLogController);
        });
      }
    });
  }

  void _scrollToBottom(TextEditingController controller) {
    // 滚动到文本底部
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: '清空日志',
            onPressed: () {
              DataCenter().clearBluetoothLogs();
              DataCenter().clearBaseStationLogs();
              setState(() {
                _bluetoothLogController.clear();
                _baseStationLogController.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 蓝牙日志 - 占据一半空间
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                    child: const Text(
                      '蓝牙日志',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _bluetoothLogController,
                      maxLines: null,
                      readOnly: true,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(8),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 基站日志 - 占据一半空间
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                    child: const Text(
                      '基站日志',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _baseStationLogController,
                      maxLines: null,
                      readOnly: true,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(8),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
