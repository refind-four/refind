// Fotos zu Angeboten (F-09, TC16): Grösse, Dateityp, Links, Anzeige.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:refind/application/services/offer_service.dart';
import 'package:refind/application/services/want_service.dart';
import 'package:refind/data/input_checks.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/data/repository_exception.dart';
import 'package:refind/data/supabase_refind_repository.dart';
import 'package:refind/model/model.dart';
import 'package:refind/presentation/discover/offer_compose_sheet.dart';
import 'package:refind/presentation/theme.dart';
import 'package:refind/presentation/wants/want_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory dir;

  setUpAll(() => dir = Directory.systemTemp.createTempSync('refind_fotos'));
  tearDownAll(() => dir.deleteSync(recursive: true));

  /// Datei mit [bytes] Bytes im Temp-Ordner.
  File fileOf(String name, int bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 0));

  const fiveMb = 5 * 1024 * 1024;

  group('Grösse (Prüfung in Repository und Maske)', () {
    test('genau 5 MB ist erlaubt, ein Byte mehr nicht', () {
      expect(OfferLimits.maxPhotoBytes, fiveMb);
      checkOfferPhotoSizes([0, 1000, fiveMb]); // wirft nicht
      expect(
        () => checkOfferPhotoSizes([1000, fiveMb + 1]),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.ungueltigeEingabe)
            .having((e) => e.message, 'message', photoTooLargeMessage)),
      );
    });

    test('fileSizes: echte Grösse, fehlende Datei zählt 0', () {
      expect(fileSizes([fileOf('a.jpg', 1234), File('${dir.path}/fehlt.jpg')]),
          [1234, 0]);
    });

    test('Mock lehnt ein zu grosses Foto ab, es entsteht kein Angebot', () async {
      final repo = MockRefindRepository(delay: Duration.zero);
      await repo.signIn('ben@refind.test', 'refind123');
      await expectLater(
        repo.createOffer('want-leica-m6', 250000, '', [fileOf('gross.jpg', fiveMb + 1)]),
        throwsA(isA<RepositoryException>()
            .having((e) => e.message, 'message', photoTooLargeMessage)),
      );
      await repo.signOut();
      await repo.signIn('anna@refind.test', 'refind123');
      final offers = await repo.getOffers('want-leica-m6', OfferSort.neueste);
      expect(offers.map((o) => o.id), ['offer-m6-cara']);
    });
  });

  group('Dateityp und Links (Supabase)', () {
    test('Endung und Medientyp, wie der Bucket sie erlaubt', () {
      expect(photoFileType('/data/x/IMG_1.jpg'), ('jpg', 'image/jpeg'));
      expect(photoFileType('/data/x/IMG_1.JPEG'), ('jpg', 'image/jpeg'));
      expect(photoFileType('/data/x/scan.png'), ('png', 'image/png'));
      expect(photoFileType('/data/x/bild.webp'), ('webp', 'image/webp'));
      // unbekannt: als JPEG, das liefert image_picker beim Verkleinern
      expect(photoFileType('/data/x/bild.heic'), ('jpg', 'image/jpeg'));
    });

    test('nur erfolgreiche Links, fehlgeschlagene fallen weg', () {
      final map = signedUrlsByPath(const [
        SignedUrlSuccess(path: 'u/o/1.jpg', signedUrl: 'https://x/1?token=a'),
        SignedUrlFailure(path: 'u/o/2.jpg', error: 'Object not found'),
      ]);
      expect(map, {'u/o/1.jpg': 'https://x/1?token=a'});
    });
  });

  group('Masken', () {
    void phoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 3900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('zu grosses Foto wird gar nicht erst aufgenommen', (tester) async {
      phoneSize(tester);
      final repo = MockRefindRepository(delay: Duration.zero);
      await tester.runAsync(() => repo.signIn('ben@refind.test', 'refind123'));
      final item = (await tester.runAsync(() => repo.getFeed(const FeedFilter())))!
          .firstWhere((i) => i.want.id == 'want-leica-m6');
      final big = fileOf('gross2.jpg', fiveMb + 1);

      await tester.pumpWidget(Provider(
        create: (_) => OfferService(repo),
        child: MaterialApp(
          theme: buildRefindTheme(),
          home: Scaffold(
            body: OfferComposeSheet(item: item, pickPhoto: (_) async => big),
          ),
        ),
      ));
      await tester.ensureVisible(find.byKey(const Key('offer-add-photo')));
      await tester.tap(find.byKey(const Key('offer-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aus der Galerie wählen'));
      await tester.pumpAndSettle();

      expect(find.text(photoTooLargeMessage), findsOneWidget);
      expect(find.text('FOTOS (0/3)'), findsOneWidget);
    });

    testWidgets('TC16: Käufer sieht die Fotos und kann sie gross öffnen',
        (tester) async {
      phoneSize(tester);
      final repo = MockRefindRepository(delay: Duration.zero);
      final photos = [
        fileOf('m6_1.jpg', 100),
        fileOf('m6_2.jpg', 100),
        fileOf('m6_3.jpg', 100),
      ];
      await tester.runAsync(() async {
        await repo.signIn('ben@refind.test', 'refind123');
        await repo.createOffer('want-leica-m6', 250000, 'M6 mit drei Fotos', photos);
        await repo.signOut();
        await repo.signIn('anna@refind.test', 'refind123');
      });
      final summary = (await tester.runAsync(repo.getMyWants))!
          .firstWhere((s) => s.want.id == 'want-leica-m6');

      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider(create: (_) => OfferService(repo)),
          Provider(create: (_) => WantService(repo)),
        ],
        child: MaterialApp(
          theme: buildRefindTheme(),
          home: WantDetailScreen(summary: summary),
        ),
      ));
      await tester.pumpAndSettle();

      // Alle drei Fotos beim Angebot von Ben
      final thumbs = find.byWidgetPredicate((w) => w is Image);
      expect(thumbs, findsNWidgets(3));

      await tester.tap(thumbs.first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offer-photo-large')), findsOneWidget);

      // Tipp schliesst die grosse Ansicht
      await tester.tap(find.byKey(const Key('offer-photo-large')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offer-photo-large')), findsNothing);
    });
  });
}
