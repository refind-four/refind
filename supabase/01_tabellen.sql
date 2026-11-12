-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

create type public.message_kind as enum ('text', 'foto');
create type public.offer_status as enum ('neu', 'gesehen', 'angenommen', 'abgesagt');
create type public.want_status as enum ('aktiv', 'pausiert', 'abgelaufen', 'erledigt');

CREATE TABLE public.place (
  id integer GENERATED ALWAYS AS IDENTITY NOT NULL,
  plz integer NOT NULL,
  name text NOT NULL,
  e integer NOT NULL,
  n integer NOT NULL,
  CONSTRAINT place_pkey PRIMARY KEY (id)
);
CREATE TABLE public.profile (
  id uuid NOT NULL,
  display_name text NOT NULL,
  city_id integer,
  avatar_url text,
  radius_km integer NOT NULL DEFAULT 20,
  member_since date NOT NULL DEFAULT CURRENT_DATE,
  CONSTRAINT profile_pkey PRIMARY KEY (id),
  CONSTRAINT profile_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT profile_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.place(id)
);
CREATE TABLE public.want (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  title text NOT NULL,
  category text NOT NULL,
  description text,
  budget_max integer NOT NULL,
  condition text NOT NULL,
  region_id integer NOT NULL,
  radius_km integer NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL,
  status USER-DEFINED NOT NULL DEFAULT 'aktiv'::want_status,
  CONSTRAINT want_pkey PRIMARY KEY (id),
  CONSTRAINT want_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profile(id),
  CONSTRAINT want_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.place(id)
);
CREATE TABLE public.offer (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  want_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  price integer NOT NULL,
  message text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  status USER-DEFINED NOT NULL DEFAULT 'neu'::offer_status,
  CONSTRAINT offer_pkey PRIMARY KEY (id),
  CONSTRAINT offer_want_id_fkey FOREIGN KEY (want_id) REFERENCES public.want(id),
  CONSTRAINT offer_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.profile(id)
);
CREATE TABLE public.photo (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL,
  url text NOT NULL,
  CONSTRAINT photo_pkey PRIMARY KEY (id),
  CONSTRAINT photo_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id)
);
CREATE TABLE public.chat_thread (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL UNIQUE,
  want_id uuid NOT NULL,
  buyer_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  last_activity timestamp with time zone NOT NULL DEFAULT now(),
  handover_at timestamp with time zone,
  handover_place text,
  agreed_price integer,
  closed_at timestamp with time zone,
  CONSTRAINT chat_thread_pkey PRIMARY KEY (id),
  CONSTRAINT chat_thread_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id),
  CONSTRAINT chat_thread_want_id_fkey FOREIGN KEY (want_id) REFERENCES public.want(id),
  CONSTRAINT chat_thread_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.profile(id),
  CONSTRAINT chat_thread_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.profile(id)
);
CREATE TABLE public.message (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  kind USER-DEFINED NOT NULL DEFAULT 'text'::message_kind,
  body text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  read_at timestamp with time zone,
  CONSTRAINT message_pkey PRIMARY KEY (id),
  CONSTRAINT message_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.chat_thread(id),
  CONSTRAINT message_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profile(id)
);
CREATE TABLE public.rating (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  thread_id uuid NOT NULL,
  stars integer NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT rating_pkey PRIMARY KEY (id),
  CONSTRAINT rating_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.profile(id),
  CONSTRAINT rating_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.profile(id),
  CONSTRAINT rating_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.chat_thread(id)
);
CREATE TABLE public.push_token (
  token text NOT NULL,
  profile_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT push_token_pkey PRIMARY KEY (token),
  CONSTRAINT push_token_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profile(id)
);