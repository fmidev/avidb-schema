-- Optional privilege setup.
-- This sets up the following roles:
--  Read/write role 'avidb_rw'
--  Read-only role 'avidb_ro'
--  Deprecated role 'avidb_iwxxm'
--  Login role 'avidb_agent' with password 'secret' belonging to the read/write group role 'avidb_rw'

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE FUNCTION pg_temp.create_role(rolename text) RETURNS void
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS(
            SELECT FROM pg_catalog.pg_roles WHERE rolname = rolename) THEN
        EXECUTE FORMAT('CREATE ROLE %I', rolename);
    END IF;
END;
$$;

SELECT pg_temp.create_role('avidb_rw');

SELECT pg_temp.create_role('avidb_ro');

SELECT pg_temp.create_role('avidb_iwxxm');

SELECT pg_temp.create_role('avidb_agent');
GRANT avidb_rw TO avidb_agent;
ALTER ROLE avidb_agent LOGIN PASSWORD 'secret';

-- Read/write privileges

ALTER FUNCTION public.add_message(in_icao_code character varying, in_message_time timestamp with time zone, in_type_id integer, in_route_id integer, in_message text, in_valid_from timestamp with time zone, in_valid_to timestamp with time zone, in_file_modified timestamp with time zone, in_flag integer, in_messir_heading text, in_version character varying) OWNER TO avidb_rw;

ALTER FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer) OWNER TO avidb_rw;

ALTER FUNCTION public.merge_station(in_icao_code character varying, in_name text, in_lat double precision, in_lon double precision, in_elevation integer, in_valid_from timestamp without time zone, in_valid_to timestamp without time zone, in_country_code character varying) OWNER TO avidb_rw;

ALTER FUNCTION public.modified_last() OWNER TO avidb_rw;

ALTER FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer) OWNER TO avidb_rw;

ALTER TABLE public.avidb_stations
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_iwxxm
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_message_format
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_message_iwxxm_details
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_message_iwxxm_details_p0
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_message_iwxxm_details_pdefault
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_message_routes
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_message_types
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_messages
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_messages_p2010
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_messages_p2020
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_messages_pdefault
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_rejected_message_iwxxm_details
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_rejected_messages
    OWNER TO avidb_rw;

-- Read-only privileges

GRANT SELECT ON TABLE public.avidb_stations TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_iwxxm TO avidb_ro;
GRANT SELECT, UPDATE ON TABLE public.avidb_iwxxm TO avidb_iwxxm;

GRANT SELECT ON TABLE public.avidb_message_format TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_p0 TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_pdefault TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_message_routes TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_message_types TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_messages TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_messages_p2010 TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_messages_p2020 TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_messages_pdefault TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_rejected_message_iwxxm_details TO avidb_ro;

GRANT SELECT ON TABLE public.avidb_rejected_messages TO avidb_ro;

-- Deprecated avidb_iwxxm privileges

GRANT ALL ON FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer) TO avidb_iwxxm;

GRANT ALL ON FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer) TO avidb_iwxxm;