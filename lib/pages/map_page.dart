import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data_center.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 地图控制器
  final MapController _mapController = MapController();

  // 当前位置（GPS设备位置）
  LatLng? _currentPosition;

  // 位置历史（用于绘制轨迹）
  final List<LatLng> _positionHistory = [];

  // 最新GGA数据
  GgaData? _latestGga;

  // 是否跟随位置
  bool _followPosition = true;

  @override
  void initState() {
    super.initState();
    // 订阅蓝牙数据流
    DataCenter().bluetoothDataStream.listen(_onBluetoothData);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // 处理蓝牙数据
  void _onBluetoothData(BluetoothDataEntry entry) {
    if (entry.dataType == BluetoothDataType.nmea) {
      // 解析GGA数据
      final gga = _parseGga(entry.content);
      if (gga != null && gga.isValid) {
        setState(() {
          _latestGga = gga;
          _currentPosition = LatLng(gga.latitude, gga.longitude);
          _positionHistory.add(_currentPosition!);

          // 限制历史记录数量
          if (_positionHistory.length > 1000) {
            _positionHistory.removeAt(0);
          }
        });

        // 如果开启跟随，移动地图到当前位置
        if (_followPosition) {
          _mapController.move(_currentPosition!, 18);
        }
      }
    }
  }

  // 解析GGA语句
  GgaData? _parseGga(String nmea) {
    // GGA格式: $GNGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
    if (!nmea.startsWith(r'$') || !nmea.contains('GGA')) {
      return null;
    }

    try {
      final parts = nmea.split(',');
      if (parts.length < 10) return null;

      // 解析纬度 (ddmm.mmmm)
      final latStr = parts[2];
      final latDir = parts[3];
      double? latitude;
      if (latStr.isNotEmpty) {
        final latDeg = double.parse(latStr.substring(0, 2));
        final latMin = double.parse(latStr.substring(2));
        latitude = latDeg + latMin / 60.0;
        if (latDir == 'S') latitude = -latitude;
      }

      // 解析经度 (dddmm.mmmm)
      final lonStr = parts[4];
      final lonDir = parts[5];
      double? longitude;
      if (lonStr.isNotEmpty) {
        final lonDeg = double.parse(lonStr.substring(0, 3));
        final lonMin = double.parse(lonStr.substring(3));
        longitude = lonDeg + lonMin / 60.0;
        if (lonDir == 'W') longitude = -longitude;
      }

      // 解析定位状态
      final quality = int.tryParse(parts[6]) ?? 0;

      // 解析卫星数量
      final satellites = int.tryParse(parts[7]) ?? 0;

      // 解析海拔高度
      final altitude = double.tryParse(parts[9]) ?? 0.0;

      if (latitude != null && longitude != null) {
        return GgaData(
          latitude: latitude,
          longitude: longitude,
          altitude: altitude,
          quality: quality,
          satellites: satellites,
          isValid: quality > 0,
        );
      }
    } catch (e) {
      // 解析失败
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图定位'),
        actions: [
          // 跟随位置开关
          IconButton(
            icon: Icon(_followPosition ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () {
              setState(() {
                _followPosition = !_followPosition;
              });
              // 如果开启跟随且当前有位置，立即移动
              if (_followPosition && _currentPosition != null) {
                _mapController.move(_currentPosition!, 18);
              }
            },
          ),
          // 清除轨迹
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _positionHistory.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 地图区域
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(39.9042, 116.4074), // 默认北京
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 22.0,
              ),
              children: [
                // 地图瓦片层 - 使用高德地图
                TileLayer(
                  urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                  subdomains: const ['1', '2', '3', '4'],
                  userAgentPackageName: 'com.example.ble_explorer',
                ),
                // 轨迹线
                if (_positionHistory.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _positionHistory,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                // GPS设备位置标记（红色）
                if (_latestGga != null && _currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40.0,
                        height: 40.0,
                        point: _currentPosition!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // 底部信息栏
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4.0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _latestGga != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'GPS设备位置',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '纬度: ${_latestGga!.latitude.toStringAsFixed(6)}°',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '经度: ${_latestGga!.longitude.toStringAsFixed(6)}°',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '海拔: ${_latestGga!.altitude.toStringAsFixed(1)} m',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '卫星: ${_latestGga!.satellites}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getQualityColor(_latestGga!.quality),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '定位状态: ${_getQualityText(_latestGga!.quality)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Text(
                    '等待GPS数据...\n请连接蓝牙GPS设备并订阅GGA数据',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
          ),
        ],
      ),
    );
  }

  // 获取定位质量颜色
  Color _getQualityColor(int quality) {
    switch (quality) {
      case 0:
        return Colors.red; // 无效
      case 1:
        return Colors.green; // GPS定位
      case 2:
        return Colors.blue; // DGPS定位
      case 4:
        return Colors.purple; // RTK固定解
      case 5:
        return Colors.orange; // RTK浮点解
      default:
        return Colors.grey;
    }
  }

  // 获取定位质量文本
  String _getQualityText(int quality) {
    switch (quality) {
      case 0:
        return '无效';
      case 1:
        return 'GPS定位';
      case 2:
        return 'DGPS定位';
      case 4:
        return 'RTK固定解';
      case 5:
        return 'RTK浮点解';
      default:
        return '未知';
    }
  }
}

// GGA数据结构
class GgaData {
  final double latitude;
  final double longitude;
  final double altitude;
  final int quality;
  final int satellites;
  final bool isValid;

  GgaData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.quality,
    required this.satellites,
    required this.isValid,
  });
}
