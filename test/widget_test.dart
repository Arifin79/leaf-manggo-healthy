import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leaf_healthy_manggo/shared/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton shows its label and responds to taps', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Klasifikasi Sekarang',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Klasifikasi Sekarang'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton shows a spinner instead of its label while loading', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Klasifikasi Sekarang',
            isLoading: true,
          ),
        ),
      ),
    );

    expect(find.text('Klasifikasi Sekarang'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
