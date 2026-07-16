import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hotel_casablanca_flutter/main.dart';

void main() {
  testWidgets('muestra la navegacion principal', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const HotelCasablancaApp());
    await tester.pump();

    expect(find.text('Casa Blanca'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Nuestras Habitaciones'), findsOneWidget);
  });
}
