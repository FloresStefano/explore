import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekend_break/screens/home.dart';

void main() {
  testWidgets('home shows the slogan and opens the destinations', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(onExplore: () => opened = true)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Il mondo è troppo piccolo per non girarlo tutto.'), findsOneWidget);
    expect(find.text('Non hai più scuse!'), findsOneWidget);
    await tester.tap(find.text('Scopri le destinazioni'));
    expect(opened, isTrue);
  });
}
