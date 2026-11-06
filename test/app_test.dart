import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidtoon/app_state.dart';
import 'package:kidtoon/main.dart';
import 'package:kidtoon/screens/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('prima pornire: copilul alege numele, apoi ajunge Acasă unde prietenul îl salută', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs);
    // Poveștile se citesc dintr-un fișier mare (în alt fir), deci le încărcăm în timp real.
    await tester.runAsync(state.loadGhi);
    expect(state.ghiBook, isNotNull);

    await tester.pumpWidget(KidToonApp(state: state));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Salut! Cum mă cheamă?'), findsOneWidget);
    expect(find.text('Alege întâi un nume'), findsOneWidget);

    await tester.tap(find.text('Zuzu'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Salut! Eu sunt Zuzu!'), findsOneWidget);
    await tester.tap(find.text('Fată'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Hai să ne jucăm cu Zuzu!'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.text('Bună! Eu sunt Zuzu!'), findsOneWidget);
    expect(state.character.name, 'Zuzu');
    expect(state.character.girl, isTrue);
    expect(prefs.getBool('characterChosen'), isTrue);

    // Poveștile poartă numele ales, nu „GHI”.
    await tester.tap(find.byTooltip('Povești'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('🎬 Povești cu Zuzu'), findsOneWidget);
    expect(find.textContaining('GHI'), findsNothing);

    // Setările sunt după poarta părinților.
    await tester.tap(find.byTooltip('Părinți'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Doar pentru părinți'), findsOneWidget);
    expect(find.textContaining('Cât face'), findsOneWidget);
    await tester.tap(find.text('Renunță'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
