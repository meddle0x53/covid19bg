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
  UPDATE public.latest_stats ls
  SET
    total = a_total,
    total_new = CASE WHEN a_total_new > ls.total_new THEN a_total_new ELSE ls.total_new END,
    dead = a_dead,
    dead_new = CASE WHEN a_dead_new > ls.dead_new THEN a_dead_new ELSE ls.dead_new END,
    recovered = a_recovered,
    recovered_new = CASE WHEN a_recovered_new > ls.recovered_new THEN a_recovered_new ELSE ls.recovered_new END,
    active = a_active,
    in_hospital = CASE WHEN a_in_hospital > ls.in_hospital THEN a_in_hospital ELSE ls.in_hospital END,
    critical = CASE WHEN a_critical > ls.critical THEN a_critical ELSE ls.critical END,
    updated = a_updated
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
    total = a_total,
    total_new = CASE WHEN a_total_new > public.historical_stats.total_new THEN a_total_new ELSE public.historical_stats.total_new END,
    dead = a_dead,
    dead_new = CASE WHEN a_dead_new > public.historical_stats.dead_new THEN a_dead_new ELSE public.historical_stats.dead_new END,
    recovered = a_recovered,
    recovered_new = CASE WHEN a_recovered_new > public.historical_stats.recovered_new THEN a_recovered_new ELSE public.historical_stats.recovered_new END,
    active = a_active,
    in_hospital = CASE WHEN a_in_hospital > public.historical_stats.in_hospital THEN a_in_hospital ELSE public.historical_stats.in_hospital END,
    critical = CASE WHEN a_critical > public.historical_stats.critical THEN a_critical ELSE public.historical_stats.critical END;
$body$ language SQL;
