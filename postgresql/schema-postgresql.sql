--
-- PostgreSQL database dump
--

-- Dumped from database version 14.2
-- Dumped by pg_dump version 14.2

-- Started on 2022-03-15 17:23:15 EET

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

--
-- TOC entry 8 (class 2615 OID 33672)
-- Name: audit; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA audit;


ALTER SCHEMA audit OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 21175)
-- Name: partman; Type: SCHEMA; Schema: -; Owner: avidb_rw
--

CREATE SCHEMA partman;


ALTER SCHEMA partman OWNER TO avidb_rw;

--
-- TOC entry 2 (class 3079 OID 33673)
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- TOC entry 7006 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- TOC entry 3 (class 3079 OID 33801)
-- Name: pg_partman; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_partman WITH SCHEMA partman;


--
-- TOC entry 7007 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION pg_partman; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_partman IS 'Extension to manage partitioned tables by time or ID';


--
-- TOC entry 4 (class 3079 OID 21452)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 7008 (class 0 OID 0)
-- Dependencies: 4
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- TOC entry 1829 (class 1247 OID 33950)
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
-- TOC entry 1148 (class 1255 OID 33961)
-- Name: add_message(character varying, timestamp with time zone, integer, integer, text, timestamp with time zone, timestamp with time zone, timestamp with time zone, integer, text, character varying); Type: FUNCTION; Schema: public; Owner: avidb_rw
--

CREATE FUNCTION public.add_message(in_icao_code character varying, in_message_time timestamp with time zone, in_type_id integer, in_route_id integer, in_message text, in_valid_from timestamp with time zone, in_valid_to timestamp with time zone, in_file_modified timestamp with time zone, in_flag integer, in_messir_heading text, in_version character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  L_STATION_ID integer;
  L_IWXXM_FLAG integer;
  L_IWXXM_FLAG2 integer;
  L_IWXXM_LIPPU integer;
BEGIN
        BEGIN
         SELECT station_id,iwxxm_flag
         INTO L_STATION_ID,L_IWXXM_FLAG
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
    
        IF in_message_time > timezone('UTC',now()) + interval '12 hours' THEN
          INSERT INTO avidb_rejected_messages
          (icao_code,message_time,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,reject_reason,version)
           VALUES
          ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,2,$11);
          RETURN 2;
        END IF;
        INSERT INTO avidb_messages
         (message_time,station_id,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,version)
        VALUES
        ($2,L_STATION_ID,$3,$4,$5,$6,$7,$8,$9,$10,$11);
        
        IF L_IWXXM_LIPPU = 1 THEN
        INSERT INTO avidb_iwxxm
         (message_time,station_id,type_id,route_id,message,valid_from,valid_to,file_modified,flag,messir_heading,version,iwxxm_status)
        VALUES
        ($2,L_STATION_ID,$3,$4,$5,$6,$7,$8,$9,$10,$11,0);
        END IF;
        
        
        RETURN 0;   
END;
$_$;


ALTER FUNCTION public.add_message(in_icao_code character varying, in_message_time timestamp with time zone, in_type_id integer, in_route_id integer, in_message text, in_valid_from timestamp with time zone, in_valid_to timestamp with time zone, in_file_modified timestamp with time zone, in_flag integer, in_messir_heading text, in_version character varying) OWNER TO avidb_rw;

--
-- TOC entry 1152 (class 1255 OID 33963)
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
-- TOC entry 1151 (class 1255 OID 33964)
-- Name: merge_station(character varying, text, double precision, double precision, integer, timestamp without time zone, timestamp without time zone, character varying); Type: FUNCTION; Schema: public; Owner: avidb_rw
--

