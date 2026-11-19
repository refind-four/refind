-- Test des Datenzugriffs (Konzeptbericht 5.1), Nick, 19.11.2026
--
-- Ausführen im Supabase-Dashboard, «SQL Editor»:
--   1. Oben rechts beim Run-Knopf die Rolle wählen:
--      «authenticated» → «Impersonate user» → Konto wählen (steht bei jedem Test)
--   2. NUR den einen Test markieren, dann «Run».
-- Voraussetzung: 05_testdaten.sql ist frisch ausgeführt (als Rolle «postgres»).
-- Nach T7 und T8 die Rolle zurück auf «postgres» stellen und 05 neu ausführen.


-- T1 · als BEN · Ben sieht Annas pausiertes Gesuch «Fujifilm X100V» nicht
-- Erwartet: 0 Zeilen (Gegenprobe als ANNA: 1 Zeile, status = pausiert)
select title, status from public.want where title = 'Fujifilm X100V';


-- T2 · als BEN · Ben kann Annas Gesuch nicht ändern
-- Ben SIEHT «Rolex Datejust 36» (aktiv), darf es aber nicht ändern.
-- Erwartet: kein Fehler, aber 0 Zeilen («Success. No rows returned»)
update public.want set title = 'Gehackt', budget_max = 100
 where title = 'Rolex Datejust 36'
returning id, title;
-- Kontrolle danach (als BEN): Titel ist unverändert, budget_max = 700000
select title, budget_max from public.want where title = 'Rolex Datejust 36';


-- T3 · als CARA · Cara sieht Bens Angebote bei fremden Gesuchen nicht
-- Ben hat Angebote bei Anna (Leica Q2, Eames ×2, Omega, Brompton, Kind of Blue)
-- und eines bei Cara (Makita).
-- Erwartet: genau 1 Zeile: «Makita Akku-Bohrschrauber», 9000, angenommen
select w.title, o.price, o.status
  from public.offer o
  join public.want w on w.id = o.want_id
 where o.seller_id = (select id from public.profile where display_name = 'Ben');


-- T4 · als BEN · Ben kann accept_offer bei Annas Gesuch nicht aufrufen
-- Ben nimmt sein eigenes Angebot (Eames, CHF 1'720) an, das Gesuch gehört Anna.
-- Erwartet: ERROR 42501 «Nicht berechtigt», nichts geändert
select public.accept_offer(id) from public.offer where price = 172000;


-- T5 · als BEN · Ben kann den Status seines Angebots nicht selbst ändern
-- (03_rechte.sql erlaubt dem Verkäufer nur price und message)
-- Erwartet: ERROR 42501 «permission denied for table offer»
update public.offer set status = 'angenommen' where price = 210000;


-- T6 · als CARA · Kein Angebot auf ein Gesuch mit angenommenem Angebot
-- «Omega Speedmaster»: Bens Angebot ist schon angenommen.
-- Erwartet: ERROR 42501 «new row violates row-level security policy for table "offer"»
insert into public.offer (want_id, seller_id, price, message)
select id, auth.uid(), 600000, 'Test T6'
  from public.want where title = 'Omega Speedmaster';


-- T7 · als ANNA · Anna kann accept_offer bei «Eames Lounge Chair» aufrufen
-- Sie nimmt Caras Angebot (CHF 1'950) an.
-- Erwartet: 1 Zeile mit einer uuid (id des neuen Chats)
select public.accept_offer(o.id)
  from public.offer o
  join public.want w on w.id = o.want_id
 where w.title = 'Eames Lounge Chair' and o.price = 195000;
-- Kontrolle (als ANNA). Erwartet: 172000 abgesagt, 195000 angenommen,
-- 210000 abgesagt, und chat = 1 nur bei 195000
select o.price, o.status,
       (select count(*) from public.chat_thread t where t.offer_id = o.id) as chat
  from public.offer o
  join public.want w on w.id = o.want_id
 where w.title = 'Eames Lounge Chair'
 order by o.price;


-- T8 · als ANNA · Zweites Annehmen beim selben Gesuch geht nicht (nach T7!)
-- Erwartet: ERROR P0001 «Es wurde bereits ein Angebot angenommen»
select public.accept_offer(o.id)
  from public.offer o
  join public.want w on w.id = o.want_id
 where w.title = 'Eames Lounge Chair' and o.price = 172000;

-- Danach: Rolle «postgres», 05_testdaten.sql neu ausführen.
