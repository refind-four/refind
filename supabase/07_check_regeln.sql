-- CHECK-Regeln für refind (ABWEICHUNGEN.md Abschnitt 3, 4, 8.2 und 8.3).
--
-- Die App prüft diese Regeln schon (input_checks.dart). Die Datenbank muss
-- sie aber auch prüfen, damit niemand die App umgehen kann.
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor», in zwei Teilen:
--   TEIL A zuerst allein ausführen (markieren, dann «Run»).
--          Zeigt alle bestehenden Zeilen, die eine Regel verletzen.
--          Keine Zeilen = alles gut.
--   TEIL B danach ausführen. Fügt die Regeln hinzu.
--          Mehrmals ausführen schadet nicht (alte Regel wird ersetzt).
--          Verletzt noch eine Zeile eine Regel, bricht Teil B mit einem
--          Fehler ab und es wird gar nichts geändert.
--
-- Beträge in Rappen: CHF 10'000 = 1'000'000.


-- =====================================================================
-- TEIL A: Bestehende Daten prüfen
-- =====================================================================
select 'want' as tabelle, id::text as id, title as wert, 'Titel 1–80 Zeichen' as regel
  from public.want where char_length(btrim(title)) < 1 or char_length(title) > 80
union all
select 'want', id::text, left(description, 30), 'Beschreibung max. 1000 Zeichen'
  from public.want where char_length(description) > 1000
union all
select 'want', id::text, budget_max::text, 'Budget > 0 und <= 1''000''000 Rappen'
  from public.want where budget_max <= 0 or budget_max > 1000000
union all
select 'want', id::text, radius_km::text, 'Umkreis 1–200 km'
  from public.want where radius_km not between 1 and 200
union all
select 'want', id::text, (expires_at - created_at)::text, 'Laufzeit 7, 14 oder 30 Tage'
  from public.want
 where not (   expires_at between created_at + interval '7 days'  - interval '1 hour'
                              and created_at + interval '7 days'  + interval '1 hour'
            or expires_at between created_at + interval '14 days' - interval '1 hour'
                              and created_at + interval '14 days' + interval '1 hour'
            or expires_at between created_at + interval '30 days' - interval '1 hour'
                              and created_at + interval '30 days' + interval '1 hour')
union all
select 'want', id::text, category, 'Kategorie nicht erlaubt'
  from public.want
 where category not in ('Uhren', 'Möbel', 'Velo', 'Vinyl', 'Kameras', 'Werkzeug')
union all
select 'want', id::text, category || ' / ' || condition, 'Zustand passt nicht zur Kategorie'
  from public.want
 where (category, condition) not in (
        ('Uhren',    'Original'), ('Uhren',    'Serviciert'),         ('Uhren',    'Egal'),
        ('Möbel',    'Wie neu'),  ('Möbel',    'Gebraucht'),          ('Möbel',    'Egal'),
        ('Velo',     'Fahrbereit'), ('Velo',   'Revisionsbedürftig'), ('Velo',     'Egal'),
        ('Vinyl',    'Neuwertig'), ('Vinyl',   'Gebraucht (leichtes Knistern ok)'), ('Vinyl', 'Egal'),
        ('Kameras',  'Voll funktionsfähig'), ('Kameras', 'Mit Mängeln'), ('Kameras', 'Egal'),
        ('Werkzeug', 'Neu'),      ('Werkzeug', 'Gebraucht'),          ('Werkzeug', 'Egal'))
union all
select 'offer', id::text, price::text, 'Preis > 0'
  from public.offer where price <= 0
union all
select 'profile', id::text, display_name, 'Anzeigename 1–40 Zeichen'
  from public.profile where char_length(btrim(display_name)) < 1 or char_length(display_name) > 40
union all
select 'profile', id::text, radius_km::text, 'Umkreis 1–200 km'
  from public.profile where radius_km not between 1 and 200
union all
select 'rating', id::text, stars::text, 'Sterne 1–5'
  from public.rating where stars not between 1 and 5;


-- =====================================================================
-- TEIL B: Regeln hinzufügen
-- =====================================================================

-- ---------- want (Gesuch) ----------
alter table public.want drop constraint if exists want_title_check;
alter table public.want add  constraint want_title_check
  check (char_length(btrim(title)) between 1 and 80 and char_length(title) <= 80);

alter table public.want drop constraint if exists want_description_check;
alter table public.want add  constraint want_description_check
  check (description is null or char_length(description) <= 1000);

alter table public.want drop constraint if exists want_budget_max_check;
alter table public.want add  constraint want_budget_max_check
  check (budget_max > 0 and budget_max <= 1000000);

alter table public.want drop constraint if exists want_radius_km_check;
alter table public.want add  constraint want_radius_km_check
  check (radius_km between 1 and 200);

-- Laufzeit: expires_at liegt 7, 14 oder 30 Tage nach created_at.
-- 1 Stunde Spielraum, weil die App expires_at mit der Uhr des Handys
-- ausrechnet, created_at aber die Uhr des Servers ist.
alter table public.want drop constraint if exists want_laufzeit_check;
alter table public.want add  constraint want_laufzeit_check
  check (   expires_at between created_at + interval '7 days'  - interval '1 hour'
                           and created_at + interval '7 days'  + interval '1 hour'
         or expires_at between created_at + interval '14 days' - interval '1 hour'
                           and created_at + interval '14 days' + interval '1 hour'
         or expires_at between created_at + interval '30 days' - interval '1 hour'
                           and created_at + interval '30 days' + interval '1 hour');

alter table public.want drop constraint if exists want_category_check;
alter table public.want add  constraint want_category_check
  check (category in ('Uhren', 'Möbel', 'Velo', 'Vinyl', 'Kameras', 'Werkzeug'));

-- Zustand: nur die Werte, die zur Kategorie gehören (Abschnitt 4)
alter table public.want drop constraint if exists want_condition_check;
alter table public.want add  constraint want_condition_check
  check ((category, condition) in (
        ('Uhren',    'Original'), ('Uhren',    'Serviciert'),         ('Uhren',    'Egal'),
        ('Möbel',    'Wie neu'),  ('Möbel',    'Gebraucht'),          ('Möbel',    'Egal'),
        ('Velo',     'Fahrbereit'), ('Velo',   'Revisionsbedürftig'), ('Velo',     'Egal'),
        ('Vinyl',    'Neuwertig'), ('Vinyl',   'Gebraucht (leichtes Knistern ok)'), ('Vinyl', 'Egal'),
        ('Kameras',  'Voll funktionsfähig'), ('Kameras', 'Mit Mängeln'), ('Kameras', 'Egal'),
        ('Werkzeug', 'Neu'),      ('Werkzeug', 'Gebraucht'),          ('Werkzeug', 'Egal')));

-- ---------- offer (Angebot) ----------
alter table public.offer drop constraint if exists offer_price_check;
alter table public.offer add  constraint offer_price_check
  check (price > 0);

-- ---------- profile ----------
alter table public.profile drop constraint if exists profile_display_name_check;
alter table public.profile add  constraint profile_display_name_check
  check (char_length(btrim(display_name)) between 1 and 40 and char_length(display_name) <= 40);

alter table public.profile drop constraint if exists profile_radius_km_check;
alter table public.profile add  constraint profile_radius_km_check
  check (radius_km between 1 and 200);

-- ---------- rating (Bewertung) ----------
alter table public.rating drop constraint if exists rating_stars_check;
alter table public.rating add  constraint rating_stars_check
  check (stars between 1 and 5);
