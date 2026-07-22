import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quasar_io/models/cosmetic_item.dart';
import 'package:quasar_io/services/lang_service.dart';

void main() {
  testWidgets('shows localized app title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await LanguageService.instance.init();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text(LanguageService.instance.t('app_title')),
        ),
      ),
    );

    expect(find.text('Quasar.io'), findsOneWidget);
  });

  test('cosmetic catalog exposes starter and bot skins', () {
    expect(CosmeticCatalog.starterSkins, isNotEmpty);
    expect(CosmeticCatalog.legendarySkins, isNotEmpty);
    expect(CosmeticCatalog.findById('pulsar'), isNotNull);
    expect(CosmeticCatalog.findById('default'), isNotNull);
    expect(CosmeticCatalog.isStarterSkin('default'), isTrue);
  });
}
