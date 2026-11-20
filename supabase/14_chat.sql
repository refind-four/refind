-- Chat und Abschluss (UC8, F-13, F-05, TC20, TC24, TC27), 20.11.2026
--
-- Inhalt:
--   1. CHECK-Regeln für message und chat_thread (Factsheet Inputvalidierung)
--   2. Trigger: Zeit der Nachricht vom Server, last_activity nachführen
--   3. Echtzeit: Tabelle message in die Publication supabase_realtime
--   4. Funktion close_deal: Deal abschliessen, Gesuch «erledigt» (nur Käufer)
--
-- Echtzeit und Zugriff (TC27): Die App abonniert message mit dem Filter
-- thread_id. Supabase Realtime prüft für jede neue Zeile die RLS-Regel
-- message_select (nur Mitglieder des Chats). Ein drittes Konto bekommt
-- also auch über die Echtzeit keine Nachrichten eines fremden Chats.
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor» in zwei Teilen:
--   TEIL A zuerst allein (markieren, «Run»): zeigt Zeilen, die eine neue
--          Regel verletzen würden. Keine Zeilen = alles gut.
--   TEIL B danach. Mehrmals ausführen schadet nicht.


-- =====================================================================
-- TEIL A: Bestehende Daten prüfen
-- =====================================================================
select 'message' as tabelle, id::text as id, left(body, 30) as wert,
       'Text 1–1000 Zeichen bzw. Foto-Pfad im eigenen Ordner' as regel
  from public.message
 where not ((kind = 'text' and char_length(btrim(body)) between 1 and 1000)
         or (kind = 'foto' and body like thread_id::text || '/' || sender_id::text || '/%'
             and char_length(body) <= 300))
union all
select 'chat_thread', id::text, agreed_price::text, 'Preis > 0 und <= 1''000''000 Rappen'
  from public.chat_thread
 where agreed_price is not null and (agreed_price <= 0 or agreed_price > 1000000);


-- =====================================================================
-- TEIL B
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CHECK-Regeln
-- ---------------------------------------------------------------------
-- Text: 1 bis 1000 Zeichen (MessageLimits in lib/model/message.dart).
-- Foto: Pfad im Bucket chat-photos, im Ordner <thread_id>/<sender_id>/
-- (wie die Storage-Regel chat_photos_insert in 13_speicher.sql).
alter table public.message drop constraint if exists message_body_check;
alter table public.message add  constraint message_body_check
  check (   (kind = 'text' and char_length(btrim(body)) between 1 and 1000
                           and char_length(body) <= 1000)
         or (kind = 'foto' and body like thread_id::text || '/' || sender_id::text || '/%'
                           and char_length(body) <= 300));

-- Vereinbarter Preis wie die höchste Preisobergrenze (CHF 10'000)
alter table public.chat_thread drop constraint if exists chat_thread_agreed_price_check;
alter table public.chat_thread add  constraint chat_thread_agreed_price_check
  check (agreed_price is null or (agreed_price > 0 and agreed_price <= 1000000));


-- ---------------------------------------------------------------------
-- 2. Trigger für message
-- ---------------------------------------------------------------------
-- Vor dem Einfügen: Zeit vom Server, nicht vom Handy (sonst liesse sich
-- eine Nachricht zurückdatieren). Gelesen ist eine neue Nachricht nie.
-- Nur für Nachrichten aus der App (Rolle authenticated): 05_testdaten.sql
-- legt im SQL Editor absichtlich ältere Nachrichten an.
create or replace function private.message_before_insert()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
  if coalesce((select auth.role()), '') = 'authenticated' then
    new.created_at := now();
    new.read_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists message_before_insert on public.message;
create trigger message_before_insert
  before insert on public.message
  for each row execute function private.message_before_insert();

-- Nach dem Einfügen: last_activity des Chats nachführen (Reihenfolge in
-- der Chatliste). Die App darf chat_thread nicht direkt ändern
-- (03_rechte.sql), darum security definer.
create or replace function private.message_after_insert()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  -- Wie oben nur für die App, 05_testdaten.sql setzt last_activity selbst.
  if coalesce((select auth.role()), '') = 'authenticated' then
    update public.chat_thread
       set last_activity = new.created_at
     where id = new.thread_id;
  end if;
  return new;
end;
$$;

drop trigger if exists message_after_insert on public.message;
create trigger message_after_insert
  after insert on public.message
  for each row execute function private.message_after_insert();


-- ---------------------------------------------------------------------
-- 3. Echtzeit: message in die Publication aufnehmen (nur einmal)
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime'
                    and schemaname = 'public' and tablename = 'message') then
    alter publication supabase_realtime add table public.message;
  end if;
end;
$$;


-- ---------------------------------------------------------------------
-- 4. Deal abschliessen (UC8 Schritt 7, F-05, TC24)
-- ---------------------------------------------------------------------
-- Aufruf aus der App:
--   supabase.rpc('close_deal', params: {'p_thread_id': id, 'p_agreed_price': 165000})
-- Speichert Preis und Abschluss im Chat und setzt das Gesuch auf
-- «erledigt», in einer Transaktion. Nur der Käufer, nur einmal.
-- Fehler: 42501 nicht der Käufer, P0001 schon abgeschlossen oder Gesuch
-- nicht mehr aktiv, P0002 Chat gibt es nicht, 23514 Preis ungültig.
create or replace function public.close_deal(p_thread_id uuid, p_agreed_price integer)
returns public.chat_thread
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_thread public.chat_thread%rowtype;
  v_status public.want_status;
begin
  -- Chat sperren: zweimal schnell «Deal» schliesst nur einmal ab
  select * into v_thread from public.chat_thread where id = p_thread_id for update;
  if not found then
    raise exception 'Chat nicht gefunden' using errcode = 'P0002';
  end if;

  if v_thread.buyer_id is distinct from (select auth.uid()) then
    raise exception 'Nur der Käufer kann abschliessen' using errcode = '42501';
  end if;

  if v_thread.closed_at is not null then
    raise exception 'Der Deal ist schon abgeschlossen' using errcode = 'P0001';
  end if;

  if p_agreed_price is null or p_agreed_price <= 0 or p_agreed_price > 1000000 then
    raise exception 'Preis ungültig' using errcode = '23514';
  end if;

  select status into v_status from public.want where id = v_thread.want_id for update;
  if v_status is distinct from 'aktiv' then
    raise exception 'Gesuch ist nicht mehr aktiv' using errcode = 'P0001';
  end if;

  update public.chat_thread
     set agreed_price  = p_agreed_price,
         closed_at     = now(),
         last_activity = now()
   where id = v_thread.id
  returning * into v_thread;

  update public.want set status = 'erledigt' where id = v_thread.want_id;

  return v_thread;
end;
$$;

revoke execute on function public.close_deal(uuid, integer) from public, anon;
grant  execute on function public.close_deal(uuid, integer) to authenticated;


-- ---------------------------------------------------------------------
-- Kontrolle (Rolle «postgres»)
-- ---------------------------------------------------------------------
-- Echtzeit eingeschaltet?  Erwartet: 1 Zeile
--   select * from pg_publication_tables
--    where pubname = 'supabase_realtime' and tablename = 'message';
-- TC27 im SQL Editor: Rolle «authenticated», Impersonate CARA:
--   select * from public.message;     Erwartet: 0 Zeilen aus dem Omega-Chat
-- Danach: Rolle «postgres», 05_testdaten.sql neu ausführen.
