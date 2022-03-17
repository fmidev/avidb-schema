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

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';

CREATE FUNCTION public.add_message(in_icao_code character varying, in_message_time timestamp with time zone,
                                   in_type_id integer, in_route_id integer, in_message text,
                                   in_valid_from timestamp with time zone, in_valid_to timestamp with time zone,
                                   in_file_modified timestamp with time zone, in_flag integer, in_messir_heading text,
                                   in_version character varying) RETURNS integer
    LANGUAGE plpgsql
AS
$_$
DECLARE
    L_STATION_ID  integer;
    L_IWXXM_FLAG  integer;
    L_IWXXM_FLAG2 integer;
    L_IWXXM_LIPPU integer;
BEGIN
    BEGIN
        SELECT station_id, iwxxm_flag
        INTO L_STATION_ID,L_IWXXM_FLAG
        FROM avidb_stations
        WHERE icao_code = in_icao_code;
        IF NOT FOUND THEN
            INSERT INTO avidb_rejected_messages
            (icao_code, message_time, type_id, route_id, message, valid_from, valid_to, file_modified, flag,
             messir_heading, reject_reason, version)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 1, $11);
            RETURN 1;
        END IF;
    END;

    BEGIN
        SELECT iwxxm_flag
        INTO L_IWXXM_FLAG2
        FROM avidb_message_types
        WHERE type_id = in_type_id;
    END;

    IF L_IWXXM_FLAG = 1 and L_IWXXM_FLAG2 = 1 THEN
        L_IWXXM_LIPPU := 1;
    ELSE
        L_IWXXM_LIPPU := null;
    END IF;

    IF in_message_time > timezone('UTC', now()) + interval '12 hours' THEN
        INSERT INTO avidb_rejected_messages
        (icao_code, message_time, type_id, route_id, message, valid_from, valid_to, file_modified, flag, messir_heading,
         reject_reason, version)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 2, $11);
        RETURN 2;
    END IF;
    INSERT INTO avidb_messages
    (message_time, station_id, type_id, route_id, message, valid_from, valid_to, file_modified, flag, messir_heading,
     version)
    VALUES ($2, L_STATION_ID, $3, $4, $5, $6, $7, $8, $9, $10, $11);

    IF L_IWXXM_LIPPU = 1 THEN
        INSERT INTO avidb_iwxxm
        (message_time, station_id, type_id, route_id, message, valid_from, valid_to, file_modified, flag,
         messir_heading, version, iwxxm_status)
        VALUES ($2, L_STATION_ID, $3, $4, $5, $6, $7, $8, $9, $10, $11, 0);
    END IF;

    RETURN 0;
END;
$_$;

ALTER FUNCTION public.add_message(in_icao_code character varying, in_message_time timestamp with time zone, in_type_id integer, in_route_id integer, in_message text, in_valid_from timestamp with time zone, in_valid_to timestamp with time zone, in_file_modified timestamp with time zone, in_flag integer, in_messir_heading text, in_version character varying) OWNER TO avidb_rw;

CREATE FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer DEFAULT NULL::integer,
                                              in_limit integer DEFAULT 100) RETURNS refcursor
    LANGUAGE plpgsql
AS
$_$
BEGIN
    OPEN $1 FOR
        SELECT *
        FROM avidb_iwxxm
        where iwxxm_status = 0
          and (in_type_id is null or type_id = in_type_id)
        LIMIT in_limit;
    RETURN $1;
END;
$_$;

ALTER FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer) OWNER TO avidb_rw;

CREATE FUNCTION public.merge_station(in_icao_code character varying, in_name text, in_lat double precision,
                                     in_lon double precision, in_elevation integer,
                                     in_valid_from timestamp without time zone DEFAULT timezone('UTC'::text,
                                                                                                '1700-01-01 00:00:00+00'::timestamp with time zone),
                                     in_valid_to timestamp without time zone DEFAULT timezone('UTC'::text,
                                                                                              '9999-12-31 00:00:00+00'::timestamp with time zone),
                                     in_country_code character varying DEFAULT 'FI'::character varying) RETURNS void
    LANGUAGE plpgsql
AS
$$
BEGIN
    LOOP
        
        UPDATE avidb_stations
        SET name         = in_name
          , geom         = ST_SetSRID(ST_MakePoint(in_lon, in_lat), 4326)
          , elevation    = in_elevation
          , valid_from   = in_valid_from
          , valid_to     = in_valid_to
          , country_code = in_country_code
        WHERE icao_code = in_icao_code;
        IF found THEN
            RETURN;
        END IF;

        BEGIN
            INSERT INTO avidb_stations (icao_code, name, geom, elevation, valid_from, valid_to, country_code)
            VALUES (in_icao_code, in_name, ST_SetSRID(ST_MakePoint(in_lon, in_lat), 4326), in_elevation, in_valid_from,
                    in_valid_to, in_country_code);
            RETURN;
        EXCEPTION
            WHEN unique_violation THEN
            
        END;
    END LOOP;
