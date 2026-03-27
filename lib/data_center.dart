import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class DataCenter {
  static final DataCenter _instance = DataCenter._internal();
  factory DataCenter() => _instance;
  DataCenter._internal() {
    _initPrefs();
  }

  SharedPreferences? _prefs;

  // 日志最大行数
  static const int maxLogLines = 200;

  // SharedPreferences keys
  static const String _keyBaseStationHistory = 'base_station_history';
  static const String _keyLastBaseStationConfig = 'last_base_station_config';
  static const String _keyShowHexData = 'show_hex_data';
  static const String _keyLastBluetoothScan = 'last_bluetooth_scan';
  static const String _keyBluetoothScanResults = 'bluetooth_scan_results';

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
  List<Map<String, String>> _baseStationHistory = [];
  List<Map<String, String>> get baseStationHistory => List.unmodifiable(_baseStationHistory);

  // 蓝牙扫描结果缓存
  List<Map<String, dynamic>> _bluetoothScanResults = [];
  List<Map<String, dynamic>> get bluetoothScanResults => List.unmodifiable(_bluetoothScanResults);

  // 当前蓝牙连接状态
  bool _isBluetoothConnected = false;
  bool get isBluetoothConnected => _isBluetoothConnected;

  // 当前基站连接状态
  bool _isBaseStationConnected = false;
  bool get isBaseStationConnected => _isBaseStationConnected;

  // 是否显示十六进制数据（默认关闭）
  bool _showHexData = false;
  bool get showHexData => _showHexData;

  // 十六进制显示状态流
  final StreamController<bool> _showHexDataController = StreamController<bool>.broadcast();
  Stream<bool> get showHexDataStream => _showHexDataController.stream;

  // 上次蓝牙扫描时间
  DateTime? _lastBluetoothScanTime;
  DateTime? get lastBluetoothScanTime => _lastBluetoothScanTime;

  // 当前选中的历史记录索引
  int _selectedHistoryIndex = -1;
  int get selectedHistoryIndex => _selectedHistoryIndex;

  // 初始化 SharedPreferences
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFromPrefs();
  }

  // 从 SharedPreferences 加载数据
  Future<void> _loadFromPrefs() async {
    if (_prefs == null) return;

    // 加载基站历史记录
    final historyJson = _prefs!.getString(_keyBaseStationHistory);
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _baseStationHistory = decoded.map((e) => Map<String, String>.from(e)).toList();
      } catch (e) {
        _baseStationHistory = [];
      }
    }

    // 加载十六进制显示设置（默认 false）
    _showHexData = _prefs!.getBool(_keyShowHexData) ?? false;

    // 加载上次蓝牙扫描时间
    final lastScanMillis = _prefs!.getInt(_keyLastBluetoothScan);
    if (lastScanMillis != null) {
      _lastBluetoothScanTime = DateTime.fromMillisecondsSinceEpoch(lastScanMillis);
    }

    // 加载蓝牙扫描结果
    final scanResultsJson = _prefs!.getString(_keyBluetoothScanResults);
    if (scanResultsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(scanResultsJson);
        _bluetoothScanResults = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        _bluetoothScanResults = [];
      }
    }
  }

  // 保存基站历史记录到本地
  Future<void> _saveHistoryToPrefs() async {
    if (_prefs == null) return;
    final historyJson = jsonEncode(_baseStationHistory);
    await _prefs!.setString(_keyBaseStationHistory, historyJson);
  }

  // 设置十六进制显示
  Future<void> setShowHexData(bool show) async {
    _showHexData = show;
    _showHexDataController.add(show);
    if (_prefs != null) {
      await _prefs!.setBool(_keyShowHexData, show);
    }
  }

  // 保存当前基站配置
  Future<void> saveLastBaseStationConfig(Map<String, String> config) async {
    if (_prefs == null) return;
    final configJson = jsonEncode(config);
    await _prefs!.setString(_keyLastBaseStationConfig, configJson);
  }

  // 获取上次基站配置
  Map<String, String>? getLastBaseStationConfig() {
    if (_prefs == null) return null;
    final configJson = _prefs!.getString(_keyLastBaseStationConfig);
    if (configJson == null) return null;
    try {
      final Map<String, dynamic> decoded = jsonDecode(configJson);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return null;
    }
  }

  // 更新蓝牙扫描时间
  Future<void> updateLastBluetoothScanTime() async {
    _lastBluetoothScanTime = DateTime.now();
    if (_prefs != null) {
      await _prefs!.setInt(_keyLastBluetoothScan, _lastBluetoothScanTime!.millisecondsSinceEpoch);
    }
  }

  // 保存蓝牙扫描结果
  Future<void> saveBluetoothScanResults(List<Map<String, dynamic>> results) async {
    _bluetoothScanResults = results;
    if (_prefs != null) {
      final resultsJson = jsonEncode(results);
      await _prefs!.setString(_keyBluetoothScanResults, resultsJson);
    }
  }

  // 获取蓝牙扫描结果
  List<Map<String, dynamic>> getBluetoothScanResults() {
    return _bluetoothScanResults;
  }

  // 检查是否需要重新扫描（超过30秒）
  bool shouldRescanBluetooth() {
    if (_lastBluetoothScanTime == null) return true;
    final diff = DateTime.now().difference(_lastBluetoothScanTime!);
    return diff.inSeconds > 30;
  }

  // 设置选中的历史记录索引
  void setSelectedHistoryIndex(int index) {
    _selectedHistoryIndex = index;
  }

  // 导出配置到文件
  Future<String?> exportConfig() async {
    // 先准备配置数据
    final config = {
      'baseStationHistory': _baseStationHistory,
      'lastBaseStationConfig': getLastBaseStationConfig(),
      'showHexData': _showHexData,
      'exportTime': DateTime.now().toIso8601String(),
    };
    final configJson = jsonEncode(config);
    
    // 生成日期时间格式的文件名: 20240327_143052
    final now = DateTime.now();
    final dateTimeStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    try {
      // 获取下载目录
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final fileName = 'ble_explorer_config_$dateTimeStr.json';
      final filePath = '${directory.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsString(configJson);
      
      return filePath;
    } catch (e) {
      print('导出配置失败: $e');
      // 如果外部存储失败，尝试使用应用文档目录
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'ble_explorer_config_$dateTimeStr.json';
        final filePath = '${directory.path}/$fileName';
        
        final file = File(filePath);
        await file.writeAsString(configJson);
        
        return filePath;
      } catch (e2) {
        print('备用导出也失败: $e2');
        return null;
      }
    }
  }

  // 获取配置文件路径（用于分享）
  Future<String?> getConfigFilePath() async {
    return await exportConfig();
  }

  // 从文件导入配置
  Future<bool> importConfig(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final configJson = await file.readAsString();
      final config = jsonDecode(configJson);

      // 导入基站历史记录
      if (config['baseStationHistory'] != null) {
        final List<dynamic> history = config['baseStationHistory'];
        _baseStationHistory = history.map((e) => Map<String, String>.from(e)).toList();
        await _saveHistoryToPrefs();
      }

      // 导入上次基站配置
      if (config['lastBaseStationConfig'] != null) {
        final Map<String, dynamic> lastConfig = config['lastBaseStationConfig'];
        await saveLastBaseStationConfig(
          lastConfig.map((key, value) => MapEntry(key, value.toString())),
        );
      }

      // 导入十六进制显示设置
      if (config['showHexData'] != null) {
        await setShowHexData(config['showHexData'] as bool);
      }

      return true;
    } catch (e) {
      print('导入配置失败: $e');
      return false;
    }
  }

  // 添加蓝牙日志
  void addBluetoothLog(String log) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $log';
    _bluetoothLogs.add(logEntry);
    
    // 限制日志行数
    if (_bluetoothLogs.length > maxLogLines) {
      _bluetoothLogs.removeAt(0);
    }
    
    _bluetoothLogController.add(logEntry);
  }

  // 添加基站日志
  void addBaseStationLog(String log) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $log';
    _baseStationLogs.add(logEntry);
    
    // 限制日志行数
    if (_baseStationLogs.length > maxLogLines) {
      _baseStationLogs.removeAt(0);
    }
    
    _baseStationLogController.add(logEntry);
  }

  // 添加基站历史记录
  Future<void> addBaseStationHistory(Map<String, String> history) async {
    // 检查是否已存在相同记录
    final exists = _baseStationHistory.any((h) =>
      h['host'] == history['host'] &&
      h['port'] == history['port'] &&
      h['mountpoint'] == history['mountpoint']
    );
    if (!exists) {
      _baseStationHistory.add(history);
      await _saveHistoryToPrefs();
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
    _showHexDataController.close();
  }
}
