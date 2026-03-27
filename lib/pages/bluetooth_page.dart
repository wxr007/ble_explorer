import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../permission_handler_android.dart';
import '../data_center.dart';
import '../services/bluetooth_manager_service.dart';

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
  
  // 已连接设备列表
  List<BluetoothDevice> _connectedDevices = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // 加载已连接设备
    _loadConnectedDevices();
    
    // 监听连接设备变化
    BluetoothManagerService().connectedDevicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _connectedDevices = devices;
        });
      }
    });
    
    // 智能扫描：有已连接设备时不扫描，超过30秒才重新扫描
    if (_connectedDevices.isNotEmpty) {
      // 已有连接设备，不自动扫描，只恢复之前的扫描结果
      _restorePreviousResults();
    } else if (DataCenter().shouldRescanBluetooth()) {
      _requestPermissionsAndScan();
    } else {
      // 恢复之前的扫描结果（如果有）
      _restorePreviousResults();
    }
  }
  
  // 加载已连接设备
  void _loadConnectedDevices() {
    setState(() {
      _connectedDevices = BluetoothManagerService().connectedDevices;
    });
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
    setState(() {
      _filteredResults = _scanResults.where((result) {
        final name = _getDeviceName(result).toLowerCase();
        final address = result.device.remoteId.str.toLowerCase();
        final matchesSearch = name.contains(_searchQuery) || address.contains(_searchQuery);
        final matchesBLE = !_filterOnlyBLE || _isBLEDevice(result);
        final matchesNamed = !_filterOnlyNamed || name.isNotEmpty;
        final matchesRssi = result.rssi >= _rssiThreshold;
        return matchesSearch && matchesBLE && matchesNamed && matchesRssi;
      }).toList();
    });
  }

  bool _isBLEDevice(ScanResult result) {
    // 通过广播数据判断是否为BLE设备
    return result.advertisementData.serviceUuids.isNotEmpty ||
           result.advertisementData.manufacturerData.isNotEmpty;
  }

  Future<void> _requestPermissionsAndScan() async {
    final granted = await requestPermissions();
    if (!granted) {
      setState(() {
        _errorMessage = '需要蓝牙和位置权限';
        _isScanning = false;
      });
      return;
    }

    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _scanResults = [];
      _filteredResults = [];
      _cachedDevices = [];
      _showingCached = false;
    });

    try {
      // 确保蓝牙已开启
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 2));
      }

      // 监听扫描结果
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results;
          _filterResults();
        });
      });

      // 开始扫描
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
      );

      // 扫描完成后保存结果
      await Future.delayed(const Duration(seconds: 30));
      _saveScanResults();
      DataCenter().updateLastBluetoothScanTime();

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

  // 保存扫描结果到DataCenter
  void _saveScanResults() {
    final results = _scanResults.map((result) => {
      'name': _getDeviceName(result),
      'address': result.device.remoteId.str,
      'rssi': result.rssi,
    }).toList();
    DataCenter().saveBluetoothScanResults(results);
  }

  // 连接缓存的设备
  Future<void> _connectToCachedDevice(CachedDevice cachedDevice) async {
    // 先检查权限
    final granted = await requestPermissions();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要蓝牙和位置权限')),
      );
      return;
    }

    // 显示扫描对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在搜索设备...'),
          ],
        ),
      ),
    );

    try {
      // 确保蓝牙已开启
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 2));
      }

      // 开始扫描
      BluetoothDevice? targetDevice;
      
      FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          if (result.device.remoteId.str == cachedDevice.address) {
            targetDevice = result.device;
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
      );

      // 等待扫描完成
      await Future.delayed(const Duration(seconds: 5));

      // 关闭对话框
      if (mounted) Navigator.pop(context);

      if (targetDevice != null) {
        // 找到设备，跳转到详情页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceDetailPage(device: targetDevice!),
          ),
        );
      } else {
        // 未找到设备
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到该设备，请确保设备在附近并已开启')),
        );
      }
    } catch (e) {
      // 关闭对话框
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $e')),
      );
    }
  }

  String _getDeviceName(ScanResult result) {
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    } else if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    return 'Unknown Device';
  }

  String _getRssi(ScanResult result) {
    return result.rssi.toString();
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
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索设备名称或MAC地址',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // 过滤器
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('仅BLE'),
                  selected: _filterOnlyBLE,
                  onSelected: (selected) {
                    setState(() {
                      _filterOnlyBLE = selected;
                      _filterResults();
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('仅命名'),
                  selected: _filterOnlyNamed,
                  onSelected: (selected) {
                    setState(() {
                      _filterOnlyNamed = selected;
                      _filterResults();
                    });
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rssiThreshold,
                  hint: const Text('信号强度'),
                  items: const [
                    DropdownMenuItem(value: -100, child: Text('全部')),
                    DropdownMenuItem(value: -80, child: Text('>-80dBm')),
                    DropdownMenuItem(value: -60, child: Text('>-60dBm')),
                    DropdownMenuItem(value: -40, child: Text('>-40dBm')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _rssiThreshold = value;
                        _filterResults();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          // 状态栏
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
          // 已连接设备列表
          if (_connectedDevices.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bluetooth_connected, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        '已连接设备 (${_connectedDevices.length})',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._connectedDevices.map((device) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices, size: 20),
                    title: Text(
                      device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      device.remoteId.str,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeviceDetailPage(device: device),
                          ),
                        );
                      },
                      child: const Text('查看'),
                    ),
                  )),
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
      // 显示缓存的设备列表，点击可尝试连接
      return ListView.builder(
        itemCount: _cachedDevices.length,
        itemBuilder: (context, index) {
          final device = _cachedDevices[index];
          return ListTile(
            leading: const Icon(Icons.bluetooth, color: Colors.grey),
            title: Text(device.name),
            subtitle: Text('MAC: ${device.address}  RSSI: ${device.rssi} dBm'),
            trailing: const Text('点击连接', style: TextStyle(color: Colors.blue, fontSize: 12)),
            onTap: () => _connectToCachedDevice(device),
          );
        },
      );
    }

    if (_filteredResults.isEmpty && !_isScanning && _connectedDevices.isEmpty) {
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
  BluetoothCharacteristic? _selectedNotifyCharacteristic;
  BluetoothCharacteristic? _selectedWriteCharacteristic;

  @override
  void initState() {
    super.initState();
    // 恢复已选中的特征
    _restoreSelectedCharacteristics();
    
    // 检查是否已连接
    if (BluetoothManagerService().isDeviceConnected(widget.device)) {
      _isConnected = true;
      _loadServices();
    } else {
      _connect();
    }
  }
  
  // 恢复已选中的特征
  void _restoreSelectedCharacteristics() {
    final notifyChar = BluetoothManagerService().notifyCharacteristic;
    final writeChar = BluetoothManagerService().writeCharacteristic;
    
    if (notifyChar != null) {
      _selectedNotifyCharacteristic = notifyChar;
    }
    if (writeChar != null) {
      _selectedWriteCharacteristic = writeChar;
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.device.connect(timeout: const Duration(seconds: 10));
      _isConnected = true;
      
      // 添加到管理器
      BluetoothManagerService().addConnectedDevice(widget.device);
      
      // 监听连接状态变化
      widget.device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          BluetoothManagerService().removeConnectedDevice(widget.device);
          if (mounted) {
            setState(() {
              _isConnected = false;
            });
          }
        }
      });
      
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

  Future<void> _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      
      // 保存到管理器
      BluetoothManagerService().setNotifyCharacteristic(characteristic);
      
      // 监听通知
      characteristic.lastValueStream.listen((value) {
        _processReceivedData(value);
      });
      
      setState(() {
        _selectedNotifyCharacteristic = characteristic;
      });
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('订阅通知成功')),
        );
      }
      
      DataCenter().addBluetoothLog('订阅特征通知: ${characteristic.uuid}');
    } catch (e) {
      DataCenter().addBluetoothLog('订阅失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('订阅失败: $e')),
        );
      }
    }
  }

  // 处理接收到的数据，使用DataCenter进行解析和记录
  void _processReceivedData(List<int> value) {
    // 使用DataCenter统一处理数据（解析一次，同时记录日志和广播）
    DataCenter().handleBluetoothData(value);
  }

  void _selectWriteCharacteristic(BluetoothCharacteristic characteristic) {
    BluetoothManagerService().setWriteCharacteristic(characteristic);
    setState(() {
      _selectedWriteCharacteristic = characteristic;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已选择写入特征: ${characteristic.uuid}')),
    );
    DataCenter().addBluetoothLog('选择写入特征: ${characteristic.uuid}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isNotEmpty
            ? widget.device.platformName
            : '设备详情'),
        actions: [
          // 写入按钮
          if (_selectedWriteCharacteristic != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '发送数据',
              onPressed: () {
                _showWriteDialog();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    // 连接状态卡片
                    if (_isConnected)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bluetooth_connected, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Text(
                                  '已连接',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedNotifyCharacteristic != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '通知特征: ${_selectedNotifyCharacteristic!.uuid}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            if (_selectedWriteCharacteristic != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '写入特征: ${_selectedWriteCharacteristic!.uuid}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    // 服务列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return ExpansionTile(
                            title: Text('服务 ${index + 1}'),
                            subtitle: Text(service.uuid.toString()),
                            children: service.characteristics.map((characteristic) {
                              final isNotifySelected = _selectedNotifyCharacteristic?.uuid == characteristic.uuid;
                              final isWriteSelected = _selectedWriteCharacteristic?.uuid == characteristic.uuid;
                              
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
                                        icon: Icon(
                                          Icons.notifications,
                                          color: isNotifySelected ? Colors.blue : null,
                                        ),
                                        tooltip: isNotifySelected ? '已订阅通知' : '订阅通知',
                                        onPressed: isNotifySelected 
                                            ? null 
                                            : () => _subscribeToCharacteristic(characteristic),
                                      ),
                                    if (characteristic.properties.write || characteristic.properties.writeWithoutResponse)
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: isWriteSelected ? Colors.green : null,
                                        ),
                                        tooltip: isWriteSelected ? '已选择为写入特征' : '选择为写入特征',
                                        onPressed: () => _selectWriteCharacteristic(characteristic),
                                      ),
                                  ],
                                ),
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

  void _showWriteDialog() {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发送数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('写入特征: ${_selectedWriteCharacteristic!.uuid}'),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: '输入十六进制数据 (如: 01 02 03)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                try {
                  // 解析十六进制数据
                  final bytes = text.split(' ')
                      .where((s) => s.isNotEmpty)
                      .map((s) => int.parse(s, radix: 16))
                      .toList();
                  
                  _selectedWriteCharacteristic!.write(bytes);
                  DataCenter().addBluetoothLog('发送数据: $text');
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('数据格式错误: $e')),
                  );
                }
              }
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }
}