END;
$$;

ALTER FUNCTION public.merge_station(in_icao_code character varying, in_name text, in_lat double precision, in_lon double precision, in_elevation integer, in_valid_from timestamp without time zone, in_valid_to timestamp without time zone, in_country_code character varying) OWNER TO avidb_rw;

CREATE FUNCTION public.modified_last() RETURNS trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    NEW.modified_last := TIMEZONE('UTC', now());
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.modified_last() OWNER TO avidb_rw;

CREATE FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer,
                                              in_iwxxm_errmsg text,
                                              in_status integer DEFAULT NULL::integer) RETURNS void
    LANGUAGE plpgsql
AS
$$
BEGIN
    UPDATE avidb_iwxxm
    set iwxxm_content = in_iwxxm_content
      , iwxxm_errcode = in_iwxxm_errcode
      , iwxxm_errmsg  = in_iwxxm_errmsg
      , iwxxm_created = timezone('UTC', now())
      , iwxxm_status  = null
      , iwxxm_counter = coalesce(iwxxm_counter, 0) + 1
    where message_id = in_message_id
      and (in_status is null or iwxxm_status = in_status);

END;
$$;

ALTER FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer) OWNER TO avidb_rw;

SET default_tablespace = '';

SET default_table_access_method = heap;

CREATE TABLE public.avidb_stations
(
    station_id    integer NOT NULL,
    icao_code     character varying(4),
    name          text,
    geom          public.geometry(Point, 4326),
    elevation     integer,
    valid_from    timestamp with time zone DEFAULT timezone('UTC'::text,
                                                            '1700-01-01 00:00:00+00'::timestamp with time zone),
    valid_to      timestamp with time zone DEFAULT timezone('UTC'::text,
                                                            '9999-12-31 00:00:00+00'::timestamp with time zone),
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    iwxxm_flag    integer,
    country_code  character varying(2)
);

ALTER TABLE public.avidb_stations
    OWNER TO avidb_rw;

-- avidb_iwxxm is deprecated

CREATE TABLE public.avidb_iwxxm
(
    message_id     integer                  NOT NULL,
    message_time   timestamp with time zone NOT NULL,
    station_id     integer                  NOT NULL,
    type_id        integer                  NOT NULL,
    route_id       integer                  NOT NULL,
    message        text                     NOT NULL,
    valid_from     timestamp with time zone,
    valid_to       timestamp with time zone,
    created        timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified  timestamp with time zone,
    flag           integer                  DEFAULT 0,
    messir_heading text,
    version        character varying(20),
    iwxxm_status   integer,
    iwxxm_created  timestamp with time zone,
    iwxxm_content  text,
    iwxxm_errcode  integer,
    iwxxm_errmsg   text,
    iwxxm_counter  integer
);

ALTER TABLE public.avidb_iwxxm
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_iwxxm
    ALTER COLUMN message_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_iwxxm_message_id_seq
START
WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    );

CREATE TABLE public.avidb_message_format
(
    format_id     smallint NOT NULL,
    name          text,
    modified_last timestamp without time zone
);

ALTER TABLE public.avidb_message_format
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_message_iwxxm_details
(
    id                 bigint NOT NULL,
    message_id         bigint NOT NULL,
    collect_identifier text,
    iwxxm_version      text
)
    PARTITION BY RANGE (id);

ALTER TABLE public.avidb_message_iwxxm_details
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_message_iwxxm_details
    ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_message_iwxxm_details_id_seq
START
WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    );

CREATE TABLE public.avidb_message_iwxxm_details_p0
(
    id                 bigint NOT NULL,
    message_id         bigint NOT NULL,
    collect_identifier text,
    iwxxm_version      text
);

ALTER TABLE public.avidb_message_iwxxm_details_p0
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_message_iwxxm_details_pdefault
(
    id                 bigint NOT NULL,
    message_id         bigint NOT NULL,
    collect_identifier text,
    iwxxm_version      text
);

ALTER TABLE public.avidb_message_iwxxm_details_pdefault
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_message_routes
(
    route_id      integer NOT NULL,
    name          character varying(20),
    description   text,
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now())
);

ALTER TABLE public.avidb_message_routes
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_message_types
(
    type_id       integer NOT NULL,
    type          character varying(20),
    description   text,
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    iwxxm_flag    integer
);

