import 'package:flutter_test/flutter_test.dart';

import 'package:ble_app/main.dart';

void main() {
  testWidgets('BLE Explorer app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BLEExplorerApp());

    expect(find.text('BLE 设备扫描'), findsOneWidget);
  });
}
