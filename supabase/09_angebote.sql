-- Angebote (UC6, UC7), Vorschlag von Nick, 19.11.2026. Noch nicht ausgeführt.
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor» (ganze Datei, «Run»).
-- Mehrmals ausführen schadet nicht.
--
-- Inhalt:
--   1. Funktion mark_offers_seen: Der Käufer markiert neue Angebote als
--      «gesehen». Direkt darf er das nicht (RLS offer_update und
--      03_rechte.sql erlauben nur dem Verkäufer price und message).
--   2. CHECK-Regeln für offer: Preis höchstens CHF 10'000, Nachricht
--      höchstens 500 Zeichen (OfferLimits in lib/model/offer.dart).
--   3. Höchstens 3 Fotos pro Angebot (F-09) in der RLS-Regel photo_insert.
--
-- Vorher prüfen (muss 0 Zeilen liefern, sonst bricht Teil 2 ab):
--   select id, price, char_length(message) from public.offer
--    where price > 1000000 or char_length(message) > 500;


-- ---------------------------------------------------------------------
-- 1. Neue Angebote als gesehen markieren
-- ---------------------------------------------------------------------
-- Aufruf aus der App:  supabase.rpc('mark_offers_seen', params: {'p_want_id': wantId})
-- Ändert nur Angebote zu einem eigenen Gesuch und nur von «neu» zu «gesehen».
-- Bei einem fremden Gesuch passiert nichts (kein Fehler, verrät nichts).
create or replace function public.mark_offers_seen(p_want_id uuid)
returns void
language sql
security definer
set search_path to ''
as $$
  update public.offer o
     set status = 'gesehen'
    from public.want w
   where w.id = o.want_id
     and w.id = p_want_id
     and w.owner_id = (select auth.uid())
     and o.status = 'neu';
$$;

revoke execute on function public.mark_offers_seen(uuid) from public, anon;
grant  execute on function public.mark_offers_seen(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 2. CHECK-Regeln für offer (ergänzt 07_check_regeln.sql)
-- ---------------------------------------------------------------------
alter table public.offer drop constraint if exists offer_price_check;
alter table public.offer add  constraint offer_price_check
  check (price > 0 and price <= 1000000);

alter table public.offer drop constraint if exists offer_message_check;
alter table public.offer add  constraint offer_message_check
  check (message is null or char_length(message) <= 500);


-- ---------------------------------------------------------------------
-- 3. Höchstens 3 Fotos pro Angebot (F-09)
-- ---------------------------------------------------------------------
-- Absichtlich nicht «stable»: Nur eine volatile Funktion sieht die Zeilen,
-- die derselbe Befehl schon eingefügt hat. Die App fügt alle Fotos mit
-- einem insert ein, sonst kämen so auch 4 oder mehr Fotos durch.
create or replace function private.photo_count_ok(p_offer_id uuid)
returns boolean
language sql
security definer
set search_path to ''
as $$
  select (select count(*) from public.photo where offer_id = p_offer_id) < 3;
$$;

drop policy if exists photo_insert on public.photo;
create policy photo_insert on public.photo as PERMISSIVE for INSERT to authenticated
  with check (private.is_own_new_offer(offer_id) and private.photo_count_ok(offer_id));
