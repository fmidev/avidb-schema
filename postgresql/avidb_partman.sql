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

SET default_tablespace = '';

SET default_table_access_method = heap;


CREATE SCHEMA partman;


ALTER SCHEMA partman OWNER TO avidb_rw;

--
-- Name: pg_partman; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_partman WITH SCHEMA partman;

--
-- Name: template_public_avidb_message_iwxxm_details; Type: TABLE; Schema: partman; Owner: avidb_rw
--

CREATE TABLE partman.template_public_avidb_message_iwxxm_details (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE partman.template_public_avidb_message_iwxxm_details OWNER TO avidb_rw;

--
-- Name: template_public_avidb_messages; Type: TABLE; Schema: partman; Owner: avidb_rw
--

CREATE TABLE partman.template_public_avidb_messages (
    message_id bigint NOT NULL,
    message_time timestamp with time zone NOT NULL,
    station_id integer NOT NULL,
    type_id integer NOT NULL,
    route_id integer NOT NULL,
    message text NOT NULL,
    valid_from timestamp with time zone,
    valid_to timestamp with time zone,
    created timestamp with time zone,
    file_modified timestamp with time zone,
    flag integer,
    messir_heading text,
    version character varying(20),
    format_id smallint NOT NULL
);


ALTER TABLE partman.template_public_avidb_messages OWNER TO avidb_rw;

--
-- Name: template_public_avidb_messages template_public_avidb_messages_pkey; Type: CONSTRAINT; Schema: partman; Owner: avidb_rw
--

ALTER TABLE ONLY partman.template_public_avidb_messages
    ADD CONSTRAINT template_public_avidb_messages_pkey PRIMARY KEY (message_id);


--
-- Name: TABLE template_public_avidb_message_iwxxm_details; Type: ACL; Schema: partman; Owner: avidb_rw
--

GRANT SELECT ON TABLE partman.template_public_avidb_message_iwxxm_details TO avidb_ro;


--
-- Name: TABLE template_public_avidb_messages; Type: ACL; Schema: partman; Owner: avidb_rw
--

GRANT SELECT ON TABLE partman.template_public_avidb_messages TO avidb_ro;

SELECT partman.create_partition(
    p_parent_table := 'public.avidb_messages',
    p_control := 'message_time',
    p_interval := '1 mon',
    p_template_table := 'partman.template_public_avidb_messages',
    p_premake := 1,
    p_start_partition := to_char(date_trunc('month', current_date), 'YYYY-MM-DD')
);

UPDATE partman.part_config
SET datetime_string = 'YYYY_MM',
    inherit_privileges = true,
    premake = 4,
    infinite_time_partitions = true
WHERE parent_table = 'public.avidb_messages';

DO $$
DECLARE
    this_month date := date_trunc('month', current_date)::date;
    next_month date := (date_trunc('month', current_date) + interval '1 month')::date;
BEGIN
    EXECUTE format(
        'ALTER TABLE IF EXISTS public.%I RENAME TO %I',
        'avidb_messages_p' || to_char(this_month, 'YYYYMMDD'),
        'avidb_messages_p' || to_char(this_month, 'YYYY_MM')
    );

    EXECUTE format(
        'ALTER TABLE IF EXISTS public.%I RENAME TO %I',
        'avidb_messages_p' || to_char(next_month, 'YYYYMMDD'),
        'avidb_messages_p' || to_char(next_month, 'YYYY_MM')
    );
END $$;

ALTER TABLE IF EXISTS public.avidb_messages_default RENAME TO avidb_messages_pdefault;

SELECT partman.reapply_privileges('public.avidb_messages');

SELECT partman.create_partition(p_parent_table := 'public.avidb_message_iwxxm_details', p_control := 'id', p_interval := '10000000', p_template_table := 'partman.template_public_avidb_message_iwxxm_details');

UPDATE partman.part_config SET inherit_privileges = true WHERE parent_table = 'public.avidb_message_iwxxm_details';

ALTER TABLE IF EXISTS public.avidb_message_iwxxm_details_default RENAME TO avidb_messages_iwxxm_details_pdefault;

SELECT partman.reapply_privileges('public.avidb_message_iwxxm_details');

SELECT partman.run_maintenance();

GRANT ALL ON ALL tables IN schema partman to avidb_rw;
