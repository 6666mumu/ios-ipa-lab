import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipa_lab/main.dart';

void main() {
  testWidgets('offline smoke test increments and resets', (tester) async {
    await tester.pumpWidget(const IpaLabApp());
    expect(find.text('云端构建测试'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('tap-count'))).data, '0');
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('tap-count'))).data, '1');
    await tester.tap(find.byKey(const Key('reset')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('tap-count'))).data, '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen with large text can scroll without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const IpaLabApp());
    await tester.ensureVisible(find.byKey(const Key('increment')));
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('tap-count'))).data, '1');
    expect(tester.takeException(), isNull);
  });
}