ALTER TABLE public.avidb_message_types
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_messages
(
    message_id     bigint                             NOT NULL,
    message_time   timestamp with time zone           NOT NULL,
    station_id     integer                            NOT NULL,
    type_id        integer                            NOT NULL,
    route_id       integer                            NOT NULL,
    message        text                               NOT NULL,
    valid_from     timestamp with time zone,
    valid_to       timestamp with time zone,
    created        timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified  timestamp with time zone,
    flag           integer                  DEFAULT 0,
    messir_heading text,
    version        character varying(20),
    format_id      smallint                 DEFAULT 1 NOT NULL
)
    PARTITION BY RANGE (message_time);

ALTER TABLE public.avidb_messages
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_messages
    ALTER COLUMN message_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_messages_message_id_seq
START
WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    );

CREATE TABLE public.avidb_messages_p2010
(
    message_id     bigint                             NOT NULL,
    message_time   timestamp with time zone           NOT NULL,
    station_id     integer                            NOT NULL,
    type_id        integer                            NOT NULL,
    route_id       integer                            NOT NULL,
    message        text                               NOT NULL,
    valid_from     timestamp with time zone,
    valid_to       timestamp with time zone,
    created        timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified  timestamp with time zone,
    flag           integer                  DEFAULT 0,
    messir_heading text,
    version        character varying(20),
    format_id      smallint                 DEFAULT 1 NOT NULL
);

ALTER TABLE public.avidb_messages_p2010
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_messages_p2020
(
    message_id     bigint                             NOT NULL,
    message_time   timestamp with time zone           NOT NULL,
    station_id     integer                            NOT NULL,
    type_id        integer                            NOT NULL,
    route_id       integer                            NOT NULL,
    message        text                               NOT NULL,
    valid_from     timestamp with time zone,
    valid_to       timestamp with time zone,
    created        timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified  timestamp with time zone,
    flag           integer                  DEFAULT 0,
    messir_heading text,
    version        character varying(20),
    format_id      smallint                 DEFAULT 1 NOT NULL
);

ALTER TABLE public.avidb_messages_p2020
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_messages_pdefault
(
    message_id     bigint                             NOT NULL,
    message_time   timestamp with time zone           NOT NULL,
    station_id     integer                            NOT NULL,
    type_id        integer                            NOT NULL,
    route_id       integer                            NOT NULL,
    message        text                               NOT NULL,
    valid_from     timestamp with time zone,
    valid_to       timestamp with time zone,
    created        timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified  timestamp with time zone,
    flag           integer                  DEFAULT 0,
    messir_heading text,
    version        character varying(20),
    format_id      smallint                 DEFAULT 1 NOT NULL
);

ALTER TABLE public.avidb_messages_pdefault
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_rejected_message_iwxxm_details
(
    rejected_message_id bigint NOT NULL,
    collect_identifier  text,
    iwxxm_version       text
);

ALTER TABLE public.avidb_rejected_message_iwxxm_details
    OWNER TO avidb_rw;

CREATE TABLE public.avidb_rejected_messages
(
    rejected_message_id bigint                             NOT NULL,
    icao_code           text,
    message_time        timestamp with time zone,
    type_id             integer,
    route_id            integer,
    message             text,
    valid_from          timestamp with time zone,
    valid_to            timestamp with time zone,
    created             timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified       timestamp with time zone,
    flag                integer                  DEFAULT 0,
    messir_heading      text,
    reject_reason       integer,
    version             character varying(20),
    format_id           smallint                 DEFAULT 1 NOT NULL
);

ALTER TABLE public.avidb_rejected_messages
    OWNER TO avidb_rw;

ALTER TABLE public.avidb_rejected_messages
    ALTER COLUMN rejected_message_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_rejected_messages_rejected_message_id_seq
START
WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    );

ALTER TABLE public.avidb_stations
    ALTER COLUMN station_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_stations_station_id_seq
