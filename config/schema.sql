CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE IF NOT EXISTS public.locations (
  name                varchar(128)       PRIMARY KEY,
  code                varchar(4),
  parent_location     varchar(128)       references public.locations(name)
);

CREATE TABLE IF NOT EXISTS public.latest_stats (
  location            varchar(128)       references public.locations(name) UNIQUE,
  total               integer            DEFAULT -1 NOT NULL,
  total_new           integer            DEFAULT -1 NOT NULL,
  dead                integer            DEFAULT -1 NOT NULL,
  dead_new            integer            DEFAULT -1 NOT NULL,
  recovered           integer            DEFAULT -1 NOT NULL,
  recovered_new       integer            DEFAULT -1 NOT NULL,
  active              integer            DEFAULT -1 NOT NULL,
  in_hospital         integer            DEFAULT -1 NOT NULL,
  critical            integer            DEFAULT -1 NOT NULL,
  updated             timestamp          DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.historical_stats (
  location            varchar(128)       references public.locations(name),
  total               integer            DEFAULT -1 NOT NULL,
  total_new           integer            DEFAULT -1 NOT NULL,
  dead                integer            DEFAULT -1 NOT NULL,
  dead_new            integer            DEFAULT -1 NOT NULL,
  recovered           integer            DEFAULT -1 NOT NULL,
  recovered_new       integer            DEFAULT -1 NOT NULL,
  active              integer            DEFAULT -1 NOT NULL,
  in_hospital         integer            DEFAULT -1 NOT NULL,
  critical            integer            DEFAULT -1 NOT NULL,
  day                 date               NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_histotical_stats_unique ON public.historical_stats (location, day);

CREATE OR REPLACE FUNCTION public_create_location (
  a_name varchar, a_code varchar, a_parent_location varchar
)
RETURNS void
AS
$body$
  INSERT INTO public.locations (name, code, parent_location)
  VALUES(a_name, a_code, a_parent_location)
  ON CONFLICT (name)
  DO NOTHING;
$body$ language SQL;

CREATE OR REPLACE FUNCTION public_insert_latest_stats (
  a_location varchar, a_location_code varchar, a_location_parent varchar,
  a_total integer, a_total_new integer, a_dead integer, a_dead_new integer,
  a_recovered integer, a_recovered_new integer, a_active integer,
  a_in_hospital integer, a_critical integer, a_updated timestamp
)
RETURNS void
AS
$body$
  SELECT public_create_location(a_location, a_location_code, a_location_parent);
  INSERT INTO public.latest_stats (
    location, total, total_new, dead, dead_new, recovered, recovered_new,
    active, in_hospital, critical, updated
  )
  VALUES(
    a_location, a_total, a_total_new, a_dead, a_dead_new, a_recovered, a_recovered_new,
    a_active, a_in_hospital, a_critical, a_updated
  )
  ON CONFLICT (location)
  DO NOTHING;
$body$ language SQL;

CREATE OR REPLACE FUNCTION public_update_latest_stats (
  a_location varchar, a_location_code varchar, a_location_parent varchar,
  a_total integer, a_total_new integer, a_dead integer, a_dead_new integer,
  a_recovered integer, a_recovered_new integer, a_active integer,
  a_in_hospital integer, a_critical integer, a_updated timestamp
)
RETURNS void
AS
$body$
BEGIN
  UPDATE public.latest_stats
  SET
    total = a_total, total_new = a_total_new, dead = a_dead, dead_new = a_dead_new,
    recovered = a_recovered, recovered_new = a_recovered_new, active = a_active,
    in_hospital = a_in_hospital, critical = a_critical, updated = a_updated
  WHERE location = a_location;
  IF NOT FOUND THEN
    PERFORM public_insert_latest_stats(
      a_location, a_location_code, a_location_parent,
      a_total, a_total_new, a_dead, a_dead_new, a_recovered, a_recovered_new,
      a_active, a_in_hospital, a_critical, a_updated
    );
  END IF;
END
$body$ language plpgsql;

CREATE OR REPLACE FUNCTION public_insert_historical_stats (
  a_location varchar, a_location_code varchar, a_location_parent varchar,
  a_total integer, a_total_new integer, a_dead integer, a_dead_new integer,
  a_recovered integer, a_recovered_new integer, a_active integer,
  a_in_hospital integer, a_critical integer, a_day date
)
RETURNS void
AS
$body$
  SELECT public_create_location(a_location, a_location_code, a_location_parent);
  INSERT INTO public.historical_stats (
    location, total, total_new, dead, dead_new, recovered, recovered_new,
    active, in_hospital, critical, day
  )
  VALUES(
    a_location, a_total, a_total_new, a_dead, a_dead_new, a_recovered, a_recovered_new,
    a_active, a_in_hospital, a_critical, a_day
  )
  ON CONFLICT (location, day)
  DO UPDATE SET
    total = a_total, total_new = a_total_new, dead = a_dead, dead_new = a_dead_new,
    recovered = a_recovered, recovered_new = a_recovered_new, active = a_active,
    in_hospital = a_in_hospital, critical = a_critical;
$body$ language SQL;
