-- Dateiablage für Fotos (F-09, TC16, ABWEICHUNGEN 9.3), 20.11.2026
--
-- Zwei private Buckets in Supabase Storage:
--   offer-photos  Fotos zu Angeboten (UC6), Pfad <uid>/<offer_id>/<n>.jpg
--   chat-photos   Fotos im Chat (UC8, vorbereitet), Pfad <thread_id>/<uid>/<name>
--
-- Privat heisst: Es gibt keine öffentlichen Links. Die App holt Links, die
-- eine Stunde gültig sind (createSignedUrlsResult), und das klappt nur für
-- Dateien, die die RLS-Regeln unten zum Lesen freigeben.
--
-- Regeln (storage.objects):
--   Angebotsfotos hochladen: nur in den eigenen Ordner (<uid> = auth.uid()),
--     nur zu einem eigenen Angebot mit Status «neu», höchstens 3 pro Angebot
--   Angebotsfotos lesen: wer das Angebot sehen darf (private.can_read_offer:
--     Verkäufer und Besitzer des Gesuchs)
--   Angebotsfotos löschen: nur eigene, solange das Angebot «neu» ist
--   Chatfotos hochladen: nur Mitglieder des Chats, nur in den eigenen Ordner
--   Chatfotos lesen: nur Mitglieder des Chats
--   Ändern (update) ist nirgends erlaubt.
-- Grösse höchstens 5 MB, nur JPEG, PNG und WebP (am Bucket eingestellt,
-- Supabase weist alles andere schon beim Hochladen ab).
--
-- Voraussetzung: 04_funktionen.sql (can_read_offer, is_own_new_offer,
-- is_thread_member).
-- Ausführen im Supabase-Dashboard unter «SQL Editor» (ganze Datei, «Run»).
-- Mehrmals ausführen schadet nicht.


-- ---------------------------------------------------------------------
-- 1. Buckets
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('offer-photos', 'offer-photos', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp']),
       ('chat-photos',  'chat-photos',  false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
   set public             = excluded.public,
       file_size_limit    = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types;


-- ---------------------------------------------------------------------
-- 2. Hilfsfunktionen
-- ---------------------------------------------------------------------
-- Ordnername als uuid, oder null, wenn er keine gültige uuid ist.
-- (Ein direktes ::uuid würde bei einem falschen Pfad einen Fehler werfen.)
create or replace function private.uuid_or_null(p_text text)
returns uuid
language plpgsql
immutable
set search_path to ''
as $$
begin
  return p_text::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

-- Wie viele Fotos liegen schon im Ordner eines Angebots?
-- security definer, damit die Regel unabhängig von den Leserechten zählt.
-- Nicht «stable»: So sieht die Funktion auch Dateien, die kurz vorher im
-- selben Ablauf hochgeladen wurden.
create or replace function private.offer_photo_count(p_offer_id uuid)
returns integer
language sql
security definer
set search_path to ''
as $$
  select count(*)::integer
    from storage.objects o
   where o.bucket_id = 'offer-photos'
     and (storage.foldername(o.name))[2] = p_offer_id::text;
$$;

grant execute on function private.uuid_or_null(text) to authenticated;
grant execute on function private.offer_photo_count(uuid) to authenticated;
revoke execute on function private.offer_photo_count(uuid) from public, anon;


-- ---------------------------------------------------------------------
-- 3. Regeln für Angebotsfotos (offer-photos)
--    Pfad: <uid des Verkäufers>/<offer_id>/<n>.jpg
-- ---------------------------------------------------------------------
drop policy if exists offer_photos_insert on storage.objects;
create policy offer_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'offer-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and private.is_own_new_offer(private.uuid_or_null((storage.foldername(name))[2]))
    and private.offer_photo_count(private.uuid_or_null((storage.foldername(name))[2])) < 3
  );

drop policy if exists offer_photos_select on storage.objects;
create policy offer_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'offer-photos'
    and private.can_read_offer(private.uuid_or_null((storage.foldername(name))[2]))
  );

drop policy if exists offer_photos_delete on storage.objects;
create policy offer_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'offer-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and private.is_own_new_offer(private.uuid_or_null((storage.foldername(name))[2]))
  );


-- ---------------------------------------------------------------------
-- 4. Regeln für Chatfotos (chat-photos), vorbereitet für UC8
--    Pfad: <thread_id>/<uid des Absenders>/<name>
-- ---------------------------------------------------------------------
drop policy if exists chat_photos_insert on storage.objects;
create policy chat_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-photos'
    and private.is_thread_member(private.uuid_or_null((storage.foldername(name))[1]))
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

drop policy if exists chat_photos_select on storage.objects;
create policy chat_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-photos'
    and private.is_thread_member(private.uuid_or_null((storage.foldername(name))[1]))
  );


-- ---------------------------------------------------------------------
-- Kontrolle (Rolle «postgres»)
-- ---------------------------------------------------------------------
-- Buckets: Erwartet 2 Zeilen, public = false, 5242880, drei Bildtypen
--   select id, public, file_size_limit, allowed_mime_types from storage.buckets;
-- Regeln: Erwartet 5 Zeilen
--   select policyname, cmd from pg_policies
--    where schemaname = 'storage' and tablename = 'objects'
--      and policyname like any (array['offer_photos_%', 'chat_photos_%']);
-- Hochgeladene Fotos:
--   select name, metadata->>'size' as bytes, created_at
--     from storage.objects where bucket_id = 'offer-photos' order by created_at desc;
