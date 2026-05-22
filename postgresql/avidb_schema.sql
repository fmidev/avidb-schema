--
-- PostgreSQL database dump
--

-- Dumped from database version 17.3
-- Dumped by pg_dump version 17.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA audit;


ALTER SCHEMA audit OWNER TO postgres;

--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: aixm_uom_distance_vertical; Type: TYPE; Schema: public; Owner: avidb_rw
--

CREATE TYPE public.aixm_uom_distance_vertical AS ENUM (
    'FT',
    'M',
    'FL',
    'SM',
    'OTHER'
);


ALTER TYPE public.aixm_uom_distance_vertical OWNER TO avidb_rw;

--
-- Name: add_message(character varying, timestamp with time zone, integer, integer, text, timestamp with time zone, timestamp with time zone, timestamp with time zone, integer, text, character varying); Type: FUNCTION; Schema: public; Owner: avidb_rw
--

CREATE FUNCTION public.add_message(in_icao_code character varying, in_message_time timestamp with time zone, in_type_id integer, in_route_id integer, in_message text, in_valid_from timestamp with time zone, in_valid_to timestamp with time zone, in_file_modified timestamp with time zone, in_flag integer, in_messir_heading text, in_version character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  L_STATION_ID integer;
BEGIN
        -- UNKNOWN_STATION_ICAO_CODE
        BEGIN
         SELECT station_id
         INTO L_STATION_ID
         FROM avidb_stations
         WHERE icao_code = in_icao_code;

         IF NOT FOUND THEN
          INSERT INTO avidb_rejected_messages
          (icao_code,message_time,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,reject_reason,version)
           VALUES
          ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,1,$11);
          RETURN 1;
         END IF;      
        END;
  
        --MESSAGE_TIME_IN_FUTURE
        IF in_message_time > timezone('UTC',now()) + interval '12 hours' THEN
          INSERT INTO avidb_rejected_messages
          (icao_code,message_time,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,reject_reason,version)
           VALUES
          ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,2,$11);
          RETURN 2;
        END IF;

        -- FORBIDDEN_BULLETIN_LOCATION_INDICATOR
        IF  in_icao_code like 'EF%' and in_messir_heading not like '% EF%' THEN
          INSERT INTO avidb_rejected_messages
          (icao_code,message_time,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,reject_reason,version)
           VALUES
          ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,6,$11);
          RETURN 6;

        END IF;

        -- FORBIDDEN_MESSAGE_STATION_ICAO_CODE
        IF  in_icao_code not like 'EF%' and in_messir_heading like '% EF%' THEN
          INSERT INTO avidb_rejected_messages
          (icao_code,message_time,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,reject_reason,version)
           VALUES
          ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,5,$11);
          RETURN 5;
        END IF;


        INSERT INTO avidb_messages
         (message_time,station_id,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,version,format_id)
        VALUES
        ($2,L_STATION_ID,$3,$4,$5,$6,$7,$8,$9,$10,$11,1);
                
        
        RETURN 0;   
END;
$_$;


ALTER FUNCTION public.add_message(in_icao_code character varying, in_message_time timestamp with time zone, in_type_id integer, in_route_id integer, in_message text, in_valid_from timestamp with time zone, in_valid_to timestamp with time zone, in_file_modified timestamp with time zone, in_flag integer, in_messir_heading text, in_version character varying) OWNER TO avidb_rw;

--
-- Name: get_messages_for_iwxxm(refcursor, integer, integer); Type: FUNCTION; Schema: public; Owner: avidb_rw
--

CREATE FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer DEFAULT NULL::integer, in_limit integer DEFAULT 100) RETURNS refcursor
    LANGUAGE plpgsql
    AS $_$                                                     
    BEGIN
      OPEN $1 FOR 
        SELECT * 
        FROM avidb_iwxxm
        where iwxxm_status = 0
        and ( in_type_id is null or type_id = in_type_id ) 
        LIMIT in_limit
        ;  
      RETURN $1;                                                       
    END;
    $_$;


ALTER FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer) OWNER TO avidb_rw;

--
-- Name: merge_station(character varying, text, double precision, double precision, integer, timestamp without time zone, timestamp without time zone, character varying); Type: FUNCTION; Schema: public; Owner: avidb_rw
--

