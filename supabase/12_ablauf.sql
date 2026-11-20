-- Gesuche stündlich auf «abgelaufen» setzen (UC4 Schritt 5, TC11), 20.11.2026
--
-- Konzept 4.3: Funktion expire_wants(), «setzt abgelaufene Gesuche stündlich
-- auf abgelaufen, gestartet über pg_cron».
--
-- Voraussetzung: Erweiterung pg_cron ist eingeschaltet
--   (Dashboard → Database → Extensions → pg_cron).
-- Ausführen im Supabase-Dashboard unter «SQL Editor» (ganze Datei, «Run»).
-- Mehrmals ausführen schadet nicht: Der Auftrag wird ersetzt, nicht doppelt
-- angelegt.
--
-- Zusammenspiel:
--   - get_feed (10) blendet ein Gesuch schon ab dem Ablaufdatum aus, nicht
--     erst nach diesem Auftrag (TC11: «fehlt sofort im Feed»).
--   - Die App zeigt es ab dem Ablaufdatum als abgelaufen an (StatusLogic),
--     auch wenn der Auftrag noch nicht gelaufen ist.
--   - Dieser Auftrag setzt spätestens nach einer Stunde auch den Status in
--     der Datenbank (TC11: «spätestens nach einer Stunde abgelaufen»).
--   - republish_want (11) nimmt beides an: Status «abgelaufen» oder
--     Ablaufdatum erreicht.


-- ---------------------------------------------------------------------
-- 1. Funktion: aktive und pausierte Gesuche ohne angenommenes Angebot,
--    deren Ablaufdatum erreicht ist, auf «abgelaufen» setzen (Abbildung 2).
--    Gibt die Anzahl geänderter Gesuche zurück.
-- ---------------------------------------------------------------------
create or replace function private.expire_wants()
returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_count integer;
begin
  update public.want w
     set status = 'abgelaufen'
   where w.status in ('aktiv', 'pausiert')
     and w.expires_at <= now()
     -- Mit angenommenem Angebot läuft ein Gesuch nicht mehr ab (Kapitel 2.1)
     and not exists (select 1 from public.offer o
                      where o.want_id = w.id and o.status = 'angenommen');
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Nur der Auftrag (Rolle postgres) ruft die Funktion auf, nicht die App.
revoke execute on function private.expire_wants() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. Auftrag: jede Stunde zur vollen Stunde
-- ---------------------------------------------------------------------
-- Alten Auftrag gleichen Namens entfernen, dann neu anlegen
select cron.unschedule(jobid) from cron.job where jobname = 'expire_wants';

select cron.schedule('expire_wants', '0 * * * *', 'select private.expire_wants()');


-- ---------------------------------------------------------------------
-- Kontrolle (Rolle «postgres»)
-- ---------------------------------------------------------------------
-- Auftrag angelegt?           Erwartet: 1 Zeile, schedule = 0 * * * *
--   select jobid, jobname, schedule, command from cron.job;
-- Von Hand ausführen (TC11):  Erwartet: Anzahl geänderter Gesuche
--   select private.expire_wants();
-- Letzte Läufe:
--   select status, return_message, start_time
--     from cron.job_run_details order by start_time desc limit 5;
--
-- TC11 vorbereiten: Ablaufdatum eines Testgesuchs in die Vergangenheit
-- setzen. Laufzeit-Regel (07) beachten, darum created_at mitschieben:
--   update public.want
--      set created_at = now() - interval '14 days 1 minute',
--          expires_at = now() - interval '1 minute'
--    where title = 'Rolex Datejust 36';
