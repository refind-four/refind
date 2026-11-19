-- VORSCHLAG (noch nicht mit dem Team abgesprochen): Angebot annehmen (F-12)
--
-- Aufruf aus der App:  supabase.rpc('accept_offer', params: {'p_offer_id': offerId})
-- Rückgabe: id des Chats (chat_thread) zu diesem Angebot.
--
-- Was die Funktion in EINER Transaktion macht (alles oder nichts):
--   1. prüft: Wer aufruft, ist Besitzer des Gesuchs. Das Gesuch ist aktiv und
--      nicht abgelaufen. Es gibt noch kein angenommenes Angebot. Das Angebot
--      hat den Status «neu» oder «gesehen».
--   2. setzt das Angebot auf «angenommen»
--   3. setzt alle anderen offenen Angebote zum Gesuch auf «abgesagt»
--   4. legt den Chat zwischen Käufer (Besitzer) und Verkäufer an, falls es
--      ihn noch nicht gibt
--
-- Warum eine Funktion und nicht drei Updates aus der App:
--   - Die RLS-Regel offer_update erlaubt nur dem Verkäufer Änderungen, und
--     03_rechte.sql erlaubt nur price und message. Der Käufer darf den Status
--     also gar nicht direkt ändern (gut so).
--   - Zwei Updates nacheinander aus der App können halb gelingen
--     (angenommen, aber die anderen nicht abgesagt).
--   - «for update» sperrt das Gesuch kurz. Drückt jemand zweimal schnell,
--     wird trotzdem nur ein Angebot angenommen.

create or replace function public.accept_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_offer  public.offer%rowtype;
  v_want   public.want%rowtype;
  v_thread uuid;
begin
  select * into v_offer from public.offer where id = p_offer_id;
  if not found then
    raise exception 'Angebot nicht gefunden' using errcode = 'P0002';
  end if;

  -- Gesuch sperren, damit nicht zwei Angebote gleichzeitig angenommen werden
  select * into v_want from public.want where id = v_offer.want_id for update;

  if v_want.owner_id is distinct from (select auth.uid()) then
    raise exception 'Nicht berechtigt' using errcode = '42501';
  end if;

  if v_want.status <> 'aktiv' or v_want.expires_at <= now() then
    raise exception 'Gesuch ist nicht mehr aktiv' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.offer
              where want_id = v_want.id and status = 'angenommen') then
    raise exception 'Es wurde bereits ein Angebot angenommen' using errcode = 'P0001';
  end if;

  -- Status nach dem Sperren nochmals lesen
  select * into v_offer from public.offer where id = p_offer_id;
  if v_offer.status not in ('neu', 'gesehen') then
    raise exception 'Angebot kann nicht angenommen werden' using errcode = 'P0001';
  end if;

  update public.offer set status = 'angenommen' where id = v_offer.id;

  update public.offer
     set status = 'abgesagt'
   where want_id = v_want.id
     and id <> v_offer.id
     and status in ('neu', 'gesehen');

  -- Chat anlegen oder den bestehenden benutzen
  insert into public.chat_thread (offer_id, want_id, buyer_id, seller_id)
  values (v_offer.id, v_want.id, v_want.owner_id, v_offer.seller_id)
  on conflict (offer_id) do update set last_activity = now()
  returning id into v_thread;

  return v_thread;
end;
$$;

-- Nur angemeldete Benutzer dürfen die Funktion aufrufen
revoke execute on function public.accept_offer(uuid) from public, anon;
grant  execute on function public.accept_offer(uuid) to authenticated;
