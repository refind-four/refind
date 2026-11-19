-- Testdaten für refind (ersetzt 05_orte_vorlaeufig.sql).
--
-- Voraussetzung: Die drei Testkonten sind im Dashboard angelegt
-- (Authentication -> Users -> Add user, Auto Confirm User):
--   anna@refind.test, ben@refind.test, cara@refind.test
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor».
-- Mehrmals ausführen schadet nicht: Zuerst werden alle alten Daten der
-- drei Testkonten gelöscht, dann neu angelegt. Andere Konten bleiben
-- unverändert. Die Orte werden nur ergänzt, wenn sie noch fehlen.
--
-- Beträge in Rappen (CHF 1.00 = 100).
-- Am Schluss zeigt eine Tabelle alle Gesuche der Testkonten (9 Zeilen).

-- ---------------------------------------------------------------------
-- 1. Vorläufige Ortschaften (aus 05_orte_vorlaeufig.sql übernommen)
-- ---------------------------------------------------------------------
-- Koordinaten: LV95 in Metern (e = Ost, n = Nord), Stadtzentrum, auf etwa
-- 100 m gerundet. Übergang, bis das Ortschaftenverzeichnis von swisstopo
-- importiert ist (Konzept 2.1).

insert into public.place (plz, name, e, n)
select v.plz, v.name, v.e, v.n
from (values
  (3000, 'Bern',        2600670, 1199655),
  (8001, 'Zürich',      2683100, 1247500),
  (8400, 'Winterthur',  2697000, 1261800),
  (4001, 'Basel',       2611300, 1267500),
  (6003, 'Luzern',      2666200, 1211500),
  (9000, 'St. Gallen',  2746000, 1254500),
  (1003, 'Lausanne',    2538000, 1152500),
  (1201, 'Genève',      2500200, 1118000)
) as v (plz, name, e, n)
where not exists (
  select 1 from public.place p where p.plz = v.plz and p.name = v.name
);

-- ---------------------------------------------------------------------
-- 2. Testdaten der Konten A, B, C
-- ---------------------------------------------------------------------
do $$
declare
  v_anna   uuid;
  v_ben    uuid;
  v_cara   uuid;
  v_bern   integer;
  v_zuerich integer;
  v_omega  uuid;
  v_offer_ben uuid;
  v_thread uuid;
  -- für Schritt 2
  v_winterthur integer;
  v_want   uuid;
  v_offer  uuid;
