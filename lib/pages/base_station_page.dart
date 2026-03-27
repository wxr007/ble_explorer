import 'package:flutter/material.dart';
import '../data_center.dart';

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

  @override
  void initState() {
    super.initState();
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

  void _connect() {
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
    DataCenter().addBaseStationHistory(history);

    // 记录日志
    DataCenter().addBaseStationLog('尝试连接: ${_hostController.text}:${_portController.text}');

    // 连接逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('连接中...')),
    );

    // 模拟连接成功
    Future.delayed(const Duration(seconds: 2), () {
      DataCenter().setBaseStationConnected(true);
    });
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
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text('${data['host']}:${data['port']}'),
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
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: '端口',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _mountpointController,
              decoration: const InputDecoration(
                labelText: '挂载点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // 连接按钮
            ElevatedButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.connect_without_contact),
              label: const Text('连接'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
