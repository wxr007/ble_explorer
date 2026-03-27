# AGENTS.md - BLE Explorer Flutter App

## Project Overview

This is a Flutter Android application that scans and explores BLE (Bluetooth Low Energy) devices, similar to the Python `ble_explorer.py` script. The app uses `flutter_blue_plus` for BLE communication and `permission_handler` for runtime permissions.

## Build Commands

### Install Dependencies
```bash
cd ble_explorer
flutter pub get
```

### Run App (Debug)
```bash
cd ble_explorer
flutter run
```

### Build Debug APK
```bash
cd ble_explorer
flutter build apk --debug
```

### Build Release APK
```bash
cd ble_explorer
flutter build apk --release
```

### Run Tests
```bash
cd ble_explorer
flutter test
```

### Run Single Test
```bash
cd ble_explorer
flutter test test/widget_test.dart
```

### Analyze Code (Lint)
```bash
cd ble_explorer
flutter analyze
```

### Format Code
```bash
cd ble_explorer
flutter format lib/
```

## Code Style Guidelines

### General
- Use Flutter's recommended lints from `package:flutter_lints/flutter.yaml`
- Enable Material 3 design: `useMaterial3: true` in ThemeData
- Target Android SDK 34, minimum SDK 21

### Imports
- Group imports in order: Dart core, Flutter, third-party packages, project imports
- Use absolute imports with `package:` prefix
```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'my_app/file.dart';
```

### Naming Conventions
- **Classes**: PascalCase (e.g., `DeviceScanPage`)
- **Private classes**: Prefix with underscore (e.g., `_DeviceScanPageState`)
- **Variables/methods**: camelCase (e.g., `deviceList`, `startScan()`)
- **Constants**: lowerCamelCase with `k` prefix (e.g., `kDefaultTimeout`)
- **Files**: snake_case (e.g., `device_scan_page.dart`)

### Types
- Use explicit types for public APIs
- Prefer `var` for local variables when type is obvious
- Use `final` by default, `var` only when reassignment needed
- Nullable types with `?` (e.g., `String? errorMessage`)

### Widgets
- Use `const` constructors where possible
- Prefer `StatelessWidget` over `StatefulWidget` when no state
- Use `late` for late-initialized variables in StatefulWidget
- Always call `super.initState()` and `super.dispose()`

### Error Handling
- Use try-catch for async operations
- Display errors via SnackBar or UI feedback
- Set error state with `setState()` for UI updates
```dart
try {
  await someAsyncOperation();
} catch (e) {
  setState(() {
    _errorMessage = 'Error: $e';
  });
}
```

### Async/Await
- Always await async functions properly
- Use `async` keyword for functions returning Future
- Handle loading states with booleans

### UI Patterns
- Use `Scaffold` as root widget
- Use `AppBar` for top navigation
- Use `Navigator.push()` for page navigation
- Use `setState()` to trigger rebuilds
- Use `FutureBuilder` for async UI updates

## Project Structure

```
ble_explorer/
├── lib/
│   ├── main.dart              # App entry point with bottom navigation
│   ├── data_center.dart       # Global data management class
│   ├── permission_handler_android.dart  # Permission handling
│   ├── pages/
│   │   ├── bluetooth_page.dart    # BLE device scanning page
│   │   ├── base_station_page.dart # Base station connection page
│   │   └── log_page.dart          # Log display page
│   └── services/
│       └── ntrip_client_service.dart  # NTRIP client implementation
├── android/
│   ├── app/src/main/
│   │   └── AndroidManifest.xml  # BLE permissions
│   └── build.gradle
├── pubspec.yaml               # Dependencies
├── analysis_options.yaml      # Lint rules
└── test/
    └── widget_test.dart
```

## Data Center (数据管理中心)

`DataCenter` 是一个单例类，用于管理应用中的全局数据流转：

### 功能
- **蓝牙日志管理**: 添加、获取、清空蓝牙相关日志
- **基站日志管理**: 添加、获取、清空基站相关日志
- **历史记录管理**: 保存和获取基站连接历史
- **连接状态管理**: 跟踪蓝牙和基站的连接状态
- **数据流**: 提供 Stream 接口实时监听日志更新

### 使用方式
```dart
// 获取实例
final dataCenter = DataCenter();

// 添加日志
DataCenter().addBluetoothLog('扫描到设备');
DataCenter().addBaseStationLog('连接成功');

// 获取日志文本
String logs = DataCenter().getBluetoothLogsText();

// 监听日志更新
DataCenter().bluetoothLogStream.listen((log) {
  // 更新UI
});
```

## New Features Added

### Bottom Navigation Bar
- Added bottom navigation bar with three tabs:
  1. **蓝牙** - BLE device scanning and exploration
  2. **基站** - Base station connection settings
  3. **日志** - Log display for Bluetooth and base station

### Base Station Page
- Input fields for:
  - 主机 (Host)
  - 端口 (Port)
  - 挂载点 (Mountpoint)
  - 用户名 (Username)
  - 密码 (Password) with Eye Toggle visibility switch
- History dropdown to save and load previous connections
- **新建连接**: Selecting "新建连接" clears all input fields
- NTRIP Client connection support
- Connect/Disconnect button with state management
- Auto-saves connection history to DataCenter
- Real-time data reception and logging

### NTRIP Client Service
- Custom NTRIP client implementation (`ntrip_client_service.dart`)
- TCP socket connection to NTRIP caster
- Basic authentication with Base64 encoding
- RTCM data reception and parsing
- Real-time data streaming to DataCenter
- Connection state management

### Log Page
- Two multi-line text fields to display:
  - 蓝牙日志 (Bluetooth logs) - Full height utilization
  - 基站日志 (Base station logs) - Full height utilization
- Real-time log updates via DataCenter streams
- Clear logs button in app bar
- Optimized layout with minimal padding

## Dependencies

- `flutter_blue_plus: ^1.36.8` - BLE communication
- `permission_handler: ^11.3.0` - Runtime permissions
- `flutter_lints: ^4.0.0` - Linting (dev)

## Android Permissions (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

## Common Tasks

### Adding New Dependencies
1. Add to `pubspec.yaml` under `dependencies`
2. Run `flutter pub get`
3. Build to verify compatibility

### Modifying Android Config
- Edit `android/app/build.gradle` for SDK versions
- Edit `android/app/src/main/AndroidManifest.xml` for permissions
- Gradle wrapper: `android/gradle/wrapper/gradle-wrapper.properties`

### Modifying Flutter Code
- Edit `lib/main.dart` for app logic
- Follow the existing code patterns and conventions
- Run `flutter analyze` before committing

## Known Build Issues

- If `flutter_blue_plus_android` build fails, manually edit the plugin's build.gradle:
  - Path: `C:\Users\<user>\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_blue_plus_android-7.0.4\android\build.gradle`
  - Change `flutter.compileSdkVersion` to a hardcoded value like `34`
