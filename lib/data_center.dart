import 'dart:async';

class DataCenter {
  static final DataCenter _instance = DataCenter._internal();
  factory DataCenter() => _instance;
  DataCenter._internal();

  // 蓝牙日志流
  final StreamController<String> _bluetoothLogController = StreamController<String>.broadcast();
  Stream<String> get bluetoothLogStream => _bluetoothLogController.stream;

  // 基站日志流
  final StreamController<String> _baseStationLogController = StreamController<String>.broadcast();
  Stream<String> get baseStationLogStream => _baseStationLogController.stream;

  // 蓝牙日志列表
  final List<String> _bluetoothLogs = [];
  List<String> get bluetoothLogs => List.unmodifiable(_bluetoothLogs);

  // 基站日志列表
  final List<String> _baseStationLogs = [];
  List<String> get baseStationLogs => List.unmodifiable(_baseStationLogs);

  // 基站连接历史
  final List<Map<String, String>> _baseStationHistory = [];
  List<Map<String, String>> get baseStationHistory => List.unmodifiable(_baseStationHistory);

  // 当前蓝牙连接状态
  bool _isBluetoothConnected = false;
  bool get isBluetoothConnected => _isBluetoothConnected;

  // 当前基站连接状态
  bool _isBaseStationConnected = false;
  bool get isBaseStationConnected => _isBaseStationConnected;

  // 添加蓝牙日志
  void addBluetoothLog(String log) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $log';
    _bluetoothLogs.add(logEntry);
    _bluetoothLogController.add(logEntry);
  }

  // 添加基站日志
  void addBaseStationLog(String log) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $log';
    _baseStationLogs.add(logEntry);
    _baseStationLogController.add(logEntry);
  }

  // 添加基站历史记录
  void addBaseStationHistory(Map<String, String> history) {
    // 检查是否已存在相同记录
    final exists = _baseStationHistory.any((h) =>
      h['host'] == history['host'] &&
      h['port'] == history['port'] &&
      h['mountpoint'] == history['mountpoint']
    );
    if (!exists) {
      _baseStationHistory.add(history);
    }
  }

  // 设置蓝牙连接状态
  void setBluetoothConnected(bool connected) {
    _isBluetoothConnected = connected;
    addBluetoothLog(connected ? '蓝牙已连接' : '蓝牙已断开');
  }

  // 设置基站连接状态
  void setBaseStationConnected(bool connected) {
    _isBaseStationConnected = connected;
    addBaseStationLog(connected ? '基站已连接' : '基站已断开');
  }

  // 清空蓝牙日志
  void clearBluetoothLogs() {
    _bluetoothLogs.clear();
  }

  // 清空基站日志
  void clearBaseStationLogs() {
    _baseStationLogs.clear();
  }

  // 获取所有蓝牙日志文本
  String getBluetoothLogsText() {
    return _bluetoothLogs.join('\n');
  }

  // 获取所有基站日志文本
  String getBaseStationLogsText() {
    return _baseStationLogs.join('\n');
  }

  // 释放资源
  void dispose() {
    _bluetoothLogController.close();
    _baseStationLogController.close();
  }
}
