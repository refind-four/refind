-- Konto löschen (UC2, TC06, N-05), 20.11.2026
--
-- Ablauf in der App (SupabaseRefindRepository.deleteAccount):
--   1. account_photo_paths()   liefert die Pfade der EIGENEN Fotos
--   2. Storage-API             löscht diese Dateien (Regeln aus Teil 3)
--   3. delete_own_account()    löscht alle Zeilen in einer Transaktion
--   4. lokal abmelden          zurück zu «Anmelden»
--
-- Was gelöscht wird (Fremdschlüssel haben kein ON DELETE CASCADE, darum
-- löscht die Funktion in der richtigen Reihenfolge selbst):
--   - Chats, in denen das Konto Käufer oder Verkäufer ist, mit Nachrichten
--     und Bewertungen (auch die des Gegenübers in diesen Chats)
--   - Bewertungen von und für das Konto
--   - eigene Angebote und alle Angebote zu eigenen Gesuchen, mit Fotozeilen
--   - eigene Gesuche, Pushtoken, Profil und das Anmeldekonto (auth.users)
--
-- Nicht gelöscht: Dateien ANDERER in der Dateiablage (Fotos anderer zu den
-- eigenen Gesuchen, Chatfotos des Gegenübers). Die Storage-Regeln erlauben
-- das Löschen fremder Dateien bewusst nicht (M183). Diese Dateien bleiben
-- ohne Zeile in der Datenbank zurück, siehe ABWEICHUNGEN.md 13.4.
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor» (ganze Datei, «Run»).
-- Voraussetzung: 13_speicher.sql. Mehrmals ausführen schadet nicht.


-- ---------------------------------------------------------------------
-- 1. Pfade der eigenen Fotos
-- ---------------------------------------------------------------------
-- Nur Dateien im eigenen Ordner: offer-photos/<uid>/… und
-- chat-photos/<thread_id>/<uid>/…
create or replace function public.account_photo_paths()
returns table (bucket text, path text)
language sql
stable
security definer
set search_path to ''
as $$
  select 'offer-photos', p.url
    from public.photo p
    join public.offer o on o.id = p.offer_id
   where o.seller_id = (select auth.uid())
     and p.url like (select auth.uid())::text || '/%'
  union all
  select 'chat-photos', m.body
    from public.message m
   where m.sender_id = (select auth.uid())
     and m.kind = 'foto';
$$;


-- ---------------------------------------------------------------------
-- 2. Alle Zeilen des eigenen Kontos löschen
-- ---------------------------------------------------------------------
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Nicht angemeldet' using errcode = '42501';
  end if;

  -- Chats des Kontos (als Käufer oder Verkäufer). Chats zu eigenen
  -- Gesuchen haben immer das Konto als Käufer, Chats zu eigenen
  -- Angeboten das Konto als Verkäufer: Diese Liste deckt beides ab.
  create temporary table loesch_chats on commit drop as
    select id from public.chat_thread
     where buyer_id = v_uid or seller_id = v_uid;

  -- Angebote: eigene und alle zu eigenen Gesuchen
  create temporary table loesch_angebote on commit drop as
    select o.id from public.offer o
     where o.seller_id = v_uid
        or o.want_id in (select w.id from public.want w where w.owner_id = v_uid);

  delete from public.rating
   where from_user_id = v_uid
      or to_user_id   = v_uid
      or thread_id in (select id from loesch_chats);

  delete from public.message
   where thread_id in (select id from loesch_chats)
      or sender_id = v_uid;

  delete from public.chat_thread where id in (select id from loesch_chats);

  delete from public.photo where offer_id in (select id from loesch_angebote);
  delete from public.offer where id in (select id from loesch_angebote);

  delete from public.want       where owner_id   = v_uid;
  delete from public.push_token where profile_id = v_uid;
  delete from public.profile    where id         = v_uid;

  -- Anmeldekonto (Sitzungen und Identitäten löscht Supabase mit)
  delete from auth.users where id = v_uid;
end;
$$;

revoke execute on function public.account_photo_paths() from public, anon;
grant  execute on function public.account_photo_paths() to authenticated;
revoke execute on function public.delete_own_account() from public, anon;
grant  execute on function public.delete_own_account() to authenticated;


-- ---------------------------------------------------------------------
-- 3. Storage: eigene Fotos löschen dürfen (nur der eigene Ordner)
-- ---------------------------------------------------------------------
-- Bisher (13_speicher.sql) durfte man eigene Angebotsfotos nur löschen,
-- solange das Angebot «neu» ist, und Chatfotos gar nicht. Fürs Löschen
-- des Kontos braucht es beides. Fremde Dateien bleiben geschützt.
drop policy if exists offer_photos_delete on storage.objects;
create policy offer_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'offer-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists chat_photos_delete on storage.objects;
create policy chat_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'chat-photos'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );


-- ---------------------------------------------------------------------
-- Kontrolle
-- ---------------------------------------------------------------------
-- Funktionen vorhanden?   Erwartet: 2 Zeilen
--   select proname from pg_proc
--    where proname in ('account_photo_paths', 'delete_own_account');
-- TC06 nach dem Löschen eines Testkontos (Rolle «postgres»), alles 0:
--   select (select count(*) from auth.users  where email = 'cara@refind.test') as konto,
--          (select count(*) from public.want  w join auth.users u on u.id = w.owner_id
--            where u.email = 'cara@refind.test') as gesuche;
-- Danach: Testkonto im Dashboard neu anlegen und 05_testdaten.sql ausführen.
