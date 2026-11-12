create schema if not exists private;
CREATE OR REPLACE FUNCTION private.is_own_new_offer(p_offer_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select exists (select 1 from public.offer
                   where id = p_offer_id
                     and seller_id = (select auth.uid())
                     and status = 'neu');
$function$
;
CREATE OR REPLACE FUNCTION private.is_thread_member(p_thread_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select exists (select 1 from public.chat_thread
                   where id = p_thread_id
                     and (select auth.uid()) in (buyer_id, seller_id));
$function$
;
CREATE OR REPLACE FUNCTION private.is_want_owner(p_want_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select exists (select 1 from public.want
                   where id = p_want_id and owner_id = (select auth.uid()));
$function$
;
CREATE OR REPLACE FUNCTION private.has_offer_on_want(p_want_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select exists (select 1 from public.offer
                   where want_id = p_want_id and seller_id = (select auth.uid()));
$function$
;
CREATE OR REPLACE FUNCTION private.want_open_for_offer(p_want_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select exists (select 1 from public.want w
                   where w.id = p_want_id
                     and w.owner_id <> (select auth.uid())
                     and w.status = 'aktiv'
                     and w.expires_at > now()
                     and not exists (select 1 from public.offer o
                                     where o.want_id = w.id and o.status = 'angenommen'));
$function$
;
CREATE OR REPLACE FUNCTION private.can_read_offer(p_offer_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select exists (select 1 from public.offer o
                   join public.want w on w.id = o.want_id
                   where o.id = p_offer_id
                     and (select auth.uid()) in (o.seller_id, w.owner_id));
$function$
;
CREATE OR REPLACE FUNCTION private.can_rate(p_thread_id uuid, p_to_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select exists (select 1 from public.chat_thread t
                   where t.id = p_thread_id
                     and t.closed_at is not null
                     and (   (t.buyer_id  = (select auth.uid()) and t.seller_id = p_to_user)
                          or (t.seller_id = (select auth.uid()) and t.buyer_id  = p_to_user)));
$function$
;
CREATE OR REPLACE FUNCTION private.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
    insert into public.profile (id, display_name)
    values (new.id,
            coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
                     'Neues Mitglied'));
    return new;
end;
$function$
;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();