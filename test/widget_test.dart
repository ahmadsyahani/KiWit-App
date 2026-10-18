import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/widgets/risk_badge.dart';

void main() {
  testWidgets('RiskBadge displays correct text and renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RiskBadge(level: RiskLevel.rendah),
        ),
      ),
    );

    expect(find.text('Rendah'), findsOneWidget);
  });
}