CREATE FUNCTION public.merge_station(in_icao_code character varying, in_name text, in_lat double precision, in_lon double precision, in_elevation integer, in_valid_from timestamp without time zone DEFAULT timezone('UTC'::text, '1700-01-01 01:39:49+01:39:49'::timestamp with time zone), in_valid_to timestamp without time zone DEFAULT timezone('UTC'::text, '9999-12-31 02:00:00+02'::timestamp with time zone), in_country_code character varying DEFAULT 'FI'::character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    LOOP
        -- first try to update the key
        UPDATE avidb_stations
        SET
          name = in_name
        , geom =  ST_SetSRID(ST_MakePoint(in_lon,in_lat),4326)
        , elevation = in_elevation
        , valid_from = in_valid_from
        , valid_to = in_valid_to
        , country_code = in_country_code
        WHERE icao_code = in_icao_code;
        IF found THEN
            RETURN;
        END IF;
        -- not there, so try to insert the key
        -- if someone else inserts the same key concurrently,
        -- we could get a unique-key failure
        BEGIN
        INSERT INTO avidb_stations (icao_code,name,geom,elevation,valid_from, valid_to, country_code)
        VALUES
        (in_icao_code,in_name,ST_SetSRID(ST_MakePoint(in_lon,in_lat),4326),in_elevation,in_valid_from, in_valid_to , in_country_code );
            RETURN;
        EXCEPTION WHEN unique_violation THEN
            -- Do nothing, and loop to try the UPDATE again.
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION public.merge_station(in_icao_code character varying, in_name text, in_lat double precision, in_lon double precision, in_elevation integer, in_valid_from timestamp without time zone, in_valid_to timestamp without time zone, in_country_code character varying) OWNER TO avidb_rw;

--
-- Name: modified_last(); Type: FUNCTION; Schema: public; Owner: avidb_rw
--

CREATE FUNCTION public.modified_last() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        NEW.modified_last := TIMEZONE('UTC',now());
        RETURN NEW;
    END;
$$;


ALTER FUNCTION public.modified_last() OWNER TO avidb_rw;

--
-- Name: update_converted_iwxxm(integer, text, integer, text, integer); Type: FUNCTION; Schema: public; Owner: avidb_rw
--

CREATE FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer DEFAULT NULL::integer) RETURNS void
    LANGUAGE plpgsql
    AS $$                                                     
    BEGIN
      UPDATE avidb_iwxxm
      set iwxxm_content = in_iwxxm_content
      ,   iwxxm_errcode = in_iwxxm_errcode
      ,   iwxxm_errmsg  = in_iwxxm_errmsg
      ,   iwxxm_created = timezone('UTC',now())
      ,   iwxxm_status  = null
      ,   iwxxm_counter = coalesce(iwxxm_counter,0) + 1  
      where message_id = in_message_id
      and (in_status is null or iwxxm_status = in_status );
                                                             
    END;
    $$;


