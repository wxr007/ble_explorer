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

// 缓存的设备信息类
class CachedDevice {
  final String name;
  final String address;
  final int rssi;

  CachedDevice({required this.name, required this.address, required this.rssi});
}

class DeviceScanPage extends StatefulWidget {
  const DeviceScanPage({super.key});

  @override
  State<DeviceScanPage> createState() => _DeviceScanPageState();
}

class _DeviceScanPageState extends State<DeviceScanPage> {
  List<ScanResult> _scanResults = [];
  List<ScanResult> _filteredResults = [];
  List<CachedDevice> _cachedDevices = [];
  bool _isScanning = false;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _filterOnlyBLE = false;
  bool _filterOnlyNamed = false;
  int _rssiThreshold = -100;
  bool _showingCached = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // 智能扫描：超过30秒才重新扫描
    if (DataCenter().shouldRescanBluetooth()) {
      _requestPermissionsAndScan();
    } else {
      // 恢复之前的扫描结果（如果有）
      _restorePreviousResults();
    }
  }

  // 恢复之前的扫描结果
  void _restorePreviousResults() {
    final savedResults = DataCenter().getBluetoothScanResults();
    if (savedResults.isNotEmpty) {
      setState(() {
        _cachedDevices = savedResults.map((e) => CachedDevice(
          name: e['name'] ?? 'Unknown Device',
          address: e['address'] ?? '',
          rssi: e['rssi'] ?? -100,
        )).toList();
        _showingCached = true;
        _isScanning = false;
      });
    } else {
      setState(() {
        _isScanning = false;
      });
    }
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
    if (_showingCached) {
      // 过滤缓存的设备
      return;
    }
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
      _cachedDevices = [];
      _showingCached = false;
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
          
          // 保存扫描结果到DataCenter
          _saveScanResults();
        });
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
      
      // 记录扫描时间
      await DataCenter().updateLastBluetoothScanTime();
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

  // 保存扫描结果到DataCenter
  void _saveScanResults() {
    final results = _scanResults.map((result) => {
      'name': _getDeviceName(result),
      'address': result.device.remoteId.str,
      'rssi': result.rssi,
    }).toList();
    DataCenter().saveBluetoothScanResults(results);
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
                    : _showingCached
                        ? '显示缓存的 ${_cachedDevices.length} 个设备 (点击刷新重新扫描)'
                        : '共发现 ${_searchQuery.isEmpty ? _scanResults.length : _filteredResults.length} 个设备'),
              ],
            ),
          ),
          Expanded(
            child: _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_isScanning && _scanResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showingCached && _cachedDevices.isNotEmpty) {
      // 显示缓存的设备列表
      return ListView.builder(
        itemCount: _cachedDevices.length,
        itemBuilder: (context, index) {
          final device = _cachedDevices[index];
          return ListTile(
            leading: const Icon(Icons.bluetooth, color: Colors.grey),
            title: Text(device.name),
            subtitle: Text('MAC: ${device.address}  RSSI: ${device.rssi} dBm'),
            trailing: const Text('缓存', style: TextStyle(color: Colors.grey, fontSize: 12)),
          );
        },
      );
    }

    if (_filteredResults.isEmpty && !_isScanning) {
      return const Center(child: Text('点击右上角刷新按钮开始扫描'));
    }

    return ListView.builder(
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
              ? Center(child: Text(_errorMessage!))
              : ListView.builder(
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    return ExpansionTile(
                      title: Text('服务 ${index + 1}'),
                      subtitle: Text(service.uuid.toString()),
                      children: service.characteristics.map((characteristic) {
                        return ListTile(
                          title: Text(characteristic.uuid.toString()),
                          subtitle: Text('属性: ${_getPropertiesString(characteristic)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (characteristic.properties.read)
                                IconButton(
                                  icon: const Icon(Icons.read_more),
                                  onPressed: () async {
                                    try {
                                      final value = await characteristic.read();
                                      DataCenter().addBluetoothLog('读取特征值: ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                                    } catch (e) {
                                      DataCenter().addBluetoothLog('读取失败: $e');
                                    }
                                  },
                                ),
                              if (characteristic.properties.notify)
                                IconButton(
                                  icon: const Icon(Icons.notifications),
                                  onPressed: () async {
                                    try {
                                      await characteristic.setNotifyValue(true);
                                      characteristic.lastValueStream.listen((value) {
                                        DataCenter().addBluetoothLog('通知数据: ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                                      });
                                    } catch (e) {
                                      DataCenter().addBluetoothLog('订阅失败: $e');
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
    );
  }
}
