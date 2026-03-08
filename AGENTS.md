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
│   └── main.dart              # All app code (single file)
├── android/
│   ├── app/src/main/
│   │   └── AndroidManifest.xml  # BLE permissions
│   └── build.gradle
├── pubspec.yaml               # Dependencies
├── analysis_options.yaml      # Lint rules
└── test/
    └── widget_test.dart
```

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
