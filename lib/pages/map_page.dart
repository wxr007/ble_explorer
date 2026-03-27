import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../data_center.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 地图控制器
  final MapController _mapController = MapController();

  // 当前位置（优先使用GPS设备位置，否则使用手机位置）
  LatLng? _currentPosition;

  // 手机位置
  LatLng? _phonePosition;

  // 位置历史（用于绘制轨迹）
  final List<LatLng> _positionHistory = [];

  // 最新GGA数据
  GgaData? _latestGga;

  // 是否跟随位置
  bool _followPosition = true;

  // 是否正在获取手机定位
  bool _isGettingPhoneLocation = false;

  // 调试信息
  String _debugInfo = '';

  // 是否使用卫星底图
  bool _useSatelliteMap = false;

  // Location 实例
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    // 订阅蓝牙数据流
    DataCenter().bluetoothDataStream.listen(_onBluetoothData);
    // 获取手机定位
    _getPhoneLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // 位置更新订阅
  StreamSubscription<LocationData>? _locationSubscription;

  // 获取手机定位
  Future<void> _getPhoneLocation() async {
    setState(() {
      _isGettingPhoneLocation = true;
      _debugInfo = '开始获取定位...';
    });

    try {
      // 检查定位服务是否开启
      _updateDebugInfo('检查定位服务...');
      bool serviceEnabled = await _location.serviceEnabled();
      _updateDebugInfo('定位服务状态: $serviceEnabled');

      if (!serviceEnabled) {
        _updateDebugInfo('请求开启定位服务...');
        serviceEnabled = await _location.requestService();
        _updateDebugInfo('用户响应定位服务: $serviceEnabled');

        if (!serviceEnabled) {
          setState(() {
            _isGettingPhoneLocation = false;
            _debugInfo = '定位服务未开启';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请开启手机定位服务')),
            );
          }
          return;
        }
      }

      // 检查权限
      _updateDebugInfo('检查定位权限...');
      PermissionStatus permission = await _location.hasPermission();
      _updateDebugInfo('当前权限状态: $permission');

      if (permission == PermissionStatus.denied) {
        _updateDebugInfo('请求定位权限...');
        permission = await _location.requestPermission();
        _updateDebugInfo('用户响应权限: $permission');

        if (permission != PermissionStatus.granted) {
          setState(() {
            _isGettingPhoneLocation = false;
            _debugInfo = '定位权限被拒绝';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('定位权限被拒绝')),
            );
          }
          return;
        }
      }

      if (permission == PermissionStatus.deniedForever) {
        setState(() {
          _isGettingPhoneLocation = false;
          _debugInfo = '定位权限被永久拒绝';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('定位权限被永久拒绝，请在设置中开启')),
          );
        }
        return;
      }

      // 配置定位参数
      _updateDebugInfo('配置定位参数...');
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 0,
      );

      // 先尝试获取一次当前位置（快速返回）
      _updateDebugInfo('尝试快速获取位置...');
      try {
        LocationData locationData = await _location.getLocation().timeout(
          const Duration(seconds: 5),
        );

        if (locationData.latitude != null && locationData.longitude != null) {
          _updateDebugInfo('快速获取成功: lat=${locationData.latitude}, lng=${locationData.longitude}');
          _updatePhonePosition(locationData);
          return;
        } else {
          _updateDebugInfo('快速获取返回空位置');
        }
      } on TimeoutException {
        _updateDebugInfo('快速获取超时，开始持续监听...');
      } catch (e) {
        _updateDebugInfo('快速获取失败: $e');
      }

      // 如果快速获取失败，使用持续监听
      _updateDebugInfo('开始持续监听位置更新...');

      // 取消之前的订阅
      await _locationSubscription?.cancel();

      // 设置超时
      Timer? timeoutTimer;
      timeoutTimer = Timer(const Duration(seconds: 60), () {
        _locationSubscription?.cancel();
        setState(() {
          _isGettingPhoneLocation = false;
          _debugInfo = '持续监听超时（60秒），请检查GPS信号';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取定位超时，请确保在室外或开启WiFi')),
          );
        }
      });

      // 监听位置更新
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData locationData) {
          timeoutTimer?.cancel();
          _updateDebugInfo('监听到位置更新: lat=${locationData.latitude}, lng=${locationData.longitude}');
          _updatePhonePosition(locationData);
        },
        onError: (error) {
          timeoutTimer?.cancel();
          _updateDebugInfo('位置监听错误: $error');
          setState(() {
            _isGettingPhoneLocation = false;
            _debugInfo = '位置监听错误: $error';
          });
        },
      );
    } catch (e, stackTrace) {
      setState(() {
        _isGettingPhoneLocation = false;
        _debugInfo = '错误: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取手机定位失败: $e')),
        );
      }
    }
  }

  // 更新手机位置
  void _updatePhonePosition(LocationData locationData) {
    if (locationData.latitude != null && locationData.longitude != null) {
      setState(() {
        _phonePosition = LatLng(locationData.latitude!, locationData.longitude!);
        // 如果还没有GPS设备位置，使用手机位置作为当前位置
        if (_currentPosition == null) {
          _currentPosition = _phonePosition;
        }
        _isGettingPhoneLocation = false;
        _debugInfo = '定位成功: ${_phonePosition!.latitude.toStringAsFixed(6)}, ${_phonePosition!.longitude.toStringAsFixed(6)}';
      });

      // 如果开启跟随且没有GPS位置，移动地图到手机位置
      if (_followPosition && _latestGga == null && _phonePosition != null) {
        _mapController.move(_phonePosition!, 15);
      }

      // 取消订阅，因为我们已经获取到位置了
      _locationSubscription?.cancel();
      _locationSubscription = null;
    }
  }

  void _updateDebugInfo(String info) {
    setState(() {
      _debugInfo = info;
    });
    debugPrint('[MapPage] $info');
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
          // 切换卫星底图
          IconButton(
            icon: Icon(_useSatelliteMap ? Icons.map : Icons.satellite),
            tooltip: _useSatelliteMap ? '切换街道图' : '切换卫星图',
            onPressed: () {
              setState(() {
                _useSatelliteMap = !_useSatelliteMap;
              });
            },
          ),
          // 回到正北方向
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: '回到正北',
            onPressed: () {
              _mapController.rotate(0);
            },
          ),
          // 刷新手机定位
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _isGettingPhoneLocation ? null : _getPhoneLocation,
          ),
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
                initialCenter: _currentPosition ?? const LatLng(39.9042, 116.4074), // 默认北京
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 22.0,
              ),
              children: [
                // 地图瓦片层 - 根据设置切换街道图或卫星图
                if (_useSatelliteMap)
                  // 高德卫星图
                  TileLayer(
                    urlTemplate: 'https://webst0{s}.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}',
                    subdomains: const ['1', '2', '3', '4'],
                    userAgentPackageName: 'com.example.ble_explorer',
                  )
                else
                  // 高德街道图
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
                // 手机位置标记（蓝色，只在没有GPS位置时显示）
                if (_phonePosition != null && _latestGga == null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40.0,
                        height: 40.0,
                        point: _phonePosition!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 40.0,
                        ),
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
            child: Column(
              children: [
                // 调试信息显示
                if (_debugInfo.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      '调试: $_debugInfo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                // 定位状态显示
                if (_isGettingPhoneLocation)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('正在获取手机定位...'),
                    ],
                  )
                else if (_latestGga != null)
                  Column(
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
                else if (_phonePosition != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            '手机定位',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '纬度: ${_phonePosition!.latitude.toStringAsFixed(6)}°',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '经度: ${_phonePosition!.longitude.toStringAsFixed(6)}°',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  const Text(
                    '等待定位数据...\n请确保GPS设备已连接或手机定位已开启',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
              ],
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
