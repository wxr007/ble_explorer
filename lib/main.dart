import 'package:flutter/material.dart';
import 'pages/bluetooth_page.dart';
import 'pages/base_station_page.dart';
import 'pages/log_page.dart';
import 'pages/map_page.dart';

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
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const BluetoothPage(),
    const BaseStationPage(),
    const LogPage(),
    const MapPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[700],
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: '蓝牙',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.signal_wifi_4_bar),
            label: '基站',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.text_snippet),
            label: '日志',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '地图',
          ),
        ],
      ),
    );
  }
}
