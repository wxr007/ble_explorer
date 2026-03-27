import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../permission_handler_android.dart';
import '../data_center.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  @override
  Widget build(BuildContext context) {
    return const DeviceScanPage();
  }
}

class DeviceScanPage extends StatefulWidget {
  const DeviceScanPage({super.key});

  @override
  State<DeviceScanPage> createState() => _DeviceScanPageState();
}

class _DeviceScanPageState extends State<DeviceScanPage> {
  List<ScanResult> _scanResults = [];
  List<ScanResult> _filteredResults = [];
  bool _isScanning = false;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _filterOnlyBLE = false;
  bool _filterOnlyNamed = false;
  int _rssiThreshold = -100;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterResults();
    });
  }

  void _filterResults() {
    _filteredResults = _scanResults.where((result) {
      final deviceName = _getDeviceName(result).toLowerCase();
      final deviceAddress = result.device.remoteId.str.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          deviceName.contains(_searchQuery) ||
          deviceAddress.contains(_searchQuery);

      const isBLE = true;
      final matchesBLE = !_filterOnlyBLE || isBLE;

      final hasName = _getDeviceName(result) != 'Unknown Device';
      final matchesNamed = !_filterOnlyNamed || hasName;

      final matchesRSSI = result.rssi >= _rssiThreshold;

      return matchesSearch && matchesBLE && matchesNamed && matchesRSSI;
    }).toList();
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '过滤选项',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    title: const Text('只显示BLE设备'),
                    value: _filterOnlyBLE,
                    onChanged: (value) {
                      setState(() {
                        _filterOnlyBLE = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('只显示名称不为空的'),
                    value: _filterOnlyNamed,
                    onChanged: (value) {
                      setState(() {
                        _filterOnlyNamed = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('RSSI 阈值:'),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _rssiThreshold.toDouble(),
                          min: -100,
                          max: 0,
                          divisions: 100,
                          label: '$_rssiThreshold dBm',
                          onChanged: (value) {
                            setState(() {
                              _rssiThreshold = value.round();
                            });
                          },
                        ),
                      ),
                      Text('$_rssiThreshold dBm', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          _filterOnlyBLE = false;
                          _filterOnlyNamed = false;
                          _rssiThreshold = -100;
                          setState(() {
                            _filterResults();
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('重置'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterResults();
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _requestPermissionsAndScan() async {
    final granted = await requestPermissions();
    if (!granted) {
      setState(() {
        _errorMessage = '需要蓝牙和位置权限才能扫描设备';
      });
      return;
    }
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanResults = [];
      _errorMessage = null;
    });

    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 2));
      }

      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          final uniqueResults = <ScanResult>[];
          final seenAddresses = <String>{};

          for (var result in results) {
            final address = result.device.remoteId.str;
            if (!seenAddresses.contains(address)) {
              seenAddresses.add(address);
              uniqueResults.add(result);
            }
          }

          _scanResults = uniqueResults;
          _filterResults();
        });
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
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

  String _getDeviceName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    return 'Unknown Device';
  }

  int _getRssi(ScanResult result) {
    return result.rssi;
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
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '过滤选项',
            onPressed: _showFilterDialog,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '根据名称或地址过滤',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (_isScanning) const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(_isScanning
                    ? '扫描中...'
                    : '共发现 ${_searchQuery.isEmpty ? _scanResults.length : _filteredResults.length} 个设备'),
              ],
            ),
          ),
          Expanded(
            child: _filteredResults.isEmpty && !_isScanning
                ? const Center(child: Text('点击右上角刷新按钮开始扫描'))
                : ListView.builder(
                    itemCount: _filteredResults.length,
                    itemBuilder: (context, index) {
                      final result = _filteredResults[index];
                      final device = result.device;
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(_getDeviceName(result)),
                        subtitle: Text('MAC: ${device.remoteId.str}  RSSI: ${_getRssi(result)} dBm'),
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
      DataCenter().setBluetoothConnected(true);
      await _loadServices();
    } catch (e) {
      setState(() {
        _errorMessage = '连接失败: $e';
      });
      DataCenter().addBluetoothLog('连接失败: $e');
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
      DataCenter().addBluetoothLog('发现 ${services.length} 个服务');
    } catch (e) {
      setState(() {
        _errorMessage = '获取服务失败: $e';
      });
      DataCenter().addBluetoothLog('获取服务失败: $e');
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
      DataCenter().setBluetoothConnected(false);
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
      DataCenter().addBluetoothLog('读取特征值: $_readValue');
    } catch (e) {
      _showSnackBar('读取失败: $e');
      DataCenter().addBluetoothLog('读取失败: $e');
    }
  }

  Future<void> _write() async {
    if (_writeController.text.isEmpty) return;
    try {
      final bytes = _writeController.text.codeUnits;
      await widget.characteristic.write(bytes);
      _showSnackBar('写入成功');
      DataCenter().addBluetoothLog('写入数据: ${_writeController.text}');
    } catch (e) {
      _showSnackBar('写入失败: $e');
      DataCenter().addBluetoothLog('写入失败: $e');
    }
  }

  Future<void> _toggleNotify() async {
    if (_isSubscribed) {
      await widget.characteristic.setNotifyValue(false);
      setState(() {
        _isSubscribed = false;
      });
      _showSnackBar('已取消订阅');
      DataCenter().addBluetoothLog('取消订阅通知');
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
        DataCenter().addBluetoothLog('收到通知: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
      });
      setState(() {
        _isSubscribed = true;
      });
      _showSnackBar('已订阅通知');
      DataCenter().addBluetoothLog('订阅通知成功');
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
