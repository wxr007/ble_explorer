import 'dart:async';
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
  final ScrollController _bluetoothScrollController = ScrollController();
  final ScrollController _baseStationScrollController = ScrollController();

  StreamSubscription<String>? _bluetoothLogSubscription;
  StreamSubscription<String>? _baseStationLogSubscription;
  StreamSubscription<bool>? _showHexDataSubscription;

  bool _showHexData = false;

  @override
  void initState() {
    super.initState();
    _showHexData = DataCenter().showHexData;
    _bluetoothLogController.text = DataCenter().getBluetoothLogsText();
    _baseStationLogController.text = DataCenter().getBaseStationLogsText();

    // 监听日志更新
    _bluetoothLogSubscription = DataCenter().bluetoothLogStream.listen((log) {
      if (mounted) {
        setState(() {
          _bluetoothLogController.text = DataCenter().getBluetoothLogsText();
        });
        _scrollToBottom(_bluetoothScrollController);
      }
    });

    _baseStationLogSubscription = DataCenter().baseStationLogStream.listen((log) {
      if (mounted) {
        setState(() {
          _baseStationLogController.text = DataCenter().getBaseStationLogsText();
        });
        _scrollToBottom(_baseStationScrollController);
      }
    });

    // 监听十六进制显示设置变化
    _showHexDataSubscription = DataCenter().showHexDataStream.listen((show) {
      if (mounted) {
        setState(() {
          _showHexData = show;
        });
      }
    });

    // 初始滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(_bluetoothScrollController);
      _scrollToBottom(_baseStationScrollController);
    });
  }

  @override
  void dispose() {
    _bluetoothLogSubscription?.cancel();
    _baseStationLogSubscription?.cancel();
    _showHexDataSubscription?.cancel();
    _bluetoothScrollController.dispose();
    _baseStationScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom(ScrollController controller) {
    if (controller.hasClients) {
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleHexDisplay(bool value) {
    DataCenter().setShowHexData(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          // 十六进制显示开关
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '十六进制',
                style: TextStyle(fontSize: 12, color: Colors.black),
              ),
              Switch(
                value: _showHexData,
                onChanged: _toggleHexDisplay,
                activeColor: Colors.black,
              ),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.black),
            label: const Text('清空', style: TextStyle(fontSize: 12, color: Colors.black)),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '蓝牙日志',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '(${DataCenter().bluetoothLogs.length}/${DataCenter.maxLogLines})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bluetoothScrollController,
                      child: TextField(
                        controller: _bluetoothLogController,
                        maxLines: null,
                        readOnly: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(8),
                          isDense: true,
                        ),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '基站日志',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '(${DataCenter().baseStationLogs.length}/${DataCenter.maxLogLines})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _baseStationScrollController,
                      child: TextField(
                        controller: _baseStationLogController,
                        maxLines: null,
                        readOnly: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(8),
                          isDense: true,
                        ),
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
