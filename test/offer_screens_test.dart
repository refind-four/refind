import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:refind/application/services/offer_service.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/model/model.dart';
import 'package:refind/presentation/chat/chat_screen.dart';
import 'package:refind/presentation/discover/offer_compose_sheet.dart';
import 'package:refind/presentation/theme.dart';
import 'package:refind/presentation/wants/want_detail_screen.dart';

/// Maske mit OfferService, ohne Anmelden-Maske davor.
///
/// Aufrufe ans Mock ausserhalb der Maske laufen in tester.runAsync: In
/// testWidgets steht die Uhr still, das Future.delayed im Mock würde sonst
/// nie fertig und der Test bliebe hängen.
Widget host(MockRefindRepository repo, Widget child) => Provider(
      create: (_) => OfferService(repo),
      child: MaterialApp(theme: buildRefindTheme(), home: child),
    );

void main() {
  late MockRefindRepository repo;

  setUp(() => repo = MockRefindRepository(delay: Duration.zero));

  testWidgets('UC6: Angebot mit Preis, Nachricht und Foto senden', (tester) async {
    await tester.runAsync(() => repo.signIn('luca@refind.test', 'refind123'));
    final item = (await tester.runAsync(() => repo.getFeed(const FeedFilter())))!
        .firstWhere((i) => i.want.id == 'want-5'); // Leica M6 von Mia
    Offer? result;

    await tester.pumpWidget(host(
      repo,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showOfferComposeSheet(
              context,
              item,
              pickPhoto: (_) async => File('test.jpg'), // statt Kamera
            ),
            child: const Text('öffnen'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    // Leer senden: Preis wird markiert, nichts gespeichert
    await tester.ensureVisible(find.text('Angebot senden').last);
    await tester.tap(find.text('Angebot senden').last);
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib einen Preis ein.'), findsOneWidget);

    // Über Budget (CHF 2'200): Hinweis für den Verkäufer
    await tester.enterText(find.byKey(const Key('offer-price')), '2300');
    await tester.pump();
    expect(find.textContaining('über der Preisobergrenze'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('offer-price')), "2'100");
    await tester.enterText(find.byKey(const Key('offer-message')), 'M6 von 1990');
    await tester.ensureVisible(find.byKey(const Key('offer-add-photo')));
    await tester.tap(find.byKey(const Key('offer-add-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus der Galerie wählen'));
    await tester.pumpAndSettle();
    expect(find.text('FOTOS (1/3)'), findsOneWidget);

    await tester.ensureVisible(find.text('Angebot senden').last);
    await tester.tap(find.text('Angebot senden').last);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.priceRappen, 210000);
    expect(result!.photos, hasLength(1));
    expect(find.text('Angebot gesendet.'), findsOneWidget);
  });

  testWidgets('F-09: nach drei Fotos kein weiteres', (tester) async {
    await tester.runAsync(() => repo.signIn('luca@refind.test', 'refind123'));
    final item = (await tester.runAsync(() => repo.getFeed(const FeedFilter())))!.first;
    await tester.pumpWidget(host(
      repo,
      Scaffold(
        body: OfferComposeSheet(item: item, pickPhoto: (_) async => File('x.jpg')),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.byKey(const Key('offer-add-photo')));
      await tester.tap(find.byKey(const Key('offer-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aus der Galerie wählen'));
      await tester.pumpAndSettle();
    }
    expect(find.text('FOTOS (3/3)'), findsOneWidget);
    expect(find.byKey(const Key('offer-add-photo')), findsNothing);
  });

  testWidgets('UC7: über Budget markiert, sortiert, annehmen öffnet den Chat',
      (tester) async {
    await tester.runAsync(() => repo.signIn('anna@refind.test', 'refind123'));
    final summary =
        (await tester.runAsync(repo.getMyWants))!.firstWhere((s) => s.want.id == 'want-1');

    await tester.pumpWidget(host(repo, WantDetailScreen(summary: summary)));
    await tester.pumpAndSettle();

    // F-10: günstigstes zuerst
    final prices = tester
        .widgetList<Text>(find.textContaining(RegExp(r"^CHF \d")))
        .map((t) => t.data)
        .toList();
    expect(prices, ["CHF 2'300", "CHF 2'450", "CHF 2'650"]);

    // F-11: nur Mias Angebot über CHF 2'500 ist markiert
    expect(find.byKey(const Key('over-budget-offer-4')), findsOneWidget);
    expect(find.text('ÜBER BUDGET +CHF 150'), findsOneWidget);
    expect(find.byKey(const Key('over-budget-offer-1')), findsNothing);

    // F-12: annehmen, bestätigen, Chat öffnet sich
    await tester.ensureVisible(find.byKey(const Key('accept-offer-1')));
    await tester.tap(find.byKey(const Key('accept-offer-1')));
    await tester.pumpAndSettle();
    expect(find.text('Angebot annehmen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Annehmen'));
    await tester.pumpAndSettle();

    final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chat.thread?.offerId, 'offer-1');
    final offers = (await tester.runAsync(
        () => repo.getOffers('want-1', OfferSort.neueste)))!;
    expect(offers.where((o) => o.status == OfferStatus.abgesagt), hasLength(2));
  });
}
