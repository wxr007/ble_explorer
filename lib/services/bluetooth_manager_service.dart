import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../data_center.dart';

class BluetoothManagerService {
  static final BluetoothManagerService _instance = BluetoothManagerService._internal();
  factory BluetoothManagerService() => _instance;
  BluetoothManagerService._internal();

  // 已连接的设备列表
  final List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothDevice> get connectedDevices => List.unmodifiable(_connectedDevices);

  // 设备连接状态流
  final StreamController<List<BluetoothDevice>> _connectedDevicesController = 
      StreamController<List<BluetoothDevice>>.broadcast();
  Stream<List<BluetoothDevice>> get connectedDevicesStream => _connectedDevicesController.stream;

  // 当前选中的通知特征
  BluetoothCharacteristic? _notifyCharacteristic;
  BluetoothCharacteristic? get notifyCharacteristic => _notifyCharacteristic;

  // 当前选中的写入特征
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;

  // 特征选择状态流
  final StreamController<void> _characteristicController = StreamController<void>.broadcast();
  Stream<void> get characteristicStream => _characteristicController.stream;

  // 添加已连接设备
  void addConnectedDevice(BluetoothDevice device) {
    if (!_connectedDevices.any((d) => d.remoteId.str == device.remoteId.str)) {
      _connectedDevices.add(device);
      _connectedDevicesController.add(List.unmodifiable(_connectedDevices));
      DataCenter().setBluetoothConnected(true);
      DataCenter().addBluetoothLog('设备已连接: ${device.remoteId.str}');
    }
  }

  // 移除已连接设备
  void removeConnectedDevice(BluetoothDevice device) {
    _connectedDevices.removeWhere((d) => d.remoteId.str == device.remoteId.str);
    _connectedDevicesController.add(List.unmodifiable(_connectedDevices));
    if (_connectedDevices.isEmpty) {
      DataCenter().setBluetoothConnected(false);
      _notifyCharacteristic = null;
      _writeCharacteristic = null;
    }
    DataCenter().addBluetoothLog('设备已断开: ${device.remoteId.str}');
  }

  // 断开所有设备
  Future<void> disconnectAll() async {
    for (var device in List.from(_connectedDevices)) {
      try {
        await device.disconnect();
      } catch (e) {
        print('断开设备失败: $e');
      }
    }
    _connectedDevices.clear();
    _connectedDevicesController.add([]);
    DataCenter().setBluetoothConnected(false);
    _notifyCharacteristic = null;
    _writeCharacteristic = null;
  }

  // 设置通知特征
  void setNotifyCharacteristic(BluetoothCharacteristic? characteristic) {
    _notifyCharacteristic = characteristic;
    _characteristicController.add(null);
  }

  // 设置写入特征
  void setWriteCharacteristic(BluetoothCharacteristic? characteristic) {
    _writeCharacteristic = characteristic;
    _characteristicController.add(null);
  }

  // 写入数据
  Future<bool> writeData(List<int> data) async {
    if (_writeCharacteristic == null) {
      DataCenter().addBluetoothLog('错误: 未选择写入特征');
      return false;
    }
    try {
      await _writeCharacteristic!.write(data);
      return true;
    } catch (e) {
      DataCenter().addBluetoothLog('写入失败: $e');
      return false;
    }
  }

  // 检查设备是否已连接
  bool isDeviceConnected(BluetoothDevice device) {
    return _connectedDevices.any((d) => d.remoteId.str == device.remoteId.str);
  }

  void dispose() {
    _connectedDevicesController.close();
    _characteristicController.close();
  }
}