START
WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    );

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_p0 FOR VALUES FROM ('0') TO ('10000000');

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_pdefault DEFAULT;

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2010 FOR VALUES FROM ('2010-01-01 00:00:00+00') TO ('2020-01-01 00:00:00+00');

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020 FOR VALUES FROM ('2020-01-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_pdefault DEFAULT;

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_pk PRIMARY KEY (message_id);

ALTER TABLE ONLY public.avidb_message_format
    ADD CONSTRAINT avidb_message_format_pk PRIMARY KEY (format_id);

ALTER TABLE ONLY public.avidb_message_iwxxm_details
    ADD CONSTRAINT avidb_message_iwxxm_details_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.avidb_message_iwxxm_details_p0
    ADD CONSTRAINT avidb_message_iwxxm_details_p0_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.avidb_message_iwxxm_details_pdefault
    ADD CONSTRAINT avidb_message_iwxxm_details_pdefault_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.avidb_message_routes
    ADD CONSTRAINT avidb_message_routes_pk PRIMARY KEY (route_id);

ALTER TABLE ONLY public.avidb_message_types
    ADD CONSTRAINT avidb_message_types_pk PRIMARY KEY (type_id);

ALTER TABLE ONLY public.avidb_messages_p2010
    ADD CONSTRAINT avidb_messages_p2010_pkey PRIMARY KEY (message_id);

ALTER TABLE ONLY public.avidb_messages_p2020
    ADD CONSTRAINT avidb_messages_p2020_pkey PRIMARY KEY (message_id);

ALTER TABLE ONLY public.avidb_messages_pdefault
    ADD CONSTRAINT avidb_messages_pdefault_pkey PRIMARY KEY (message_id);

ALTER TABLE ONLY public.avidb_rejected_message_iwxxm_details
    ADD CONSTRAINT avidb_rejected_message_iwxxm_details_pkey PRIMARY KEY (rejected_message_id);

ALTER TABLE ONLY public.avidb_rejected_messages
    ADD CONSTRAINT avidb_rejected_messages_pkey1 PRIMARY KEY (rejected_message_id);

ALTER TABLE ONLY public.avidb_stations
    ADD CONSTRAINT avidb_stations_icao_code_key UNIQUE (icao_code);

ALTER TABLE ONLY public.avidb_stations
    ADD CONSTRAINT avidb_stations_pk PRIMARY KEY (station_id);

CREATE INDEX avidb_iwxxm_cr_idx ON public.avidb_iwxxm USING btree (created);

CREATE INDEX avidb_iwxxm_idx ON public.avidb_iwxxm USING btree (message_time, type_id, station_id);

CREATE INDEX avidb_iwxxm_st_idx ON public.avidb_iwxxm USING btree (station_id);

CREATE INDEX avidb_iwxxm_status ON public.avidb_iwxxm USING btree (iwxxm_status);

CREATE INDEX avidb_messages_created_idx ON public.avidb_messages USING btree (created);

CREATE INDEX avidb_messages_station_id_idx ON public.avidb_messages USING btree (station_id);

CREATE INDEX avidb_messages_idx ON public.avidb_messages USING btree (message_time, type_id, station_id, format_id);

CREATE INDEX avidb_rejected_messages_idx1 ON public.avidb_rejected_messages USING btree (created);

CREATE INDEX avidb_stations_geom_idx ON public.avidb_stations USING gist (geom);

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_p0_pkey;

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_pdefault_pkey;

CREATE TRIGGER avidb_message_routes_trg
    BEFORE INSERT OR UPDATE
    ON public.avidb_message_routes
    FOR EACH ROW
EXECUTE FUNCTION public.modified_last();

CREATE TRIGGER avidb_message_types_trg
    BEFORE INSERT OR UPDATE
    ON public.avidb_message_types
    FOR EACH ROW
EXECUTE FUNCTION public.modified_last();

CREATE TRIGGER avidb_stations_trg
    BEFORE INSERT OR UPDATE
    ON public.avidb_stations
    FOR EACH ROW
EXECUTE FUNCTION public.modified_last();

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk1 FOREIGN KEY (station_id) REFERENCES public.avidb_stations (station_id) MATCH FULL;

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk2 FOREIGN KEY (type_id) REFERENCES public.avidb_message_types (type_id) MATCH FULL;

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk3 FOREIGN KEY (route_id) REFERENCES public.avidb_message_routes (route_id) MATCH FULL;

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk1 FOREIGN KEY (station_id) REFERENCES public.avidb_stations (station_id) MATCH FULL;

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk2 FOREIGN KEY (type_id) REFERENCES public.avidb_message_types (type_id) MATCH FULL;

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk3 FOREIGN KEY (route_id) REFERENCES public.avidb_message_routes (route_id) MATCH FULL;

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk4 FOREIGN KEY (format_id) REFERENCES public.avidb_message_format (format_id);

ALTER TABLE ONLY public.avidb_rejected_message_iwxxm_details
    ADD CONSTRAINT avidb_rejected_message_iwxxm_details_fk_rejected_message_id FOREIGN KEY (rejected_message_id) REFERENCES public.avidb_rejected_messages (rejected_message_id);

ALTER TABLE ONLY public.avidb_rejected_messages
    ADD CONSTRAINT avidb_rejected_messages_fkey_format_id FOREIGN KEY (format_id) REFERENCES public.avidb_message_format (format_id);

GRANT ALL ON FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer) TO avidb_iwxxm;

GRANT ALL ON FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer) TO avidb_iwxxm;

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

ALTER DEFAULT PRIVILEGES FOR ROLE avidb_rw IN SCHEMA public GRANT SELECT ON TABLES TO avidb_ro;
