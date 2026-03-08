import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const BLEExplorerApp());
}

class BLEExplorerApp extends StatelessWidget {
  const BLEExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Explorer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DeviceScanPage(),
    );
  }
}

class DeviceScanPage extends StatefulWidget {
  const DeviceScanPage({super.key});

  @override
  State<DeviceScanPage> createState() => _DeviceScanPageState();
}

class _DeviceScanPageState extends State<DeviceScanPage> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    if (bluetoothScan.isGranted && bluetoothConnect.isGranted && location.isGranted) {
      _startScan();
    } else {
      setState(() {
        _errorMessage = '需要蓝牙和位置权限才能扫描设备';
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
      _errorMessage = null;
    });

    try {
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _devices = results.map((r) => r.device).toList();
        });
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      setState(() {
        _errorMessage = '扫描失败: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  String _getDeviceName(BluetoothDevice device) {
    return device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';
  }

  int? _getRssi(List<ScanResult> results, String address) {
    for (var r in results) {
      if (r.device.remoteId.str == address) {
        return r.rssi;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 设备扫描'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _requestPermissionsAndScan,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[100],
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_isScanning) const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(_isScanning ? '扫描中...' : '共发现 ${_devices.length} 个设备'),
              ],
            ),
          ),
          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? const Center(child: Text('点击右上角刷新按钮开始扫描'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return FutureBuilder<List<ScanResult>>(
                        future: FlutterBluePlus.scanResults.first,
                        builder: (context, snapshot) {
                          final rssi = _getRssi(snapshot.data ?? [], device.remoteId.str);
                          return ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(_getDeviceName(device)),
                            subtitle: Text('MAC: ${device.remoteId.str}${rssi != null ? "  RSSI: $rssi dBm" : ""}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeviceDetailPage(device: device),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DeviceDetailPage extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDetailPage({super.key, required this.device});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  List<BluetoothService> _services = [];
  bool _isConnected = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.device.connect(timeout: const Duration(seconds: 10));
      _isConnected = true;
      await _loadServices();
    } catch (e) {
      setState(() {
        _errorMessage = '连接失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadServices() async {
    try {
      final services = await widget.device.discoverServices();
      setState(() {
        _services = services;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '获取服务失败: $e';
      });
    }
  }

  String _getPropertiesString(BluetoothCharacteristic characteristic) {
    List<String> props = [];
    if (characteristic.properties.read) props.add('R');
    if (characteristic.properties.write) props.add('W');
    if (characteristic.properties.writeWithoutResponse) props.add('W*');
    if (characteristic.properties.notify) props.add('N');
    if (characteristic.properties.indicate) props.add('I');
    return props.isEmpty ? '无' : props.join(' | ');
  }

  @override
  void dispose() {
    if (_isConnected) {
      widget.device.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isNotEmpty 
            ? widget.device.platformName 
            : '设备详情'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: _isConnected ? Colors.green[100] : Colors.orange[100],
                      child: Row(
                        children: [
                          Icon(_isConnected ? Icons.check_circle : Icons.warning,
                              color: _isConnected ? Colors.green : Colors.orange),
                          const SizedBox(width: 8),
                          Text(_isConnected ? '已连接' : '未连接'),
                        ],
                      ),
                    ),
                    if (_isConnected)
                      Expanded(
                        child: _services.isEmpty
                            ? const Center(child: Text('未发现服务'))
                            : ListView.builder(
                                itemCount: _services.length,
                                itemBuilder: (context, serviceIndex) {
                                  final service = _services[serviceIndex];
                                  return ExpansionTile(
                                    title: Text('服务 ${serviceIndex + 1}'),
                                    subtitle: Text('UUID: ${service.uuid}'),
                                    children: service.characteristics.map((char) {
                                      return ListTile(
                                        leading: const Icon(Icons.tune),
                                        title: const Text('特征'),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('UUID: ${char.uuid}'),
                                            Text('属性: ${_getPropertiesString(char)}',
                                                style: TextStyle(
                                                    color: Colors.blue[700], fontSize: 12)),
                                          ],
                                        ),
                                        trailing: (char.properties.notify || char.properties.indicate)
                                            ? const Icon(Icons.notifications_active, color: Colors.orange)
                                            : null,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CharacteristicPage(
                                                device: widget.device,
                                                service: service,
                                                characteristic: char,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                      ),
                  ],
                ),
    );
  }
}

class CharacteristicPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothService service;
  final BluetoothCharacteristic characteristic;

  const CharacteristicPage({
    super.key,
    required this.device,
    required this.service,
    required this.characteristic,
  });

  @override
  State<CharacteristicPage> createState() => _CharacteristicPageState();
}

class _CharacteristicPageState extends State<CharacteristicPage> {
  String? _readValue;
  final TextEditingController _writeController = TextEditingController();
  final List<String> _notifications = [];
  bool _isSubscribed = false;

  Future<void> _read() async {
    try {
      final value = await widget.characteristic.read();
      setState(() {
        _readValue = value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
      });
    } catch (e) {
      _showSnackBar('读取失败: $e');
    }
  }

  Future<void> _write() async {
    if (_writeController.text.isEmpty) return;
    try {
      final bytes = _writeController.text.codeUnits;
      await widget.characteristic.write(bytes);
      _showSnackBar('写入成功');
    } catch (e) {
      _showSnackBar('写入失败: $e');
    }
  }

  Future<void> _toggleNotify() async {
    if (_isSubscribed) {
      await widget.characteristic.setNotifyValue(false);
      setState(() {
        _isSubscribed = false;
      });
      _showSnackBar('已取消订阅');
    } else {
      await widget.characteristic.setNotifyValue(true);
      widget.characteristic.lastValueStream.listen((value) {
        setState(() {
          final hex = value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
          String text = '';
          try {
            text = String.fromCharCodes(value);
          } catch (_) {}
          _notifications.insert(0, '$hex${text.isNotEmpty ? "\n$text" : ""}');
          if (_notifications.length > 50) _notifications.removeLast();
        });
      });
      setState(() {
        _isSubscribed = true;
      });
      _showSnackBar('已订阅通知');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    if (_isSubscribed) {
      widget.characteristic.setNotifyValue(false);
    }
    _writeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final char = widget.characteristic;
    return Scaffold(
      appBar: AppBar(
        title: const Text('特征详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('服务 UUID:', style: Theme.of(context).textTheme.titleSmall),
                    Text(widget.service.uuid.toString()),
                    const SizedBox(height: 8),
                    Text('特征 UUID:', style: Theme.of(context).textTheme.titleSmall),
                    Text(char.uuid.toString()),
                    const SizedBox(height: 8),
                    Text('属性:', style: Theme.of(context).textTheme.titleSmall),
                    Text(_getPropertiesString(char)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (char.properties.read)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _read,
                      icon: const Icon(Icons.download),
                      label: const Text('读取'),
                    ),
                  ),
                if (char.properties.read) const SizedBox(width: 8),
                if (char.properties.write || char.properties.writeWithoutResponse)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _write,
                      icon: const Icon(Icons.upload),
                      label: const Text('写入'),
                    ),
                  ),
              ],
            ),
            if (char.properties.write || char.properties.writeWithoutResponse) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _writeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '输入要写入的数据',
                  hintText: '输入字符串',
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (char.properties.notify || char.properties.indicate)
              ElevatedButton.icon(
                onPressed: _toggleNotify,
                icon: Icon(_isSubscribed ? Icons.notifications_off : Icons.notifications_active),
                label: Text(_isSubscribed ? '取消订阅' : '订阅通知'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubscribed ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            if (_readValue != null) ...[
              const SizedBox(height: 16),
              const Text('读取结果:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_readValue!),
              ),
            ],
            if (_notifications.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('通知:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  reverse: true,
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_notifications[index]),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPropertiesString(BluetoothCharacteristic characteristic) {
    List<String> props = [];
    if (characteristic.properties.read) props.add('可读(R)');
    if (characteristic.properties.write) props.add('可写(W)');
    if (characteristic.properties.writeWithoutResponse) props.add('无响应写(W*)');
    if (characteristic.properties.notify) props.add('通知(N)');
    if (characteristic.properties.indicate) props.add('指示(I)');
    return props.isEmpty ? '无' : props.join(' | ');
  }
}
