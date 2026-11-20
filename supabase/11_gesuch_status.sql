-- Gesuch pausieren, aktivieren, nochmal aufhängen (UC4, F-05), 20.11.2026
--
-- Aufruf aus der App:
--   supabase.rpc('set_want_status', params: {'p_want_id': id, 'p_status': 'pausiert'})
--   supabase.rpc('republish_want',  params: {'p_want_id': id})
--
-- Warum Funktionen und nicht ein update aus der App:
--   - Abbildung 2 und UC4 erlauben nur bestimmte Wechsel (aktiv ⇄ pausiert,
--     abgelaufen → aktiv). Mit angenommenem Angebot oder erledigt ist nichts
--     mehr möglich. Die RLS-Regel want_update prüft das nicht.
--   - «Nochmal aufhängen» setzt das Ablaufdatum auf 14 Tage ab heute. Die
--     CHECK-Regel want_laufzeit_check (07) verlangt aber expires_at =
--     created_at + 7, 14 oder 30 Tage. Darum setzt republish_want auch
--     created_at neu: Das Gesuch gilt als neu aufgehängt. created_at darf
--     die App nicht ändern (03_rechte.sql), nur diese Funktion.
--   - Danach dürfen status und expires_at NUR noch diese Funktionen und
--     accept_offer ändern (Teil 3). So kann niemand die App umgehen und ein
--     Gesuch mit angenommenem Angebot pausieren oder ein Ablaufdatum in
--     10 Jahren setzen.
--
-- Fehler:
--   42501  nicht der Besitzer
--   P0001  Wechsel nicht erlaubt (Status, abgelaufen, angenommenes Angebot)
--   P0002  Gesuch gibt es nicht
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor» (ganze Datei, «Run»).
-- Mehrmals ausführen schadet nicht.


-- ---------------------------------------------------------------------
-- 1. Pausieren und Aktivieren (UC4 Schritt 3)
-- ---------------------------------------------------------------------
create or replace function public.set_want_status(p_want_id uuid,
                                                  p_status public.want_status)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_want public.want%rowtype;
begin
  -- Gesuch sperren, damit zwei schnelle Klicks sich nicht überholen
  select * into v_want from public.want where id = p_want_id for update;
  if not found then
    raise exception 'Gesuch nicht gefunden' using errcode = 'P0002';
  end if;

  if v_want.owner_id is distinct from (select auth.uid()) then
    raise exception 'Nicht berechtigt' using errcode = '42501';
  end if;

  -- Nur aktiv → pausiert und pausiert → aktiv (Abbildung 2)
  if not ((v_want.status = 'aktiv'    and p_status = 'pausiert') or
          (v_want.status = 'pausiert' and p_status = 'aktiv')) then
    raise exception 'Wechsel von % zu % nicht erlaubt', v_want.status, p_status
      using errcode = 'P0001';
  end if;

  -- Abgelaufen: nur noch «Nochmal aufhängen»
  if v_want.expires_at <= now() then
    raise exception 'Gesuch ist abgelaufen' using errcode = 'P0001';
  end if;

  -- UC4 Ausnahme: mit angenommenem Angebot nicht mehr pausieren
  if exists (select 1 from public.offer
              where want_id = v_want.id and status = 'angenommen') then
    raise exception 'Es wurde bereits ein Angebot angenommen' using errcode = 'P0001';
  end if;

  update public.want set status = p_status where id = v_want.id;
end;
$$;


-- ---------------------------------------------------------------------
-- 2. Nochmal aufhängen (UC4 Schritt 6): 14 Tage ab heute, Status aktiv
-- ---------------------------------------------------------------------
create or replace function public.republish_want(p_want_id uuid)
returns public.want
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_want public.want%rowtype;
begin
  select * into v_want from public.want where id = p_want_id for update;
  if not found then
    raise exception 'Gesuch nicht gefunden' using errcode = 'P0002';
  end if;

  if v_want.owner_id is distinct from (select auth.uid()) then
    raise exception 'Nicht berechtigt' using errcode = '42501';
  end if;

  -- Nur abgelaufene Gesuche: Status «abgelaufen» oder aktiv/pausiert mit
  -- erreichtem Ablaufdatum (falls der stündliche Auftrag noch nicht lief)
  if not (v_want.status = 'abgelaufen' or
          (v_want.status in ('aktiv', 'pausiert') and v_want.expires_at <= now())) then
    raise exception 'Gesuch ist nicht abgelaufen' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.offer
              where want_id = v_want.id and status = 'angenommen') then
    raise exception 'Es wurde bereits ein Angebot angenommen' using errcode = 'P0001';
  end if;

  update public.want
     set status     = 'aktiv',
         created_at = now(),
         expires_at = now() + interval '14 days'
   where id = v_want.id
  returning * into v_want;

  return v_want;
end;
$$;


-- ---------------------------------------------------------------------
-- 3. Rechte: status und expires_at nur noch über die Funktionen
-- ---------------------------------------------------------------------
-- 03_rechte.sql erlaubt authenticated update auf status und expires_at.
-- Das wird hier zurückgenommen. Alle anderen Spalten (Titel, Budget …)
-- bleiben für «Bearbeiten» änderbar.
revoke update (status, expires_at) on public.want from authenticated;

revoke execute on function public.set_want_status(uuid, public.want_status) from public, anon;
grant  execute on function public.set_want_status(uuid, public.want_status) to authenticated;
revoke execute on function public.republish_want(uuid) from public, anon;
grant  execute on function public.republish_want(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- Kontrolle im SQL Editor (Rolle «authenticated», «Impersonate user»)
-- ---------------------------------------------------------------------
-- als ANNA: Rolex pausieren → kein Fehler, danach status = pausiert
--   select public.set_want_status(
--     (select id from public.want where title = 'Rolex Datejust 36'), 'pausiert');
-- als ANNA: Technics nochmal aufhängen → 1 Zeile mit status = aktiv
--   select status, expires_at from public.republish_want(
--     (select id from public.want where title = 'Technics SL-1200'));
-- als ANNA: Omega pausieren → ERROR P0001 (Angebot angenommen)
-- als BEN:  Rolex pausieren → ERROR 42501 (nicht berechtigt)
-- als ANNA: direkt ändern → ERROR 42501 permission denied
--   update public.want set status = 'aktiv' where title = 'Fujifilm X100V';
-- Danach: Rolle «postgres», 05_testdaten.sql neu ausführen.
