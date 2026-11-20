import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:refind/application/services/auth_service.dart';
import 'package:refind/application/services/chat_service.dart';
import 'package:refind/application/services/offer_service.dart';
import 'package:refind/application/services/want_service.dart';
import 'package:refind/application/state/session_provider.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/model/model.dart';
import 'package:refind/presentation/chat/chat_screen.dart';
import 'package:refind/presentation/discover/offer_compose_sheet.dart';
import 'package:refind/presentation/theme.dart';
import 'package:refind/presentation/wants/want_detail_screen.dart';

/// Maske mit den Services, ohne Anmelden-Maske davor. ChatService und
/// SessionProvider braucht der Chat, der sich nach «Annehmen» öffnet.
///
/// Aufrufe ans Mock ausserhalb der Maske laufen in tester.runAsync: In
/// testWidgets steht die Uhr still, das Future.delayed im Mock würde sonst
/// nie fertig und der Test bliebe hängen.
Widget host(MockRefindRepository repo, Widget child) => MultiProvider(
      providers: [
        Provider(create: (_) => OfferService(repo)),
        Provider(create: (_) => WantService(repo)),
        Provider(create: (_) => ChatService(repo)),
        ChangeNotifierProvider(
            create: (_) => SessionProvider(AuthService(repo))..restore()),
      ],
      child: MaterialApp(theme: buildRefindTheme(), home: child),
    );

void main() {
  late MockRefindRepository repo;

  setUp(() => repo = MockRefindRepository(delay: Duration.zero));

  testWidgets('UC6: Angebot mit Preis, Nachricht und Foto senden', (tester) async {
    await tester.runAsync(() => repo.signIn('ben@refind.test', 'refind123'));
    final item = (await tester.runAsync(() => repo.getFeed(const FeedFilter())))!
        .firstWhere((i) => i.want.id == 'want-leica-m6'); // Leica M6 von Anna
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

    // Über Budget (CHF 2'800): Hinweis für den Verkäufer
    await tester.enterText(find.byKey(const Key('offer-price')), '2900');
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
    await tester.runAsync(() => repo.signIn('ben@refind.test', 'refind123'));
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
    // Hoher Bildschirm (360 × 1300 dp): Kopf mit Status-Knöpfen und alle
    // drei Angebote gleichzeitig sichtbar, damit die Reihenfolge prüfbar ist
    tester.view.physicalSize = const Size(1080, 3900);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => repo.signIn('anna@refind.test', 'refind123'));
    final summary =
        (await tester.runAsync(repo.getMyWants))!
            .firstWhere((s) => s.want.id == 'want-eames'); // Budget CHF 2'000

    await tester.pumpWidget(host(repo, WantDetailScreen(summary: summary)));
    await tester.pumpAndSettle();

    // F-10: günstigstes zuerst
    final prices = tester
        .widgetList<Text>(find.textContaining(RegExp(r"^CHF \d")))
        .map((t) => t.data)
        .toList();
    expect(prices, ["CHF 1'720", "CHF 1'950", "CHF 2'100"]);

    // F-11: nur Bens zweites Angebot über CHF 2'000 ist markiert
    expect(find.byKey(const Key('over-budget-offer-eames-ben-2')), findsOneWidget);
    expect(find.text('ÜBER BUDGET +CHF 100'), findsOneWidget);
    expect(find.byKey(const Key('over-budget-offer-eames-ben-1')), findsNothing);

    // F-12: annehmen, bestätigen, Chat öffnet sich
    await tester.ensureVisible(find.byKey(const Key('accept-offer-eames-ben-1')));
    await tester.tap(find.byKey(const Key('accept-offer-eames-ben-1')));
    await tester.pumpAndSettle();
    expect(find.text('Angebot annehmen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Annehmen'));
    await tester.pumpAndSettle();

    final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chat.thread?.offerId, 'offer-eames-ben-1');
    final offers = (await tester.runAsync(
        () => repo.getOffers('want-eames', OfferSort.neueste)))!;
    expect(offers.where((o) => o.status == OfferStatus.abgesagt), hasLength(2));

    // TC19: Der Chat ist wirklich offen, mit Ben, Gesuch und Angebotspreis
    expect(tester.widget<Text>(find.byKey(const Key('chat-title'))).data, 'Ben');
    expect(find.text('EAMES LOUNGE CHAIR'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('chat-price'))).data,
        "CHF 1'720");
    // Gleich die erste Nachricht schreiben
    await tester.enterText(find.byKey(const Key('chat-input')), 'Wann passt es dir?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Wann passt es dir?'), findsOneWidget);

    // TC19: Das Gesuch fehlt danach im Feed (hier: Cara)
    final feed = (await tester.runAsync(() async {
      await repo.signIn('cara@refind.test', 'refind123');
      return repo.getFeed(const FeedFilter());
    }))!;
    expect(feed.map((i) => i.want.id), isNot(contains('want-eames')));
  });
}
