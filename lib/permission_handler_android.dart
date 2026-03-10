import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

Future<bool> requestPermissions() async {
  if (Platform.isAndroid) {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();
    return bluetoothScan.isGranted && bluetoothConnect.isGranted && location.isGranted;
  } else if (Platform.isWindows) {
    // Windows 需要蓝牙和位置权限
    final bluetooth = await Permission.bluetooth.request();
    final location = await Permission.location.request();
    return bluetooth.isGranted && location.isGranted;
  }
  return true;
}