begin
  -- Konten über die Mailadresse finden
  select id into v_anna from auth.users where email = 'anna@refind.test';
  select id into v_ben  from auth.users where email = 'ben@refind.test';
  select id into v_cara from auth.users where email = 'cara@refind.test';

  if v_anna is null or v_ben is null or v_cara is null then
    raise exception 'Testkonto fehlt. Bitte zuerst anna@, ben@ und cara@refind.test im Dashboard anlegen.';
  end if;

  select id into v_bern    from public.place where plz = 3000 and name = 'Bern';
  select id into v_zuerich from public.place where plz = 8001 and name = 'Zürich';

  -- 2a. Alte Testdaten löschen (Reihenfolge wegen der Fremdschlüssel)
  delete from public.rating
   where from_user_id in (v_anna, v_ben, v_cara)
      or to_user_id   in (v_anna, v_ben, v_cara);

  delete from public.message
   where thread_id in (select id from public.chat_thread
                        where buyer_id  in (v_anna, v_ben, v_cara)
                           or seller_id in (v_anna, v_ben, v_cara));

  delete from public.chat_thread
   where buyer_id  in (v_anna, v_ben, v_cara)
      or seller_id in (v_anna, v_ben, v_cara);

  delete from public.photo
   where offer_id in (select o.id from public.offer o
                       join public.want w on w.id = o.want_id
                       where o.seller_id in (v_anna, v_ben, v_cara)
                          or w.owner_id  in (v_anna, v_ben, v_cara));

  delete from public.offer o
   using public.want w
   where w.id = o.want_id
     and (o.seller_id in (v_anna, v_ben, v_cara)
          or w.owner_id in (v_anna, v_ben, v_cara));

  delete from public.want
   where owner_id in (v_anna, v_ben, v_cara);

  -- 2b. Profile (werden beim Anlegen des Kontos automatisch erstellt,
  --     hier nur Name und Wohnort setzen; falls eines fehlt, anlegen)
  insert into public.profile (id, display_name, city_id, radius_km, member_since)
  values (v_anna, 'Anna', v_bern,    20, date '2026-09-01'),
         (v_ben,  'Ben',  v_zuerich, 30, date '2026-08-15'),
         (v_cara, 'Cara', null,      20, date '2026-10-20')
  on conflict (id) do update
     set display_name = excluded.display_name,
         city_id      = excluded.city_id,
         radius_km    = excluded.radius_km,
         avatar_url   = null,
         member_since = excluded.member_since;

  -- 2c. Gesuch «Omega Speedmaster» von Anna (aktiv, Laufzeit 14 Tage)
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_anna, 'Omega Speedmaster', 'Uhren',
          'Moonwatch, gerne mit Box und Papieren.',
          650000,                          -- CHF 6''500
          'Original', v_bern, 50,
          now() - interval '2 days',
          now() - interval '2 days' + interval '14 days',
          'aktiv')
  returning id into v_omega;

  -- 2d. Drei Angebote: Ben (angenommen, dazu gibt es den Chat, UC7 -> UC8),
  --     zwei von Cara (dadurch abgesagt)
  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_omega, v_ben, 590000,
          'Speedmaster Professional 2019, serviciert, mit Box und Papieren.',
          now() - interval '1 day 20 hours', 'angenommen')
  returning id into v_offer_ben;

  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_omega, v_cara, 620000,
          'Speedmaster Reduced, guter Zustand, ohne Papiere.',
          now() - interval '1 day 6 hours', 'abgesagt'),
         (v_omega, v_cara, 640000,
          'Speedmaster Moonwatch Hesalite, Erstbesitz.',
          now() - interval '3 hours', 'abgesagt');

  -- 2e. Chat zwischen Anna (Käuferin) und Ben (Verkäufer) zu Bens Angebot
  insert into public.chat_thread (offer_id, want_id, buyer_id, seller_id, last_activity)
  values (v_offer_ben, v_omega, v_anna, v_ben, now() - interval '1 day')
  returning id into v_thread;

  insert into public.message (thread_id, sender_id, kind, body, created_at, read_at)
  values (v_thread, v_anna, 'text',
          'Hallo Ben, wann war der letzte Service?',
          now() - interval '1 day 2 hours', now() - interval '1 day 1 hour'),
         (v_thread, v_ben, 'text',
          'Hallo Anna, im März 2025 bei Omega. Die Quittung ist dabei.',
          now() - interval '1 day 1 hour', now() - interval '1 day'),
         (v_thread, v_anna, 'text',
          'Super. Könnte ich die Uhr am Samstag in Zürich anschauen?',
          now() - interval '1 day', null);

  -- -------------------------------------------------------------------
  -- 3. Restliche Testdaten
  -- -------------------------------------------------------------------
  -- Jedes Gesuch: expires_at = created_at + 7, 14 oder 30 Tage
  -- (Laufzeit-Regel aus ABWEICHUNGEN.md 3.9).

  select id into v_winterthur from public.place where plz = 8400 and name = 'Winterthur';

  -- 3a. «Leica M6» von Anna, Region Winterthur, aktiv, ein Angebot von Cara
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_anna, 'Leica M6', 'Kameras',
          'Gehäuse, gerne mit 50 mm Summicron.',
          280000,                          -- CHF 2''800
          'Voll funktionsfähig', v_winterthur, 20,
          now() - interval '3 days',
          now() - interval '3 days' + interval '30 days',
          'aktiv')
  returning id into v_want;

  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_want, v_cara, 265000,
          'M6 TTL von 1998, Belichtungsmesser funktioniert.',
          now() - interval '1 day', 'neu');

  -- 3b. «Leica Q2» von Anna, Region Bern, aktiv, 3 Angebote (TC09):
  --     Ben (gesehen), Cara zweimal (neu)
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_anna, 'Leica Q2', 'Kameras', null,
          380000,                          -- CHF 3''800
          'Egal', v_bern, 30,
          now() - interval '1 day',
          now() - interval '1 day' + interval '7 days',
          'aktiv')
  returning id into v_want;

  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_want, v_ben,  360000, 'Q2 von 2021, mit zweitem Akku.',
          now() - interval '20 hours', 'gesehen'),
         (v_want, v_cara, 345000, 'Q2 mit Gebrauchsspuren am Gehäuse.',
          now() - interval '8 hours', 'neu'),
         (v_want, v_cara, 375000, 'Q2 wie neu, Garantie bis 2027.',
          now() - interval '2 hours', 'neu');

  -- 3c. «Rolex Datejust 36» von Anna, pausiert
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_anna, 'Rolex Datejust 36', 'Uhren',
          'Stahl, Zifferblatt silber oder blau.',
          700000,                          -- CHF 7''000
          'Serviciert', v_bern, 50,
          now() - interval '5 days',
          now() - interval '5 days' + interval '30 days',
          'pausiert');

  -- 3d. «Eames Lounge Chair» von Ben, Budget CHF 2'000,
  --     Angebote CHF 1'720 / 1'950 / 2'100 (das letzte liegt über dem Budget)
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_ben, 'Eames Lounge Chair', 'Möbel',
          'Mit Ottomane, Leder schwarz.',
          200000,                          -- CHF 2''000
          'Gebraucht', v_zuerich, 50,
          now() - interval '4 days',
          now() - interval '4 days' + interval '14 days',
          'aktiv')
  returning id into v_want;

  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_want, v_anna, 172000, 'Lizenzversion, Leder mit Gebrauchsspuren.',
          now() - interval '3 days', 'neu'),
         (v_want, v_cara, 195000, 'Original Vitra, 2015 gekauft.',
          now() - interval '2 days', 'gesehen'),
         (v_want, v_cara, 210000, 'Original Vitra, wie neu, mit Rechnung.',
          now() - interval '5 hours', 'neu');

  -- 3e. Abgelaufenes Gesuch von Anna (Laufzeit 14 Tage, vor 6 Tagen abgelaufen)
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_anna, 'Technics SL-1200', 'Vinyl', null,
          60000,                           -- CHF 600
          'Egal', v_bern, 20,
          now() - interval '20 days',
          now() - interval '20 days' + interval '14 days',
          'abgelaufen');

  -- 3f. Drei erledigte Gesuche, bei denen Ben verkauft hat.
  --     Jedes hat ein angenommenes Angebot und einen abgeschlossenen Chat,
  --     dazu die Bewertung für Ben (5, 4 und 3 Sterne).

  -- Erledigt 1: Anna kauft von Ben, 5 Sterne
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_anna, 'Brompton M6L', 'Velo', null, 150000,
          'Fahrbereit', v_bern, 100,
          now() - interval '60 days',
          now() - interval '60 days' + interval '30 days',
          'erledigt')
  returning id into v_want;

  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_want, v_ben, 120000, 'Brompton 2020, frisch serviciert.',
          now() - interval '58 days', 'angenommen')
  returning id into v_offer;

  insert into public.chat_thread (offer_id, want_id, buyer_id, seller_id, last_activity,
                                  handover_at, handover_place, agreed_price, closed_at)
  values (v_offer, v_want, v_anna, v_ben, now() - interval '50 days',
          now() - interval '52 days', 'Bahnhof Bern, Treffpunkt', 120000,
          now() - interval '50 days')
  returning id into v_thread;

  insert into public.message (thread_id, sender_id, kind, body, created_at, read_at)
  values (v_thread, v_anna, 'text', 'Danke, das Velo fährt super!',
          now() - interval '51 days', now() - interval '50 days');

  insert into public.rating (from_user_id, to_user_id, thread_id, stars, created_at)
  values (v_anna, v_ben, v_thread, 5, now() - interval '50 days');

  -- Erledigt 2: Cara kauft von Ben, 4 Sterne
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_cara, 'Makita Akku-Bohrschrauber', 'Werkzeug', null, 15000,
          'Gebraucht', v_zuerich, 30,
          now() - interval '45 days',
          now() - interval '45 days' + interval '14 days',
          'erledigt')
  returning id into v_want;

  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_want, v_ben, 9000, 'Mit zwei Akkus und Koffer.',
          now() - interval '44 days', 'angenommen')
  returning id into v_offer;

  insert into public.chat_thread (offer_id, want_id, buyer_id, seller_id, last_activity,
                                  handover_at, handover_place, agreed_price, closed_at)
  values (v_offer, v_want, v_cara, v_ben, now() - interval '40 days',
          now() - interval '41 days', 'Zürich HB', 8500,
          now() - interval '40 days')
  returning id into v_thread;

  insert into public.rating (from_user_id, to_user_id, thread_id, stars, created_at)
  values (v_cara, v_ben, v_thread, 4, now() - interval '40 days');

  -- Erledigt 3: Anna kauft von Ben, 3 Sterne
  insert into public.want (owner_id, title, category, description, budget_max,
                           condition, region_id, radius_km, created_at,
                           expires_at, status)
  values (v_anna, 'Miles Davis – Kind of Blue', 'Vinyl', 'Originalpressung bevorzugt.', 8000,
          'Gebraucht (leichtes Knistern ok)', v_bern, 200,
          now() - interval '35 days',
          now() - interval '35 days' + interval '7 days',
          'erledigt')
  returning id into v_want;

  insert into public.offer (want_id, seller_id, price, message, created_at, status)
  values (v_want, v_ben, 6000, 'Nachpressung 1997, Hülle mit Knick.',
          now() - interval '34 days', 'angenommen')
  returning id into v_offer;

  insert into public.chat_thread (offer_id, want_id, buyer_id, seller_id, last_activity,
                                  handover_at, handover_place, agreed_price, closed_at)
  values (v_offer, v_want, v_anna, v_ben, now() - interval '30 days',
          null, 'Versand per Post', 6000,
          now() - interval '30 days')
  returning id into v_thread;

  insert into public.rating (from_user_id, to_user_id, thread_id, stars, created_at)
  values (v_anna, v_ben, v_thread, 3, now() - interval '30 days');
end $$;

-- ---------------------------------------------------------------------
-- 4. Kontrolle: Übersicht der Testdaten
-- ---------------------------------------------------------------------
select w.title, p.display_name as besitzer, pl.name as region, w.status,
       w.budget_max / 100 as budget_chf,
       (select count(*) from public.offer o where o.want_id = w.id) as angebote
from public.want w
join public.profile p on p.id = w.owner_id
join public.place pl on pl.id = w.region_id
where p.display_name in ('Anna', 'Ben', 'Cara')
order by w.created_at desc;
