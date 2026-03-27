import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../data_center.dart';

class NtripClientService {
  static final NtripClientService _instance = NtripClientService._internal();
  factory NtripClientService() => _instance;
  NtripClientService._internal();

  Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  StreamSubscription? _subscription;

  // 连接状态流，用于通知页面更新
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  Future<void> connect({
    required String host,
    required int port,
    required String mountpoint,
    required String username,
    required String password,
  }) async {
    if (_isConnected || _isConnecting) {
      DataCenter().addBaseStationLog('NTRIP 已在连接中或已连接');
      return;
    }

    _isConnecting = true;
    _connectionStateController.add(false);
    DataCenter().addBaseStationLog('正在连接 NTRIP 基站: $host:$port/$mountpoint');

    try {
      // 建立 TCP 连接
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      
      // 构建 NTRIP 请求头
      final auth = _encodeBase64('$username:$password');
      final request = 
        'GET /$mountpoint HTTP/1.1\r\n'
        'Host: $host:$port\r\n'
        'Ntrip-Version: Ntrip/2.0\r\n'
        'User-Agent: BLEExplorer/1.0\r\n'
        'Authorization: Basic $auth\r\n'
        'Connection: close\r\n'
        '\r\n';

      _socket!.write(request);
      await _socket!.flush();

      DataCenter().addBaseStationLog('已发送 NTRIP 认证请求');

      // 监听响应
      _subscription = _socket!.listen(
        (data) {
          _handleData(data);
        },
        onError: (error) {
          DataCenter().addBaseStationLog('NTRIP 连接错误: $error');
          disconnect();
        },
        onDone: () {
          DataCenter().addBaseStationLog('NTRIP 连接已关闭');
          disconnect();
        },
      );

      // 等待服务器响应
      await Future.delayed(const Duration(seconds: 2));
      
      if (_socket != null) {
        _isConnected = true;
        _isConnecting = false;
        _connectionStateController.add(true);
        DataCenter().setBaseStationConnected(true);
        DataCenter().addBaseStationLog('NTRIP 连接成功');
      }
    } catch (e) {
      _isConnecting = false;
      _connectionStateController.add(false);
      DataCenter().addBaseStationLog('NTRIP 连接失败: $e');
      rethrow;
    }
  }

  void _handleData(Uint8List data) {
    final length = data.length;
    
    // 根据设置决定是否显示十六进制数据
    if (DataCenter().showHexData) {
      final hexString = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      DataCenter().addBaseStationLog('收到数据 [$length bytes]: $hexString');
    } else {
      DataCenter().addBaseStationLog('收到数据 [$length bytes]');
    }
    
    // 检查是否是 RTCM 数据 (以 0xD3 开头)
    if (data.isNotEmpty && data[0] == 0xD3) {
      DataCenter().addBaseStationLog('RTCM 数据包接收成功');
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    
    _socket?.close();
    _socket = null;
    
    _isConnected = false;
    _isConnecting = false;
    
    _connectionStateController.add(false);
    DataCenter().setBaseStationConnected(false);
    DataCenter().addBaseStationLog('NTRIP 已断开连接');
  }

  String _encodeBase64(String input) {
    final bytes = input.codeUnits;
    return _base64Encode(bytes);
  }

  String _base64Encode(List<int> bytes) {
    const String base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final StringBuffer result = StringBuffer();
    
    int i = 0;
    while (i < bytes.length) {
      int b1 = bytes[i++];
      int b2 = i < bytes.length ? bytes[i++] : 0;
      int b3 = i < bytes.length ? bytes[i++] : 0;

      int bitmap = (b1 << 16) | (b2 << 8) | b3;

      result.write(base64Chars[(bitmap >> 18) & 0x3F]);
      result.write(base64Chars[(bitmap >> 12) & 0x3F]);
      result.write(i - 2 < bytes.length ? base64Chars[(bitmap >> 6) & 0x3F] : '=');
      result.write(i - 1 < bytes.length ? base64Chars[bitmap & 0x3F] : '=');
    }
    
    return result.toString();
  }

  void dispose() {
    _connectionStateController.close();
  }
}
