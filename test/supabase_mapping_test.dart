// Prüft die Teile von SupabaseRefindRepository, die ohne Netz laufen:
// Umwandlung der Datenbankzeilen und Übersetzung der Fehler.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/repository_exception.dart';
import 'package:refind/data/supabase_refind_repository.dart';
import 'package:refind/model/model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> wantRow({
  String status = 'aktiv',
  String expiresAt = '2026-11-26T10:00:00+00:00',
  String? description,
}) =>
    {
      'id': 'b1f0c2e4-0000-0000-0000-000000000001',
      'owner_id': 'a0000000-0000-0000-0000-000000000001',
      'title': 'Omega Seamaster',
      'category': 'Uhren',
      'description': description,
      'budget_max': 165000,
      'condition': 'Original',
      'region_id': 3,
      'radius_km': 20,
      'created_at': '2026-11-12T10:00:00+00:00',
      'expires_at': expiresAt,
      'status': status,
    };

void main() {
  group('Datenbankzeile → Modell', () {
    test('place', () {
      final p = placeFromRow(
          {'id': 3, 'plz': 3011, 'name': 'Bern', 'e': 2600000, 'n': 1200000});
      expect(p.label, '3011 Bern');
      expect(p.e, 2600000);
    });

    test('profile ohne Wohnort', () {
      final u = userFromRow({
        'id': 'a0000000-0000-0000-0000-000000000001',
        'display_name': 'Anna',
        'city_id': null,
        'avatar_url': null,
        'radius_km': 20,
        'member_since': '2026-11-12',
      });
      expect(u.displayName, 'Anna');
      expect(u.cityId, isNull);
      expect(u.memberSince, DateTime(2026, 11, 12));
    });

    test('want: Beträge in Rappen, leere Beschreibung wird ""', () {
      final w = wantRow();
      final want = wantFromRow(w, now: DateTime.utc(2026, 11, 12, 12));
      expect(want.budgetMaxRappen, 165000);
      expect(want.description, '');
      expect(want.status, WantStatus.aktiv);
    });

    test('want: aktiv, aber Ablaufdatum vorbei → abgelaufen', () {
      final want = wantFromRow(wantRow(), now: DateTime.utc(2026, 11, 27));
      expect(want.status, WantStatus.abgelaufen);
    });

    test('want: pausiert bleibt pausiert, auch nach Ablauf', () {
      final want =
          wantFromRow(wantRow(status: 'pausiert'), now: DateTime.utc(2026, 12));
      expect(want.status, WantStatus.pausiert);
    });

    test('Zeile aus get_feed mit Region und Name des Käufers', () {
      final item = feedItemFromRow({
        ...wantRow(),
        'region': {'id': 3, 'plz': 3000, 'name': 'Bern', 'e': 2600670, 'n': 1199655},
        'owner': {'display_name': 'Anna'},
      });
      expect(item.buyerName, 'Anna');
      expect(item.region.name, 'Bern');
      expect(item.want.title, 'Omega Seamaster');
    });
  });

  group('Suchmuster für ilike', () {
    test('enthält', () => expect(containsPattern('Leica'), '%Leica%'));

    test('% und _ aus der Eingabe gelten nicht als Platzhalter', () {
      expect(containsPattern('100%'), r'%100\%%');
      expect(containsPattern('a_b'), r'%a\_b%');
      expect(containsPattern(r'a\b'), r'%a\\b%');
    });
  });

  group('Fehler von Supabase → RepositoryException', () {
    RepositoryException map(Object e) => mapSupabaseError(e) as RepositoryException;

    test('falsches Passwort', () {
      final e = map(const AuthApiException('Invalid login credentials',
          statusCode: '400', code: 'invalid_credentials'));
      expect(e.kind, RepositoryErrorKind.nichtBerechtigt);
      expect(e.message, 'Mailadresse oder Passwort ist falsch.');
    });

    test('Mail nicht bestätigt', () {
      final e = map(const AuthApiException('Email not confirmed',
          statusCode: '400', code: 'email_not_confirmed'));
      expect(e.kind, RepositoryErrorKind.mailNichtBestaetigt);
    });

    test('Konto existiert schon: verrät nichts', () {
      final e = map(const AuthApiException('User already registered',
          statusCode: '422', code: 'user_already_exists'));
      expect(e.kind, RepositoryErrorKind.konflikt);
      expect(e.message, isNot(contains('registered')));
    });

    test('zu viele Versuche', () {
      final e = map(const AuthApiException('rate limit',
          statusCode: '429', code: 'over_request_rate_limit'));
      expect(e.message, contains('Zu viele Versuche'));
    });

    test('kein Netz', () {
      expect(map(const SocketException('Failed host lookup')).kind,
          RepositoryErrorKind.keineVerbindung);
      expect(map(AuthRetryableFetchException(message: 'offline')).kind,
          RepositoryErrorKind.keineVerbindung);
    });

    test('RLS verweigert', () {
      final e = map(const PostgrestException(
          message: 'new row violates row-level security policy', code: '42501'));
      expect(e.kind, RepositoryErrorKind.nichtBerechtigt);
      expect(e.message, isNot(contains('row-level')));
    });

    test('CHECK-Regel oder unbekannte Region', () {
      expect(map(const PostgrestException(message: 'check', code: '23514')).kind,
          RepositoryErrorKind.ungueltigeEingabe);
      expect(map(const PostgrestException(message: 'fk', code: '23503')).kind,
          RepositoryErrorKind.ungueltigeEingabe);
    });

    test('Programmierfehler werden nicht versteckt', () {
      final error = StateError('Fehler im Code');
      expect(mapSupabaseError(error), same(error));
    });
  });
}
