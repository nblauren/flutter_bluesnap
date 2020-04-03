import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bluesnap/flutter_bluesnap.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_bluesnap');

  TestWidgetsFlutterBinding.ensureInitialized();

  // TODO....

  // setUp(() {
  //   channel.setMockMethodCallHandler((MethodCall methodCall) async {
  //     return '42';
  //   });
  // });

  // tearDown(() {
  //   channel.setMockMethodCallHandler(null);
  // });

  // test('getPlatformVersion', () async {
  //   // expect(await FlutterBluesnap.platformVersion, '42');
  // });
}
