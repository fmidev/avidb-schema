-- Optional icao fir schema

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

CREATE TABLE public.icao_fir_yhdiste
(
    gid       integer NOT NULL,
    region    character varying(4),
    statecode character varying(3),
    statename character varying(52),
    areageom  public.geometry(MultiPolygon, 4326)
);

ALTER TABLE public.icao_fir_yhdiste
    OWNER TO avidb_rw;

ALTER TABLE public.icao_fir_yhdiste
    ALTER COLUMN gid ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.icao_fir_yhdiste_gid_seq
START
WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    );

CREATE TABLE public.icao_fir_yhdistelma
(
    gid       integer NOT NULL,
    firname   character varying(25),
    region    character varying(4),
    icaocode  character varying(4),
    statecode character varying(3),
    statename character varying(52),
    geom      public.geometry(MultiPolygon, 4326)
);

ALTER TABLE public.icao_fir_yhdistelma
    OWNER TO avidb_rw;

ALTER TABLE public.icao_fir_yhdistelma
    ALTER COLUMN gid ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.icao_fir_yhdistelma_gid_seq
START
WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    );

ALTER TABLE ONLY public.icao_fir_yhdiste
    ADD CONSTRAINT icao_fir_yhdiste_pkey PRIMARY KEY (gid);

ALTER TABLE ONLY public.icao_fir_yhdistelma
    ADD CONSTRAINT icao_fir_yhdistelma_pkey PRIMARY KEY (gid);

GRANT SELECT ON TABLE public.icao_fir_yhdiste TO avidb_ro;

GRANT SELECT ON TABLE public.icao_fir_yhdistelma TO avidb_ro;