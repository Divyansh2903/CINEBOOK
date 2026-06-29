import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cinebook_app/core/format.dart';

void main() {
  test('rupees formats whole-rupee integers with the ₹ symbol', () {
    expect(rupees(1250), '₹1,250');
    expect(rupees(800), '₹800');
  });

  testWidgets('a bare scaffold renders without crashing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