CREATE FUNCTION public.merge_station(in_icao_code character varying, in_name text, in_lat double precision, in_lon double precision, in_elevation integer, in_valid_from timestamp without time zone DEFAULT timezone('UTC'::text, '1700-01-01 00:00:00+00'::timestamp with time zone), in_valid_to timestamp without time zone DEFAULT timezone('UTC'::text, '9999-12-31 00:00:00+00'::timestamp with time zone), in_country_code character varying DEFAULT 'FI'::character varying) RETURNS void
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
-- TOC entry 1067 (class 1255 OID 32129)
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
-- TOC entry 1153 (class 1255 OID 33965)
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
-- TOC entry 315 (class 1259 OID 27397)
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
-- TOC entry 312 (class 1259 OID 25965)
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
-- TOC entry 336 (class 1259 OID 33966)
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
    valid_from timestamp with time zone DEFAULT timezone('UTC'::text, '1700-01-01 00:00:00+00'::timestamp with time zone) NOT NULL,
    valid_to timestamp with time zone DEFAULT timezone('UTC'::text, '9999-12-31 00:00:00+00'::timestamp with time zone) NOT NULL,
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    CONSTRAINT ck_aerodrome_name CHECK (((aerodrome_name)::text ~ '^([A-Z]|[0-9]|[, !"&#$%''''()*+-\\./:;<=>?@[\\\]^_|{}]){1,60}$'::text)),
    CONSTRAINT ck_iata_code CHECK (((iata_code)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT ck_icao_code CHECK (((icao_code)::text ~ '^[A-Z]{4}$'::text))
);


ALTER TABLE public.avidb_aerodrome OWNER TO avidb_rw;

--
-- TOC entry 337 (class 1259 OID 33977)
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
-- TOC entry 219 (class 1259 OID 22514)
-- Name: avidb_stations; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_stations (
    station_id integer NOT NULL,
    icao_code character varying(4),
    name text,
    geom public.geometry(Point,4326),
    elevation integer,
    valid_from timestamp with time zone DEFAULT timezone('UTC'::text, '1700-01-01 00:00:00+00'::timestamp with time zone),
    valid_to timestamp with time zone DEFAULT timezone('UTC'::text, '9999-12-31 00:00:00+00'::timestamp with time zone),
    modified_last timestamp with time zone DEFAULT timezone('UTC'::text, now()),
    iwxxm_flag integer,
    country_code character varying(2)
);


ALTER TABLE public.avidb_stations OWNER TO avidb_rw;

--
-- TOC entry 338 (class 1259 OID 33978)
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


ALTER TABLE public.avidb_aerodrome_iwxxm_metadata OWNER TO avidb_rw;

--
-- TOC entry 220 (class 1259 OID 22526)
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
-- TOC entry 221 (class 1259 OID 22533)
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
-- TOC entry 222 (class 1259 OID 22534)
-- Name: avidb_message_format; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_format (
    format_id smallint NOT NULL,
    name text,
    modified_last timestamp without time zone
);


ALTER TABLE public.avidb_message_format OWNER TO avidb_rw;

--
-- TOC entry 314 (class 1259 OID 27391)
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
-- TOC entry 313 (class 1259 OID 27390)
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
-- TOC entry 322 (class 1259 OID 32589)
-- Name: avidb_message_iwxxm_details_p0; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_iwxxm_details_p0 (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_message_iwxxm_details_p0 OWNER TO avidb_rw;

--
-- TOC entry 323 (class 1259 OID 32596)
-- Name: avidb_message_iwxxm_details_p10000000; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_iwxxm_details_p10000000 (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_message_iwxxm_details_p10000000 OWNER TO avidb_rw;

--
-- TOC entry 324 (class 1259 OID 32603)
-- Name: avidb_message_iwxxm_details_p20000000; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_iwxxm_details_p20000000 (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_message_iwxxm_details_p20000000 OWNER TO avidb_rw;

--
-- TOC entry 327 (class 1259 OID 32657)
-- Name: avidb_message_iwxxm_details_p30000000; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_iwxxm_details_p30000000 (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_message_iwxxm_details_p30000000 OWNER TO avidb_rw;

--
-- TOC entry 328 (class 1259 OID 32664)
-- Name: avidb_message_iwxxm_details_p40000000; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_iwxxm_details_p40000000 (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_message_iwxxm_details_p40000000 OWNER TO avidb_rw;

--
-- TOC entry 325 (class 1259 OID 32624)
-- Name: avidb_message_iwxxm_details_pdefault; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_message_iwxxm_details_pdefault (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_message_iwxxm_details_pdefault OWNER TO avidb_rw;

--
-- TOC entry 223 (class 1259 OID 22539)
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
-- TOC entry 224 (class 1259 OID 22545)
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
-- TOC entry 311 (class 1259 OID 25959)
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
-- TOC entry 225 (class 1259 OID 22559)
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
-- TOC entry 226 (class 1259 OID 22570)
-- Name: avidb_messages_p2015_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_03 (
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
);


ALTER TABLE public.avidb_messages_p2015_03 OWNER TO avidb_rw;

--
-- TOC entry 227 (class 1259 OID 22580)
-- Name: avidb_messages_p2015_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_04 (
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
);


ALTER TABLE public.avidb_messages_p2015_04 OWNER TO avidb_rw;

--
-- TOC entry 228 (class 1259 OID 22590)
-- Name: avidb_messages_p2015_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_05 (
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
);


ALTER TABLE public.avidb_messages_p2015_05 OWNER TO avidb_rw;

--
-- TOC entry 229 (class 1259 OID 22600)
-- Name: avidb_messages_p2015_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_06 (
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
);


ALTER TABLE public.avidb_messages_p2015_06 OWNER TO avidb_rw;

--
-- TOC entry 230 (class 1259 OID 22610)
-- Name: avidb_messages_p2015_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_07 (
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
);


ALTER TABLE public.avidb_messages_p2015_07 OWNER TO avidb_rw;

--
-- TOC entry 231 (class 1259 OID 22620)
-- Name: avidb_messages_p2015_08; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_08 (
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
);


ALTER TABLE public.avidb_messages_p2015_08 OWNER TO avidb_rw;

--
-- TOC entry 232 (class 1259 OID 22630)
-- Name: avidb_messages_p2015_09; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_09 (
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
);


ALTER TABLE public.avidb_messages_p2015_09 OWNER TO avidb_rw;

--
-- TOC entry 233 (class 1259 OID 22640)
-- Name: avidb_messages_p2015_10; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_10 (
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
);


ALTER TABLE public.avidb_messages_p2015_10 OWNER TO avidb_rw;

--
-- TOC entry 234 (class 1259 OID 22650)
-- Name: avidb_messages_p2015_11; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_11 (
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
);


ALTER TABLE public.avidb_messages_p2015_11 OWNER TO avidb_rw;

--
-- TOC entry 235 (class 1259 OID 22660)
-- Name: avidb_messages_p2015_12; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2015_12 (
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
);


ALTER TABLE public.avidb_messages_p2015_12 OWNER TO avidb_rw;

--
-- TOC entry 236 (class 1259 OID 22670)
-- Name: avidb_messages_p2016_01; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_01 (
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
);


ALTER TABLE public.avidb_messages_p2016_01 OWNER TO avidb_rw;

--
-- TOC entry 237 (class 1259 OID 22680)
-- Name: avidb_messages_p2016_02; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_02 (
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
);


ALTER TABLE public.avidb_messages_p2016_02 OWNER TO avidb_rw;

--
-- TOC entry 238 (class 1259 OID 22690)
-- Name: avidb_messages_p2016_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_03 (
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
);


ALTER TABLE public.avidb_messages_p2016_03 OWNER TO avidb_rw;

--
-- TOC entry 239 (class 1259 OID 22700)
-- Name: avidb_messages_p2016_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_04 (
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
);


ALTER TABLE public.avidb_messages_p2016_04 OWNER TO avidb_rw;

--
-- TOC entry 240 (class 1259 OID 22710)
-- Name: avidb_messages_p2016_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_05 (
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
);


ALTER TABLE public.avidb_messages_p2016_05 OWNER TO avidb_rw;

--
-- TOC entry 241 (class 1259 OID 22720)
-- Name: avidb_messages_p2016_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_06 (
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
);


ALTER TABLE public.avidb_messages_p2016_06 OWNER TO avidb_rw;

--
-- TOC entry 242 (class 1259 OID 22730)
-- Name: avidb_messages_p2016_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_07 (
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
);


ALTER TABLE public.avidb_messages_p2016_07 OWNER TO avidb_rw;

--
-- TOC entry 243 (class 1259 OID 22740)
-- Name: avidb_messages_p2016_08; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_08 (
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
);


ALTER TABLE public.avidb_messages_p2016_08 OWNER TO avidb_rw;

--
-- TOC entry 244 (class 1259 OID 22750)
-- Name: avidb_messages_p2016_09; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_09 (
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
);


ALTER TABLE public.avidb_messages_p2016_09 OWNER TO avidb_rw;

--
-- TOC entry 245 (class 1259 OID 22760)
-- Name: avidb_messages_p2016_10; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_10 (
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
);


ALTER TABLE public.avidb_messages_p2016_10 OWNER TO avidb_rw;

--
-- TOC entry 246 (class 1259 OID 22770)
-- Name: avidb_messages_p2016_11; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_11 (
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
);


ALTER TABLE public.avidb_messages_p2016_11 OWNER TO avidb_rw;

--
-- TOC entry 247 (class 1259 OID 22780)
-- Name: avidb_messages_p2016_12; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2016_12 (
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
);


ALTER TABLE public.avidb_messages_p2016_12 OWNER TO avidb_rw;

--
-- TOC entry 248 (class 1259 OID 22790)
-- Name: avidb_messages_p2017_01; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_01 (
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
);


ALTER TABLE public.avidb_messages_p2017_01 OWNER TO avidb_rw;

--
-- TOC entry 249 (class 1259 OID 22800)
-- Name: avidb_messages_p2017_02; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_02 (
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
);


ALTER TABLE public.avidb_messages_p2017_02 OWNER TO avidb_rw;

--
-- TOC entry 250 (class 1259 OID 22810)
-- Name: avidb_messages_p2017_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_03 (
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
);


ALTER TABLE public.avidb_messages_p2017_03 OWNER TO avidb_rw;

--
-- TOC entry 251 (class 1259 OID 22820)
-- Name: avidb_messages_p2017_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_04 (
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
);


ALTER TABLE public.avidb_messages_p2017_04 OWNER TO avidb_rw;

--
-- TOC entry 252 (class 1259 OID 22830)
-- Name: avidb_messages_p2017_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_05 (
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
);


ALTER TABLE public.avidb_messages_p2017_05 OWNER TO avidb_rw;

--
-- TOC entry 253 (class 1259 OID 22840)
-- Name: avidb_messages_p2017_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_06 (
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
);


ALTER TABLE public.avidb_messages_p2017_06 OWNER TO avidb_rw;

--
-- TOC entry 254 (class 1259 OID 22850)
-- Name: avidb_messages_p2017_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_07 (
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
);


ALTER TABLE public.avidb_messages_p2017_07 OWNER TO avidb_rw;

--
-- TOC entry 255 (class 1259 OID 22860)
-- Name: avidb_messages_p2017_08; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_08 (
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
);


ALTER TABLE public.avidb_messages_p2017_08 OWNER TO avidb_rw;

--
-- TOC entry 256 (class 1259 OID 22870)
-- Name: avidb_messages_p2017_09; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_09 (
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
);


ALTER TABLE public.avidb_messages_p2017_09 OWNER TO avidb_rw;

--
-- TOC entry 257 (class 1259 OID 22880)
-- Name: avidb_messages_p2017_10; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_10 (
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
);


ALTER TABLE public.avidb_messages_p2017_10 OWNER TO avidb_rw;

--
-- TOC entry 258 (class 1259 OID 22890)
-- Name: avidb_messages_p2017_11; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_11 (
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
);


ALTER TABLE public.avidb_messages_p2017_11 OWNER TO avidb_rw;

--
-- TOC entry 259 (class 1259 OID 22900)
-- Name: avidb_messages_p2017_12; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2017_12 (
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
);


ALTER TABLE public.avidb_messages_p2017_12 OWNER TO avidb_rw;

--
-- TOC entry 260 (class 1259 OID 22910)
-- Name: avidb_messages_p2018_01; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_01 (
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
);


ALTER TABLE public.avidb_messages_p2018_01 OWNER TO avidb_rw;

--
-- TOC entry 261 (class 1259 OID 22920)
-- Name: avidb_messages_p2018_02; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_02 (
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
);


ALTER TABLE public.avidb_messages_p2018_02 OWNER TO avidb_rw;

--
-- TOC entry 262 (class 1259 OID 22930)
-- Name: avidb_messages_p2018_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_03 (
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
);


ALTER TABLE public.avidb_messages_p2018_03 OWNER TO avidb_rw;

--
-- TOC entry 263 (class 1259 OID 22940)
-- Name: avidb_messages_p2018_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_04 (
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
);


ALTER TABLE public.avidb_messages_p2018_04 OWNER TO avidb_rw;

--
-- TOC entry 264 (class 1259 OID 22950)
-- Name: avidb_messages_p2018_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_05 (
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
);


ALTER TABLE public.avidb_messages_p2018_05 OWNER TO avidb_rw;

--
-- TOC entry 265 (class 1259 OID 22960)
-- Name: avidb_messages_p2018_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_06 (
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
);


ALTER TABLE public.avidb_messages_p2018_06 OWNER TO avidb_rw;

--
-- TOC entry 266 (class 1259 OID 22970)
-- Name: avidb_messages_p2018_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_07 (
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
);


ALTER TABLE public.avidb_messages_p2018_07 OWNER TO avidb_rw;

--
-- TOC entry 267 (class 1259 OID 22980)
-- Name: avidb_messages_p2018_08; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_08 (
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
);


ALTER TABLE public.avidb_messages_p2018_08 OWNER TO avidb_rw;

--
-- TOC entry 268 (class 1259 OID 22990)
-- Name: avidb_messages_p2018_09; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_09 (
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
);


ALTER TABLE public.avidb_messages_p2018_09 OWNER TO avidb_rw;

--
-- TOC entry 269 (class 1259 OID 23000)
-- Name: avidb_messages_p2018_10; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_10 (
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
);


ALTER TABLE public.avidb_messages_p2018_10 OWNER TO avidb_rw;

--
-- TOC entry 270 (class 1259 OID 23010)
-- Name: avidb_messages_p2018_11; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_11 (
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
);


ALTER TABLE public.avidb_messages_p2018_11 OWNER TO avidb_rw;

--
-- TOC entry 271 (class 1259 OID 23020)
-- Name: avidb_messages_p2018_12; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2018_12 (
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
);


ALTER TABLE public.avidb_messages_p2018_12 OWNER TO avidb_rw;

--
-- TOC entry 272 (class 1259 OID 23030)
-- Name: avidb_messages_p2019_01; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_01 (
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
);


ALTER TABLE public.avidb_messages_p2019_01 OWNER TO avidb_rw;

--
-- TOC entry 273 (class 1259 OID 23040)
-- Name: avidb_messages_p2019_02; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_02 (
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
);


ALTER TABLE public.avidb_messages_p2019_02 OWNER TO avidb_rw;

--
-- TOC entry 274 (class 1259 OID 23050)
-- Name: avidb_messages_p2019_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_03 (
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
);


ALTER TABLE public.avidb_messages_p2019_03 OWNER TO avidb_rw;

--
-- TOC entry 275 (class 1259 OID 23060)
-- Name: avidb_messages_p2019_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_04 (
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
);


ALTER TABLE public.avidb_messages_p2019_04 OWNER TO avidb_rw;

--
-- TOC entry 276 (class 1259 OID 23070)
-- Name: avidb_messages_p2019_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_05 (
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
);


ALTER TABLE public.avidb_messages_p2019_05 OWNER TO avidb_rw;

--
-- TOC entry 277 (class 1259 OID 23080)
-- Name: avidb_messages_p2019_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_06 (
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
);


ALTER TABLE public.avidb_messages_p2019_06 OWNER TO avidb_rw;

--
-- TOC entry 278 (class 1259 OID 23090)
-- Name: avidb_messages_p2019_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_07 (
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
);


ALTER TABLE public.avidb_messages_p2019_07 OWNER TO avidb_rw;

--
-- TOC entry 279 (class 1259 OID 23100)
-- Name: avidb_messages_p2019_08; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_08 (
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
);


ALTER TABLE public.avidb_messages_p2019_08 OWNER TO avidb_rw;

--
-- TOC entry 280 (class 1259 OID 23110)
-- Name: avidb_messages_p2019_09; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_09 (
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
);


ALTER TABLE public.avidb_messages_p2019_09 OWNER TO avidb_rw;

--
-- TOC entry 281 (class 1259 OID 23120)
-- Name: avidb_messages_p2019_10; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_10 (
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
);


ALTER TABLE public.avidb_messages_p2019_10 OWNER TO avidb_rw;

--
-- TOC entry 282 (class 1259 OID 23130)
-- Name: avidb_messages_p2019_11; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_11 (
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
);


ALTER TABLE public.avidb_messages_p2019_11 OWNER TO avidb_rw;

--
-- TOC entry 283 (class 1259 OID 23140)
-- Name: avidb_messages_p2019_12; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2019_12 (
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
);


ALTER TABLE public.avidb_messages_p2019_12 OWNER TO avidb_rw;

--
-- TOC entry 284 (class 1259 OID 23150)
-- Name: avidb_messages_p2020_01; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_01 (
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
);


ALTER TABLE public.avidb_messages_p2020_01 OWNER TO avidb_rw;

--
-- TOC entry 285 (class 1259 OID 23160)
-- Name: avidb_messages_p2020_02; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_02 (
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
);


ALTER TABLE public.avidb_messages_p2020_02 OWNER TO avidb_rw;

--
-- TOC entry 286 (class 1259 OID 23170)
-- Name: avidb_messages_p2020_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_03 (
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
);


ALTER TABLE public.avidb_messages_p2020_03 OWNER TO avidb_rw;

--
-- TOC entry 287 (class 1259 OID 23180)
-- Name: avidb_messages_p2020_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_04 (
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
);


ALTER TABLE public.avidb_messages_p2020_04 OWNER TO avidb_rw;

--
-- TOC entry 288 (class 1259 OID 23190)
-- Name: avidb_messages_p2020_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_05 (
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
);


ALTER TABLE public.avidb_messages_p2020_05 OWNER TO avidb_rw;

--
-- TOC entry 289 (class 1259 OID 23200)
-- Name: avidb_messages_p2020_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_06 (
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
);


ALTER TABLE public.avidb_messages_p2020_06 OWNER TO avidb_rw;

--
-- TOC entry 290 (class 1259 OID 23210)
-- Name: avidb_messages_p2020_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_07 (
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
);


ALTER TABLE public.avidb_messages_p2020_07 OWNER TO avidb_rw;

--
-- TOC entry 291 (class 1259 OID 23220)
-- Name: avidb_messages_p2020_08; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_08 (
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
);


ALTER TABLE public.avidb_messages_p2020_08 OWNER TO avidb_rw;

--
-- TOC entry 292 (class 1259 OID 23230)
-- Name: avidb_messages_p2020_09; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_09 (
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
);


ALTER TABLE public.avidb_messages_p2020_09 OWNER TO avidb_rw;

--
-- TOC entry 293 (class 1259 OID 23240)
-- Name: avidb_messages_p2020_10; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_10 (
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
);


ALTER TABLE public.avidb_messages_p2020_10 OWNER TO avidb_rw;

--
-- TOC entry 294 (class 1259 OID 23250)
-- Name: avidb_messages_p2020_11; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_11 (
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
);


ALTER TABLE public.avidb_messages_p2020_11 OWNER TO avidb_rw;

--
-- TOC entry 295 (class 1259 OID 23260)
-- Name: avidb_messages_p2020_12; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2020_12 (
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
);


ALTER TABLE public.avidb_messages_p2020_12 OWNER TO avidb_rw;

--
-- TOC entry 296 (class 1259 OID 23270)
-- Name: avidb_messages_p2021_01; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_01 (
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
);


ALTER TABLE public.avidb_messages_p2021_01 OWNER TO avidb_rw;

--
-- TOC entry 297 (class 1259 OID 23280)
-- Name: avidb_messages_p2021_02; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_02 (
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
);


ALTER TABLE public.avidb_messages_p2021_02 OWNER TO avidb_rw;

--
-- TOC entry 298 (class 1259 OID 23290)
-- Name: avidb_messages_p2021_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_03 (
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
);


ALTER TABLE public.avidb_messages_p2021_03 OWNER TO avidb_rw;

--
-- TOC entry 299 (class 1259 OID 23300)
-- Name: avidb_messages_p2021_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_04 (
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
);


ALTER TABLE public.avidb_messages_p2021_04 OWNER TO avidb_rw;

--
-- TOC entry 300 (class 1259 OID 23310)
-- Name: avidb_messages_p2021_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_05 (
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
);


ALTER TABLE public.avidb_messages_p2021_05 OWNER TO avidb_rw;

--
-- TOC entry 301 (class 1259 OID 23320)
-- Name: avidb_messages_p2021_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_06 (
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
);


ALTER TABLE public.avidb_messages_p2021_06 OWNER TO avidb_rw;

--
-- TOC entry 302 (class 1259 OID 23330)
-- Name: avidb_messages_p2021_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_07 (
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
);


ALTER TABLE public.avidb_messages_p2021_07 OWNER TO avidb_rw;

--
-- TOC entry 303 (class 1259 OID 23340)
-- Name: avidb_messages_p2021_08; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_08 (
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
);


ALTER TABLE public.avidb_messages_p2021_08 OWNER TO avidb_rw;

--
-- TOC entry 304 (class 1259 OID 23350)
-- Name: avidb_messages_p2021_09; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_09 (
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
);


ALTER TABLE public.avidb_messages_p2021_09 OWNER TO avidb_rw;

--
-- TOC entry 305 (class 1259 OID 23360)
-- Name: avidb_messages_p2021_10; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_10 (
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
);


ALTER TABLE public.avidb_messages_p2021_10 OWNER TO avidb_rw;

--
-- TOC entry 306 (class 1259 OID 23370)
-- Name: avidb_messages_p2021_11; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_11 (
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
);


ALTER TABLE public.avidb_messages_p2021_11 OWNER TO avidb_rw;

--
-- TOC entry 307 (class 1259 OID 23380)
-- Name: avidb_messages_p2021_12; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2021_12 (
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
);


ALTER TABLE public.avidb_messages_p2021_12 OWNER TO avidb_rw;

--
-- TOC entry 308 (class 1259 OID 23390)
-- Name: avidb_messages_p2022_01; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2022_01 (
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
);


ALTER TABLE public.avidb_messages_p2022_01 OWNER TO avidb_rw;

--
-- TOC entry 309 (class 1259 OID 23400)
-- Name: avidb_messages_p2022_02; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2022_02 (
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
);


ALTER TABLE public.avidb_messages_p2022_02 OWNER TO avidb_rw;

--
-- TOC entry 317 (class 1259 OID 28329)
-- Name: avidb_messages_p2022_03; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2022_03 (
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
);


ALTER TABLE public.avidb_messages_p2022_03 OWNER TO avidb_rw;

--
-- TOC entry 318 (class 1259 OID 28354)
-- Name: avidb_messages_p2022_04; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2022_04 (
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
);


ALTER TABLE public.avidb_messages_p2022_04 OWNER TO avidb_rw;

--
-- TOC entry 319 (class 1259 OID 28379)
-- Name: avidb_messages_p2022_05; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2022_05 (
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
);


ALTER TABLE public.avidb_messages_p2022_05 OWNER TO avidb_rw;

--
-- TOC entry 321 (class 1259 OID 32539)
-- Name: avidb_messages_p2022_06; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2022_06 (
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
);


ALTER TABLE public.avidb_messages_p2022_06 OWNER TO avidb_rw;

--
-- TOC entry 326 (class 1259 OID 32631)
-- Name: avidb_messages_p2022_07; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_p2022_07 (
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
);


ALTER TABLE public.avidb_messages_p2022_07 OWNER TO avidb_rw;

--
-- TOC entry 320 (class 1259 OID 32489)
-- Name: avidb_messages_pdefault; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_messages_pdefault (
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
);


ALTER TABLE public.avidb_messages_pdefault OWNER TO avidb_rw;

--
-- TOC entry 316 (class 1259 OID 27451)
-- Name: avidb_rejected_message_iwxxm_details; Type: TABLE; Schema: public; Owner: avidb_rw
--

CREATE TABLE public.avidb_rejected_message_iwxxm_details (
    rejected_message_id bigint NOT NULL,
    collect_identifier text,
    iwxxm_version text
);


ALTER TABLE public.avidb_rejected_message_iwxxm_details OWNER TO avidb_rw;

--
-- TOC entry 330 (class 1259 OID 32712)
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
-- TOC entry 329 (class 1259 OID 32711)
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
-- TOC entry 310 (class 1259 OID 23457)
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
-- TOC entry 339 (class 1259 OID 33982)
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
-- TOC entry 7166 (class 0 OID 0)
-- Dependencies: 339
-- Name: TABLE gt_pk_metadata; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON TABLE public.gt_pk_metadata IS 'GeoServer primary key metadata table. See https://docs.geoserver.org/stable/en/user/data/database/primarykey.html';


--
-- TOC entry 7167 (class 0 OID 0)
-- Dependencies: 339
-- Name: COLUMN gt_pk_metadata.table_schema; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.table_schema IS 'Name of the database schema in which the table is located.';


--
-- TOC entry 7168 (class 0 OID 0)
-- Dependencies: 339
-- Name: COLUMN gt_pk_metadata.table_name; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.table_name IS 'Name of the table to be published.';


--
-- TOC entry 7169 (class 0 OID 0)
-- Dependencies: 339
-- Name: COLUMN gt_pk_metadata.pk_column; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_column IS 'Name of a column used to form the feature IDs.';


--
-- TOC entry 7170 (class 0 OID 0)
-- Dependencies: 339
-- Name: COLUMN gt_pk_metadata.pk_column_idx; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_column_idx IS 'Index of the column in a multi-column key. In case multi column keys are needed multiple records with the same table schema and table name will be used.';


--
-- TOC entry 7171 (class 0 OID 0)
-- Dependencies: 339
-- Name: COLUMN gt_pk_metadata.pk_policy; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_policy IS 'The new value generation policy, used in case a new feature needs to be added in the table (following a WFS-T insert operation).';


--
-- TOC entry 7172 (class 0 OID 0)
-- Dependencies: 339
-- Name: COLUMN gt_pk_metadata.pk_sequence; Type: COMMENT; Schema: public; Owner: avidb_rw
--

COMMENT ON COLUMN public.gt_pk_metadata.pk_sequence IS 'The name of the database sequence to be used when generating a new value for the pk_column.';


--
-- TOC entry 340 (class 1259 OID 33986)
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
-- TOC entry 341 (class 1259 OID 33991)
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
-- TOC entry 342 (class 1259 OID 33992)
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
-- TOC entry 343 (class 1259 OID 33997)
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
-- TOC entry 344 (class 1259 OID 33998)
-- Name: katko; Type: TABLE; Schema: public; Owner: avidb_katkot
--

CREATE TABLE public.katko (
    station character varying(4) NOT NULL,
    messagetype character varying(15) NOT NULL,
    starttime timestamp without time zone NOT NULL,
    endtime timestamp without time zone,
    description character varying(1000)
);


ALTER TABLE public.katko OWNER TO avidb_katkot;

--
-- TOC entry 5705 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p0; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_p0 FOR VALUES FROM ('0') TO ('10000000');


--
-- TOC entry 5706 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p10000000; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_p10000000 FOR VALUES FROM ('10000000') TO ('20000000');


--
-- TOC entry 5707 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p20000000; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_p20000000 FOR VALUES FROM ('20000000') TO ('30000000');


--
-- TOC entry 5710 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p30000000; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_p30000000 FOR VALUES FROM ('30000000') TO ('40000000');


--
-- TOC entry 5711 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p40000000; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_p40000000 FOR VALUES FROM ('40000000') TO ('50000000');


--
-- TOC entry 5708 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_pdefault; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details ATTACH PARTITION public.avidb_message_iwxxm_details_pdefault DEFAULT;


--
-- TOC entry 5616 (class 0 OID 0)
-- Name: avidb_messages_p2015_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_03 FOR VALUES FROM ('2015-03-01 00:00:00+00') TO ('2015-04-01 00:00:00+00');


--
-- TOC entry 5617 (class 0 OID 0)
-- Name: avidb_messages_p2015_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_04 FOR VALUES FROM ('2015-04-01 00:00:00+00') TO ('2015-05-01 00:00:00+00');


--
-- TOC entry 5618 (class 0 OID 0)
-- Name: avidb_messages_p2015_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_05 FOR VALUES FROM ('2015-05-01 00:00:00+00') TO ('2015-06-01 00:00:00+00');


--
-- TOC entry 5619 (class 0 OID 0)
-- Name: avidb_messages_p2015_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_06 FOR VALUES FROM ('2015-06-01 00:00:00+00') TO ('2015-07-01 00:00:00+00');


--
-- TOC entry 5620 (class 0 OID 0)
-- Name: avidb_messages_p2015_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_07 FOR VALUES FROM ('2015-07-01 00:00:00+00') TO ('2015-08-01 00:00:00+00');


--
-- TOC entry 5621 (class 0 OID 0)
-- Name: avidb_messages_p2015_08; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_08 FOR VALUES FROM ('2015-08-01 00:00:00+00') TO ('2015-09-01 00:00:00+00');


--
-- TOC entry 5622 (class 0 OID 0)
-- Name: avidb_messages_p2015_09; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_09 FOR VALUES FROM ('2015-09-01 00:00:00+00') TO ('2015-10-01 00:00:00+00');


--
-- TOC entry 5623 (class 0 OID 0)
-- Name: avidb_messages_p2015_10; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_10 FOR VALUES FROM ('2015-10-01 00:00:00+00') TO ('2015-11-01 00:00:00+00');


--
-- TOC entry 5624 (class 0 OID 0)
-- Name: avidb_messages_p2015_11; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_11 FOR VALUES FROM ('2015-11-01 00:00:00+00') TO ('2015-12-01 00:00:00+00');


--
-- TOC entry 5625 (class 0 OID 0)
-- Name: avidb_messages_p2015_12; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2015_12 FOR VALUES FROM ('2015-12-01 00:00:00+00') TO ('2016-01-01 00:00:00+00');


--
-- TOC entry 5626 (class 0 OID 0)
-- Name: avidb_messages_p2016_01; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_01 FOR VALUES FROM ('2016-01-01 00:00:00+00') TO ('2016-02-01 00:00:00+00');


--
-- TOC entry 5627 (class 0 OID 0)
-- Name: avidb_messages_p2016_02; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_02 FOR VALUES FROM ('2016-02-01 00:00:00+00') TO ('2016-03-01 00:00:00+00');


--
-- TOC entry 5628 (class 0 OID 0)
-- Name: avidb_messages_p2016_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_03 FOR VALUES FROM ('2016-03-01 00:00:00+00') TO ('2016-04-01 00:00:00+00');


--
-- TOC entry 5629 (class 0 OID 0)
-- Name: avidb_messages_p2016_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_04 FOR VALUES FROM ('2016-04-01 00:00:00+00') TO ('2016-05-01 00:00:00+00');


--
-- TOC entry 5630 (class 0 OID 0)
-- Name: avidb_messages_p2016_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_05 FOR VALUES FROM ('2016-05-01 00:00:00+00') TO ('2016-06-01 00:00:00+00');


--
-- TOC entry 5631 (class 0 OID 0)
-- Name: avidb_messages_p2016_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_06 FOR VALUES FROM ('2016-06-01 00:00:00+00') TO ('2016-07-01 00:00:00+00');


--
-- TOC entry 5632 (class 0 OID 0)
-- Name: avidb_messages_p2016_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_07 FOR VALUES FROM ('2016-07-01 00:00:00+00') TO ('2016-08-01 00:00:00+00');


--
-- TOC entry 5633 (class 0 OID 0)
-- Name: avidb_messages_p2016_08; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_08 FOR VALUES FROM ('2016-08-01 00:00:00+00') TO ('2016-09-01 00:00:00+00');


--
-- TOC entry 5634 (class 0 OID 0)
-- Name: avidb_messages_p2016_09; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_09 FOR VALUES FROM ('2016-09-01 00:00:00+00') TO ('2016-10-01 00:00:00+00');


--
-- TOC entry 5635 (class 0 OID 0)
-- Name: avidb_messages_p2016_10; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_10 FOR VALUES FROM ('2016-10-01 00:00:00+00') TO ('2016-11-01 00:00:00+00');


--
-- TOC entry 5636 (class 0 OID 0)
-- Name: avidb_messages_p2016_11; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_11 FOR VALUES FROM ('2016-11-01 00:00:00+00') TO ('2016-12-01 00:00:00+00');


--
-- TOC entry 5637 (class 0 OID 0)
-- Name: avidb_messages_p2016_12; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2016_12 FOR VALUES FROM ('2016-12-01 00:00:00+00') TO ('2017-01-01 00:00:00+00');


--
-- TOC entry 5638 (class 0 OID 0)
-- Name: avidb_messages_p2017_01; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_01 FOR VALUES FROM ('2017-01-01 00:00:00+00') TO ('2017-02-01 00:00:00+00');


--
-- TOC entry 5639 (class 0 OID 0)
-- Name: avidb_messages_p2017_02; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_02 FOR VALUES FROM ('2017-02-01 00:00:00+00') TO ('2017-03-01 00:00:00+00');


--
-- TOC entry 5640 (class 0 OID 0)
-- Name: avidb_messages_p2017_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_03 FOR VALUES FROM ('2017-03-01 00:00:00+00') TO ('2017-04-01 00:00:00+00');


--
-- TOC entry 5641 (class 0 OID 0)
-- Name: avidb_messages_p2017_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_04 FOR VALUES FROM ('2017-04-01 00:00:00+00') TO ('2017-05-01 00:00:00+00');


--
-- TOC entry 5642 (class 0 OID 0)
-- Name: avidb_messages_p2017_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_05 FOR VALUES FROM ('2017-05-01 00:00:00+00') TO ('2017-06-01 00:00:00+00');


--
-- TOC entry 5643 (class 0 OID 0)
-- Name: avidb_messages_p2017_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_06 FOR VALUES FROM ('2017-06-01 00:00:00+00') TO ('2017-07-01 00:00:00+00');


--
-- TOC entry 5644 (class 0 OID 0)
-- Name: avidb_messages_p2017_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_07 FOR VALUES FROM ('2017-07-01 00:00:00+00') TO ('2017-08-01 00:00:00+00');


--
-- TOC entry 5645 (class 0 OID 0)
-- Name: avidb_messages_p2017_08; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_08 FOR VALUES FROM ('2017-08-01 00:00:00+00') TO ('2017-09-01 00:00:00+00');


--
-- TOC entry 5646 (class 0 OID 0)
-- Name: avidb_messages_p2017_09; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_09 FOR VALUES FROM ('2017-09-01 00:00:00+00') TO ('2017-10-01 00:00:00+00');


--
-- TOC entry 5647 (class 0 OID 0)
-- Name: avidb_messages_p2017_10; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_10 FOR VALUES FROM ('2017-10-01 00:00:00+00') TO ('2017-11-01 00:00:00+00');


--
-- TOC entry 5648 (class 0 OID 0)
-- Name: avidb_messages_p2017_11; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_11 FOR VALUES FROM ('2017-11-01 00:00:00+00') TO ('2017-12-01 00:00:00+00');


--
-- TOC entry 5649 (class 0 OID 0)
-- Name: avidb_messages_p2017_12; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2017_12 FOR VALUES FROM ('2017-12-01 00:00:00+00') TO ('2018-01-01 00:00:00+00');


--
-- TOC entry 5650 (class 0 OID 0)
-- Name: avidb_messages_p2018_01; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_01 FOR VALUES FROM ('2018-01-01 00:00:00+00') TO ('2018-02-01 00:00:00+00');


--
-- TOC entry 5651 (class 0 OID 0)
-- Name: avidb_messages_p2018_02; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_02 FOR VALUES FROM ('2018-02-01 00:00:00+00') TO ('2018-03-01 00:00:00+00');


--
-- TOC entry 5652 (class 0 OID 0)
-- Name: avidb_messages_p2018_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_03 FOR VALUES FROM ('2018-03-01 00:00:00+00') TO ('2018-04-01 00:00:00+00');


--
-- TOC entry 5653 (class 0 OID 0)
-- Name: avidb_messages_p2018_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_04 FOR VALUES FROM ('2018-04-01 00:00:00+00') TO ('2018-05-01 00:00:00+00');


--
-- TOC entry 5654 (class 0 OID 0)
-- Name: avidb_messages_p2018_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_05 FOR VALUES FROM ('2018-05-01 00:00:00+00') TO ('2018-06-01 00:00:00+00');


--
-- TOC entry 5655 (class 0 OID 0)
-- Name: avidb_messages_p2018_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_06 FOR VALUES FROM ('2018-06-01 00:00:00+00') TO ('2018-07-01 00:00:00+00');


--
-- TOC entry 5656 (class 0 OID 0)
-- Name: avidb_messages_p2018_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_07 FOR VALUES FROM ('2018-07-01 00:00:00+00') TO ('2018-08-01 00:00:00+00');


--
-- TOC entry 5657 (class 0 OID 0)
-- Name: avidb_messages_p2018_08; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_08 FOR VALUES FROM ('2018-08-01 00:00:00+00') TO ('2018-09-01 00:00:00+00');


--
-- TOC entry 5658 (class 0 OID 0)
-- Name: avidb_messages_p2018_09; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_09 FOR VALUES FROM ('2018-09-01 00:00:00+00') TO ('2018-10-01 00:00:00+00');


--
-- TOC entry 5659 (class 0 OID 0)
-- Name: avidb_messages_p2018_10; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_10 FOR VALUES FROM ('2018-10-01 00:00:00+00') TO ('2018-11-01 00:00:00+00');


--
-- TOC entry 5660 (class 0 OID 0)
-- Name: avidb_messages_p2018_11; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_11 FOR VALUES FROM ('2018-11-01 00:00:00+00') TO ('2018-12-01 00:00:00+00');


--
-- TOC entry 5661 (class 0 OID 0)
-- Name: avidb_messages_p2018_12; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2018_12 FOR VALUES FROM ('2018-12-01 00:00:00+00') TO ('2019-01-01 00:00:00+00');


--
-- TOC entry 5662 (class 0 OID 0)
-- Name: avidb_messages_p2019_01; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_01 FOR VALUES FROM ('2019-01-01 00:00:00+00') TO ('2019-02-01 00:00:00+00');


--
-- TOC entry 5663 (class 0 OID 0)
-- Name: avidb_messages_p2019_02; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_02 FOR VALUES FROM ('2019-02-01 00:00:00+00') TO ('2019-03-01 00:00:00+00');


--
-- TOC entry 5664 (class 0 OID 0)
-- Name: avidb_messages_p2019_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_03 FOR VALUES FROM ('2019-03-01 00:00:00+00') TO ('2019-04-01 00:00:00+00');


--
-- TOC entry 5665 (class 0 OID 0)
-- Name: avidb_messages_p2019_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_04 FOR VALUES FROM ('2019-04-01 00:00:00+00') TO ('2019-05-01 00:00:00+00');


--
-- TOC entry 5666 (class 0 OID 0)
-- Name: avidb_messages_p2019_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_05 FOR VALUES FROM ('2019-05-01 00:00:00+00') TO ('2019-06-01 00:00:00+00');


--
-- TOC entry 5667 (class 0 OID 0)
-- Name: avidb_messages_p2019_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_06 FOR VALUES FROM ('2019-06-01 00:00:00+00') TO ('2019-07-01 00:00:00+00');


--
-- TOC entry 5668 (class 0 OID 0)
-- Name: avidb_messages_p2019_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_07 FOR VALUES FROM ('2019-07-01 00:00:00+00') TO ('2019-08-01 00:00:00+00');


--
-- TOC entry 5669 (class 0 OID 0)
-- Name: avidb_messages_p2019_08; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_08 FOR VALUES FROM ('2019-08-01 00:00:00+00') TO ('2019-09-01 00:00:00+00');


--
-- TOC entry 5670 (class 0 OID 0)
-- Name: avidb_messages_p2019_09; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_09 FOR VALUES FROM ('2019-09-01 00:00:00+00') TO ('2019-10-01 00:00:00+00');


--
-- TOC entry 5671 (class 0 OID 0)
-- Name: avidb_messages_p2019_10; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_10 FOR VALUES FROM ('2019-10-01 00:00:00+00') TO ('2019-11-01 00:00:00+00');


--
-- TOC entry 5672 (class 0 OID 0)
-- Name: avidb_messages_p2019_11; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_11 FOR VALUES FROM ('2019-11-01 00:00:00+00') TO ('2019-12-01 00:00:00+00');


--
-- TOC entry 5673 (class 0 OID 0)
-- Name: avidb_messages_p2019_12; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2019_12 FOR VALUES FROM ('2019-12-01 00:00:00+00') TO ('2020-01-01 00:00:00+00');


--
-- TOC entry 5674 (class 0 OID 0)
-- Name: avidb_messages_p2020_01; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_01 FOR VALUES FROM ('2020-01-01 00:00:00+00') TO ('2020-02-01 00:00:00+00');


--
-- TOC entry 5675 (class 0 OID 0)
-- Name: avidb_messages_p2020_02; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_02 FOR VALUES FROM ('2020-02-01 00:00:00+00') TO ('2020-03-01 00:00:00+00');


--
-- TOC entry 5676 (class 0 OID 0)
-- Name: avidb_messages_p2020_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_03 FOR VALUES FROM ('2020-03-01 00:00:00+00') TO ('2020-04-01 00:00:00+00');


--
-- TOC entry 5677 (class 0 OID 0)
-- Name: avidb_messages_p2020_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_04 FOR VALUES FROM ('2020-04-01 00:00:00+00') TO ('2020-05-01 00:00:00+00');


--
-- TOC entry 5678 (class 0 OID 0)
-- Name: avidb_messages_p2020_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_05 FOR VALUES FROM ('2020-05-01 00:00:00+00') TO ('2020-06-01 00:00:00+00');


--
-- TOC entry 5679 (class 0 OID 0)
-- Name: avidb_messages_p2020_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_06 FOR VALUES FROM ('2020-06-01 00:00:00+00') TO ('2020-07-01 00:00:00+00');


--
-- TOC entry 5680 (class 0 OID 0)
-- Name: avidb_messages_p2020_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_07 FOR VALUES FROM ('2020-07-01 00:00:00+00') TO ('2020-08-01 00:00:00+00');


--
-- TOC entry 5681 (class 0 OID 0)
-- Name: avidb_messages_p2020_08; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_08 FOR VALUES FROM ('2020-08-01 00:00:00+00') TO ('2020-09-01 00:00:00+00');


--
-- TOC entry 5682 (class 0 OID 0)
-- Name: avidb_messages_p2020_09; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_09 FOR VALUES FROM ('2020-09-01 00:00:00+00') TO ('2020-10-01 00:00:00+00');


--
-- TOC entry 5683 (class 0 OID 0)
-- Name: avidb_messages_p2020_10; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_10 FOR VALUES FROM ('2020-10-01 00:00:00+00') TO ('2020-11-01 00:00:00+00');


--
-- TOC entry 5684 (class 0 OID 0)
-- Name: avidb_messages_p2020_11; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_11 FOR VALUES FROM ('2020-11-01 00:00:00+00') TO ('2020-12-01 00:00:00+00');


--
-- TOC entry 5685 (class 0 OID 0)
-- Name: avidb_messages_p2020_12; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2020_12 FOR VALUES FROM ('2020-12-01 00:00:00+00') TO ('2021-01-01 00:00:00+00');


--
-- TOC entry 5686 (class 0 OID 0)
-- Name: avidb_messages_p2021_01; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_01 FOR VALUES FROM ('2021-01-01 00:00:00+00') TO ('2021-02-01 00:00:00+00');


--
-- TOC entry 5687 (class 0 OID 0)
-- Name: avidb_messages_p2021_02; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_02 FOR VALUES FROM ('2021-02-01 00:00:00+00') TO ('2021-03-01 00:00:00+00');


--
-- TOC entry 5688 (class 0 OID 0)
-- Name: avidb_messages_p2021_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_03 FOR VALUES FROM ('2021-03-01 00:00:00+00') TO ('2021-04-01 00:00:00+00');


--
-- TOC entry 5689 (class 0 OID 0)
-- Name: avidb_messages_p2021_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_04 FOR VALUES FROM ('2021-04-01 00:00:00+00') TO ('2021-05-01 00:00:00+00');


--
-- TOC entry 5690 (class 0 OID 0)
-- Name: avidb_messages_p2021_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_05 FOR VALUES FROM ('2021-05-01 00:00:00+00') TO ('2021-06-01 00:00:00+00');


--
-- TOC entry 5691 (class 0 OID 0)
-- Name: avidb_messages_p2021_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_06 FOR VALUES FROM ('2021-06-01 00:00:00+00') TO ('2021-07-01 00:00:00+00');


--
-- TOC entry 5692 (class 0 OID 0)
-- Name: avidb_messages_p2021_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_07 FOR VALUES FROM ('2021-07-01 00:00:00+00') TO ('2021-08-01 00:00:00+00');


--
-- TOC entry 5693 (class 0 OID 0)
-- Name: avidb_messages_p2021_08; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_08 FOR VALUES FROM ('2021-08-01 00:00:00+00') TO ('2021-09-01 00:00:00+00');


--
-- TOC entry 5694 (class 0 OID 0)
-- Name: avidb_messages_p2021_09; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_09 FOR VALUES FROM ('2021-09-01 00:00:00+00') TO ('2021-10-01 00:00:00+00');


--
-- TOC entry 5695 (class 0 OID 0)
-- Name: avidb_messages_p2021_10; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_10 FOR VALUES FROM ('2021-10-01 00:00:00+00') TO ('2021-11-01 00:00:00+00');


--
-- TOC entry 5696 (class 0 OID 0)
-- Name: avidb_messages_p2021_11; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_11 FOR VALUES FROM ('2021-11-01 00:00:00+00') TO ('2021-12-01 00:00:00+00');


--
-- TOC entry 5697 (class 0 OID 0)
-- Name: avidb_messages_p2021_12; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2021_12 FOR VALUES FROM ('2021-12-01 00:00:00+00') TO ('2022-01-01 00:00:00+00');


--
-- TOC entry 5698 (class 0 OID 0)
-- Name: avidb_messages_p2022_01; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2022_01 FOR VALUES FROM ('2022-01-01 00:00:00+00') TO ('2022-02-01 00:00:00+00');


--
-- TOC entry 5699 (class 0 OID 0)
-- Name: avidb_messages_p2022_02; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2022_02 FOR VALUES FROM ('2022-02-01 00:00:00+00') TO ('2022-03-01 00:00:00+00');


--
-- TOC entry 5700 (class 0 OID 0)
-- Name: avidb_messages_p2022_03; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2022_03 FOR VALUES FROM ('2022-03-01 00:00:00+00') TO ('2022-04-01 00:00:00+00');


--
-- TOC entry 5701 (class 0 OID 0)
-- Name: avidb_messages_p2022_04; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2022_04 FOR VALUES FROM ('2022-04-01 00:00:00+00') TO ('2022-05-01 00:00:00+00');


--
-- TOC entry 5702 (class 0 OID 0)
-- Name: avidb_messages_p2022_05; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2022_05 FOR VALUES FROM ('2022-05-01 00:00:00+00') TO ('2022-06-01 00:00:00+00');


--
-- TOC entry 5704 (class 0 OID 0)
-- Name: avidb_messages_p2022_06; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2022_06 FOR VALUES FROM ('2022-06-01 00:00:00+00') TO ('2022-07-01 00:00:00+00');


--
-- TOC entry 5709 (class 0 OID 0)
-- Name: avidb_messages_p2022_07; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_p2022_07 FOR VALUES FROM ('2022-07-01 00:00:00+00') TO ('2022-08-01 00:00:00+00');


--
-- TOC entry 5703 (class 0 OID 0)
-- Name: avidb_messages_pdefault; Type: TABLE ATTACH; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages ATTACH PARTITION public.avidb_messages_pdefault DEFAULT;


--
-- TOC entry 6492 (class 2606 OID 26640)
-- Name: template_public_avidb_messages template_public_avidb_messages_pkey; Type: CONSTRAINT; Schema: partman; Owner: avidb_rw
--

ALTER TABLE ONLY partman.template_public_avidb_messages
    ADD CONSTRAINT template_public_avidb_messages_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6553 (class 2606 OID 34029)
-- Name: avidb_aerodrome avidb_aerodrome_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_aerodrome
    ADD CONSTRAINT avidb_aerodrome_pkey PRIMARY KEY (aerodrome_id);


--
-- TOC entry 6059 (class 2606 OID 23608)
-- Name: avidb_iwxxm avidb_iwxxm_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_pk PRIMARY KEY (message_id);


--
-- TOC entry 6063 (class 2606 OID 23610)
-- Name: avidb_message_format avidb_message_format_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_format
    ADD CONSTRAINT avidb_message_format_pk PRIMARY KEY (format_id);


--
-- TOC entry 6494 (class 2606 OID 27396)
-- Name: avidb_message_iwxxm_details avidb_message_iwxxm_details_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details
    ADD CONSTRAINT avidb_message_iwxxm_details_pkey PRIMARY KEY (id);


--
-- TOC entry 6523 (class 2606 OID 32595)
-- Name: avidb_message_iwxxm_details_p0 avidb_message_iwxxm_details_p0_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details_p0
    ADD CONSTRAINT avidb_message_iwxxm_details_p0_pkey PRIMARY KEY (id);


--
-- TOC entry 6525 (class 2606 OID 32602)
-- Name: avidb_message_iwxxm_details_p10000000 avidb_message_iwxxm_details_p10000000_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details_p10000000
    ADD CONSTRAINT avidb_message_iwxxm_details_p10000000_pkey PRIMARY KEY (id);


--
-- TOC entry 6527 (class 2606 OID 32609)
-- Name: avidb_message_iwxxm_details_p20000000 avidb_message_iwxxm_details_p20000000_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details_p20000000
    ADD CONSTRAINT avidb_message_iwxxm_details_p20000000_pkey PRIMARY KEY (id);


--
-- TOC entry 6536 (class 2606 OID 32663)
-- Name: avidb_message_iwxxm_details_p30000000 avidb_message_iwxxm_details_p30000000_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details_p30000000
    ADD CONSTRAINT avidb_message_iwxxm_details_p30000000_pkey PRIMARY KEY (id);


--
-- TOC entry 6538 (class 2606 OID 32670)
-- Name: avidb_message_iwxxm_details_p40000000 avidb_message_iwxxm_details_p40000000_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details_p40000000
    ADD CONSTRAINT avidb_message_iwxxm_details_p40000000_pkey PRIMARY KEY (id);


--
-- TOC entry 6529 (class 2606 OID 32630)
-- Name: avidb_message_iwxxm_details_pdefault avidb_message_iwxxm_details_pdefault_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_iwxxm_details_pdefault
    ADD CONSTRAINT avidb_message_iwxxm_details_pdefault_pkey PRIMARY KEY (id);


--
-- TOC entry 6065 (class 2606 OID 23612)
-- Name: avidb_message_routes avidb_message_routes_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_routes
    ADD CONSTRAINT avidb_message_routes_pk PRIMARY KEY (route_id);


--
-- TOC entry 6067 (class 2606 OID 23614)
-- Name: avidb_message_types avidb_message_types_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_message_types
    ADD CONSTRAINT avidb_message_types_pk PRIMARY KEY (type_id);


--
-- TOC entry 6071 (class 2606 OID 27971)
-- Name: avidb_messages_p2015_03 avidb_messages_p2015_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_03
    ADD CONSTRAINT avidb_messages_p2015_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6076 (class 2606 OID 27973)
-- Name: avidb_messages_p2015_04 avidb_messages_p2015_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_04
    ADD CONSTRAINT avidb_messages_p2015_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6081 (class 2606 OID 27975)
-- Name: avidb_messages_p2015_05 avidb_messages_p2015_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_05
    ADD CONSTRAINT avidb_messages_p2015_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6086 (class 2606 OID 27977)
-- Name: avidb_messages_p2015_06 avidb_messages_p2015_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_06
    ADD CONSTRAINT avidb_messages_p2015_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6091 (class 2606 OID 27979)
-- Name: avidb_messages_p2015_07 avidb_messages_p2015_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_07
    ADD CONSTRAINT avidb_messages_p2015_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6096 (class 2606 OID 27981)
-- Name: avidb_messages_p2015_08 avidb_messages_p2015_08_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_08
    ADD CONSTRAINT avidb_messages_p2015_08_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6101 (class 2606 OID 27983)
-- Name: avidb_messages_p2015_09 avidb_messages_p2015_09_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_09
    ADD CONSTRAINT avidb_messages_p2015_09_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6106 (class 2606 OID 27985)
-- Name: avidb_messages_p2015_10 avidb_messages_p2015_10_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_10
    ADD CONSTRAINT avidb_messages_p2015_10_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6111 (class 2606 OID 27987)
-- Name: avidb_messages_p2015_11 avidb_messages_p2015_11_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_11
    ADD CONSTRAINT avidb_messages_p2015_11_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6116 (class 2606 OID 27989)
-- Name: avidb_messages_p2015_12 avidb_messages_p2015_12_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2015_12
    ADD CONSTRAINT avidb_messages_p2015_12_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6121 (class 2606 OID 27991)
-- Name: avidb_messages_p2016_01 avidb_messages_p2016_01_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_01
    ADD CONSTRAINT avidb_messages_p2016_01_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6126 (class 2606 OID 27993)
-- Name: avidb_messages_p2016_02 avidb_messages_p2016_02_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_02
    ADD CONSTRAINT avidb_messages_p2016_02_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6131 (class 2606 OID 27995)
-- Name: avidb_messages_p2016_03 avidb_messages_p2016_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_03
    ADD CONSTRAINT avidb_messages_p2016_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6136 (class 2606 OID 27997)
-- Name: avidb_messages_p2016_04 avidb_messages_p2016_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_04
    ADD CONSTRAINT avidb_messages_p2016_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6141 (class 2606 OID 27999)
-- Name: avidb_messages_p2016_05 avidb_messages_p2016_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_05
    ADD CONSTRAINT avidb_messages_p2016_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6146 (class 2606 OID 28001)
-- Name: avidb_messages_p2016_06 avidb_messages_p2016_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_06
    ADD CONSTRAINT avidb_messages_p2016_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6151 (class 2606 OID 28003)
-- Name: avidb_messages_p2016_07 avidb_messages_p2016_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_07
    ADD CONSTRAINT avidb_messages_p2016_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6156 (class 2606 OID 28005)
-- Name: avidb_messages_p2016_08 avidb_messages_p2016_08_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_08
    ADD CONSTRAINT avidb_messages_p2016_08_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6161 (class 2606 OID 28007)
-- Name: avidb_messages_p2016_09 avidb_messages_p2016_09_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_09
    ADD CONSTRAINT avidb_messages_p2016_09_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6166 (class 2606 OID 28009)
-- Name: avidb_messages_p2016_10 avidb_messages_p2016_10_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_10
    ADD CONSTRAINT avidb_messages_p2016_10_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6171 (class 2606 OID 28011)
-- Name: avidb_messages_p2016_11 avidb_messages_p2016_11_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_11
    ADD CONSTRAINT avidb_messages_p2016_11_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6176 (class 2606 OID 28013)
-- Name: avidb_messages_p2016_12 avidb_messages_p2016_12_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2016_12
    ADD CONSTRAINT avidb_messages_p2016_12_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6181 (class 2606 OID 28015)
-- Name: avidb_messages_p2017_01 avidb_messages_p2017_01_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_01
    ADD CONSTRAINT avidb_messages_p2017_01_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6186 (class 2606 OID 28017)
-- Name: avidb_messages_p2017_02 avidb_messages_p2017_02_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_02
    ADD CONSTRAINT avidb_messages_p2017_02_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6191 (class 2606 OID 28019)
-- Name: avidb_messages_p2017_03 avidb_messages_p2017_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_03
    ADD CONSTRAINT avidb_messages_p2017_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6196 (class 2606 OID 28021)
-- Name: avidb_messages_p2017_04 avidb_messages_p2017_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_04
    ADD CONSTRAINT avidb_messages_p2017_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6201 (class 2606 OID 28023)
-- Name: avidb_messages_p2017_05 avidb_messages_p2017_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_05
    ADD CONSTRAINT avidb_messages_p2017_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6206 (class 2606 OID 28025)
-- Name: avidb_messages_p2017_06 avidb_messages_p2017_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_06
    ADD CONSTRAINT avidb_messages_p2017_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6211 (class 2606 OID 28027)
-- Name: avidb_messages_p2017_07 avidb_messages_p2017_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_07
    ADD CONSTRAINT avidb_messages_p2017_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6216 (class 2606 OID 28029)
-- Name: avidb_messages_p2017_08 avidb_messages_p2017_08_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_08
    ADD CONSTRAINT avidb_messages_p2017_08_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6221 (class 2606 OID 28031)
-- Name: avidb_messages_p2017_09 avidb_messages_p2017_09_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_09
    ADD CONSTRAINT avidb_messages_p2017_09_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6226 (class 2606 OID 28033)
-- Name: avidb_messages_p2017_10 avidb_messages_p2017_10_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_10
    ADD CONSTRAINT avidb_messages_p2017_10_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6231 (class 2606 OID 28035)
-- Name: avidb_messages_p2017_11 avidb_messages_p2017_11_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_11
    ADD CONSTRAINT avidb_messages_p2017_11_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6236 (class 2606 OID 28037)
-- Name: avidb_messages_p2017_12 avidb_messages_p2017_12_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2017_12
    ADD CONSTRAINT avidb_messages_p2017_12_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6241 (class 2606 OID 28039)
-- Name: avidb_messages_p2018_01 avidb_messages_p2018_01_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_01
    ADD CONSTRAINT avidb_messages_p2018_01_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6246 (class 2606 OID 28041)
-- Name: avidb_messages_p2018_02 avidb_messages_p2018_02_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_02
    ADD CONSTRAINT avidb_messages_p2018_02_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6251 (class 2606 OID 28043)
-- Name: avidb_messages_p2018_03 avidb_messages_p2018_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_03
    ADD CONSTRAINT avidb_messages_p2018_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6256 (class 2606 OID 28045)
-- Name: avidb_messages_p2018_04 avidb_messages_p2018_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_04
    ADD CONSTRAINT avidb_messages_p2018_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6261 (class 2606 OID 28047)
-- Name: avidb_messages_p2018_05 avidb_messages_p2018_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_05
    ADD CONSTRAINT avidb_messages_p2018_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6266 (class 2606 OID 28049)
-- Name: avidb_messages_p2018_06 avidb_messages_p2018_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_06
    ADD CONSTRAINT avidb_messages_p2018_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6271 (class 2606 OID 28051)
-- Name: avidb_messages_p2018_07 avidb_messages_p2018_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_07
    ADD CONSTRAINT avidb_messages_p2018_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6276 (class 2606 OID 28053)
-- Name: avidb_messages_p2018_08 avidb_messages_p2018_08_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_08
    ADD CONSTRAINT avidb_messages_p2018_08_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6281 (class 2606 OID 28055)
-- Name: avidb_messages_p2018_09 avidb_messages_p2018_09_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_09
    ADD CONSTRAINT avidb_messages_p2018_09_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6286 (class 2606 OID 28057)
-- Name: avidb_messages_p2018_10 avidb_messages_p2018_10_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_10
    ADD CONSTRAINT avidb_messages_p2018_10_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6291 (class 2606 OID 28059)
-- Name: avidb_messages_p2018_11 avidb_messages_p2018_11_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_11
    ADD CONSTRAINT avidb_messages_p2018_11_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6296 (class 2606 OID 28061)
-- Name: avidb_messages_p2018_12 avidb_messages_p2018_12_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2018_12
    ADD CONSTRAINT avidb_messages_p2018_12_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6301 (class 2606 OID 28063)
-- Name: avidb_messages_p2019_01 avidb_messages_p2019_01_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_01
    ADD CONSTRAINT avidb_messages_p2019_01_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6306 (class 2606 OID 28065)
-- Name: avidb_messages_p2019_02 avidb_messages_p2019_02_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_02
    ADD CONSTRAINT avidb_messages_p2019_02_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6311 (class 2606 OID 28067)
-- Name: avidb_messages_p2019_03 avidb_messages_p2019_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_03
    ADD CONSTRAINT avidb_messages_p2019_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6316 (class 2606 OID 28069)
-- Name: avidb_messages_p2019_04 avidb_messages_p2019_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_04
    ADD CONSTRAINT avidb_messages_p2019_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6321 (class 2606 OID 28071)
-- Name: avidb_messages_p2019_05 avidb_messages_p2019_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_05
    ADD CONSTRAINT avidb_messages_p2019_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6326 (class 2606 OID 28073)
-- Name: avidb_messages_p2019_06 avidb_messages_p2019_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_06
    ADD CONSTRAINT avidb_messages_p2019_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6331 (class 2606 OID 28075)
-- Name: avidb_messages_p2019_07 avidb_messages_p2019_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_07
    ADD CONSTRAINT avidb_messages_p2019_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6336 (class 2606 OID 28077)
-- Name: avidb_messages_p2019_08 avidb_messages_p2019_08_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_08
    ADD CONSTRAINT avidb_messages_p2019_08_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6341 (class 2606 OID 28079)
-- Name: avidb_messages_p2019_09 avidb_messages_p2019_09_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_09
    ADD CONSTRAINT avidb_messages_p2019_09_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6346 (class 2606 OID 28081)
-- Name: avidb_messages_p2019_10 avidb_messages_p2019_10_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_10
    ADD CONSTRAINT avidb_messages_p2019_10_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6351 (class 2606 OID 28084)
-- Name: avidb_messages_p2019_11 avidb_messages_p2019_11_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_11
    ADD CONSTRAINT avidb_messages_p2019_11_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6356 (class 2606 OID 28086)
-- Name: avidb_messages_p2019_12 avidb_messages_p2019_12_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2019_12
    ADD CONSTRAINT avidb_messages_p2019_12_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6361 (class 2606 OID 28088)
-- Name: avidb_messages_p2020_01 avidb_messages_p2020_01_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_01
    ADD CONSTRAINT avidb_messages_p2020_01_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6366 (class 2606 OID 28090)
-- Name: avidb_messages_p2020_02 avidb_messages_p2020_02_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_02
    ADD CONSTRAINT avidb_messages_p2020_02_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6371 (class 2606 OID 28092)
-- Name: avidb_messages_p2020_03 avidb_messages_p2020_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_03
    ADD CONSTRAINT avidb_messages_p2020_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6376 (class 2606 OID 28094)
-- Name: avidb_messages_p2020_04 avidb_messages_p2020_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_04
    ADD CONSTRAINT avidb_messages_p2020_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6381 (class 2606 OID 28096)
-- Name: avidb_messages_p2020_05 avidb_messages_p2020_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_05
    ADD CONSTRAINT avidb_messages_p2020_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6386 (class 2606 OID 28098)
-- Name: avidb_messages_p2020_06 avidb_messages_p2020_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_06
    ADD CONSTRAINT avidb_messages_p2020_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6391 (class 2606 OID 28100)
-- Name: avidb_messages_p2020_07 avidb_messages_p2020_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_07
    ADD CONSTRAINT avidb_messages_p2020_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6396 (class 2606 OID 28102)
-- Name: avidb_messages_p2020_08 avidb_messages_p2020_08_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_08
    ADD CONSTRAINT avidb_messages_p2020_08_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6401 (class 2606 OID 28104)
-- Name: avidb_messages_p2020_09 avidb_messages_p2020_09_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_09
    ADD CONSTRAINT avidb_messages_p2020_09_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6406 (class 2606 OID 28106)
-- Name: avidb_messages_p2020_10 avidb_messages_p2020_10_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_10
    ADD CONSTRAINT avidb_messages_p2020_10_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6411 (class 2606 OID 28108)
-- Name: avidb_messages_p2020_11 avidb_messages_p2020_11_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_11
    ADD CONSTRAINT avidb_messages_p2020_11_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6416 (class 2606 OID 28110)
-- Name: avidb_messages_p2020_12 avidb_messages_p2020_12_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2020_12
    ADD CONSTRAINT avidb_messages_p2020_12_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6421 (class 2606 OID 28112)
-- Name: avidb_messages_p2021_01 avidb_messages_p2021_01_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_01
    ADD CONSTRAINT avidb_messages_p2021_01_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6426 (class 2606 OID 28114)
-- Name: avidb_messages_p2021_02 avidb_messages_p2021_02_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_02
    ADD CONSTRAINT avidb_messages_p2021_02_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6431 (class 2606 OID 28116)
-- Name: avidb_messages_p2021_03 avidb_messages_p2021_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_03
    ADD CONSTRAINT avidb_messages_p2021_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6436 (class 2606 OID 28118)
-- Name: avidb_messages_p2021_04 avidb_messages_p2021_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_04
    ADD CONSTRAINT avidb_messages_p2021_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6441 (class 2606 OID 28120)
-- Name: avidb_messages_p2021_05 avidb_messages_p2021_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_05
    ADD CONSTRAINT avidb_messages_p2021_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6446 (class 2606 OID 28122)
-- Name: avidb_messages_p2021_06 avidb_messages_p2021_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_06
    ADD CONSTRAINT avidb_messages_p2021_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6451 (class 2606 OID 28124)
-- Name: avidb_messages_p2021_07 avidb_messages_p2021_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_07
    ADD CONSTRAINT avidb_messages_p2021_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6456 (class 2606 OID 28126)
-- Name: avidb_messages_p2021_08 avidb_messages_p2021_08_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_08
    ADD CONSTRAINT avidb_messages_p2021_08_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6461 (class 2606 OID 28128)
-- Name: avidb_messages_p2021_09 avidb_messages_p2021_09_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_09
    ADD CONSTRAINT avidb_messages_p2021_09_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6466 (class 2606 OID 28130)
-- Name: avidb_messages_p2021_10 avidb_messages_p2021_10_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_10
    ADD CONSTRAINT avidb_messages_p2021_10_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6471 (class 2606 OID 28132)
-- Name: avidb_messages_p2021_11 avidb_messages_p2021_11_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_11
    ADD CONSTRAINT avidb_messages_p2021_11_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6476 (class 2606 OID 28134)
-- Name: avidb_messages_p2021_12 avidb_messages_p2021_12_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_12
    ADD CONSTRAINT avidb_messages_p2021_12_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6481 (class 2606 OID 28136)
-- Name: avidb_messages_p2022_01 avidb_messages_p2022_01_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2022_01
    ADD CONSTRAINT avidb_messages_p2022_01_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6486 (class 2606 OID 28138)
-- Name: avidb_messages_p2022_02 avidb_messages_p2022_02_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2022_02
    ADD CONSTRAINT avidb_messages_p2022_02_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6500 (class 2606 OID 28341)
-- Name: avidb_messages_p2022_03 avidb_messages_p2022_03_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2022_03
    ADD CONSTRAINT avidb_messages_p2022_03_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6505 (class 2606 OID 28366)
-- Name: avidb_messages_p2022_04 avidb_messages_p2022_04_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2022_04
    ADD CONSTRAINT avidb_messages_p2022_04_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6510 (class 2606 OID 28391)
-- Name: avidb_messages_p2022_05 avidb_messages_p2022_05_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2022_05
    ADD CONSTRAINT avidb_messages_p2022_05_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6520 (class 2606 OID 32551)
-- Name: avidb_messages_p2022_06 avidb_messages_p2022_06_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2022_06
    ADD CONSTRAINT avidb_messages_p2022_06_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6533 (class 2606 OID 32643)
-- Name: avidb_messages_p2022_07 avidb_messages_p2022_07_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2022_07
    ADD CONSTRAINT avidb_messages_p2022_07_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6515 (class 2606 OID 32513)
-- Name: avidb_messages_pdefault avidb_messages_pdefault_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_pdefault
    ADD CONSTRAINT avidb_messages_pdefault_pkey PRIMARY KEY (message_id);


--
-- TOC entry 6496 (class 2606 OID 27457)
-- Name: avidb_rejected_message_iwxxm_details avidb_rejected_message_iwxxm_details_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_message_iwxxm_details
    ADD CONSTRAINT avidb_rejected_message_iwxxm_details_pkey PRIMARY KEY (rejected_message_id);


--
-- TOC entry 6541 (class 2606 OID 32722)
-- Name: avidb_rejected_messages avidb_rejected_messages_pkey1; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_messages
    ADD CONSTRAINT avidb_rejected_messages_pkey1 PRIMARY KEY (rejected_message_id);


--
-- TOC entry 6053 (class 2606 OID 32196)
-- Name: avidb_stations avidb_stations_icao_code_key; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_stations
    ADD CONSTRAINT avidb_stations_icao_code_key UNIQUE (icao_code);


--
-- TOC entry 6055 (class 2606 OID 23809)
-- Name: avidb_stations avidb_stations_pk; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_stations
    ADD CONSTRAINT avidb_stations_pk PRIMARY KEY (station_id);


--
-- TOC entry 6557 (class 2606 OID 34031)
-- Name: gt_pk_metadata gt_pk_metadata_table_schema_table_name_pk_column_key; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.gt_pk_metadata
    ADD CONSTRAINT gt_pk_metadata_table_schema_table_name_pk_column_key UNIQUE (table_schema, table_name, pk_column);


--
-- TOC entry 6559 (class 2606 OID 34033)
-- Name: icao_fir_yhdiste icao_fir_yhdiste_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.icao_fir_yhdiste
    ADD CONSTRAINT icao_fir_yhdiste_pkey PRIMARY KEY (gid);


--
-- TOC entry 6561 (class 2606 OID 34035)
-- Name: icao_fir_yhdistelma icao_fir_yhdistelma_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.icao_fir_yhdistelma
    ADD CONSTRAINT icao_fir_yhdistelma_pkey PRIMARY KEY (gid);


--
-- TOC entry 6563 (class 2606 OID 34037)
-- Name: katko katko_pkey; Type: CONSTRAINT; Schema: public; Owner: avidb_katkot
--

ALTER TABLE ONLY public.katko
    ADD CONSTRAINT katko_pkey PRIMARY KEY (station, messagetype, starttime);


--
-- TOC entry 6550 (class 1259 OID 34038)
-- Name: avidb_aerodrome_iata_code_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE UNIQUE INDEX avidb_aerodrome_iata_code_idx ON public.avidb_aerodrome USING btree (iata_code) WHERE (iata_code IS NOT NULL);


--
-- TOC entry 6551 (class 1259 OID 34039)
-- Name: avidb_aerodrome_icao_code_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE UNIQUE INDEX avidb_aerodrome_icao_code_idx ON public.avidb_aerodrome USING btree (icao_code) WHERE (icao_code IS NOT NULL);


--
-- TOC entry 6554 (class 1259 OID 34040)
-- Name: avidb_aerodrome_reference_point_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_aerodrome_reference_point_idx ON public.avidb_aerodrome USING gist (reference_point);


--
-- TOC entry 6555 (class 1259 OID 34041)
-- Name: avidb_aerodrome_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE UNIQUE INDEX avidb_aerodrome_station_id_idx ON public.avidb_aerodrome USING btree (station_id) WHERE (icao_code IS NOT NULL);


--
-- TOC entry 6056 (class 1259 OID 23822)
-- Name: avidb_iwxxm_cr_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_cr_idx ON public.avidb_iwxxm USING btree (created);


--
-- TOC entry 6057 (class 1259 OID 23823)
-- Name: avidb_iwxxm_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_idx ON public.avidb_iwxxm USING btree (message_time, type_id, station_id);


--
-- TOC entry 6060 (class 1259 OID 23824)
-- Name: avidb_iwxxm_st_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_st_idx ON public.avidb_iwxxm USING btree (station_id);


--
-- TOC entry 6061 (class 1259 OID 23825)
-- Name: avidb_iwxxm_status; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_iwxxm_status ON public.avidb_iwxxm USING btree (iwxxm_status);


--
-- TOC entry 6488 (class 1259 OID 25973)
-- Name: avidb_messages_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_created_idx ON ONLY public.avidb_messages USING btree (created);


--
-- TOC entry 6489 (class 1259 OID 25974)
-- Name: avidb_messages_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_idx ON ONLY public.avidb_messages USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6068 (class 1259 OID 23831)
-- Name: avidb_messages_p2015_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_03_created_idx ON public.avidb_messages_p2015_03 USING btree (created);


--
-- TOC entry 6069 (class 1259 OID 23832)
-- Name: avidb_messages_p2015_03_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_03_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6490 (class 1259 OID 25975)
-- Name: avidb_messages_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_station_id_idx ON ONLY public.avidb_messages USING btree (station_id);


--
-- TOC entry 6072 (class 1259 OID 23833)
-- Name: avidb_messages_p2015_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_03_station_id_idx ON public.avidb_messages_p2015_03 USING btree (station_id);


--
-- TOC entry 6073 (class 1259 OID 23834)
-- Name: avidb_messages_p2015_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_04_created_idx ON public.avidb_messages_p2015_04 USING btree (created);


--
-- TOC entry 6074 (class 1259 OID 23835)
-- Name: avidb_messages_p2015_04_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_04_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6077 (class 1259 OID 23836)
-- Name: avidb_messages_p2015_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_04_station_id_idx ON public.avidb_messages_p2015_04 USING btree (station_id);


--
-- TOC entry 6078 (class 1259 OID 23837)
-- Name: avidb_messages_p2015_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_05_created_idx ON public.avidb_messages_p2015_05 USING btree (created);


--
-- TOC entry 6079 (class 1259 OID 23838)
-- Name: avidb_messages_p2015_05_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_05_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6082 (class 1259 OID 23839)
-- Name: avidb_messages_p2015_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_05_station_id_idx ON public.avidb_messages_p2015_05 USING btree (station_id);


--
-- TOC entry 6083 (class 1259 OID 23840)
-- Name: avidb_messages_p2015_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_06_created_idx ON public.avidb_messages_p2015_06 USING btree (created);


--
-- TOC entry 6084 (class 1259 OID 23841)
-- Name: avidb_messages_p2015_06_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_06_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6087 (class 1259 OID 23842)
-- Name: avidb_messages_p2015_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_06_station_id_idx ON public.avidb_messages_p2015_06 USING btree (station_id);


--
-- TOC entry 6088 (class 1259 OID 23843)
-- Name: avidb_messages_p2015_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_07_created_idx ON public.avidb_messages_p2015_07 USING btree (created);


--
-- TOC entry 6089 (class 1259 OID 23844)
-- Name: avidb_messages_p2015_07_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_07_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6092 (class 1259 OID 23845)
-- Name: avidb_messages_p2015_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_07_station_id_idx ON public.avidb_messages_p2015_07 USING btree (station_id);


--
-- TOC entry 6093 (class 1259 OID 23846)
-- Name: avidb_messages_p2015_08_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_08_created_idx ON public.avidb_messages_p2015_08 USING btree (created);


--
-- TOC entry 6094 (class 1259 OID 23847)
-- Name: avidb_messages_p2015_08_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_08_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_08 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6097 (class 1259 OID 23848)
-- Name: avidb_messages_p2015_08_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_08_station_id_idx ON public.avidb_messages_p2015_08 USING btree (station_id);


--
-- TOC entry 6098 (class 1259 OID 23849)
-- Name: avidb_messages_p2015_09_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_09_created_idx ON public.avidb_messages_p2015_09 USING btree (created);


--
-- TOC entry 6099 (class 1259 OID 23850)
-- Name: avidb_messages_p2015_09_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_09_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_09 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6102 (class 1259 OID 23851)
-- Name: avidb_messages_p2015_09_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_09_station_id_idx ON public.avidb_messages_p2015_09 USING btree (station_id);


--
-- TOC entry 6103 (class 1259 OID 23852)
-- Name: avidb_messages_p2015_10_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_10_created_idx ON public.avidb_messages_p2015_10 USING btree (created);


--
-- TOC entry 6104 (class 1259 OID 23853)
-- Name: avidb_messages_p2015_10_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_10_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_10 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6107 (class 1259 OID 23854)
-- Name: avidb_messages_p2015_10_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_10_station_id_idx ON public.avidb_messages_p2015_10 USING btree (station_id);


--
-- TOC entry 6108 (class 1259 OID 23856)
-- Name: avidb_messages_p2015_11_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_11_created_idx ON public.avidb_messages_p2015_11 USING btree (created);


--
-- TOC entry 6109 (class 1259 OID 23857)
-- Name: avidb_messages_p2015_11_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_11_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_11 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6112 (class 1259 OID 23858)
-- Name: avidb_messages_p2015_11_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_11_station_id_idx ON public.avidb_messages_p2015_11 USING btree (station_id);


--
-- TOC entry 6113 (class 1259 OID 23860)
-- Name: avidb_messages_p2015_12_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_12_created_idx ON public.avidb_messages_p2015_12 USING btree (created);


--
-- TOC entry 6114 (class 1259 OID 23861)
-- Name: avidb_messages_p2015_12_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_12_message_time_type_id_station_id_idx ON public.avidb_messages_p2015_12 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6117 (class 1259 OID 23862)
-- Name: avidb_messages_p2015_12_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2015_12_station_id_idx ON public.avidb_messages_p2015_12 USING btree (station_id);


--
-- TOC entry 6118 (class 1259 OID 23863)
-- Name: avidb_messages_p2016_01_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_01_created_idx ON public.avidb_messages_p2016_01 USING btree (created);


--
-- TOC entry 6119 (class 1259 OID 23864)
-- Name: avidb_messages_p2016_01_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_01_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_01 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6122 (class 1259 OID 23865)
-- Name: avidb_messages_p2016_01_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_01_station_id_idx ON public.avidb_messages_p2016_01 USING btree (station_id);


--
-- TOC entry 6123 (class 1259 OID 23866)
-- Name: avidb_messages_p2016_02_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_02_created_idx ON public.avidb_messages_p2016_02 USING btree (created);


--
-- TOC entry 6124 (class 1259 OID 23867)
-- Name: avidb_messages_p2016_02_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_02_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_02 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6127 (class 1259 OID 23868)
-- Name: avidb_messages_p2016_02_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_02_station_id_idx ON public.avidb_messages_p2016_02 USING btree (station_id);


--
-- TOC entry 6128 (class 1259 OID 23869)
-- Name: avidb_messages_p2016_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_03_created_idx ON public.avidb_messages_p2016_03 USING btree (created);


--
-- TOC entry 6129 (class 1259 OID 23870)
-- Name: avidb_messages_p2016_03_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_03_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6132 (class 1259 OID 23871)
-- Name: avidb_messages_p2016_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_03_station_id_idx ON public.avidb_messages_p2016_03 USING btree (station_id);


--
-- TOC entry 6133 (class 1259 OID 23872)
-- Name: avidb_messages_p2016_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_04_created_idx ON public.avidb_messages_p2016_04 USING btree (created);


--
-- TOC entry 6134 (class 1259 OID 23873)
-- Name: avidb_messages_p2016_04_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_04_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6137 (class 1259 OID 23874)
-- Name: avidb_messages_p2016_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_04_station_id_idx ON public.avidb_messages_p2016_04 USING btree (station_id);


--
-- TOC entry 6138 (class 1259 OID 23875)
-- Name: avidb_messages_p2016_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_05_created_idx ON public.avidb_messages_p2016_05 USING btree (created);


--
-- TOC entry 6139 (class 1259 OID 23876)
-- Name: avidb_messages_p2016_05_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_05_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6142 (class 1259 OID 23877)
-- Name: avidb_messages_p2016_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_05_station_id_idx ON public.avidb_messages_p2016_05 USING btree (station_id);


--
-- TOC entry 6143 (class 1259 OID 23878)
-- Name: avidb_messages_p2016_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_06_created_idx ON public.avidb_messages_p2016_06 USING btree (created);


--
-- TOC entry 6144 (class 1259 OID 23879)
-- Name: avidb_messages_p2016_06_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_06_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6147 (class 1259 OID 23880)
-- Name: avidb_messages_p2016_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_06_station_id_idx ON public.avidb_messages_p2016_06 USING btree (station_id);


--
-- TOC entry 6148 (class 1259 OID 23881)
-- Name: avidb_messages_p2016_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_07_created_idx ON public.avidb_messages_p2016_07 USING btree (created);


--
-- TOC entry 6149 (class 1259 OID 23882)
-- Name: avidb_messages_p2016_07_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_07_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6152 (class 1259 OID 23883)
-- Name: avidb_messages_p2016_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_07_station_id_idx ON public.avidb_messages_p2016_07 USING btree (station_id);


--
-- TOC entry 6153 (class 1259 OID 23884)
-- Name: avidb_messages_p2016_08_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_08_created_idx ON public.avidb_messages_p2016_08 USING btree (created);


--
-- TOC entry 6154 (class 1259 OID 23886)
-- Name: avidb_messages_p2016_08_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_08_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_08 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6157 (class 1259 OID 23887)
-- Name: avidb_messages_p2016_08_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_08_station_id_idx ON public.avidb_messages_p2016_08 USING btree (station_id);


--
-- TOC entry 6158 (class 1259 OID 23888)
-- Name: avidb_messages_p2016_09_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_09_created_idx ON public.avidb_messages_p2016_09 USING btree (created);


--
-- TOC entry 6159 (class 1259 OID 23889)
-- Name: avidb_messages_p2016_09_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_09_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_09 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6162 (class 1259 OID 23890)
-- Name: avidb_messages_p2016_09_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_09_station_id_idx ON public.avidb_messages_p2016_09 USING btree (station_id);


--
-- TOC entry 6163 (class 1259 OID 23891)
-- Name: avidb_messages_p2016_10_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_10_created_idx ON public.avidb_messages_p2016_10 USING btree (created);


--
-- TOC entry 6164 (class 1259 OID 23892)
-- Name: avidb_messages_p2016_10_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_10_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_10 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6167 (class 1259 OID 23893)
-- Name: avidb_messages_p2016_10_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_10_station_id_idx ON public.avidb_messages_p2016_10 USING btree (station_id);


--
-- TOC entry 6168 (class 1259 OID 23894)
-- Name: avidb_messages_p2016_11_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_11_created_idx ON public.avidb_messages_p2016_11 USING btree (created);


--
-- TOC entry 6169 (class 1259 OID 23895)
-- Name: avidb_messages_p2016_11_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_11_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_11 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6172 (class 1259 OID 23896)
-- Name: avidb_messages_p2016_11_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_11_station_id_idx ON public.avidb_messages_p2016_11 USING btree (station_id);


--
-- TOC entry 6173 (class 1259 OID 23897)
-- Name: avidb_messages_p2016_12_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_12_created_idx ON public.avidb_messages_p2016_12 USING btree (created);


--
-- TOC entry 6174 (class 1259 OID 23898)
-- Name: avidb_messages_p2016_12_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_12_message_time_type_id_station_id_idx ON public.avidb_messages_p2016_12 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6177 (class 1259 OID 23899)
-- Name: avidb_messages_p2016_12_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2016_12_station_id_idx ON public.avidb_messages_p2016_12 USING btree (station_id);


--
-- TOC entry 6178 (class 1259 OID 23900)
-- Name: avidb_messages_p2017_01_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_01_created_idx ON public.avidb_messages_p2017_01 USING btree (created);


--
-- TOC entry 6179 (class 1259 OID 23901)
-- Name: avidb_messages_p2017_01_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_01_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_01 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6182 (class 1259 OID 23902)
-- Name: avidb_messages_p2017_01_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_01_station_id_idx ON public.avidb_messages_p2017_01 USING btree (station_id);


--
-- TOC entry 6183 (class 1259 OID 23903)
-- Name: avidb_messages_p2017_02_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_02_created_idx ON public.avidb_messages_p2017_02 USING btree (created);


--
-- TOC entry 6184 (class 1259 OID 23904)
-- Name: avidb_messages_p2017_02_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_02_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_02 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6187 (class 1259 OID 23905)
-- Name: avidb_messages_p2017_02_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_02_station_id_idx ON public.avidb_messages_p2017_02 USING btree (station_id);


--
-- TOC entry 6188 (class 1259 OID 23906)
-- Name: avidb_messages_p2017_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_03_created_idx ON public.avidb_messages_p2017_03 USING btree (created);


--
-- TOC entry 6189 (class 1259 OID 23907)
-- Name: avidb_messages_p2017_03_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_03_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6192 (class 1259 OID 23908)
-- Name: avidb_messages_p2017_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_03_station_id_idx ON public.avidb_messages_p2017_03 USING btree (station_id);


--
-- TOC entry 6193 (class 1259 OID 23909)
-- Name: avidb_messages_p2017_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_04_created_idx ON public.avidb_messages_p2017_04 USING btree (created);


--
-- TOC entry 6194 (class 1259 OID 23911)
-- Name: avidb_messages_p2017_04_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_04_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6197 (class 1259 OID 23912)
-- Name: avidb_messages_p2017_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_04_station_id_idx ON public.avidb_messages_p2017_04 USING btree (station_id);


--
-- TOC entry 6198 (class 1259 OID 23914)
-- Name: avidb_messages_p2017_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_05_created_idx ON public.avidb_messages_p2017_05 USING btree (created);


--
-- TOC entry 6199 (class 1259 OID 23915)
-- Name: avidb_messages_p2017_05_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_05_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6202 (class 1259 OID 23916)
-- Name: avidb_messages_p2017_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_05_station_id_idx ON public.avidb_messages_p2017_05 USING btree (station_id);


--
-- TOC entry 6203 (class 1259 OID 23917)
-- Name: avidb_messages_p2017_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_06_created_idx ON public.avidb_messages_p2017_06 USING btree (created);


--
-- TOC entry 6204 (class 1259 OID 23918)
-- Name: avidb_messages_p2017_06_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_06_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6207 (class 1259 OID 23919)
-- Name: avidb_messages_p2017_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_06_station_id_idx ON public.avidb_messages_p2017_06 USING btree (station_id);


--
-- TOC entry 6208 (class 1259 OID 23920)
-- Name: avidb_messages_p2017_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_07_created_idx ON public.avidb_messages_p2017_07 USING btree (created);


--
-- TOC entry 6209 (class 1259 OID 23921)
-- Name: avidb_messages_p2017_07_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_07_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6212 (class 1259 OID 23922)
-- Name: avidb_messages_p2017_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_07_station_id_idx ON public.avidb_messages_p2017_07 USING btree (station_id);


--
-- TOC entry 6213 (class 1259 OID 23923)
-- Name: avidb_messages_p2017_08_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_08_created_idx ON public.avidb_messages_p2017_08 USING btree (created);


--
-- TOC entry 6214 (class 1259 OID 23924)
-- Name: avidb_messages_p2017_08_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_08_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_08 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6217 (class 1259 OID 23925)
-- Name: avidb_messages_p2017_08_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_08_station_id_idx ON public.avidb_messages_p2017_08 USING btree (station_id);


--
-- TOC entry 6218 (class 1259 OID 23926)
-- Name: avidb_messages_p2017_09_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_09_created_idx ON public.avidb_messages_p2017_09 USING btree (created);


--
-- TOC entry 6219 (class 1259 OID 23927)
-- Name: avidb_messages_p2017_09_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_09_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_09 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6222 (class 1259 OID 23928)
-- Name: avidb_messages_p2017_09_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_09_station_id_idx ON public.avidb_messages_p2017_09 USING btree (station_id);


--
-- TOC entry 6223 (class 1259 OID 23929)
-- Name: avidb_messages_p2017_10_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_10_created_idx ON public.avidb_messages_p2017_10 USING btree (created);


--
-- TOC entry 6224 (class 1259 OID 23931)
-- Name: avidb_messages_p2017_10_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_10_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_10 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6227 (class 1259 OID 23932)
-- Name: avidb_messages_p2017_10_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_10_station_id_idx ON public.avidb_messages_p2017_10 USING btree (station_id);


--
-- TOC entry 6228 (class 1259 OID 23933)
-- Name: avidb_messages_p2017_11_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_11_created_idx ON public.avidb_messages_p2017_11 USING btree (created);


--
-- TOC entry 6229 (class 1259 OID 23934)
-- Name: avidb_messages_p2017_11_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_11_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_11 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6232 (class 1259 OID 23935)
-- Name: avidb_messages_p2017_11_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_11_station_id_idx ON public.avidb_messages_p2017_11 USING btree (station_id);


--
-- TOC entry 6233 (class 1259 OID 23936)
-- Name: avidb_messages_p2017_12_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_12_created_idx ON public.avidb_messages_p2017_12 USING btree (created);


--
-- TOC entry 6234 (class 1259 OID 23937)
-- Name: avidb_messages_p2017_12_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_12_message_time_type_id_station_id_idx ON public.avidb_messages_p2017_12 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6237 (class 1259 OID 23938)
-- Name: avidb_messages_p2017_12_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2017_12_station_id_idx ON public.avidb_messages_p2017_12 USING btree (station_id);


--
-- TOC entry 6238 (class 1259 OID 23939)
-- Name: avidb_messages_p2018_01_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_01_created_idx ON public.avidb_messages_p2018_01 USING btree (created);


--
-- TOC entry 6239 (class 1259 OID 23940)
-- Name: avidb_messages_p2018_01_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_01_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_01 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6242 (class 1259 OID 23941)
-- Name: avidb_messages_p2018_01_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_01_station_id_idx ON public.avidb_messages_p2018_01 USING btree (station_id);


--
-- TOC entry 6243 (class 1259 OID 23942)
-- Name: avidb_messages_p2018_02_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_02_created_idx ON public.avidb_messages_p2018_02 USING btree (created);


--
-- TOC entry 6244 (class 1259 OID 23943)
-- Name: avidb_messages_p2018_02_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_02_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_02 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6247 (class 1259 OID 23944)
-- Name: avidb_messages_p2018_02_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_02_station_id_idx ON public.avidb_messages_p2018_02 USING btree (station_id);


--
-- TOC entry 6248 (class 1259 OID 23945)
-- Name: avidb_messages_p2018_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_03_created_idx ON public.avidb_messages_p2018_03 USING btree (created);


--
-- TOC entry 6249 (class 1259 OID 23946)
-- Name: avidb_messages_p2018_03_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_03_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6252 (class 1259 OID 23947)
-- Name: avidb_messages_p2018_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_03_station_id_idx ON public.avidb_messages_p2018_03 USING btree (station_id);


--
-- TOC entry 6253 (class 1259 OID 23948)
-- Name: avidb_messages_p2018_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_04_created_idx ON public.avidb_messages_p2018_04 USING btree (created);


--
-- TOC entry 6254 (class 1259 OID 23949)
-- Name: avidb_messages_p2018_04_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_04_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6257 (class 1259 OID 23950)
-- Name: avidb_messages_p2018_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_04_station_id_idx ON public.avidb_messages_p2018_04 USING btree (station_id);


--
-- TOC entry 6258 (class 1259 OID 23951)
-- Name: avidb_messages_p2018_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_05_created_idx ON public.avidb_messages_p2018_05 USING btree (created);


--
-- TOC entry 6259 (class 1259 OID 23952)
-- Name: avidb_messages_p2018_05_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_05_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6262 (class 1259 OID 23953)
-- Name: avidb_messages_p2018_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_05_station_id_idx ON public.avidb_messages_p2018_05 USING btree (station_id);


--
-- TOC entry 6263 (class 1259 OID 23954)
-- Name: avidb_messages_p2018_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_06_created_idx ON public.avidb_messages_p2018_06 USING btree (created);


--
-- TOC entry 6264 (class 1259 OID 23955)
-- Name: avidb_messages_p2018_06_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_06_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6267 (class 1259 OID 23956)
-- Name: avidb_messages_p2018_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_06_station_id_idx ON public.avidb_messages_p2018_06 USING btree (station_id);


--
-- TOC entry 6268 (class 1259 OID 23957)
-- Name: avidb_messages_p2018_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_07_created_idx ON public.avidb_messages_p2018_07 USING btree (created);


--
-- TOC entry 6269 (class 1259 OID 23958)
-- Name: avidb_messages_p2018_07_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_07_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6272 (class 1259 OID 23959)
-- Name: avidb_messages_p2018_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_07_station_id_idx ON public.avidb_messages_p2018_07 USING btree (station_id);


--
-- TOC entry 6273 (class 1259 OID 23960)
-- Name: avidb_messages_p2018_08_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_08_created_idx ON public.avidb_messages_p2018_08 USING btree (created);


--
-- TOC entry 6274 (class 1259 OID 23961)
-- Name: avidb_messages_p2018_08_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_08_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_08 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6277 (class 1259 OID 23962)
-- Name: avidb_messages_p2018_08_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_08_station_id_idx ON public.avidb_messages_p2018_08 USING btree (station_id);


--
-- TOC entry 6278 (class 1259 OID 23964)
-- Name: avidb_messages_p2018_09_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_09_created_idx ON public.avidb_messages_p2018_09 USING btree (created);


--
-- TOC entry 6279 (class 1259 OID 23965)
-- Name: avidb_messages_p2018_09_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_09_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_09 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6282 (class 1259 OID 23967)
-- Name: avidb_messages_p2018_09_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_09_station_id_idx ON public.avidb_messages_p2018_09 USING btree (station_id);


--
-- TOC entry 6283 (class 1259 OID 23968)
-- Name: avidb_messages_p2018_10_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_10_created_idx ON public.avidb_messages_p2018_10 USING btree (created);


--
-- TOC entry 6284 (class 1259 OID 23969)
-- Name: avidb_messages_p2018_10_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_10_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_10 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6287 (class 1259 OID 23970)
-- Name: avidb_messages_p2018_10_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_10_station_id_idx ON public.avidb_messages_p2018_10 USING btree (station_id);


--
-- TOC entry 6288 (class 1259 OID 23971)
-- Name: avidb_messages_p2018_11_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_11_created_idx ON public.avidb_messages_p2018_11 USING btree (created);


--
-- TOC entry 6289 (class 1259 OID 23972)
-- Name: avidb_messages_p2018_11_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_11_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_11 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6292 (class 1259 OID 23973)
-- Name: avidb_messages_p2018_11_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_11_station_id_idx ON public.avidb_messages_p2018_11 USING btree (station_id);


--
-- TOC entry 6293 (class 1259 OID 23974)
-- Name: avidb_messages_p2018_12_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_12_created_idx ON public.avidb_messages_p2018_12 USING btree (created);


--
-- TOC entry 6294 (class 1259 OID 23975)
-- Name: avidb_messages_p2018_12_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_12_message_time_type_id_station_id_idx ON public.avidb_messages_p2018_12 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6297 (class 1259 OID 23976)
-- Name: avidb_messages_p2018_12_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2018_12_station_id_idx ON public.avidb_messages_p2018_12 USING btree (station_id);


--
-- TOC entry 6298 (class 1259 OID 23977)
-- Name: avidb_messages_p2019_01_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_01_created_idx ON public.avidb_messages_p2019_01 USING btree (created);


--
-- TOC entry 6299 (class 1259 OID 23978)
-- Name: avidb_messages_p2019_01_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_01_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_01 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6302 (class 1259 OID 23979)
-- Name: avidb_messages_p2019_01_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_01_station_id_idx ON public.avidb_messages_p2019_01 USING btree (station_id);


--
-- TOC entry 6303 (class 1259 OID 23980)
-- Name: avidb_messages_p2019_02_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_02_created_idx ON public.avidb_messages_p2019_02 USING btree (created);


--
-- TOC entry 6304 (class 1259 OID 23981)
-- Name: avidb_messages_p2019_02_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_02_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_02 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6307 (class 1259 OID 23983)
-- Name: avidb_messages_p2019_02_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_02_station_id_idx ON public.avidb_messages_p2019_02 USING btree (station_id);


--
-- TOC entry 6308 (class 1259 OID 23984)
-- Name: avidb_messages_p2019_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_03_created_idx ON public.avidb_messages_p2019_03 USING btree (created);


--
-- TOC entry 6309 (class 1259 OID 23985)
-- Name: avidb_messages_p2019_03_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_03_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6312 (class 1259 OID 23986)
-- Name: avidb_messages_p2019_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_03_station_id_idx ON public.avidb_messages_p2019_03 USING btree (station_id);


--
-- TOC entry 6313 (class 1259 OID 23987)
-- Name: avidb_messages_p2019_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_04_created_idx ON public.avidb_messages_p2019_04 USING btree (created);


--
-- TOC entry 6314 (class 1259 OID 23988)
-- Name: avidb_messages_p2019_04_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_04_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6317 (class 1259 OID 23989)
-- Name: avidb_messages_p2019_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_04_station_id_idx ON public.avidb_messages_p2019_04 USING btree (station_id);


--
-- TOC entry 6318 (class 1259 OID 23990)
-- Name: avidb_messages_p2019_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_05_created_idx ON public.avidb_messages_p2019_05 USING btree (created);


--
-- TOC entry 6319 (class 1259 OID 23991)
-- Name: avidb_messages_p2019_05_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_05_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6322 (class 1259 OID 23992)
-- Name: avidb_messages_p2019_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_05_station_id_idx ON public.avidb_messages_p2019_05 USING btree (station_id);


--
-- TOC entry 6323 (class 1259 OID 23993)
-- Name: avidb_messages_p2019_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_06_created_idx ON public.avidb_messages_p2019_06 USING btree (created);


--
-- TOC entry 6324 (class 1259 OID 23994)
-- Name: avidb_messages_p2019_06_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_06_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6327 (class 1259 OID 23995)
-- Name: avidb_messages_p2019_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_06_station_id_idx ON public.avidb_messages_p2019_06 USING btree (station_id);


--
-- TOC entry 6328 (class 1259 OID 23996)
-- Name: avidb_messages_p2019_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_07_created_idx ON public.avidb_messages_p2019_07 USING btree (created);


--
-- TOC entry 6329 (class 1259 OID 23997)
-- Name: avidb_messages_p2019_07_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_07_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6332 (class 1259 OID 23998)
-- Name: avidb_messages_p2019_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_07_station_id_idx ON public.avidb_messages_p2019_07 USING btree (station_id);


--
-- TOC entry 6333 (class 1259 OID 23999)
-- Name: avidb_messages_p2019_08_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_08_created_idx ON public.avidb_messages_p2019_08 USING btree (created);


--
-- TOC entry 6334 (class 1259 OID 24000)
-- Name: avidb_messages_p2019_08_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_08_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_08 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6337 (class 1259 OID 24001)
-- Name: avidb_messages_p2019_08_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_08_station_id_idx ON public.avidb_messages_p2019_08 USING btree (station_id);


--
-- TOC entry 6338 (class 1259 OID 24002)
-- Name: avidb_messages_p2019_09_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_09_created_idx ON public.avidb_messages_p2019_09 USING btree (created);


--
-- TOC entry 6339 (class 1259 OID 24003)
-- Name: avidb_messages_p2019_09_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_09_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_09 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6342 (class 1259 OID 24004)
-- Name: avidb_messages_p2019_09_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_09_station_id_idx ON public.avidb_messages_p2019_09 USING btree (station_id);


--
-- TOC entry 6343 (class 1259 OID 24005)
-- Name: avidb_messages_p2019_10_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_10_created_idx ON public.avidb_messages_p2019_10 USING btree (created);


--
-- TOC entry 6344 (class 1259 OID 24006)
-- Name: avidb_messages_p2019_10_message_time_type_id_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_10_message_time_type_id_station_id_idx ON public.avidb_messages_p2019_10 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6347 (class 1259 OID 24007)
-- Name: avidb_messages_p2019_10_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_10_station_id_idx ON public.avidb_messages_p2019_10 USING btree (station_id);


--
-- TOC entry 6348 (class 1259 OID 24010)
-- Name: avidb_messages_p2019_11_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_11_created_idx ON public.avidb_messages_p2019_11 USING btree (created);


--
-- TOC entry 6349 (class 1259 OID 24011)
-- Name: avidb_messages_p2019_11_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_11_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2019_11 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6352 (class 1259 OID 24012)
-- Name: avidb_messages_p2019_11_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_11_station_id_idx ON public.avidb_messages_p2019_11 USING btree (station_id);


--
-- TOC entry 6353 (class 1259 OID 24013)
-- Name: avidb_messages_p2019_12_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_12_created_idx ON public.avidb_messages_p2019_12 USING btree (created);


--
-- TOC entry 6354 (class 1259 OID 24014)
-- Name: avidb_messages_p2019_12_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_12_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2019_12 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6357 (class 1259 OID 24015)
-- Name: avidb_messages_p2019_12_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2019_12_station_id_idx ON public.avidb_messages_p2019_12 USING btree (station_id);


--
-- TOC entry 6358 (class 1259 OID 24017)
-- Name: avidb_messages_p2020_01_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_01_created_idx ON public.avidb_messages_p2020_01 USING btree (created);


--
-- TOC entry 6359 (class 1259 OID 24018)
-- Name: avidb_messages_p2020_01_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_01_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_01 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6362 (class 1259 OID 24019)
-- Name: avidb_messages_p2020_01_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_01_station_id_idx ON public.avidb_messages_p2020_01 USING btree (station_id);


--
-- TOC entry 6363 (class 1259 OID 24020)
-- Name: avidb_messages_p2020_02_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_02_created_idx ON public.avidb_messages_p2020_02 USING btree (created);


--
-- TOC entry 6364 (class 1259 OID 24021)
-- Name: avidb_messages_p2020_02_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_02_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_02 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6367 (class 1259 OID 24022)
-- Name: avidb_messages_p2020_02_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_02_station_id_idx ON public.avidb_messages_p2020_02 USING btree (station_id);


--
-- TOC entry 6368 (class 1259 OID 24023)
-- Name: avidb_messages_p2020_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_03_created_idx ON public.avidb_messages_p2020_03 USING btree (created);


--
-- TOC entry 6369 (class 1259 OID 24024)
-- Name: avidb_messages_p2020_03_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_03_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6372 (class 1259 OID 24025)
-- Name: avidb_messages_p2020_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_03_station_id_idx ON public.avidb_messages_p2020_03 USING btree (station_id);


--
-- TOC entry 6373 (class 1259 OID 24026)
-- Name: avidb_messages_p2020_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_04_created_idx ON public.avidb_messages_p2020_04 USING btree (created);


--
-- TOC entry 6374 (class 1259 OID 24027)
-- Name: avidb_messages_p2020_04_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_04_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6377 (class 1259 OID 24028)
-- Name: avidb_messages_p2020_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_04_station_id_idx ON public.avidb_messages_p2020_04 USING btree (station_id);


--
-- TOC entry 6378 (class 1259 OID 24029)
-- Name: avidb_messages_p2020_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_05_created_idx ON public.avidb_messages_p2020_05 USING btree (created);


--
-- TOC entry 6379 (class 1259 OID 24031)
-- Name: avidb_messages_p2020_05_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_05_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6382 (class 1259 OID 24032)
-- Name: avidb_messages_p2020_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_05_station_id_idx ON public.avidb_messages_p2020_05 USING btree (station_id);


--
-- TOC entry 6383 (class 1259 OID 24033)
-- Name: avidb_messages_p2020_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_06_created_idx ON public.avidb_messages_p2020_06 USING btree (created);


--
-- TOC entry 6384 (class 1259 OID 24034)
-- Name: avidb_messages_p2020_06_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_06_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6387 (class 1259 OID 24035)
-- Name: avidb_messages_p2020_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_06_station_id_idx ON public.avidb_messages_p2020_06 USING btree (station_id);


--
-- TOC entry 6388 (class 1259 OID 24036)
-- Name: avidb_messages_p2020_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_07_created_idx ON public.avidb_messages_p2020_07 USING btree (created);


--
-- TOC entry 6389 (class 1259 OID 24037)
-- Name: avidb_messages_p2020_07_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_07_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6392 (class 1259 OID 24038)
-- Name: avidb_messages_p2020_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_07_station_id_idx ON public.avidb_messages_p2020_07 USING btree (station_id);


--
-- TOC entry 6393 (class 1259 OID 24039)
-- Name: avidb_messages_p2020_08_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_08_created_idx ON public.avidb_messages_p2020_08 USING btree (created);


--
-- TOC entry 6394 (class 1259 OID 24040)
-- Name: avidb_messages_p2020_08_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_08_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_08 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6397 (class 1259 OID 24041)
-- Name: avidb_messages_p2020_08_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_08_station_id_idx ON public.avidb_messages_p2020_08 USING btree (station_id);


--
-- TOC entry 6398 (class 1259 OID 24042)
-- Name: avidb_messages_p2020_09_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_09_created_idx ON public.avidb_messages_p2020_09 USING btree (created);


--
-- TOC entry 6399 (class 1259 OID 24043)
-- Name: avidb_messages_p2020_09_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_09_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_09 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6402 (class 1259 OID 24044)
-- Name: avidb_messages_p2020_09_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_09_station_id_idx ON public.avidb_messages_p2020_09 USING btree (station_id);


--
-- TOC entry 6403 (class 1259 OID 24045)
-- Name: avidb_messages_p2020_10_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_10_created_idx ON public.avidb_messages_p2020_10 USING btree (created);


--
-- TOC entry 6404 (class 1259 OID 24046)
-- Name: avidb_messages_p2020_10_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_10_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_10 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6407 (class 1259 OID 24047)
-- Name: avidb_messages_p2020_10_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_10_station_id_idx ON public.avidb_messages_p2020_10 USING btree (station_id);


--
-- TOC entry 6408 (class 1259 OID 24048)
-- Name: avidb_messages_p2020_11_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_11_created_idx ON public.avidb_messages_p2020_11 USING btree (created);


--
-- TOC entry 6409 (class 1259 OID 24049)
-- Name: avidb_messages_p2020_11_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_11_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_11 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6412 (class 1259 OID 24050)
-- Name: avidb_messages_p2020_11_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_11_station_id_idx ON public.avidb_messages_p2020_11 USING btree (station_id);


--
-- TOC entry 6413 (class 1259 OID 24051)
-- Name: avidb_messages_p2020_12_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_12_created_idx ON public.avidb_messages_p2020_12 USING btree (created);


--
-- TOC entry 6414 (class 1259 OID 24052)
-- Name: avidb_messages_p2020_12_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_12_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2020_12 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6417 (class 1259 OID 24053)
-- Name: avidb_messages_p2020_12_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2020_12_station_id_idx ON public.avidb_messages_p2020_12 USING btree (station_id);


--
-- TOC entry 6418 (class 1259 OID 24054)
-- Name: avidb_messages_p2021_01_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_01_created_idx ON public.avidb_messages_p2021_01 USING btree (created);


--
-- TOC entry 6419 (class 1259 OID 24056)
-- Name: avidb_messages_p2021_01_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_01_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_01 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6422 (class 1259 OID 24057)
-- Name: avidb_messages_p2021_01_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_01_station_id_idx ON public.avidb_messages_p2021_01 USING btree (station_id);


--
-- TOC entry 6423 (class 1259 OID 24058)
-- Name: avidb_messages_p2021_02_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_02_created_idx ON public.avidb_messages_p2021_02 USING btree (created);


--
-- TOC entry 6424 (class 1259 OID 24059)
-- Name: avidb_messages_p2021_02_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_02_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_02 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6427 (class 1259 OID 24060)
-- Name: avidb_messages_p2021_02_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_02_station_id_idx ON public.avidb_messages_p2021_02 USING btree (station_id);


--
-- TOC entry 6428 (class 1259 OID 24061)
-- Name: avidb_messages_p2021_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_03_created_idx ON public.avidb_messages_p2021_03 USING btree (created);


--
-- TOC entry 6429 (class 1259 OID 24062)
-- Name: avidb_messages_p2021_03_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_03_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6432 (class 1259 OID 24063)
-- Name: avidb_messages_p2021_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_03_station_id_idx ON public.avidb_messages_p2021_03 USING btree (station_id);


--
-- TOC entry 6433 (class 1259 OID 24064)
-- Name: avidb_messages_p2021_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_04_created_idx ON public.avidb_messages_p2021_04 USING btree (created);


--
-- TOC entry 6434 (class 1259 OID 24065)
-- Name: avidb_messages_p2021_04_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_04_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6437 (class 1259 OID 24067)
-- Name: avidb_messages_p2021_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_04_station_id_idx ON public.avidb_messages_p2021_04 USING btree (station_id);


--
-- TOC entry 6438 (class 1259 OID 24068)
-- Name: avidb_messages_p2021_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_05_created_idx ON public.avidb_messages_p2021_05 USING btree (created);


--
-- TOC entry 6439 (class 1259 OID 24069)
-- Name: avidb_messages_p2021_05_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_05_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6442 (class 1259 OID 24070)
-- Name: avidb_messages_p2021_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_05_station_id_idx ON public.avidb_messages_p2021_05 USING btree (station_id);


--
-- TOC entry 6443 (class 1259 OID 24071)
-- Name: avidb_messages_p2021_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_06_created_idx ON public.avidb_messages_p2021_06 USING btree (created);


--
-- TOC entry 6444 (class 1259 OID 24072)
-- Name: avidb_messages_p2021_06_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_06_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6447 (class 1259 OID 24073)
-- Name: avidb_messages_p2021_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_06_station_id_idx ON public.avidb_messages_p2021_06 USING btree (station_id);


--
-- TOC entry 6448 (class 1259 OID 24074)
-- Name: avidb_messages_p2021_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_07_created_idx ON public.avidb_messages_p2021_07 USING btree (created);


--
-- TOC entry 6449 (class 1259 OID 24075)
-- Name: avidb_messages_p2021_07_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_07_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6452 (class 1259 OID 24076)
-- Name: avidb_messages_p2021_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_07_station_id_idx ON public.avidb_messages_p2021_07 USING btree (station_id);


--
-- TOC entry 6453 (class 1259 OID 24077)
-- Name: avidb_messages_p2021_08_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_08_created_idx ON public.avidb_messages_p2021_08 USING btree (created);


--
-- TOC entry 6454 (class 1259 OID 24078)
-- Name: avidb_messages_p2021_08_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_08_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_08 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6457 (class 1259 OID 24079)
-- Name: avidb_messages_p2021_08_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_08_station_id_idx ON public.avidb_messages_p2021_08 USING btree (station_id);


--
-- TOC entry 6458 (class 1259 OID 24080)
-- Name: avidb_messages_p2021_09_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_09_created_idx ON public.avidb_messages_p2021_09 USING btree (created);


--
-- TOC entry 6459 (class 1259 OID 24081)
-- Name: avidb_messages_p2021_09_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_09_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_09 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6462 (class 1259 OID 24082)
-- Name: avidb_messages_p2021_09_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_09_station_id_idx ON public.avidb_messages_p2021_09 USING btree (station_id);


--
-- TOC entry 6463 (class 1259 OID 24083)
-- Name: avidb_messages_p2021_10_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_10_created_idx ON public.avidb_messages_p2021_10 USING btree (created);


--
-- TOC entry 6464 (class 1259 OID 24084)
-- Name: avidb_messages_p2021_10_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_10_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_10 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6467 (class 1259 OID 24085)
-- Name: avidb_messages_p2021_10_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_10_station_id_idx ON public.avidb_messages_p2021_10 USING btree (station_id);


--
-- TOC entry 6468 (class 1259 OID 24086)
-- Name: avidb_messages_p2021_11_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_11_created_idx ON public.avidb_messages_p2021_11 USING btree (created);


--
-- TOC entry 6469 (class 1259 OID 24088)
-- Name: avidb_messages_p2021_11_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_11_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_11 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6472 (class 1259 OID 24089)
-- Name: avidb_messages_p2021_11_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_11_station_id_idx ON public.avidb_messages_p2021_11 USING btree (station_id);


--
-- TOC entry 6473 (class 1259 OID 24090)
-- Name: avidb_messages_p2021_12_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_12_created_idx ON public.avidb_messages_p2021_12 USING btree (created);


--
-- TOC entry 6474 (class 1259 OID 24091)
-- Name: avidb_messages_p2021_12_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_12_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2021_12 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6477 (class 1259 OID 24092)
-- Name: avidb_messages_p2021_12_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2021_12_station_id_idx ON public.avidb_messages_p2021_12 USING btree (station_id);


--
-- TOC entry 6478 (class 1259 OID 24093)
-- Name: avidb_messages_p2022_01_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_01_created_idx ON public.avidb_messages_p2022_01 USING btree (created);


--
-- TOC entry 6479 (class 1259 OID 24094)
-- Name: avidb_messages_p2022_01_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_01_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2022_01 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6482 (class 1259 OID 24095)
-- Name: avidb_messages_p2022_01_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_01_station_id_idx ON public.avidb_messages_p2022_01 USING btree (station_id);


--
-- TOC entry 6483 (class 1259 OID 24096)
-- Name: avidb_messages_p2022_02_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_02_created_idx ON public.avidb_messages_p2022_02 USING btree (created);


--
-- TOC entry 6484 (class 1259 OID 24097)
-- Name: avidb_messages_p2022_02_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_02_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2022_02 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6487 (class 1259 OID 24098)
-- Name: avidb_messages_p2022_02_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_02_station_id_idx ON public.avidb_messages_p2022_02 USING btree (station_id);


--
-- TOC entry 6497 (class 1259 OID 28337)
-- Name: avidb_messages_p2022_03_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_03_created_idx ON public.avidb_messages_p2022_03 USING btree (created);


--
-- TOC entry 6498 (class 1259 OID 28338)
-- Name: avidb_messages_p2022_03_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_03_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2022_03 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6501 (class 1259 OID 28339)
-- Name: avidb_messages_p2022_03_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_03_station_id_idx ON public.avidb_messages_p2022_03 USING btree (station_id);


--
-- TOC entry 6502 (class 1259 OID 28362)
-- Name: avidb_messages_p2022_04_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_04_created_idx ON public.avidb_messages_p2022_04 USING btree (created);


--
-- TOC entry 6503 (class 1259 OID 28363)
-- Name: avidb_messages_p2022_04_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_04_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2022_04 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6506 (class 1259 OID 28364)
-- Name: avidb_messages_p2022_04_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_04_station_id_idx ON public.avidb_messages_p2022_04 USING btree (station_id);


--
-- TOC entry 6507 (class 1259 OID 28387)
-- Name: avidb_messages_p2022_05_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_05_created_idx ON public.avidb_messages_p2022_05 USING btree (created);


--
-- TOC entry 6508 (class 1259 OID 28388)
-- Name: avidb_messages_p2022_05_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_05_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2022_05 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6511 (class 1259 OID 28389)
-- Name: avidb_messages_p2022_05_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_05_station_id_idx ON public.avidb_messages_p2022_05 USING btree (station_id);


--
-- TOC entry 6517 (class 1259 OID 32547)
-- Name: avidb_messages_p2022_06_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_06_created_idx ON public.avidb_messages_p2022_06 USING btree (created);


--
-- TOC entry 6518 (class 1259 OID 32548)
-- Name: avidb_messages_p2022_06_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_06_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2022_06 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6521 (class 1259 OID 32549)
-- Name: avidb_messages_p2022_06_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_06_station_id_idx ON public.avidb_messages_p2022_06 USING btree (station_id);


--
-- TOC entry 6530 (class 1259 OID 32639)
-- Name: avidb_messages_p2022_07_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_07_created_idx ON public.avidb_messages_p2022_07 USING btree (created);


--
-- TOC entry 6531 (class 1259 OID 32640)
-- Name: avidb_messages_p2022_07_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_07_message_time_type_id_station_id_for_idx ON public.avidb_messages_p2022_07 USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6534 (class 1259 OID 32641)
-- Name: avidb_messages_p2022_07_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_p2022_07_station_id_idx ON public.avidb_messages_p2022_07 USING btree (station_id);


--
-- TOC entry 6512 (class 1259 OID 32497)
-- Name: avidb_messages_pdefault_created_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_pdefault_created_idx ON public.avidb_messages_pdefault USING btree (created);


--
-- TOC entry 6513 (class 1259 OID 32498)
-- Name: avidb_messages_pdefault_message_time_type_id_station_id_for_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_pdefault_message_time_type_id_station_id_for_idx ON public.avidb_messages_pdefault USING btree (message_time, type_id, station_id, format_id);


--
-- TOC entry 6516 (class 1259 OID 32499)
-- Name: avidb_messages_pdefault_station_id_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_messages_pdefault_station_id_idx ON public.avidb_messages_pdefault USING btree (station_id);


--
-- TOC entry 6539 (class 1259 OID 32734)
-- Name: avidb_rejected_messages_idx1; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_rejected_messages_idx1 ON public.avidb_rejected_messages USING btree (created);


--
-- TOC entry 6051 (class 1259 OID 32209)
-- Name: avidb_stations_geom_idx; Type: INDEX; Schema: public; Owner: avidb_rw
--

CREATE INDEX avidb_stations_geom_idx ON public.avidb_stations USING gist (geom);


--
-- TOC entry 6831 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p0_pkey; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_p0_pkey;


--
-- TOC entry 6832 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p10000000_pkey; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_p10000000_pkey;


--
-- TOC entry 6833 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p20000000_pkey; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_p20000000_pkey;


--
-- TOC entry 6838 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p30000000_pkey; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_p30000000_pkey;


--
-- TOC entry 6839 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_p40000000_pkey; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_p40000000_pkey;


--
-- TOC entry 6834 (class 0 OID 0)
-- Name: avidb_message_iwxxm_details_pdefault_pkey; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_message_iwxxm_details_pkey ATTACH PARTITION public.avidb_message_iwxxm_details_pdefault_pkey;


--
-- TOC entry 6564 (class 0 OID 0)
-- Name: avidb_messages_p2015_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_03_created_idx;


--
-- TOC entry 6565 (class 0 OID 0)
-- Name: avidb_messages_p2015_03_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_03_message_time_type_id_station_id_idx;


--
-- TOC entry 6566 (class 0 OID 0)
-- Name: avidb_messages_p2015_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_03_station_id_idx;


--
-- TOC entry 6567 (class 0 OID 0)
-- Name: avidb_messages_p2015_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_04_created_idx;


--
-- TOC entry 6568 (class 0 OID 0)
-- Name: avidb_messages_p2015_04_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_04_message_time_type_id_station_id_idx;


--
-- TOC entry 6569 (class 0 OID 0)
-- Name: avidb_messages_p2015_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_04_station_id_idx;


--
-- TOC entry 6570 (class 0 OID 0)
-- Name: avidb_messages_p2015_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_05_created_idx;


--
-- TOC entry 6571 (class 0 OID 0)
-- Name: avidb_messages_p2015_05_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_05_message_time_type_id_station_id_idx;


--
-- TOC entry 6572 (class 0 OID 0)
-- Name: avidb_messages_p2015_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_05_station_id_idx;


--
-- TOC entry 6573 (class 0 OID 0)
-- Name: avidb_messages_p2015_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_06_created_idx;


--
-- TOC entry 6574 (class 0 OID 0)
-- Name: avidb_messages_p2015_06_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_06_message_time_type_id_station_id_idx;


--
-- TOC entry 6575 (class 0 OID 0)
-- Name: avidb_messages_p2015_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_06_station_id_idx;


--
-- TOC entry 6576 (class 0 OID 0)
-- Name: avidb_messages_p2015_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_07_created_idx;


--
-- TOC entry 6577 (class 0 OID 0)
-- Name: avidb_messages_p2015_07_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_07_message_time_type_id_station_id_idx;


--
-- TOC entry 6578 (class 0 OID 0)
-- Name: avidb_messages_p2015_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_07_station_id_idx;


--
-- TOC entry 6579 (class 0 OID 0)
-- Name: avidb_messages_p2015_08_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_08_created_idx;


--
-- TOC entry 6580 (class 0 OID 0)
-- Name: avidb_messages_p2015_08_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_08_message_time_type_id_station_id_idx;


--
-- TOC entry 6581 (class 0 OID 0)
-- Name: avidb_messages_p2015_08_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_08_station_id_idx;


--
-- TOC entry 6582 (class 0 OID 0)
-- Name: avidb_messages_p2015_09_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_09_created_idx;


--
-- TOC entry 6583 (class 0 OID 0)
-- Name: avidb_messages_p2015_09_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_09_message_time_type_id_station_id_idx;


--
-- TOC entry 6584 (class 0 OID 0)
-- Name: avidb_messages_p2015_09_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_09_station_id_idx;


--
-- TOC entry 6585 (class 0 OID 0)
-- Name: avidb_messages_p2015_10_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_10_created_idx;


--
-- TOC entry 6586 (class 0 OID 0)
-- Name: avidb_messages_p2015_10_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_10_message_time_type_id_station_id_idx;


--
-- TOC entry 6587 (class 0 OID 0)
-- Name: avidb_messages_p2015_10_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_10_station_id_idx;


--
-- TOC entry 6588 (class 0 OID 0)
-- Name: avidb_messages_p2015_11_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_11_created_idx;


--
-- TOC entry 6589 (class 0 OID 0)
-- Name: avidb_messages_p2015_11_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_11_message_time_type_id_station_id_idx;


--
-- TOC entry 6590 (class 0 OID 0)
-- Name: avidb_messages_p2015_11_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_11_station_id_idx;


--
-- TOC entry 6591 (class 0 OID 0)
-- Name: avidb_messages_p2015_12_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2015_12_created_idx;


--
-- TOC entry 6592 (class 0 OID 0)
-- Name: avidb_messages_p2015_12_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2015_12_message_time_type_id_station_id_idx;


--
-- TOC entry 6593 (class 0 OID 0)
-- Name: avidb_messages_p2015_12_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2015_12_station_id_idx;


--
-- TOC entry 6594 (class 0 OID 0)
-- Name: avidb_messages_p2016_01_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_01_created_idx;


--
-- TOC entry 6595 (class 0 OID 0)
-- Name: avidb_messages_p2016_01_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_01_message_time_type_id_station_id_idx;


--
-- TOC entry 6596 (class 0 OID 0)
-- Name: avidb_messages_p2016_01_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_01_station_id_idx;


--
-- TOC entry 6597 (class 0 OID 0)
-- Name: avidb_messages_p2016_02_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_02_created_idx;


--
-- TOC entry 6598 (class 0 OID 0)
-- Name: avidb_messages_p2016_02_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_02_message_time_type_id_station_id_idx;


--
-- TOC entry 6599 (class 0 OID 0)
-- Name: avidb_messages_p2016_02_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_02_station_id_idx;


--
-- TOC entry 6600 (class 0 OID 0)
-- Name: avidb_messages_p2016_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_03_created_idx;


--
-- TOC entry 6601 (class 0 OID 0)
-- Name: avidb_messages_p2016_03_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_03_message_time_type_id_station_id_idx;


--
-- TOC entry 6602 (class 0 OID 0)
-- Name: avidb_messages_p2016_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_03_station_id_idx;


--
-- TOC entry 6603 (class 0 OID 0)
-- Name: avidb_messages_p2016_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_04_created_idx;


--
-- TOC entry 6604 (class 0 OID 0)
-- Name: avidb_messages_p2016_04_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_04_message_time_type_id_station_id_idx;


--
-- TOC entry 6605 (class 0 OID 0)
-- Name: avidb_messages_p2016_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_04_station_id_idx;


--
-- TOC entry 6606 (class 0 OID 0)
-- Name: avidb_messages_p2016_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_05_created_idx;


--
-- TOC entry 6607 (class 0 OID 0)
-- Name: avidb_messages_p2016_05_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_05_message_time_type_id_station_id_idx;


--
-- TOC entry 6608 (class 0 OID 0)
-- Name: avidb_messages_p2016_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_05_station_id_idx;


--
-- TOC entry 6609 (class 0 OID 0)
-- Name: avidb_messages_p2016_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_06_created_idx;


--
-- TOC entry 6610 (class 0 OID 0)
-- Name: avidb_messages_p2016_06_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_06_message_time_type_id_station_id_idx;


--
-- TOC entry 6611 (class 0 OID 0)
-- Name: avidb_messages_p2016_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_06_station_id_idx;


--
-- TOC entry 6612 (class 0 OID 0)
-- Name: avidb_messages_p2016_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_07_created_idx;


--
-- TOC entry 6613 (class 0 OID 0)
-- Name: avidb_messages_p2016_07_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_07_message_time_type_id_station_id_idx;


--
-- TOC entry 6614 (class 0 OID 0)
-- Name: avidb_messages_p2016_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_07_station_id_idx;


--
-- TOC entry 6615 (class 0 OID 0)
-- Name: avidb_messages_p2016_08_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_08_created_idx;


--
-- TOC entry 6616 (class 0 OID 0)
-- Name: avidb_messages_p2016_08_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_08_message_time_type_id_station_id_idx;


--
-- TOC entry 6617 (class 0 OID 0)
-- Name: avidb_messages_p2016_08_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_08_station_id_idx;


--
-- TOC entry 6618 (class 0 OID 0)
-- Name: avidb_messages_p2016_09_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_09_created_idx;


--
-- TOC entry 6619 (class 0 OID 0)
-- Name: avidb_messages_p2016_09_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_09_message_time_type_id_station_id_idx;


--
-- TOC entry 6620 (class 0 OID 0)
-- Name: avidb_messages_p2016_09_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_09_station_id_idx;


--
-- TOC entry 6621 (class 0 OID 0)
-- Name: avidb_messages_p2016_10_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_10_created_idx;


--
-- TOC entry 6622 (class 0 OID 0)
-- Name: avidb_messages_p2016_10_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_10_message_time_type_id_station_id_idx;


--
-- TOC entry 6623 (class 0 OID 0)
-- Name: avidb_messages_p2016_10_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_10_station_id_idx;


--
-- TOC entry 6624 (class 0 OID 0)
-- Name: avidb_messages_p2016_11_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_11_created_idx;


--
-- TOC entry 6625 (class 0 OID 0)
-- Name: avidb_messages_p2016_11_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_11_message_time_type_id_station_id_idx;


--
-- TOC entry 6626 (class 0 OID 0)
-- Name: avidb_messages_p2016_11_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_11_station_id_idx;


--
-- TOC entry 6627 (class 0 OID 0)
-- Name: avidb_messages_p2016_12_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2016_12_created_idx;


--
-- TOC entry 6628 (class 0 OID 0)
-- Name: avidb_messages_p2016_12_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2016_12_message_time_type_id_station_id_idx;


--
-- TOC entry 6629 (class 0 OID 0)
-- Name: avidb_messages_p2016_12_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2016_12_station_id_idx;


--
-- TOC entry 6630 (class 0 OID 0)
-- Name: avidb_messages_p2017_01_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_01_created_idx;


--
-- TOC entry 6631 (class 0 OID 0)
-- Name: avidb_messages_p2017_01_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_01_message_time_type_id_station_id_idx;


--
-- TOC entry 6632 (class 0 OID 0)
-- Name: avidb_messages_p2017_01_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_01_station_id_idx;


--
-- TOC entry 6633 (class 0 OID 0)
-- Name: avidb_messages_p2017_02_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_02_created_idx;


--
-- TOC entry 6634 (class 0 OID 0)
-- Name: avidb_messages_p2017_02_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_02_message_time_type_id_station_id_idx;


--
-- TOC entry 6635 (class 0 OID 0)
-- Name: avidb_messages_p2017_02_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_02_station_id_idx;


--
-- TOC entry 6636 (class 0 OID 0)
-- Name: avidb_messages_p2017_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_03_created_idx;


--
-- TOC entry 6637 (class 0 OID 0)
-- Name: avidb_messages_p2017_03_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_03_message_time_type_id_station_id_idx;


--
-- TOC entry 6638 (class 0 OID 0)
-- Name: avidb_messages_p2017_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_03_station_id_idx;


--
-- TOC entry 6639 (class 0 OID 0)
-- Name: avidb_messages_p2017_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_04_created_idx;


--
-- TOC entry 6640 (class 0 OID 0)
-- Name: avidb_messages_p2017_04_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_04_message_time_type_id_station_id_idx;


--
-- TOC entry 6641 (class 0 OID 0)
-- Name: avidb_messages_p2017_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_04_station_id_idx;


--
-- TOC entry 6642 (class 0 OID 0)
-- Name: avidb_messages_p2017_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_05_created_idx;


--
-- TOC entry 6643 (class 0 OID 0)
-- Name: avidb_messages_p2017_05_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_05_message_time_type_id_station_id_idx;


--
-- TOC entry 6644 (class 0 OID 0)
-- Name: avidb_messages_p2017_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_05_station_id_idx;


--
-- TOC entry 6645 (class 0 OID 0)
-- Name: avidb_messages_p2017_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_06_created_idx;


--
-- TOC entry 6646 (class 0 OID 0)
-- Name: avidb_messages_p2017_06_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_06_message_time_type_id_station_id_idx;


--
-- TOC entry 6647 (class 0 OID 0)
-- Name: avidb_messages_p2017_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_06_station_id_idx;


--
-- TOC entry 6648 (class 0 OID 0)
-- Name: avidb_messages_p2017_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_07_created_idx;


--
-- TOC entry 6649 (class 0 OID 0)
-- Name: avidb_messages_p2017_07_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_07_message_time_type_id_station_id_idx;


--
-- TOC entry 6650 (class 0 OID 0)
-- Name: avidb_messages_p2017_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_07_station_id_idx;


--
-- TOC entry 6651 (class 0 OID 0)
-- Name: avidb_messages_p2017_08_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_08_created_idx;


--
-- TOC entry 6652 (class 0 OID 0)
-- Name: avidb_messages_p2017_08_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_08_message_time_type_id_station_id_idx;


--
-- TOC entry 6653 (class 0 OID 0)
-- Name: avidb_messages_p2017_08_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_08_station_id_idx;


--
-- TOC entry 6654 (class 0 OID 0)
-- Name: avidb_messages_p2017_09_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_09_created_idx;


--
-- TOC entry 6655 (class 0 OID 0)
-- Name: avidb_messages_p2017_09_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_09_message_time_type_id_station_id_idx;


--
-- TOC entry 6656 (class 0 OID 0)
-- Name: avidb_messages_p2017_09_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_09_station_id_idx;


--
-- TOC entry 6657 (class 0 OID 0)
-- Name: avidb_messages_p2017_10_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_10_created_idx;


--
-- TOC entry 6658 (class 0 OID 0)
-- Name: avidb_messages_p2017_10_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_10_message_time_type_id_station_id_idx;


--
-- TOC entry 6659 (class 0 OID 0)
-- Name: avidb_messages_p2017_10_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_10_station_id_idx;


--
-- TOC entry 6660 (class 0 OID 0)
-- Name: avidb_messages_p2017_11_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_11_created_idx;


--
-- TOC entry 6661 (class 0 OID 0)
-- Name: avidb_messages_p2017_11_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_11_message_time_type_id_station_id_idx;


--
-- TOC entry 6662 (class 0 OID 0)
-- Name: avidb_messages_p2017_11_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_11_station_id_idx;


--
-- TOC entry 6663 (class 0 OID 0)
-- Name: avidb_messages_p2017_12_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2017_12_created_idx;


--
-- TOC entry 6664 (class 0 OID 0)
-- Name: avidb_messages_p2017_12_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2017_12_message_time_type_id_station_id_idx;


--
-- TOC entry 6665 (class 0 OID 0)
-- Name: avidb_messages_p2017_12_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2017_12_station_id_idx;


--
-- TOC entry 6666 (class 0 OID 0)
-- Name: avidb_messages_p2018_01_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_01_created_idx;


--
-- TOC entry 6667 (class 0 OID 0)
-- Name: avidb_messages_p2018_01_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_01_message_time_type_id_station_id_idx;


--
-- TOC entry 6668 (class 0 OID 0)
-- Name: avidb_messages_p2018_01_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_01_station_id_idx;


--
-- TOC entry 6669 (class 0 OID 0)
-- Name: avidb_messages_p2018_02_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_02_created_idx;


--
-- TOC entry 6670 (class 0 OID 0)
-- Name: avidb_messages_p2018_02_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_02_message_time_type_id_station_id_idx;


--
-- TOC entry 6671 (class 0 OID 0)
-- Name: avidb_messages_p2018_02_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_02_station_id_idx;


--
-- TOC entry 6672 (class 0 OID 0)
-- Name: avidb_messages_p2018_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_03_created_idx;


--
-- TOC entry 6673 (class 0 OID 0)
-- Name: avidb_messages_p2018_03_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_03_message_time_type_id_station_id_idx;


--
-- TOC entry 6674 (class 0 OID 0)
-- Name: avidb_messages_p2018_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_03_station_id_idx;


--
-- TOC entry 6675 (class 0 OID 0)
-- Name: avidb_messages_p2018_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_04_created_idx;


--
-- TOC entry 6676 (class 0 OID 0)
-- Name: avidb_messages_p2018_04_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_04_message_time_type_id_station_id_idx;


--
-- TOC entry 6677 (class 0 OID 0)
-- Name: avidb_messages_p2018_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_04_station_id_idx;


--
-- TOC entry 6678 (class 0 OID 0)
-- Name: avidb_messages_p2018_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_05_created_idx;


--
-- TOC entry 6679 (class 0 OID 0)
-- Name: avidb_messages_p2018_05_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_05_message_time_type_id_station_id_idx;


--
-- TOC entry 6680 (class 0 OID 0)
-- Name: avidb_messages_p2018_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_05_station_id_idx;


--
-- TOC entry 6681 (class 0 OID 0)
-- Name: avidb_messages_p2018_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_06_created_idx;


--
-- TOC entry 6682 (class 0 OID 0)
-- Name: avidb_messages_p2018_06_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_06_message_time_type_id_station_id_idx;


--
-- TOC entry 6683 (class 0 OID 0)
-- Name: avidb_messages_p2018_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_06_station_id_idx;


--
-- TOC entry 6684 (class 0 OID 0)
-- Name: avidb_messages_p2018_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_07_created_idx;


--
-- TOC entry 6685 (class 0 OID 0)
-- Name: avidb_messages_p2018_07_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_07_message_time_type_id_station_id_idx;


--
-- TOC entry 6686 (class 0 OID 0)
-- Name: avidb_messages_p2018_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_07_station_id_idx;


--
-- TOC entry 6687 (class 0 OID 0)
-- Name: avidb_messages_p2018_08_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_08_created_idx;


--
-- TOC entry 6688 (class 0 OID 0)
-- Name: avidb_messages_p2018_08_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_08_message_time_type_id_station_id_idx;


--
-- TOC entry 6689 (class 0 OID 0)
-- Name: avidb_messages_p2018_08_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_08_station_id_idx;


--
-- TOC entry 6690 (class 0 OID 0)
-- Name: avidb_messages_p2018_09_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_09_created_idx;


--
-- TOC entry 6691 (class 0 OID 0)
-- Name: avidb_messages_p2018_09_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_09_message_time_type_id_station_id_idx;


--
-- TOC entry 6692 (class 0 OID 0)
-- Name: avidb_messages_p2018_09_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_09_station_id_idx;


--
-- TOC entry 6693 (class 0 OID 0)
-- Name: avidb_messages_p2018_10_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_10_created_idx;


--
-- TOC entry 6694 (class 0 OID 0)
-- Name: avidb_messages_p2018_10_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_10_message_time_type_id_station_id_idx;


--
-- TOC entry 6695 (class 0 OID 0)
-- Name: avidb_messages_p2018_10_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_10_station_id_idx;


--
-- TOC entry 6696 (class 0 OID 0)
-- Name: avidb_messages_p2018_11_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_11_created_idx;


--
-- TOC entry 6697 (class 0 OID 0)
-- Name: avidb_messages_p2018_11_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_11_message_time_type_id_station_id_idx;


--
-- TOC entry 6698 (class 0 OID 0)
-- Name: avidb_messages_p2018_11_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_11_station_id_idx;


--
-- TOC entry 6699 (class 0 OID 0)
-- Name: avidb_messages_p2018_12_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2018_12_created_idx;


--
-- TOC entry 6700 (class 0 OID 0)
-- Name: avidb_messages_p2018_12_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2018_12_message_time_type_id_station_id_idx;


--
-- TOC entry 6701 (class 0 OID 0)
-- Name: avidb_messages_p2018_12_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2018_12_station_id_idx;


--
-- TOC entry 6702 (class 0 OID 0)
-- Name: avidb_messages_p2019_01_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_01_created_idx;


--
-- TOC entry 6703 (class 0 OID 0)
-- Name: avidb_messages_p2019_01_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_01_message_time_type_id_station_id_idx;


--
-- TOC entry 6704 (class 0 OID 0)
-- Name: avidb_messages_p2019_01_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_01_station_id_idx;


--
-- TOC entry 6705 (class 0 OID 0)
-- Name: avidb_messages_p2019_02_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_02_created_idx;


--
-- TOC entry 6706 (class 0 OID 0)
-- Name: avidb_messages_p2019_02_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_02_message_time_type_id_station_id_idx;


--
-- TOC entry 6707 (class 0 OID 0)
-- Name: avidb_messages_p2019_02_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_02_station_id_idx;


--
-- TOC entry 6708 (class 0 OID 0)
-- Name: avidb_messages_p2019_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_03_created_idx;


--
-- TOC entry 6709 (class 0 OID 0)
-- Name: avidb_messages_p2019_03_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_03_message_time_type_id_station_id_idx;


--
-- TOC entry 6710 (class 0 OID 0)
-- Name: avidb_messages_p2019_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_03_station_id_idx;


--
-- TOC entry 6711 (class 0 OID 0)
-- Name: avidb_messages_p2019_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_04_created_idx;


--
-- TOC entry 6712 (class 0 OID 0)
-- Name: avidb_messages_p2019_04_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_04_message_time_type_id_station_id_idx;


--
-- TOC entry 6713 (class 0 OID 0)
-- Name: avidb_messages_p2019_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_04_station_id_idx;


--
-- TOC entry 6714 (class 0 OID 0)
-- Name: avidb_messages_p2019_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_05_created_idx;


--
-- TOC entry 6715 (class 0 OID 0)
-- Name: avidb_messages_p2019_05_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_05_message_time_type_id_station_id_idx;


--
-- TOC entry 6716 (class 0 OID 0)
-- Name: avidb_messages_p2019_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_05_station_id_idx;


--
-- TOC entry 6717 (class 0 OID 0)
-- Name: avidb_messages_p2019_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_06_created_idx;


--
-- TOC entry 6718 (class 0 OID 0)
-- Name: avidb_messages_p2019_06_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_06_message_time_type_id_station_id_idx;


--
-- TOC entry 6719 (class 0 OID 0)
-- Name: avidb_messages_p2019_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_06_station_id_idx;


--
-- TOC entry 6720 (class 0 OID 0)
-- Name: avidb_messages_p2019_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_07_created_idx;


--
-- TOC entry 6721 (class 0 OID 0)
-- Name: avidb_messages_p2019_07_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_07_message_time_type_id_station_id_idx;


--
-- TOC entry 6722 (class 0 OID 0)
-- Name: avidb_messages_p2019_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_07_station_id_idx;


--
-- TOC entry 6723 (class 0 OID 0)
-- Name: avidb_messages_p2019_08_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_08_created_idx;


--
-- TOC entry 6724 (class 0 OID 0)
-- Name: avidb_messages_p2019_08_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_08_message_time_type_id_station_id_idx;


--
-- TOC entry 6725 (class 0 OID 0)
-- Name: avidb_messages_p2019_08_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_08_station_id_idx;


--
-- TOC entry 6726 (class 0 OID 0)
-- Name: avidb_messages_p2019_09_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_09_created_idx;


--
-- TOC entry 6727 (class 0 OID 0)
-- Name: avidb_messages_p2019_09_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_09_message_time_type_id_station_id_idx;


--
-- TOC entry 6728 (class 0 OID 0)
-- Name: avidb_messages_p2019_09_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_09_station_id_idx;


--
-- TOC entry 6729 (class 0 OID 0)
-- Name: avidb_messages_p2019_10_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_10_created_idx;


--
-- TOC entry 6730 (class 0 OID 0)
-- Name: avidb_messages_p2019_10_message_time_type_id_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_10_message_time_type_id_station_id_idx;


--
-- TOC entry 6731 (class 0 OID 0)
-- Name: avidb_messages_p2019_10_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_10_station_id_idx;


--
-- TOC entry 6732 (class 0 OID 0)
-- Name: avidb_messages_p2019_11_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_11_created_idx;


--
-- TOC entry 6733 (class 0 OID 0)
-- Name: avidb_messages_p2019_11_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_11_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6734 (class 0 OID 0)
-- Name: avidb_messages_p2019_11_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_11_station_id_idx;


--
-- TOC entry 6735 (class 0 OID 0)
-- Name: avidb_messages_p2019_12_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2019_12_created_idx;


--
-- TOC entry 6736 (class 0 OID 0)
-- Name: avidb_messages_p2019_12_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2019_12_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6737 (class 0 OID 0)
-- Name: avidb_messages_p2019_12_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2019_12_station_id_idx;


--
-- TOC entry 6738 (class 0 OID 0)
-- Name: avidb_messages_p2020_01_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_01_created_idx;


--
-- TOC entry 6739 (class 0 OID 0)
-- Name: avidb_messages_p2020_01_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_01_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6740 (class 0 OID 0)
-- Name: avidb_messages_p2020_01_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_01_station_id_idx;


--
-- TOC entry 6741 (class 0 OID 0)
-- Name: avidb_messages_p2020_02_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_02_created_idx;


--
-- TOC entry 6742 (class 0 OID 0)
-- Name: avidb_messages_p2020_02_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_02_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6743 (class 0 OID 0)
-- Name: avidb_messages_p2020_02_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_02_station_id_idx;


--
-- TOC entry 6744 (class 0 OID 0)
-- Name: avidb_messages_p2020_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_03_created_idx;


--
-- TOC entry 6745 (class 0 OID 0)
-- Name: avidb_messages_p2020_03_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_03_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6746 (class 0 OID 0)
-- Name: avidb_messages_p2020_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_03_station_id_idx;


--
-- TOC entry 6747 (class 0 OID 0)
-- Name: avidb_messages_p2020_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_04_created_idx;


--
-- TOC entry 6748 (class 0 OID 0)
-- Name: avidb_messages_p2020_04_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_04_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6749 (class 0 OID 0)
-- Name: avidb_messages_p2020_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_04_station_id_idx;


--
-- TOC entry 6750 (class 0 OID 0)
-- Name: avidb_messages_p2020_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_05_created_idx;


--
-- TOC entry 6751 (class 0 OID 0)
-- Name: avidb_messages_p2020_05_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_05_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6752 (class 0 OID 0)
-- Name: avidb_messages_p2020_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_05_station_id_idx;


--
-- TOC entry 6753 (class 0 OID 0)
-- Name: avidb_messages_p2020_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_06_created_idx;


--
-- TOC entry 6754 (class 0 OID 0)
-- Name: avidb_messages_p2020_06_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_06_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6755 (class 0 OID 0)
-- Name: avidb_messages_p2020_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_06_station_id_idx;


--
-- TOC entry 6756 (class 0 OID 0)
-- Name: avidb_messages_p2020_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_07_created_idx;


--
-- TOC entry 6757 (class 0 OID 0)
-- Name: avidb_messages_p2020_07_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_07_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6758 (class 0 OID 0)
-- Name: avidb_messages_p2020_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_07_station_id_idx;


--
-- TOC entry 6759 (class 0 OID 0)
-- Name: avidb_messages_p2020_08_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_08_created_idx;


--
-- TOC entry 6760 (class 0 OID 0)
-- Name: avidb_messages_p2020_08_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_08_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6761 (class 0 OID 0)
-- Name: avidb_messages_p2020_08_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_08_station_id_idx;


--
-- TOC entry 6762 (class 0 OID 0)
-- Name: avidb_messages_p2020_09_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_09_created_idx;


--
-- TOC entry 6763 (class 0 OID 0)
-- Name: avidb_messages_p2020_09_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_09_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6764 (class 0 OID 0)
-- Name: avidb_messages_p2020_09_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_09_station_id_idx;


--
-- TOC entry 6765 (class 0 OID 0)
-- Name: avidb_messages_p2020_10_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_10_created_idx;


--
-- TOC entry 6766 (class 0 OID 0)
-- Name: avidb_messages_p2020_10_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_10_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6767 (class 0 OID 0)
-- Name: avidb_messages_p2020_10_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_10_station_id_idx;


--
-- TOC entry 6768 (class 0 OID 0)
-- Name: avidb_messages_p2020_11_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_11_created_idx;


--
-- TOC entry 6769 (class 0 OID 0)
-- Name: avidb_messages_p2020_11_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_11_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6770 (class 0 OID 0)
-- Name: avidb_messages_p2020_11_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_11_station_id_idx;


--
-- TOC entry 6771 (class 0 OID 0)
-- Name: avidb_messages_p2020_12_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2020_12_created_idx;


--
-- TOC entry 6772 (class 0 OID 0)
-- Name: avidb_messages_p2020_12_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2020_12_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6773 (class 0 OID 0)
-- Name: avidb_messages_p2020_12_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2020_12_station_id_idx;


--
-- TOC entry 6774 (class 0 OID 0)
-- Name: avidb_messages_p2021_01_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_01_created_idx;


--
-- TOC entry 6775 (class 0 OID 0)
-- Name: avidb_messages_p2021_01_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_01_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6776 (class 0 OID 0)
-- Name: avidb_messages_p2021_01_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_01_station_id_idx;


--
-- TOC entry 6777 (class 0 OID 0)
-- Name: avidb_messages_p2021_02_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_02_created_idx;


--
-- TOC entry 6778 (class 0 OID 0)
-- Name: avidb_messages_p2021_02_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_02_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6779 (class 0 OID 0)
-- Name: avidb_messages_p2021_02_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_02_station_id_idx;


--
-- TOC entry 6780 (class 0 OID 0)
-- Name: avidb_messages_p2021_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_03_created_idx;


--
-- TOC entry 6781 (class 0 OID 0)
-- Name: avidb_messages_p2021_03_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_03_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6782 (class 0 OID 0)
-- Name: avidb_messages_p2021_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_03_station_id_idx;


--
-- TOC entry 6783 (class 0 OID 0)
-- Name: avidb_messages_p2021_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_04_created_idx;


--
-- TOC entry 6784 (class 0 OID 0)
-- Name: avidb_messages_p2021_04_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_04_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6785 (class 0 OID 0)
-- Name: avidb_messages_p2021_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_04_station_id_idx;


--
-- TOC entry 6786 (class 0 OID 0)
-- Name: avidb_messages_p2021_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_05_created_idx;


--
-- TOC entry 6787 (class 0 OID 0)
-- Name: avidb_messages_p2021_05_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_05_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6788 (class 0 OID 0)
-- Name: avidb_messages_p2021_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_05_station_id_idx;


--
-- TOC entry 6789 (class 0 OID 0)
-- Name: avidb_messages_p2021_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_06_created_idx;


--
-- TOC entry 6790 (class 0 OID 0)
-- Name: avidb_messages_p2021_06_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_06_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6791 (class 0 OID 0)
-- Name: avidb_messages_p2021_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_06_station_id_idx;


--
-- TOC entry 6792 (class 0 OID 0)
-- Name: avidb_messages_p2021_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_07_created_idx;


--
-- TOC entry 6793 (class 0 OID 0)
-- Name: avidb_messages_p2021_07_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_07_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6794 (class 0 OID 0)
-- Name: avidb_messages_p2021_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_07_station_id_idx;


--
-- TOC entry 6795 (class 0 OID 0)
-- Name: avidb_messages_p2021_08_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_08_created_idx;


--
-- TOC entry 6796 (class 0 OID 0)
-- Name: avidb_messages_p2021_08_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_08_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6797 (class 0 OID 0)
-- Name: avidb_messages_p2021_08_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_08_station_id_idx;


--
-- TOC entry 6798 (class 0 OID 0)
-- Name: avidb_messages_p2021_09_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_09_created_idx;


--
-- TOC entry 6799 (class 0 OID 0)
-- Name: avidb_messages_p2021_09_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_09_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6800 (class 0 OID 0)
-- Name: avidb_messages_p2021_09_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_09_station_id_idx;


--
-- TOC entry 6801 (class 0 OID 0)
-- Name: avidb_messages_p2021_10_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_10_created_idx;


--
-- TOC entry 6802 (class 0 OID 0)
-- Name: avidb_messages_p2021_10_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_10_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6803 (class 0 OID 0)
-- Name: avidb_messages_p2021_10_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_10_station_id_idx;


--
-- TOC entry 6804 (class 0 OID 0)
-- Name: avidb_messages_p2021_11_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_11_created_idx;


--
-- TOC entry 6805 (class 0 OID 0)
-- Name: avidb_messages_p2021_11_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_11_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6806 (class 0 OID 0)
-- Name: avidb_messages_p2021_11_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_11_station_id_idx;


--
-- TOC entry 6807 (class 0 OID 0)
-- Name: avidb_messages_p2021_12_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2021_12_created_idx;


--
-- TOC entry 6808 (class 0 OID 0)
-- Name: avidb_messages_p2021_12_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2021_12_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6809 (class 0 OID 0)
-- Name: avidb_messages_p2021_12_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2021_12_station_id_idx;


--
-- TOC entry 6810 (class 0 OID 0)
-- Name: avidb_messages_p2022_01_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2022_01_created_idx;


--
-- TOC entry 6811 (class 0 OID 0)
-- Name: avidb_messages_p2022_01_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2022_01_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6812 (class 0 OID 0)
-- Name: avidb_messages_p2022_01_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2022_01_station_id_idx;


--
-- TOC entry 6813 (class 0 OID 0)
-- Name: avidb_messages_p2022_02_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2022_02_created_idx;


--
-- TOC entry 6814 (class 0 OID 0)
-- Name: avidb_messages_p2022_02_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2022_02_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6815 (class 0 OID 0)
-- Name: avidb_messages_p2022_02_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2022_02_station_id_idx;


--
-- TOC entry 6816 (class 0 OID 0)
-- Name: avidb_messages_p2022_03_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2022_03_created_idx;


--
-- TOC entry 6817 (class 0 OID 0)
-- Name: avidb_messages_p2022_03_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2022_03_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6818 (class 0 OID 0)
-- Name: avidb_messages_p2022_03_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2022_03_station_id_idx;


--
-- TOC entry 6819 (class 0 OID 0)
-- Name: avidb_messages_p2022_04_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2022_04_created_idx;


--
-- TOC entry 6820 (class 0 OID 0)
-- Name: avidb_messages_p2022_04_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2022_04_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6821 (class 0 OID 0)
-- Name: avidb_messages_p2022_04_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2022_04_station_id_idx;


--
-- TOC entry 6822 (class 0 OID 0)
-- Name: avidb_messages_p2022_05_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2022_05_created_idx;


--
-- TOC entry 6823 (class 0 OID 0)
-- Name: avidb_messages_p2022_05_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2022_05_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6824 (class 0 OID 0)
-- Name: avidb_messages_p2022_05_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2022_05_station_id_idx;


--
-- TOC entry 6828 (class 0 OID 0)
-- Name: avidb_messages_p2022_06_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2022_06_created_idx;


--
-- TOC entry 6829 (class 0 OID 0)
-- Name: avidb_messages_p2022_06_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2022_06_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6830 (class 0 OID 0)
-- Name: avidb_messages_p2022_06_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2022_06_station_id_idx;


--
-- TOC entry 6835 (class 0 OID 0)
-- Name: avidb_messages_p2022_07_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_p2022_07_created_idx;


--
-- TOC entry 6836 (class 0 OID 0)
-- Name: avidb_messages_p2022_07_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_p2022_07_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6837 (class 0 OID 0)
-- Name: avidb_messages_p2022_07_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_p2022_07_station_id_idx;


--
-- TOC entry 6825 (class 0 OID 0)
-- Name: avidb_messages_pdefault_created_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_created_idx ATTACH PARTITION public.avidb_messages_pdefault_created_idx;


--
-- TOC entry 6826 (class 0 OID 0)
-- Name: avidb_messages_pdefault_message_time_type_id_station_id_for_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_idx ATTACH PARTITION public.avidb_messages_pdefault_message_time_type_id_station_id_for_idx;


--
-- TOC entry 6827 (class 0 OID 0)
-- Name: avidb_messages_pdefault_station_id_idx; Type: INDEX ATTACH; Schema: public; Owner: avidb_rw
--

ALTER INDEX public.avidb_messages_station_id_idx ATTACH PARTITION public.avidb_messages_pdefault_station_id_idx;


--
-- TOC entry 6854 (class 2620 OID 34042)
-- Name: avidb_aerodrome avidb_aerodrome_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_aerodrome_trg BEFORE INSERT OR UPDATE ON public.avidb_aerodrome FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- TOC entry 6852 (class 2620 OID 32211)
-- Name: avidb_message_routes avidb_message_routes_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_message_routes_trg BEFORE INSERT OR UPDATE ON public.avidb_message_routes FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- TOC entry 6853 (class 2620 OID 32212)
-- Name: avidb_message_types avidb_message_types_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_message_types_trg BEFORE INSERT OR UPDATE ON public.avidb_message_types FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- TOC entry 6851 (class 2620 OID 32213)
-- Name: avidb_stations avidb_stations_trg; Type: TRIGGER; Schema: public; Owner: avidb_rw
--

CREATE TRIGGER avidb_stations_trg BEFORE INSERT OR UPDATE ON public.avidb_stations FOR EACH ROW EXECUTE FUNCTION public.modified_last();


--
-- TOC entry 6850 (class 2606 OID 34043)
-- Name: avidb_aerodrome avidb_aerodrome_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_aerodrome
    ADD CONSTRAINT avidb_aerodrome_station_id_fkey FOREIGN KEY (station_id) REFERENCES public.avidb_stations(station_id);


--
-- TOC entry 6840 (class 2606 OID 24125)
-- Name: avidb_iwxxm avidb_iwxxm_fk1; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk1 FOREIGN KEY (station_id) REFERENCES public.avidb_stations(station_id) MATCH FULL;


--
-- TOC entry 6841 (class 2606 OID 24130)
-- Name: avidb_iwxxm avidb_iwxxm_fk2; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk2 FOREIGN KEY (type_id) REFERENCES public.avidb_message_types(type_id) MATCH FULL;


--
-- TOC entry 6842 (class 2606 OID 24135)
-- Name: avidb_iwxxm avidb_iwxxm_fk3; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_iwxxm
    ADD CONSTRAINT avidb_iwxxm_fk3 FOREIGN KEY (route_id) REFERENCES public.avidb_message_routes(route_id) MATCH FULL;


--
-- TOC entry 6844 (class 2606 OID 25976)
-- Name: avidb_messages avidb_messages_fk1; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk1 FOREIGN KEY (station_id) REFERENCES public.avidb_stations(station_id) MATCH FULL;


--
-- TOC entry 6845 (class 2606 OID 25982)
-- Name: avidb_messages avidb_messages_fk2; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk2 FOREIGN KEY (type_id) REFERENCES public.avidb_message_types(type_id) MATCH FULL;


--
-- TOC entry 6846 (class 2606 OID 25988)
-- Name: avidb_messages avidb_messages_fk3; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk3 FOREIGN KEY (route_id) REFERENCES public.avidb_message_routes(route_id) MATCH FULL;


--
-- TOC entry 6847 (class 2606 OID 25994)
-- Name: avidb_messages avidb_messages_fk4; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE public.avidb_messages
    ADD CONSTRAINT avidb_messages_fk4 FOREIGN KEY (format_id) REFERENCES public.avidb_message_format(format_id);


--
-- TOC entry 6843 (class 2606 OID 25666)
-- Name: avidb_messages_p2021_04 avidb_messages_p2021_04_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_messages_p2021_04
    ADD CONSTRAINT avidb_messages_p2021_04_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.avidb_message_types(type_id);


--
-- TOC entry 6848 (class 2606 OID 32729)
-- Name: avidb_rejected_message_iwxxm_details avidb_rejected_message_iwxxm_details_fk_rejected_message_id; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_message_iwxxm_details
    ADD CONSTRAINT avidb_rejected_message_iwxxm_details_fk_rejected_message_id FOREIGN KEY (rejected_message_id) REFERENCES public.avidb_rejected_messages(rejected_message_id);


--
-- TOC entry 6849 (class 2606 OID 32724)
-- Name: avidb_rejected_messages avidb_rejected_messages_fkey_format_id; Type: FK CONSTRAINT; Schema: public; Owner: avidb_rw
--

ALTER TABLE ONLY public.avidb_rejected_messages
    ADD CONSTRAINT avidb_rejected_messages_fkey_format_id FOREIGN KEY (format_id) REFERENCES public.avidb_message_format(format_id);


--
-- TOC entry 7009 (class 0 OID 0)
-- Dependencies: 1162
-- Name: FUNCTION apply_cluster(p_parent_schema text, p_parent_tablename text, p_child_schema text, p_child_tablename text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.apply_cluster(p_parent_schema text, p_parent_tablename text, p_child_schema text, p_child_tablename text) TO avidb_rw;


--
-- TOC entry 7010 (class 0 OID 0)
-- Dependencies: 1163
-- Name: FUNCTION apply_constraints(p_parent_table text, p_child_table text, p_analyze boolean, p_job_id bigint); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.apply_constraints(p_parent_table text, p_child_table text, p_analyze boolean, p_job_id bigint) TO avidb_rw;


--
-- TOC entry 7011 (class 0 OID 0)
-- Dependencies: 1164
-- Name: FUNCTION apply_foreign_keys(p_parent_table text, p_child_table text, p_job_id bigint, p_debug boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.apply_foreign_keys(p_parent_table text, p_child_table text, p_job_id bigint, p_debug boolean) TO avidb_rw;


--
-- TOC entry 7012 (class 0 OID 0)
-- Dependencies: 1165
-- Name: FUNCTION apply_privileges(p_parent_schema text, p_parent_tablename text, p_child_schema text, p_child_tablename text, p_job_id bigint); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.apply_privileges(p_parent_schema text, p_parent_tablename text, p_child_schema text, p_child_tablename text, p_job_id bigint) TO avidb_rw;


--
-- TOC entry 7013 (class 0 OID 0)
-- Dependencies: 1166
-- Name: FUNCTION apply_publications(p_parent_table text, p_child_schema text, p_child_tablename text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.apply_publications(p_parent_table text, p_child_schema text, p_child_tablename text) TO avidb_rw;


--
-- TOC entry 7014 (class 0 OID 0)
-- Dependencies: 1167
-- Name: FUNCTION autovacuum_off(p_parent_schema text, p_parent_tablename text, p_source_schema text, p_source_tablename text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.autovacuum_off(p_parent_schema text, p_parent_tablename text, p_source_schema text, p_source_tablename text) TO avidb_rw;


--
-- TOC entry 7015 (class 0 OID 0)
-- Dependencies: 1168
-- Name: FUNCTION autovacuum_reset(p_parent_schema text, p_parent_tablename text, p_source_schema text, p_source_tablename text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.autovacuum_reset(p_parent_schema text, p_parent_tablename text, p_source_schema text, p_source_tablename text) TO avidb_rw;


--
-- TOC entry 7016 (class 0 OID 0)
-- Dependencies: 1108
-- Name: FUNCTION check_automatic_maintenance_value(p_automatic_maintenance text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_automatic_maintenance_value(p_automatic_maintenance text) TO avidb_rw;


--
-- TOC entry 7017 (class 0 OID 0)
-- Dependencies: 1069
-- Name: FUNCTION check_control_type(p_parent_schema text, p_parent_tablename text, p_control text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_control_type(p_parent_schema text, p_parent_tablename text, p_control text) TO avidb_rw;


--
-- TOC entry 7018 (class 0 OID 0)
-- Dependencies: 1071
-- Name: FUNCTION check_default(p_exact_count boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_default(p_exact_count boolean) TO avidb_rw;


--
-- TOC entry 7019 (class 0 OID 0)
-- Dependencies: 1161
-- Name: FUNCTION check_epoch_type(p_type text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_epoch_type(p_type text) TO avidb_rw;


--
-- TOC entry 7020 (class 0 OID 0)
-- Dependencies: 1072
-- Name: FUNCTION check_name_length(p_object_name text, p_suffix text, p_table_partition boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_name_length(p_object_name text, p_suffix text, p_table_partition boolean) TO avidb_rw;


--
-- TOC entry 7021 (class 0 OID 0)
-- Dependencies: 1068
-- Name: FUNCTION check_partition_type(p_type text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_partition_type(p_type text) TO avidb_rw;


--
-- TOC entry 7022 (class 0 OID 0)
-- Dependencies: 1073
-- Name: FUNCTION check_subpart_sameconfig(p_parent_table text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_subpart_sameconfig(p_parent_table text) TO avidb_rw;


--
-- TOC entry 7023 (class 0 OID 0)
-- Dependencies: 1074
-- Name: FUNCTION check_subpartition_limits(p_parent_table text, p_type text, OUT sub_min text, OUT sub_max text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.check_subpartition_limits(p_parent_table text, p_type text, OUT sub_min text, OUT sub_max text) TO avidb_rw;


--
-- TOC entry 7024 (class 0 OID 0)
-- Dependencies: 1075
-- Name: FUNCTION create_function_id(p_parent_table text, p_job_id bigint); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.create_function_id(p_parent_table text, p_job_id bigint) TO avidb_rw;


--
-- TOC entry 7025 (class 0 OID 0)
-- Dependencies: 1076
-- Name: FUNCTION create_function_time(p_parent_table text, p_job_id bigint); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.create_function_time(p_parent_table text, p_job_id bigint) TO avidb_rw;


--
-- TOC entry 7026 (class 0 OID 0)
-- Dependencies: 1169
-- Name: FUNCTION create_parent(p_parent_table text, p_control text, p_type text, p_interval text, p_constraint_cols text[], p_premake integer, p_automatic_maintenance text, p_start_partition text, p_inherit_fk boolean, p_epoch text, p_upsert text, p_publications text[], p_trigger_return_null boolean, p_template_table text, p_jobmon boolean, p_date_trunc_interval text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.create_parent(p_parent_table text, p_control text, p_type text, p_interval text, p_constraint_cols text[], p_premake integer, p_automatic_maintenance text, p_start_partition text, p_inherit_fk boolean, p_epoch text, p_upsert text, p_publications text[], p_trigger_return_null boolean, p_template_table text, p_jobmon boolean, p_date_trunc_interval text) TO avidb_rw;


--
-- TOC entry 7027 (class 0 OID 0)
-- Dependencies: 1070
-- Name: FUNCTION create_partition_id(p_parent_table text, p_partition_ids bigint[], p_analyze boolean, p_start_partition text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.create_partition_id(p_parent_table text, p_partition_ids bigint[], p_analyze boolean, p_start_partition text) TO avidb_rw;


--
-- TOC entry 7028 (class 0 OID 0)
-- Dependencies: 1154
-- Name: FUNCTION create_partition_time(p_parent_table text, p_partition_times timestamp with time zone[], p_analyze boolean, p_start_partition text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.create_partition_time(p_parent_table text, p_partition_times timestamp with time zone[], p_analyze boolean, p_start_partition text) TO avidb_rw;


--
-- TOC entry 7029 (class 0 OID 0)
-- Dependencies: 1155
-- Name: FUNCTION create_sub_parent(p_top_parent text, p_control text, p_type text, p_interval text, p_native_check text, p_constraint_cols text[], p_premake integer, p_start_partition text, p_inherit_fk boolean, p_epoch text, p_upsert text, p_trigger_return_null boolean, p_jobmon boolean, p_date_trunc_interval text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.create_sub_parent(p_top_parent text, p_control text, p_type text, p_interval text, p_native_check text, p_constraint_cols text[], p_premake integer, p_start_partition text, p_inherit_fk boolean, p_epoch text, p_upsert text, p_trigger_return_null boolean, p_jobmon boolean, p_date_trunc_interval text) TO avidb_rw;


--
-- TOC entry 7030 (class 0 OID 0)
-- Dependencies: 1156
-- Name: FUNCTION create_trigger(p_parent_table text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.create_trigger(p_parent_table text) TO avidb_rw;


--
-- TOC entry 7031 (class 0 OID 0)
-- Dependencies: 1157
-- Name: FUNCTION drop_constraints(p_parent_table text, p_child_table text, p_debug boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.drop_constraints(p_parent_table text, p_child_table text, p_debug boolean) TO avidb_rw;


--
-- TOC entry 7032 (class 0 OID 0)
-- Dependencies: 1158
-- Name: FUNCTION drop_partition_column(p_parent_table text, p_column text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.drop_partition_column(p_parent_table text, p_column text) TO avidb_rw;


--
-- TOC entry 7033 (class 0 OID 0)
-- Dependencies: 1159
-- Name: FUNCTION drop_partition_id(p_parent_table text, p_retention bigint, p_keep_table boolean, p_keep_index boolean, p_retention_schema text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.drop_partition_id(p_parent_table text, p_retention bigint, p_keep_table boolean, p_keep_index boolean, p_retention_schema text) TO avidb_rw;


--
-- TOC entry 7034 (class 0 OID 0)
-- Dependencies: 1160
-- Name: FUNCTION drop_partition_time(p_parent_table text, p_retention interval, p_keep_table boolean, p_keep_index boolean, p_retention_schema text, p_reference_timestamp timestamp with time zone); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.drop_partition_time(p_parent_table text, p_retention interval, p_keep_table boolean, p_keep_index boolean, p_retention_schema text, p_reference_timestamp timestamp with time zone) TO avidb_rw;


--
-- TOC entry 7035 (class 0 OID 0)
-- Dependencies: 1077
-- Name: FUNCTION dump_partitioned_table_definition(p_parent_table text, p_ignore_template_table boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.dump_partitioned_table_definition(p_parent_table text, p_ignore_template_table boolean) TO avidb_rw;


--
-- TOC entry 7036 (class 0 OID 0)
-- Dependencies: 1146
-- Name: FUNCTION inherit_template_properties(p_parent_table text, p_child_schema text, p_child_tablename text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.inherit_template_properties(p_parent_table text, p_child_schema text, p_child_tablename text) TO avidb_rw;


--
-- TOC entry 7037 (class 0 OID 0)
-- Dependencies: 1078
-- Name: FUNCTION partition_data_id(p_parent_table text, p_batch_count integer, p_batch_interval bigint, p_lock_wait numeric, p_order text, p_analyze boolean, p_source_table text, p_ignored_columns text[]); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.partition_data_id(p_parent_table text, p_batch_count integer, p_batch_interval bigint, p_lock_wait numeric, p_order text, p_analyze boolean, p_source_table text, p_ignored_columns text[]) TO avidb_rw;


--
-- TOC entry 7038 (class 0 OID 0)
-- Dependencies: 1149
-- Name: PROCEDURE partition_data_proc(IN p_parent_table text, IN p_interval text, IN p_batch integer, IN p_wait integer, IN p_source_table text, IN p_order text, IN p_lock_wait integer, IN p_lock_wait_tries integer, IN p_quiet boolean, IN p_ignored_columns text[]); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON PROCEDURE partman.partition_data_proc(IN p_parent_table text, IN p_interval text, IN p_batch integer, IN p_wait integer, IN p_source_table text, IN p_order text, IN p_lock_wait integer, IN p_lock_wait_tries integer, IN p_quiet boolean, IN p_ignored_columns text[]) TO avidb_rw;


--
-- TOC entry 7039 (class 0 OID 0)
-- Dependencies: 1079
-- Name: FUNCTION partition_data_time(p_parent_table text, p_batch_count integer, p_batch_interval interval, p_lock_wait numeric, p_order text, p_analyze boolean, p_source_table text, p_ignored_columns text[]); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.partition_data_time(p_parent_table text, p_batch_count integer, p_batch_interval interval, p_lock_wait numeric, p_order text, p_analyze boolean, p_source_table text, p_ignored_columns text[]) TO avidb_rw;


--
-- TOC entry 7040 (class 0 OID 0)
-- Dependencies: 1147
-- Name: FUNCTION partition_gap_fill(p_parent_table text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.partition_gap_fill(p_parent_table text) TO avidb_rw;


--
-- TOC entry 7041 (class 0 OID 0)
-- Dependencies: 1150
-- Name: PROCEDURE reapply_constraints_proc(IN p_parent_table text, IN p_drop_constraints boolean, IN p_apply_constraints boolean, IN p_wait integer, IN p_dryrun boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON PROCEDURE partman.reapply_constraints_proc(IN p_parent_table text, IN p_drop_constraints boolean, IN p_apply_constraints boolean, IN p_wait integer, IN p_dryrun boolean) TO avidb_rw;


--
-- TOC entry 7042 (class 0 OID 0)
-- Dependencies: 1080
-- Name: FUNCTION reapply_privileges(p_parent_table text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.reapply_privileges(p_parent_table text) TO avidb_rw;


--
-- TOC entry 7043 (class 0 OID 0)
-- Dependencies: 1081
-- Name: FUNCTION run_maintenance(p_parent_table text, p_analyze boolean, p_jobmon boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.run_maintenance(p_parent_table text, p_analyze boolean, p_jobmon boolean) TO avidb_rw;


--
-- TOC entry 7044 (class 0 OID 0)
-- Dependencies: 1172
-- Name: PROCEDURE run_maintenance_proc(IN p_wait integer, IN p_analyze boolean, IN p_jobmon boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON PROCEDURE partman.run_maintenance_proc(IN p_wait integer, IN p_analyze boolean, IN p_jobmon boolean) TO avidb_rw;


--
-- TOC entry 7045 (class 0 OID 0)
-- Dependencies: 1082
-- Name: FUNCTION show_partition_info(p_child_table text, p_partition_interval text, p_parent_table text, OUT child_start_time timestamp with time zone, OUT child_end_time timestamp with time zone, OUT child_start_id bigint, OUT child_end_id bigint, OUT suffix text); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.show_partition_info(p_child_table text, p_partition_interval text, p_parent_table text, OUT child_start_time timestamp with time zone, OUT child_end_time timestamp with time zone, OUT child_start_id bigint, OUT child_end_id bigint, OUT suffix text) TO avidb_rw;


--
-- TOC entry 7046 (class 0 OID 0)
-- Dependencies: 1083
-- Name: FUNCTION show_partition_name(p_parent_table text, p_value text, OUT partition_schema text, OUT partition_table text, OUT suffix_timestamp timestamp with time zone, OUT suffix_id bigint, OUT table_exists boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.show_partition_name(p_parent_table text, p_value text, OUT partition_schema text, OUT partition_table text, OUT suffix_timestamp timestamp with time zone, OUT suffix_id bigint, OUT table_exists boolean) TO avidb_rw;


--
-- TOC entry 7047 (class 0 OID 0)
-- Dependencies: 1084
-- Name: FUNCTION show_partitions(p_parent_table text, p_order text, p_include_default boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.show_partitions(p_parent_table text, p_order text, p_include_default boolean) TO avidb_rw;


--
-- TOC entry 7048 (class 0 OID 0)
-- Dependencies: 1170
-- Name: FUNCTION stop_sub_partition(p_parent_table text, p_jobmon boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.stop_sub_partition(p_parent_table text, p_jobmon boolean) TO avidb_rw;


--
-- TOC entry 7049 (class 0 OID 0)
-- Dependencies: 1171
-- Name: FUNCTION undo_partition(p_parent_table text, p_batch_count integer, p_batch_interval text, p_keep_table boolean, p_lock_wait numeric, p_target_table text, p_ignored_columns text[], p_drop_cascade boolean, OUT partitions_undone integer, OUT rows_undone bigint); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON FUNCTION partman.undo_partition(p_parent_table text, p_batch_count integer, p_batch_interval text, p_keep_table boolean, p_lock_wait numeric, p_target_table text, p_ignored_columns text[], p_drop_cascade boolean, OUT partitions_undone integer, OUT rows_undone bigint) TO avidb_rw;


--
-- TOC entry 7050 (class 0 OID 0)
-- Dependencies: 1173
-- Name: PROCEDURE undo_partition_proc(IN p_parent_table text, IN p_interval text, IN p_batch integer, IN p_wait integer, IN p_target_table text, IN p_keep_table boolean, IN p_lock_wait integer, IN p_lock_wait_tries integer, IN p_quiet boolean, IN p_ignored_columns text[], IN p_drop_cascade boolean); Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON PROCEDURE partman.undo_partition_proc(IN p_parent_table text, IN p_interval text, IN p_batch integer, IN p_wait integer, IN p_target_table text, IN p_keep_table boolean, IN p_lock_wait integer, IN p_lock_wait_tries integer, IN p_quiet boolean, IN p_ignored_columns text[], IN p_drop_cascade boolean) TO avidb_rw;


--
-- TOC entry 7051 (class 0 OID 0)
-- Dependencies: 1152
-- Name: FUNCTION get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer); Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT ALL ON FUNCTION public.get_messages_for_iwxxm(cur refcursor, in_type_id integer, in_limit integer) TO avidb_iwxxm;


--
-- TOC entry 7052 (class 0 OID 0)
-- Dependencies: 1153
-- Name: FUNCTION update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer); Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT ALL ON FUNCTION public.update_converted_iwxxm(in_message_id integer, in_iwxxm_content text, in_iwxxm_errcode integer, in_iwxxm_errmsg text, in_status integer) TO avidb_iwxxm;


--
-- TOC entry 7053 (class 0 OID 0)
-- Dependencies: 334
-- Name: TABLE custom_time_partitions; Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON TABLE partman.custom_time_partitions TO avidb_rw;


--
-- TOC entry 7054 (class 0 OID 0)
-- Dependencies: 332
-- Name: TABLE part_config; Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON TABLE partman.part_config TO avidb_rw;


--
-- TOC entry 7055 (class 0 OID 0)
-- Dependencies: 333
-- Name: TABLE part_config_sub; Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON TABLE partman.part_config_sub TO avidb_rw;


--
-- TOC entry 7056 (class 0 OID 0)
-- Dependencies: 335
-- Name: TABLE table_privs; Type: ACL; Schema: partman; Owner: postgres
--

GRANT ALL ON TABLE partman.table_privs TO avidb_rw;


--
-- TOC entry 7057 (class 0 OID 0)
-- Dependencies: 315
-- Name: TABLE template_public_avidb_message_iwxxm_details; Type: ACL; Schema: partman; Owner: avidb_rw
--

GRANT SELECT ON TABLE partman.template_public_avidb_message_iwxxm_details TO avidb_ro;


--
-- TOC entry 7058 (class 0 OID 0)
-- Dependencies: 312
-- Name: TABLE template_public_avidb_messages; Type: ACL; Schema: partman; Owner: avidb_rw
--

GRANT SELECT ON TABLE partman.template_public_avidb_messages TO avidb_ro;


--
-- TOC entry 7059 (class 0 OID 0)
-- Dependencies: 336
-- Name: TABLE avidb_aerodrome; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_aerodrome TO avidb_ro;


--
-- TOC entry 7060 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE avidb_stations; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_stations TO avidb_ro;


--
-- TOC entry 7061 (class 0 OID 0)
-- Dependencies: 338
-- Name: TABLE avidb_aerodrome_iwxxm_metadata; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_aerodrome_iwxxm_metadata TO avidb_ro;


--
-- TOC entry 7062 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE avidb_iwxxm; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_iwxxm TO avidb_ro;
GRANT SELECT,UPDATE ON TABLE public.avidb_iwxxm TO avidb_iwxxm;


--
-- TOC entry 7063 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE avidb_message_format; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_format TO avidb_ro;


--
-- TOC entry 7064 (class 0 OID 0)
-- Dependencies: 314
-- Name: TABLE avidb_message_iwxxm_details; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details TO avidb_ro;


--
-- TOC entry 7065 (class 0 OID 0)
-- Dependencies: 322
-- Name: TABLE avidb_message_iwxxm_details_p0; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_p0 TO avidb_ro;


--
-- TOC entry 7066 (class 0 OID 0)
-- Dependencies: 323
-- Name: TABLE avidb_message_iwxxm_details_p10000000; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_p10000000 TO avidb_ro;


--
-- TOC entry 7067 (class 0 OID 0)
-- Dependencies: 324
-- Name: TABLE avidb_message_iwxxm_details_p20000000; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_p20000000 TO avidb_ro;


--
-- TOC entry 7068 (class 0 OID 0)
-- Dependencies: 327
-- Name: TABLE avidb_message_iwxxm_details_p30000000; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_p30000000 TO avidb_ro;


--
-- TOC entry 7069 (class 0 OID 0)
-- Dependencies: 328
-- Name: TABLE avidb_message_iwxxm_details_p40000000; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_p40000000 TO avidb_ro;


--
-- TOC entry 7070 (class 0 OID 0)
-- Dependencies: 325
-- Name: TABLE avidb_message_iwxxm_details_pdefault; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_iwxxm_details_pdefault TO avidb_ro;


--
-- TOC entry 7071 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE avidb_message_routes; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_routes TO avidb_ro;


--
-- TOC entry 7072 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE avidb_message_types; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_message_types TO avidb_ro;


--
-- TOC entry 7073 (class 0 OID 0)
-- Dependencies: 311
-- Name: TABLE avidb_messages; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages TO avidb_ro;


--
-- TOC entry 7074 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE avidb_messages_p2015_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_03 TO avidb_ro;


--
-- TOC entry 7075 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE avidb_messages_p2015_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_04 TO avidb_ro;


--
-- TOC entry 7076 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE avidb_messages_p2015_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_05 TO avidb_ro;


--
-- TOC entry 7077 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE avidb_messages_p2015_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_06 TO avidb_ro;


--
-- TOC entry 7078 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE avidb_messages_p2015_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_07 TO avidb_ro;


--
-- TOC entry 7079 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE avidb_messages_p2015_08; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_08 TO avidb_ro;


--
-- TOC entry 7080 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE avidb_messages_p2015_09; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_09 TO avidb_ro;


--
-- TOC entry 7081 (class 0 OID 0)
-- Dependencies: 233
-- Name: TABLE avidb_messages_p2015_10; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_10 TO avidb_ro;


--
-- TOC entry 7082 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE avidb_messages_p2015_11; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_11 TO avidb_ro;


--
-- TOC entry 7083 (class 0 OID 0)
-- Dependencies: 235
-- Name: TABLE avidb_messages_p2015_12; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2015_12 TO avidb_ro;


--
-- TOC entry 7084 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE avidb_messages_p2016_01; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_01 TO avidb_ro;


--
-- TOC entry 7085 (class 0 OID 0)
-- Dependencies: 237
-- Name: TABLE avidb_messages_p2016_02; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_02 TO avidb_ro;


--
-- TOC entry 7086 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE avidb_messages_p2016_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_03 TO avidb_ro;


--
-- TOC entry 7087 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE avidb_messages_p2016_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_04 TO avidb_ro;


--
-- TOC entry 7088 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE avidb_messages_p2016_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_05 TO avidb_ro;


--
-- TOC entry 7089 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE avidb_messages_p2016_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_06 TO avidb_ro;


--
-- TOC entry 7090 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE avidb_messages_p2016_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_07 TO avidb_ro;


--
-- TOC entry 7091 (class 0 OID 0)
-- Dependencies: 243
-- Name: TABLE avidb_messages_p2016_08; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_08 TO avidb_ro;


--
-- TOC entry 7092 (class 0 OID 0)
-- Dependencies: 244
-- Name: TABLE avidb_messages_p2016_09; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_09 TO avidb_ro;


--
-- TOC entry 7093 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE avidb_messages_p2016_10; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_10 TO avidb_ro;


--
-- TOC entry 7094 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE avidb_messages_p2016_11; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_11 TO avidb_ro;


--
-- TOC entry 7095 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE avidb_messages_p2016_12; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2016_12 TO avidb_ro;


--
-- TOC entry 7096 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE avidb_messages_p2017_01; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_01 TO avidb_ro;


--
-- TOC entry 7097 (class 0 OID 0)
-- Dependencies: 249
-- Name: TABLE avidb_messages_p2017_02; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_02 TO avidb_ro;


--
-- TOC entry 7098 (class 0 OID 0)
-- Dependencies: 250
-- Name: TABLE avidb_messages_p2017_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_03 TO avidb_ro;


--
-- TOC entry 7099 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE avidb_messages_p2017_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_04 TO avidb_ro;


--
-- TOC entry 7100 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE avidb_messages_p2017_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_05 TO avidb_ro;


--
-- TOC entry 7101 (class 0 OID 0)
-- Dependencies: 253
-- Name: TABLE avidb_messages_p2017_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_06 TO avidb_ro;


--
-- TOC entry 7102 (class 0 OID 0)
-- Dependencies: 254
-- Name: TABLE avidb_messages_p2017_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_07 TO avidb_ro;


--
-- TOC entry 7103 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE avidb_messages_p2017_08; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_08 TO avidb_ro;


--
-- TOC entry 7104 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE avidb_messages_p2017_09; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_09 TO avidb_ro;


--
-- TOC entry 7105 (class 0 OID 0)
-- Dependencies: 257
-- Name: TABLE avidb_messages_p2017_10; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_10 TO avidb_ro;


--
-- TOC entry 7106 (class 0 OID 0)
-- Dependencies: 258
-- Name: TABLE avidb_messages_p2017_11; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_11 TO avidb_ro;


--
-- TOC entry 7107 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE avidb_messages_p2017_12; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2017_12 TO avidb_ro;


--
-- TOC entry 7108 (class 0 OID 0)
-- Dependencies: 260
-- Name: TABLE avidb_messages_p2018_01; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_01 TO avidb_ro;


--
-- TOC entry 7109 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE avidb_messages_p2018_02; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_02 TO avidb_ro;


--
-- TOC entry 7110 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE avidb_messages_p2018_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_03 TO avidb_ro;


--
-- TOC entry 7111 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE avidb_messages_p2018_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_04 TO avidb_ro;


--
-- TOC entry 7112 (class 0 OID 0)
-- Dependencies: 264
-- Name: TABLE avidb_messages_p2018_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_05 TO avidb_ro;


--
-- TOC entry 7113 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE avidb_messages_p2018_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_06 TO avidb_ro;


--
-- TOC entry 7114 (class 0 OID 0)
-- Dependencies: 266
-- Name: TABLE avidb_messages_p2018_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_07 TO avidb_ro;


--
-- TOC entry 7115 (class 0 OID 0)
-- Dependencies: 267
-- Name: TABLE avidb_messages_p2018_08; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_08 TO avidb_ro;


--
-- TOC entry 7116 (class 0 OID 0)
-- Dependencies: 268
-- Name: TABLE avidb_messages_p2018_09; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_09 TO avidb_ro;


--
-- TOC entry 7117 (class 0 OID 0)
-- Dependencies: 269
-- Name: TABLE avidb_messages_p2018_10; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_10 TO avidb_ro;


--
-- TOC entry 7118 (class 0 OID 0)
-- Dependencies: 270
-- Name: TABLE avidb_messages_p2018_11; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_11 TO avidb_ro;


--
-- TOC entry 7119 (class 0 OID 0)
-- Dependencies: 271
-- Name: TABLE avidb_messages_p2018_12; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2018_12 TO avidb_ro;


--
-- TOC entry 7120 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE avidb_messages_p2019_01; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_01 TO avidb_ro;


--
-- TOC entry 7121 (class 0 OID 0)
-- Dependencies: 273
-- Name: TABLE avidb_messages_p2019_02; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_02 TO avidb_ro;


--
-- TOC entry 7122 (class 0 OID 0)
-- Dependencies: 274
-- Name: TABLE avidb_messages_p2019_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_03 TO avidb_ro;


--
-- TOC entry 7123 (class 0 OID 0)
-- Dependencies: 275
-- Name: TABLE avidb_messages_p2019_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_04 TO avidb_ro;


--
-- TOC entry 7124 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE avidb_messages_p2019_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_05 TO avidb_ro;


--
-- TOC entry 7125 (class 0 OID 0)
-- Dependencies: 277
-- Name: TABLE avidb_messages_p2019_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_06 TO avidb_ro;


--
-- TOC entry 7126 (class 0 OID 0)
-- Dependencies: 278
-- Name: TABLE avidb_messages_p2019_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_07 TO avidb_ro;


--
-- TOC entry 7127 (class 0 OID 0)
-- Dependencies: 279
-- Name: TABLE avidb_messages_p2019_08; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_08 TO avidb_ro;


--
-- TOC entry 7128 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE avidb_messages_p2019_09; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_09 TO avidb_ro;


--
-- TOC entry 7129 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE avidb_messages_p2019_10; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_10 TO avidb_ro;


--
-- TOC entry 7130 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE avidb_messages_p2019_11; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_11 TO avidb_ro;


--
-- TOC entry 7131 (class 0 OID 0)
-- Dependencies: 283
-- Name: TABLE avidb_messages_p2019_12; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2019_12 TO avidb_ro;


--
-- TOC entry 7132 (class 0 OID 0)
-- Dependencies: 284
-- Name: TABLE avidb_messages_p2020_01; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_01 TO avidb_ro;


--
-- TOC entry 7133 (class 0 OID 0)
-- Dependencies: 285
-- Name: TABLE avidb_messages_p2020_02; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_02 TO avidb_ro;


--
-- TOC entry 7134 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE avidb_messages_p2020_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_03 TO avidb_ro;


--
-- TOC entry 7135 (class 0 OID 0)
-- Dependencies: 287
-- Name: TABLE avidb_messages_p2020_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_04 TO avidb_ro;


--
-- TOC entry 7136 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE avidb_messages_p2020_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_05 TO avidb_ro;


--
-- TOC entry 7137 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE avidb_messages_p2020_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_06 TO avidb_ro;


--
-- TOC entry 7138 (class 0 OID 0)
-- Dependencies: 290
-- Name: TABLE avidb_messages_p2020_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_07 TO avidb_ro;


--
-- TOC entry 7139 (class 0 OID 0)
-- Dependencies: 291
-- Name: TABLE avidb_messages_p2020_08; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_08 TO avidb_ro;


--
-- TOC entry 7140 (class 0 OID 0)
-- Dependencies: 292
-- Name: TABLE avidb_messages_p2020_09; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_09 TO avidb_ro;


--
-- TOC entry 7141 (class 0 OID 0)
-- Dependencies: 293
-- Name: TABLE avidb_messages_p2020_10; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_10 TO avidb_ro;


--
-- TOC entry 7142 (class 0 OID 0)
-- Dependencies: 294
-- Name: TABLE avidb_messages_p2020_11; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_11 TO avidb_ro;


--
-- TOC entry 7143 (class 0 OID 0)
-- Dependencies: 295
-- Name: TABLE avidb_messages_p2020_12; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2020_12 TO avidb_ro;


--
-- TOC entry 7144 (class 0 OID 0)
-- Dependencies: 296
-- Name: TABLE avidb_messages_p2021_01; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_01 TO avidb_ro;


--
-- TOC entry 7145 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE avidb_messages_p2021_02; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_02 TO avidb_ro;


--
-- TOC entry 7146 (class 0 OID 0)
-- Dependencies: 298
-- Name: TABLE avidb_messages_p2021_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_03 TO avidb_ro;


--
-- TOC entry 7147 (class 0 OID 0)
-- Dependencies: 299
-- Name: TABLE avidb_messages_p2021_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_04 TO avidb_ro;


--
-- TOC entry 7148 (class 0 OID 0)
-- Dependencies: 300
-- Name: TABLE avidb_messages_p2021_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_05 TO avidb_ro;


--
-- TOC entry 7149 (class 0 OID 0)
-- Dependencies: 301
-- Name: TABLE avidb_messages_p2021_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_06 TO avidb_ro;


--
-- TOC entry 7150 (class 0 OID 0)
-- Dependencies: 302
-- Name: TABLE avidb_messages_p2021_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_07 TO avidb_ro;


--
-- TOC entry 7151 (class 0 OID 0)
-- Dependencies: 303
-- Name: TABLE avidb_messages_p2021_08; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_08 TO avidb_ro;


--
-- TOC entry 7152 (class 0 OID 0)
-- Dependencies: 304
-- Name: TABLE avidb_messages_p2021_09; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_09 TO avidb_ro;


--
-- TOC entry 7153 (class 0 OID 0)
-- Dependencies: 305
-- Name: TABLE avidb_messages_p2021_10; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_10 TO avidb_ro;


--
-- TOC entry 7154 (class 0 OID 0)
-- Dependencies: 306
-- Name: TABLE avidb_messages_p2021_11; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_11 TO avidb_ro;


--
-- TOC entry 7155 (class 0 OID 0)
-- Dependencies: 307
-- Name: TABLE avidb_messages_p2021_12; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2021_12 TO avidb_ro;


--
-- TOC entry 7156 (class 0 OID 0)
-- Dependencies: 308
-- Name: TABLE avidb_messages_p2022_01; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2022_01 TO avidb_ro;


--
-- TOC entry 7157 (class 0 OID 0)
-- Dependencies: 309
-- Name: TABLE avidb_messages_p2022_02; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2022_02 TO avidb_ro;


--
-- TOC entry 7158 (class 0 OID 0)
-- Dependencies: 317
-- Name: TABLE avidb_messages_p2022_03; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2022_03 TO avidb_ro;


--
-- TOC entry 7159 (class 0 OID 0)
-- Dependencies: 318
-- Name: TABLE avidb_messages_p2022_04; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2022_04 TO avidb_ro;


--
-- TOC entry 7160 (class 0 OID 0)
-- Dependencies: 319
-- Name: TABLE avidb_messages_p2022_05; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2022_05 TO avidb_ro;


--
-- TOC entry 7161 (class 0 OID 0)
-- Dependencies: 321
-- Name: TABLE avidb_messages_p2022_06; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2022_06 TO avidb_ro;


--
-- TOC entry 7162 (class 0 OID 0)
-- Dependencies: 326
-- Name: TABLE avidb_messages_p2022_07; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_p2022_07 TO avidb_ro;


--
-- TOC entry 7163 (class 0 OID 0)
-- Dependencies: 320
-- Name: TABLE avidb_messages_pdefault; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_messages_pdefault TO avidb_ro;


--
-- TOC entry 7164 (class 0 OID 0)
-- Dependencies: 316
-- Name: TABLE avidb_rejected_message_iwxxm_details; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_rejected_message_iwxxm_details TO avidb_ro;


--
-- TOC entry 7165 (class 0 OID 0)
-- Dependencies: 330
-- Name: TABLE avidb_rejected_messages; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.avidb_rejected_messages TO avidb_ro;


--
-- TOC entry 7173 (class 0 OID 0)
-- Dependencies: 339
-- Name: TABLE gt_pk_metadata; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.gt_pk_metadata TO avidb_ro;


--
-- TOC entry 7174 (class 0 OID 0)
-- Dependencies: 340
-- Name: TABLE icao_fir_yhdiste; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.icao_fir_yhdiste TO avidb_ro;


--
-- TOC entry 7175 (class 0 OID 0)
-- Dependencies: 342
-- Name: TABLE icao_fir_yhdistelma; Type: ACL; Schema: public; Owner: avidb_rw
--

GRANT SELECT ON TABLE public.icao_fir_yhdistelma TO avidb_ro;


--
-- TOC entry 3501 (class 826 OID 25952)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: avidb_rw
--

ALTER DEFAULT PRIVILEGES FOR ROLE avidb_rw IN SCHEMA public GRANT SELECT ON TABLES  TO avidb_ro;


-- Completed on 2022-03-15 17:23:15 EET

--
-- PostgreSQL database dump complete
--

