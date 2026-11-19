-- Feed «Entdecken» (UC5, F-06), KW 47
--
-- Aufruf aus der App:
--   supabase.rpc('get_feed').select('*, region:place(*), owner:profile(display_name)')
-- Kategorie und Suchbegriff hängt die App als Filter an (eq, ilike).
--
-- Warum eine Funktion und nicht einfach «select from want»:
--   Gesuche mit einem angenommenen Angebot dürfen nicht im Feed erscheinen.
--   Die RLS-Regel offer_select zeigt aber nur eigene Angebote und Angebote
--   zu eigenen Gesuchen. Ob bei einem FREMDEN Gesuch jemand anderes ein
--   Angebot angenommen hat, sieht die App also nicht (gut so, Datenschutz).
--   private.has_accepted_offer prüft das in der Datenbank und gibt nur
--   ja/nein zurück, keine Angebote.
--
-- get_feed selbst läuft mit den Rechten der aufrufenden Person
-- (security invoker). Die RLS-Regel want_select gilt also zusätzlich.
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor».
-- Mehrmals ausführen schadet nicht (create or replace).

-- Gibt es zum Gesuch ein angenommenes Angebot?
create or replace function private.has_accepted_offer(p_want_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (select 1 from public.offer
                  where want_id = p_want_id and status = 'angenommen');
$$;

-- Sichtbare Gesuche für den Feed: aktiv, nicht abgelaufen, nicht die
-- eigenen, ohne angenommenes Angebot. Das neueste zuerst.
create or replace function public.get_feed()
returns setof public.want
language sql
stable
security invoker
set search_path to ''
as $$
  select w.*
    from public.want w
   where w.owner_id <> (select auth.uid())
     and w.status = 'aktiv'
     and w.expires_at > now()
     and not private.has_accepted_offer(w.id)
   order by w.created_at desc;
$$;

-- Nur angemeldete Benutzer dürfen den Feed abrufen
revoke execute on function public.get_feed() from public, anon;
grant  execute on function public.get_feed() to authenticated;

revoke execute on function private.has_accepted_offer(uuid) from public, anon;
grant  execute on function private.has_accepted_offer(uuid) to authenticated;
grant  usage on schema private to authenticated;

-- Kontrolle: als Ben angemeldet erwartet man in der App Leica M6, Leica Q2,
-- Rolex und Eames. Im SQL Editor (ohne Anmeldung) ist auth.uid() leer,
-- dort liefert get_feed darum nichts. Diese Abfrage zeigt dasselbe ohne
-- Anmeldung, aber für Ben:
--
-- select w.title
--   from public.want w
--  where w.owner_id <> (select id from auth.users where email = 'ben@refind.test')
--    and w.status = 'aktiv' and w.expires_at > now()
--    and not private.has_accepted_offer(w.id)
--  order by w.created_at desc;
