import 'dart:async';
import 'package:flutter/material.dart';
import '../data_center.dart';
import '../services/ntrip_client_service.dart';

class BaseStationPage extends StatefulWidget {
  const BaseStationPage({super.key});

  @override
  State<BaseStationPage> createState() => _BaseStationPageState();
}

class _BaseStationPageState extends State<BaseStationPage> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _mountpointController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int _selectedHistoryIndex = -1;
  bool _isPasswordVisible = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  StreamSubscription<bool>? _connectionSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _isConnected = NtripClientService().isConnected;
    
    // 监听连接状态变化
    _connectionSubscription = NtripClientService().connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          _isConnecting = NtripClientService().isConnecting;
        });
      }
    });

    // 加载上次保存的配置
    _loadLastConfig();
  }

  // 加载上次保存的配置
  void _loadLastConfig() {
    final lastConfig = DataCenter().getLastBaseStationConfig();
    if (lastConfig != null && !_isInitialized) {
      _hostController.text = lastConfig['host'] ?? '';
      _portController.text = lastConfig['port'] ?? '';
      _mountpointController.text = lastConfig['mountpoint'] ?? '';
      _usernameController.text = lastConfig['username'] ?? '';
      _passwordController.text = lastConfig['password'] ?? '';
      _isInitialized = true;
    }
  }

  // 保存当前配置
  Future<void> _saveCurrentConfig() async {
    final config = {
      'host': _hostController.text,
      'port': _portController.text,
      'mountpoint': _mountpointController.text,
      'username': _usernameController.text,
      'password': _passwordController.text,
    };
    await DataCenter().saveLastBaseStationConfig(config);
  }

  @override
  void dispose() {
    // 页面销毁时保存当前配置
    _saveCurrentConfig();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _loadHistory(int index) {
    if (index == -1) {
      // 新建连接，清空所有输入框
      _hostController.clear();
      _portController.clear();
      _mountpointController.clear();
      _usernameController.clear();
      _passwordController.clear();
      setState(() {
        _selectedHistoryIndex = -1;
      });
    } else if (index >= 0 && index < DataCenter().baseStationHistory.length) {
      final history = DataCenter().baseStationHistory[index];
      _hostController.text = history['host']!;
      _portController.text = history['port']!;
      _mountpointController.text = history['mountpoint']!;
      _usernameController.text = history['username']!;
      _passwordController.text = history['password']!;
      setState(() {
        _selectedHistoryIndex = index;
      });
    }
  }

  Future<void> _connect() async {
    if (_hostController.text.isEmpty || _portController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写主机和端口')),
      );
      return;
    }

    // 保存到历史记录
    final history = {
      'host': _hostController.text,
      'port': _portController.text,
      'mountpoint': _mountpointController.text,
      'username': _usernameController.text,
      'password': _passwordController.text,
    };
    await DataCenter().addBaseStationHistory(history);
    
    // 保存当前配置
    await _saveCurrentConfig();

    setState(() {
      _isConnecting = true;
    });

    try {
      final port = int.tryParse(_portController.text) ?? 2101;
      
      await NtripClientService().connect(
        host: _hostController.text,
        port: port,
        mountpoint: _mountpointController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NTRIP 连接成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _disconnect() {
    NtripClientService().disconnect();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已断开连接')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('基站设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 历史记录下拉框
            DropdownButtonFormField<int>(
              value: _selectedHistoryIndex == -1 ? null : _selectedHistoryIndex,
              hint: const Text('选择历史记录'),
              items: [
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Text('新建连接'),
                ),
                ...DataCenter().baseStationHistory.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, String> data = entry.value;
                  String displayText = '${data['host']}:${data['port']}';
                  if (data['mountpoint'] != null && data['mountpoint']!.isNotEmpty) {
                    displayText += '/${data['mountpoint']}';
                  }
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(displayText),
                  );
                }),
              ],
              onChanged: (value) {
                if (value != null) {
                  _loadHistory(value);
                }
              },
              decoration: const InputDecoration(
                labelText: '历史记录',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 输入框
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: '主机',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveCurrentConfig(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: '端口',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _saveCurrentConfig(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _mountpointController,
              decoration: const InputDecoration(
                labelText: '挂载点',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveCurrentConfig(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveCurrentConfig(),
            ),
            const SizedBox(height: 12),

            // 密码输入框带可见性切换
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
              onChanged: (_) => _saveCurrentConfig(),
            ),
            const SizedBox(height: 24),

            // 连接/断开按钮
            if (_isConnecting)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _isConnected ? _disconnect : _connect,
                icon: Icon(
                  _isConnected ? Icons.link_off : Icons.connect_without_contact,
                ),
                label: Text(
                  _isConnected ? '断开连接' : '连接',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: _isConnected ? Colors.red : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
