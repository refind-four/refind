-- Vorläufige Ortschaften für Tests mit Supabase (Stand 12.11.2026).
--
-- Übergang, bis das ganze Ortschaftenverzeichnis von swisstopo importiert
-- ist (Konzept 2.1). Ohne Einträge in place lässt sich in der App keine
-- Region wählen und damit kein Gesuch erfassen (UC3).
--
-- Koordinaten: LV95 in Metern (e = Ost, n = Nord), Stadtzentrum, auf etwa
-- 100 m gerundet. Für die Umkreissuche (Konzept 4.2.3) genau genug.
--
-- Ausführen im Supabase-Dashboard unter «SQL Editor». In der App geht das
-- nicht: Die RLS-Regeln erlauben dort nur das Lesen von place.
-- Mehrmals ausführen schadet nicht: Bestehende Orte (gleiche PLZ und
-- gleicher Name) werden übersprungen.

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