ALTER FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer) OWNER TO avidb_rw;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: avidb_aerodrome; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_aerodrome (
    aerodrome_id integer NOT NULL,
    station_id integer,
    icao_code character varying(4),
    iata_code character varying(3),
    fir_code character varying(4) NOT NULL,
    aerodrome_name character varying(60),
    orig_reference_point character varying(32) NOT NULL,
    reference_point public.geometry(Point,4258) NOT NULL,
    reference_point_elevation numeric(12,4),
    reference_point_elevation_uom public.aixm_uom_distance_vertical,
    field_elevation numeric(12,4),
    field_elevation_uom public.aixm_uom_distance_vertical,
    valid_from timestamp with time zone DEFAULT timezone('UTC'::text, '1700-01-01 01:39:49+01:39:49'::timestamp with time zone) NOT NULL,
    valid_to timestamp with time zone DEFAULT timezone('UTC'::text, '9999-12-31 02:00:00+02'::timestamp with time zone) NOT NULL,
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    CONSTRAINT ck_aerodrome_name CHECK (((aerodrome_name)::text ~ '^([A-Z]|[0-9]|[, !"&#$%''''()*+-\\./:;<=>?@[\\\]^_|{}]){1,60}$'::text)),
    CONSTRAINT ck_iata_code CHECK (((iata_code)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT ck_icao_code CHECK (((icao_code)::text ~ '^[A-Z]{4}$'::text))
);


ALTER TABLE public.avidb_aerodrome OWNER TO avidb_rw;

--
-- Name: avidb_aerodrome_aerodrome_id_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_aerodrome ALTER COLUMN aerodrome_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_aerodrome_aerodrome_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: avidb_stations; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_stations (
    station_id integer NOT NULL,
    icao_code character varying(4),
    name text,
    geom public.geometry(Point,4326),
    elevation integer,
    valid_from timestamp with time zone DEFAULT timezone('UTC'::text, '1700-01-01 01:39:49+01:39:49'::timestamp with time zone),
    valid_to timestamp with time zone DEFAULT timezone('UTC'::text, '9999-12-31 02:00:00+02'::timestamp with time zone),
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    iwxxm_flag integer,
    country_code character varying(2)
);


ALTER TABLE public.avidb_stations OWNER TO avidb_rw;

--
-- Name: avidb_aerodrome_iwxxm_metadata; Type: VIEW; Schema: public; Owner: avidb_rw
--

CREATE VIEW public.avidb_aerodrome_iwxxm_metadata AS
 SELECT avidb_aerodrome.aerodrome_id AS id,
    avidb_stations.icao_code AS designator,
    avidb_aerodrome.icao_code,
    avidb_aerodrome.iata_code,
    avidb_aerodrome.fir_code,
    avidb_aerodrome.aerodrome_name,
    avidb_aerodrome.reference_point,
    avidb_aerodrome.reference_point_elevation,
    (avidb_aerodrome.reference_point_elevation_uom)::text AS reference_point_elevation_uom,
    avidb_aerodrome.field_elevation,
    (avidb_aerodrome.field_elevation_uom)::text AS field_elevation_uom
   FROM public.avidb_aerodrome,
    public.avidb_stations
  WHERE ((avidb_aerodrome.station_id = avidb_stations.station_id) AND (avidb_aerodrome.station_id IS NOT NULL) AND (avidb_stations.station_id IS NOT NULL));


ALTER VIEW public.avidb_aerodrome_iwxxm_metadata OWNER TO avidb_rw;

--
-- Name: avidb_iwxxm; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_iwxxm (
    message_id integer NOT NULL,
    message_time timestamp with time zone NOT NULL,
    station_id integer NOT NULL,
    type_id integer NOT NULL,
    route_id integer NOT NULL,
    message text NOT NULL,
    valid_from timestamp with time zone,
    valid_to timestamp with time zone,
    created timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified timestamp with time zone,
    flag integer DEFAULT 0,
    messir_heading text,
    version character varying(20),
    iwxxm_status integer,
    iwxxm_created timestamp with time zone,
    iwxxm_content text,
    iwxxm_errcode integer,
    iwxxm_errmsg text,
    iwxxm_counter integer
);


ALTER TABLE public.avidb_iwxxm OWNER TO avidb_rw;

--
-- Name: avidb_iwxxm_message_id_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_iwxxm ALTER COLUMN message_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_iwxxm_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: avidb_message_format; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_format (
    format_id smallint NOT NULL,
    name text,
    modified_last timestamp without time zone
);


ALTER TABLE public.avidb_message_format OWNER TO avidb_rw;

--
-- Name: avidb_message_iwxxm_details; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_iwxxm_details (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
)
PARTITION BY RANGE (id);


ALTER TABLE public.avidb_message_iwxxm_details OWNER TO avidb_rw;

--
-- Name: avidb_message_iwxxm_details_id_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_message_iwxxm_details ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_message_iwxxm_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: avidb_message_routes; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_routes (
    route_id integer NOT NULL,
    name character varying(20),
    description text,
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now())
);


ALTER TABLE public.avidb_message_routes OWNER TO avidb_rw;

--
-- Name: avidb_message_types; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_types (
    type_id integer NOT NULL,
    type character varying(20),
    description text,
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    iwxxm_flag integer
);


ALTER TABLE public.avidb_message_types OWNER TO avidb_rw;

--
-- Name: avidb_messages; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages (
    message_id bigint NOT NULL,
    message_time timestamp with time zone NOT NULL,
    station_id integer NOT NULL,
    type_id integer NOT NULL,
    route_id integer NOT NULL,
    message text NOT NULL,
    valid_from timestamp with time zone,
    valid_to timestamp with time zone,
    created timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified timestamp with time zone,
    flag integer DEFAULT 0,
    messir_heading text,
    version character varying(20),
    format_id smallint DEFAULT 1 NOT NULL
)
PARTITION BY RANGE (message_time);


ALTER TABLE public.avidb_messages OWNER TO avidb_rw;

--
-- Name: avidb_messages_message_id_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages ALTER COLUMN message_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_messages_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: avidb_rejected_message_iwxxm_details; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_rejected_message_iwxxm_details (
    rejected_message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_rejected_message_iwxxm_details OWNER TO avidb_rw;

--
-- Name: avidb_rejected_messages; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_rejected_messages (
    rejected_message_id bigint NOT NULL,
    icao_code text,
    message_time timestamp with time zone,
    type_id integer,
    route_id integer,
    message text,
    valid_from timestamp with time zone,
    valid_to timestamp with time zone,
    created timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    file_modified timestamp with time zone,
    flag integer DEFAULT 0,
    messir_heading text,
    reject_reason integer,
    version character varying(20),
    format_id smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.avidb_rejected_messages OWNER TO avidb_rw;

--
-- Name: avidb_rejected_messages_rejected_message_id_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_rejected_messages ALTER COLUMN rejected_message_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_rejected_messages_rejected_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: avidb_stations_station_id_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_stations ALTER COLUMN station_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.avidb_stations_station_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: gt_pk_metadata; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.gt_pk_metadata (
    table_schema character varying(32) NOT NULL,
    table_name character varying(32) NOT NULL,
    pk_column character varying(32) NOT NULL,
    pk_column_idx integer,
    pk_policy character varying(32),
    pk_sequence character varying(64),
    CONSTRAINT gt_pk_metadata_pk_policy_check CHECK (((pk_policy)::text = ANY (ARRAY[('sequence'::character varying)::text, ('assigned'::character varying)::text, ('autogenerated'::character varying)::text])))
);


ALTER TABLE public.gt_pk_metadata OWNER TO avidb_rw;

--
-- Name: TABLE gt_pk_metadata; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON TABLE public.gt_pk_metadata IS 'GeoServer primary key metadata table. See https://docs.geoserver.org/stable/en/user/data/database/primarykey.html';


--
-- Name: COLUMN gt_pk_metadata.table_schema; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.table_schema IS 'Name of the database schema in which the table is located.';


--
-- Name: COLUMN gt_pk_metadata.table_name; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.table_name IS 'Name of the table to be published.';


--
-- Name: COLUMN gt_pk_metadata.pk_column; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_column IS 'Name of a column used to form the feature IDs.';


--
-- Name: COLUMN gt_pk_metadata.pk_column_idx; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_column_idx IS 'Index of the column in a multi-column key. In case multi column keys are needed multiple records with the same table schema and table name will be used.';


--
-- Name: COLUMN gt_pk_metadata.pk_policy; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_policy IS 'The new value generation policy, used in case a new feature needs to be added in the table (following a WFS-T insert operation).';


--
-- Name: COLUMN gt_pk_metadata.pk_sequence; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_sequence IS 'The name of the database sequence to be used when generating a new value for the pk_column.';


--
-- Name: icao_fir_yhdiste; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.icao_fir_yhdiste (
    gid integer NOT NULL,
    region character varying(4),
    statecode character varying(3),
    statename character varying(52),
    areageom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public.icao_fir_yhdiste OWNER TO avidb_rw;

--
-- Name: icao_fir_yhdiste_gid_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.icao_fir_yhdiste ALTER COLUMN gid ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.icao_fir_yhdiste_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: icao_fir_yhdistelma; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.icao_fir_yhdistelma (
    gid integer NOT NULL,
    firname character varying(25),
    region character varying(4),
    icaocode character varying(4),
    statecode character varying(3),
    statename character varying(52),
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public.icao_fir_yhdistelma OWNER TO avidb_rw;

--
-- Name: icao_fir_yhdistelma_gid_seq; Type: SEQUENCE; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.icao_fir_yhdistelma ALTER COLUMN gid ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.icao_fir_yhdistelma_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: avidb_aerodrome avidb_aerodrome_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_aerodrome
    ADD CONSTRAINT avidb_aerodrome_pkey PRIMARY KEY (aerodrome_id);


--
-- Name: avidb_iwxxm avidb_iwxxm_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_pk PRIMARY KEY (message_id);


--
-- Name: avidb_message_format avidb_message_format_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_format
    ADD CONSTRAINT avidb_message_format_pk PRIMARY KEY (format_id);


--
-- Name: avidb_message_iwxxm_details avidb_message_iwxxm_details_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details
    ADD CONSTRAINT avidb_message_iwxxm_details_pkey PRIMARY KEY (id);


--
-- Name: avidb_message_routes avidb_message_routes_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_routes
    ADD CONSTRAINT avidb_message_routes_pk PRIMARY KEY (route_id);


--
-- Name: avidb_message_types avidb_message_types_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_types
    ADD CONSTRAINT avidb_message_types_pk PRIMARY KEY (type_id);


--
-- Name: avidb_rejected_message_iwxxm_details avidb_rejected_message_iwxxm_details_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_message_iwxxm_details
    ADD CONSTRAINT avidb_rejected_message_iwxxm_details_pkey PRIMARY KEY (rejected_message_id);


--
-- Name: avidb_rejected_messages avidb_rejected_messages_pkey1; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_messages
    ADD CONSTRAINT avidb_rejected_messages_pkey1 PRIMARY KEY (rejected_message_id);


--
-- Name: avidb_stations avidb_stations_icao_code_key; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_stations
    ADD CONSTRAINT avidb_stations_icao_code_key UNIQUE (icao_code);


--
-- Name: avidb_stations avidb_stations_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_stations
    ADD CONSTRAINT avidb_stations_pk PRIMARY KEY (station_id);


--
-- Name: gt_pk_metadata gt_pk_metadata_table_schema_table_name_pk_column_key; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.gt_pk_metadata
    ADD CONSTRAINT gt_pk_metadata_table_schema_table_name_pk_column_key UNIQUE (table_schema, table_name, pk_column);


--
-- Name: icao_fir_yhdiste icao_fir_yhdiste_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.icao_fir_yhdiste
    ADD CONSTRAINT icao_fir_yhdiste_pkey PRIMARY KEY (gid);


--
-- Name: icao_fir_yhdistelma icao_fir_yhdistelma_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.icao_fir_yhdistelma
    ADD CONSTRAINT icao_fir_yhdistelma_pkey PRIMARY KEY (gid);


--
-- Name: avidb_aerodrome_iata_code_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE UNIQUE INDEX avidb_aerodrome_iata_code_idx ON public.avidb_aerodrome USING btree (iata_code) WHERE (iata_code IS NOT NULL);


--
-- Name: avidb_aerodrome_icao_code_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE UNIQUE INDEX avidb_aerodrome_icao_code_idx ON public.avidb_aerodrome USING btree (icao_code) WHERE (icao_code IS NOT NULL);


--
-- Name: avidb_aerodrome_reference_point_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_aerodrome_reference_point_idx ON public.avidb_aerodrome USING gist (reference_point);


--
-- Name: avidb_aerodrome_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE UNIQUE INDEX avidb_aerodrome_station_id_idx ON public.avidb_aerodrome USING btree (station_id) WHERE (icao_code IS NOT NULL);


--
-- Name: avidb_iwxxm_cr_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_cr_idx ON public.avidb_iwxxm USING btree (created);


--
-- Name: avidb_iwxxm_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_idx ON public.avidb_iwxxm USING btree (message_time, type_id, station_id);


--
-- Name: avidb_iwxxm_st_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_st_idx ON public.avidb_iwxxm USING btree (station_id);


--
-- Name: avidb_iwxxm_status; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_status ON public.avidb_iwxxm USING btree (iwxxm_status);


--
-- Name: avidb_messages_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_created_idx ON ONLY public.avidb_messages USING btree (created);


--
-- Name: avidb_messages_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_idx ON ONLY public.avidb_messages USING btree (message_time, type_id, station_id, format_id);


--
-- Name: avidb_messages_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_station_id_idx ON ONLY public.avidb_messages USING btree (station_id);


--
-- Name: avidb_rejected_messages_idx1; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_rejected_messages_idx1 ON public.avidb_rejected_messages USING btree (created);


--
-- Name: avidb_stations_geom_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_stations_geom_idx ON public.avidb_stations USING gist (geom);


--
-- Name: avidb_aerodrome avidb_aerodrome_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_aerodrome_trg BEFORE INSERT OR UPDATE ON public.avidb_aerodrome FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- Name: avidb_message_routes avidb_message_routes_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_message_routes_trg BEFORE INSERT OR UPDATE ON public.avidb_message_routes FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- Name: avidb_message_types avidb_message_types_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_message_types_trg BEFORE INSERT OR UPDATE ON public.avidb_message_types FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- Name: avidb_stations avidb_stations_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_stations_trg BEFORE INSERT OR UPDATE ON public.avidb_stations FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- Name: avidb_aerodrome avidb_aerodrome_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_aerodrome
    ADD CONSTRAINT avidb_aerodrome_station_id_fkey FOREIGN KEY (station_id) REFERENCES public.avidb_stations(station_id);


--
-- Name: avidb_iwxxm avidb_iwxxm_fk1; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk1 FOREIGN KEY (station_id) REFERENCES public.avidb_stations(station_id) MATCH FULL;


--
-- Name: avidb_iwxxm avidb_iwxxm_fk2; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk2 FOREIGN KEY (type_id) REFERENCES public.avidb_message_types(type_id) MATCH FULL;


--
-- Name: avidb_iwxxm avidb_iwxxm_fk3; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk3 FOREIGN KEY (route_id) REFERENCES public.avidb_message_routes(route_id) MATCH FULL;


--
-- Name: avidb_messages avidb_messages_fk1; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk1 FOREIGN KEY (station_id) REFERENCES public.avidb_stations(station_id) MATCH FULL;


--
-- Name: avidb_messages avidb_messages_fk2; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk2 FOREIGN KEY (type_id) REFERENCES public.avidb_message_types(type_id) MATCH FULL;


--
-- Name: avidb_messages avidb_messages_fk3; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk3 FOREIGN KEY (route_id) REFERENCES public.avidb_message_routes(route_id) MATCH FULL;


--
-- Name: avidb_messages avidb_messages_fk4; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk4 FOREIGN KEY (format_id) REFERENCES public.avidb_message_format(format_id);


--
-- Name: avidb_rejected_message_iwxxm_details avidb_rejected_message_iwxxm_details_fk_rejected_message_id; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_message_iwxxm_details
    ADD CONSTRAINT avidb_rejected_message_iwxxm_details_fk_rejected_message_id FOREIGN KEY (rejected_message_id) REFERENCES public.avidb_rejected_messages(rejected_message_id);


--
-- Name: avidb_rejected_messages avidb_rejected_messages_fkey_format_id; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_messages
    ADD CONSTRAINT avidb_rejected_messages_fkey_format_id FOREIGN KEY (format_id) REFERENCES public.avidb_message_format(format_id);


--
-- Name: FUNCTION get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer); Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT ALL ON FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer) TO avidb_iwxxm;


--
-- Name: FUNCTION update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer); Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT ALL ON FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer) TO avidb_iwxxm;


--
-- Name: TABLE avidb_aerodrome; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_aerodrome TO avidb_ro;


--
-- Name: TABLE avidb_stations; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_stations TO avidb_ro;


--
-- Name: TABLE avidb_aerodrome_iwxxm_metadata; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_aerodrome_iwxxm_metadata TO avidb_ro;


--
-- Name: TABLE avidb_iwxxm; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_iwxxm TO avidb_ro;
GRANT SELECT,UPDATE ON TABLE public.avidb_iwxxm TO avidb_iwxxm;


--
-- Name: TABLE avidb_message_format; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_format TO avidb_ro;


--
-- Name: TABLE avidb_message_iwxxm_details; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details TO avidb_ro;


--
-- Name: TABLE avidb_message_routes; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_routes TO avidb_ro;


--
-- Name: TABLE avidb_message_types; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_types TO avidb_ro;


--
-- Name: TABLE avidb_messages; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages TO avidb_ro;


--
-- Name: TABLE avidb_rejected_message_iwxxm_details; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_rejected_message_iwxxm_details TO avidb_ro;


--
-- Name: TABLE avidb_rejected_messages; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_rejected_messages TO avidb_ro;


--
-- Name: TABLE gt_pk_metadata; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.gt_pk_metadata TO avidb_ro;


--
-- Name: TABLE icao_fir_yhdiste; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.icao_fir_yhdiste TO avidb_ro;


--
-- Name: TABLE icao_fir_yhdistelma; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.icao_fir_yhdistelma TO avidb_ro;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: avidb_rw
--

ALTER DEFAULT PRIVILEGES FOR ROLE avidb_rw IN SCHEMA public GRANT SELECT ON TABLES TO avidb_ro;


--
-- PostgreSQL database dump complete
--

