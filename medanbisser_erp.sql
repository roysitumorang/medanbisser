--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.2
-- Dumped by pg_dump version 9.6.2

-- Started on 2017-03-19 00:24:43 WIB

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE "medanbisser_erp";
--
-- TOC entry 2564 (class 1262 OID 16393)
-- Name: medanbisser_erp; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE "medanbisser_erp" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE "medanbisser_erp" OWNER TO "postgres";

\connect "medanbisser_erp"

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2565 (class 0 OID 0)
-- Dependencies: 3
-- Name: SCHEMA "public"; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA "public" IS 'standard public schema';


--
-- TOC entry 1 (class 3079 OID 12427)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner:
--

CREATE EXTENSION IF NOT EXISTS "plpgsql" WITH SCHEMA "pg_catalog";


--
-- TOC entry 2566 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION "plpgsql"; Type: COMMENT; Schema: -; Owner:
--

COMMENT ON EXTENSION "plpgsql" IS 'PL/pgSQL procedural language';


SET search_path = "public", pg_catalog;

--
-- TOC entry 220 (class 1255 OID 16394)
-- Name: _calc_days_in_year(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "_calc_days_in_year"("year" integer) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $$
  BEGIN
    IF (year & 3) = 0 AND ((year % 100) <> 0 OR (year % 400) = 0 AND year <> 0) THEN
      RETURN 366;
    ELSE
      RETURN 365;
    END IF;
  END;
$$;


ALTER FUNCTION "public"."_calc_days_in_year"("year" integer) OWNER TO "postgres";

--
-- TOC entry 248 (class 1255 OID 16395)
-- Name: _calc_week("date", integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "_calc_week"("qdate" "date", "behavior" integer) RETURNS integer[]
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $$
  DECLARE
    _WEEK_MONDAY_FIRST  CONSTANT integer := 1;
    _WEEK_YEAR          CONSTANT integer := 2;
    _WEEK_FIRST_WEEKDAY CONSTANT integer := 4;
    qyear         integer := EXTRACT(YEAR FROM qdate);
    qmonth        integer := EXTRACT(MONTH FROM qdate);
    qday          integer := EXTRACT(DAY FROM qdate);
    daynr         integer := EXTRACT(DOY FROM qdate);
    yday1         date    := pg_catalog.date_trunc('year', qdate);
    first_daynr   integer := 1;
    monday_first  boolean := (behavior & _WEEK_MONDAY_FIRST) <> 0;
    week_year     boolean := (behavior & _WEEK_YEAR) <> 0;
    first_weekday boolean := (behavior & _WEEK_FIRST_WEEKDAY) <> 0;
    weekday       integer := _calc_weekday(yday1, NOT monday_first);
    days          integer;
  BEGIN
    IF qmonth = 1 AND qday <= 7 - weekday THEN
      IF (NOT week_year) AND ((first_weekday AND weekday <> 0) OR (NOT first_weekday AND weekday >= 4)) THEN
        RETURN array[0, qyear];
      END IF;

      week_year := true;
      qyear := qyear - 1;
      days := _calc_days_in_year(qyear);
      first_daynr := first_daynr - days;
      weekday := (weekday + 53 * 7 - days) % 7;
    END IF;

    IF (first_weekday AND weekday <> 0) OR (NOT first_weekday AND weekday >= 4) THEN
      days := daynr - (first_daynr + (7 - weekday));
    ELSE
      days := daynr - (first_daynr - weekday);
    END IF;

    IF week_year AND days >= 52 * 7 THEN
      weekday := (weekday + _calc_days_in_year(qyear)) % 7;
      IF (NOT first_weekday AND weekday < 4) OR (first_weekday AND weekday = 0) THEN
	qyear := qyear + 1;
        RETURN array[1, qyear];
      END IF;
    END IF;

    RETURN array[days / 7 + 1, qyear];
  END;
$$;


ALTER FUNCTION "public"."_calc_week"("qdate" "date", "behavior" integer) OWNER TO "postgres";

--
-- TOC entry 249 (class 1255 OID 16396)
-- Name: _calc_weekday("date", boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "_calc_weekday"("qdate" "date", "sundayfirst" boolean) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $$
  BEGIN
    RETURN (EXTRACT(DOW FROM qdate)::integer + CASE WHEN sundayfirst THEN 0 ELSE 6 END) % 7;
  END;
$$;


ALTER FUNCTION "public"."_calc_weekday"("qdate" "date", "sundayfirst" boolean) OWNER TO "postgres";

--
-- TOC entry 222 (class 1255 OID 16397)
-- Name: _week_mode(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "_week_mode"("mode" integer) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $$
  DECLARE
    _WEEK_MONDAY_FIRST  CONSTANT integer := 1;
    _WEEK_FIRST_WEEKDAY CONSTANT integer := 4;
    week_format integer := mode & 7;
  BEGIN
    IF (week_format & _WEEK_MONDAY_FIRST) = 0 THEN
      week_format := week_format # _WEEK_FIRST_WEEKDAY;
    END IF;

    RETURN week_format;
  END;
$$;


ALTER FUNCTION "public"."_week_mode"("mode" integer) OWNER TO "postgres";

--
-- TOC entry 223 (class 1255 OID 16398)
-- Name: adddate(timestamp without time zone, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "adddate"(timestamp without time zone, integer) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 + (INTERVAL '1 day' * $2)
$_$;


ALTER FUNCTION "public"."adddate"(timestamp without time zone, integer) OWNER TO "postgres";

--
-- TOC entry 224 (class 1255 OID 16399)
-- Name: adddate(timestamp without time zone, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "adddate"(timestamp without time zone, interval) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
    SELECT $1 + $2
$_$;


ALTER FUNCTION "public"."adddate"(timestamp without time zone, interval) OWNER TO "postgres";

--
-- TOC entry 225 (class 1255 OID 16400)
-- Name: addtime(interval, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "addtime"(interval, interval) RETURNS interval
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 + $2
$_$;


ALTER FUNCTION "public"."addtime"(interval, interval) OWNER TO "postgres";

--
-- TOC entry 226 (class 1255 OID 16401)
-- Name: addtime(timestamp without time zone, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "addtime"(timestamp without time zone, interval) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 + $2
$_$;


ALTER FUNCTION "public"."addtime"(timestamp without time zone, interval) OWNER TO "postgres";

--
-- TOC entry 227 (class 1255 OID 16402)
-- Name: convert_tz(timestamp without time zone, "text", "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "convert_tz"(timestamp without time zone, "text", "text") RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN POSITION(':' IN $3) = 0 THEN
      ($1 operator(pg_catalog.||) ' ' operator(pg_catalog.||) $2)::timestamp with time zone AT TIME ZONE $3
    ELSE
      ($1 operator(pg_catalog.||) ' ' operator(pg_catalog.||) $2)::timestamp with time zone AT TIME ZONE $3::interval
    END
$_$;


ALTER FUNCTION "public"."convert_tz"(timestamp without time zone, "text", "text") OWNER TO "postgres";

--
-- TOC entry 228 (class 1255 OID 16403)
-- Name: curdate(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "curdate"() RETURNS "date"
    LANGUAGE "sql"
    AS $$
  SELECT CURRENT_DATE
$$;


ALTER FUNCTION "public"."curdate"() OWNER TO "postgres";

--
-- TOC entry 229 (class 1255 OID 16404)
-- Name: curtime(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "curtime"() RETURNS time without time zone
    LANGUAGE "sql"
    AS $$
  SELECT LOCALTIME(0)
$$;


ALTER FUNCTION "public"."curtime"() OWNER TO "postgres";

--
-- TOC entry 230 (class 1255 OID 16405)
-- Name: date_add(timestamp without time zone, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "date_add"(timestamp without time zone, interval) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 + $2
$_$;


ALTER FUNCTION "public"."date_add"(timestamp without time zone, interval) OWNER TO "postgres";

--
-- TOC entry 250 (class 1255 OID 16406)
-- Name: date_format(timestamp without time zone, "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "date_format"(timestamp without time zone, "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $_$
  DECLARE
    i int := 1;
    temp text := '';
    c text;
    n text;
    res text;
  BEGIN
    WHILE i <= pg_catalog.length($2) LOOP
      -- Look at current character
      c := SUBSTRING ($2 FROM i FOR 1);
      -- If it's a '%' and not the last character then process it as a placeholder
      IF c = '%' AND i != pg_catalog.length($2) THEN
        n := SUBSTRING ($2 FROM (i + 1) FOR 1);
        SELECT INTO res CASE
          WHEN n = 'a' THEN pg_catalog.to_char($1, 'Dy')
          WHEN n = 'b' THEN pg_catalog.to_char($1, 'Mon')
          WHEN n = 'c' THEN pg_catalog.to_char($1, 'FMMM')
          WHEN n = 'D' THEN pg_catalog.to_char($1, 'FMDDth')
          WHEN n = 'd' THEN pg_catalog.to_char($1, 'DD')
          WHEN n = 'e' THEN pg_catalog.to_char($1, 'FMDD')
          WHEN n = 'f' THEN pg_catalog.to_char($1, 'US')
          WHEN n = 'H' THEN pg_catalog.to_char($1, 'HH24')
          WHEN n = 'h' THEN pg_catalog.to_char($1, 'HH12')
          WHEN n = 'I' THEN pg_catalog.to_char($1, 'HH12')
          WHEN n = 'i' THEN pg_catalog.to_char($1, 'MI')
          WHEN n = 'j' THEN pg_catalog.to_char($1, 'DDD')
          WHEN n = 'k' THEN pg_catalog.to_char($1, 'FMHH24')
          WHEN n = 'l' THEN pg_catalog.to_char($1, 'FMHH12')
          WHEN n = 'M' THEN pg_catalog.to_char($1, 'FMMonth')
          WHEN n = 'm' THEN pg_catalog.to_char($1, 'MM')
          WHEN n = 'p' THEN pg_catalog.to_char($1, 'AM')
          WHEN n = 'r' THEN pg_catalog.to_char($1, 'HH12:MI:SS AM')
          WHEN n = 'S' THEN pg_catalog.to_char($1, 'SS')
          WHEN n = 's' THEN pg_catalog.to_char($1, 'SS')
          WHEN n = 'T' THEN pg_catalog.to_char($1, 'HH24:MI:SS')
          WHEN n = 'U' THEN pg_catalog.lpad(week($1::date, 0)::text, 2, '0')
          WHEN n = 'u' THEN pg_catalog.lpad(week($1::date, 1)::text, 2, '0')
          WHEN n = 'V' THEN pg_catalog.lpad(week($1::date, 2)::text, 2, '0')
          WHEN n = 'v' THEN pg_catalog.lpad(week($1::date, 3)::text, 2, '0')
          WHEN n = 'W' THEN pg_catalog.to_char($1, 'FMDay')
          WHEN n = 'w' THEN EXTRACT(DOW FROM $1)::text
          WHEN n = 'X' THEN pg_catalog.lpad(((_calc_week($1::date, _week_mode(2)))[2])::text, 4, '0')
          WHEN n = 'x' THEN pg_catalog.lpad(((_calc_week($1::date, _week_mode(3)))[2])::text, 4, '0')
          WHEN n = 'Y' THEN pg_catalog.to_char($1, 'YYYY')
          WHEN n = 'y' THEN pg_catalog.to_char($1, 'YY')
          WHEN n = '%' THEN pg_catalog.to_char($1, '%')
          ELSE NULL
        END;
        temp := temp operator(pg_catalog.||) res;
        i := i + 2;
      ELSE
        -- Otherwise just append the character to the string
        temp = temp operator(pg_catalog.||) c;
        i := i + 1;
      END IF;
    END LOOP;
    RETURN temp;
  END
$_$;


ALTER FUNCTION "public"."date_format"(timestamp without time zone, "text") OWNER TO "postgres";

--
-- TOC entry 251 (class 1255 OID 16407)
-- Name: date_sub(timestamp without time zone, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "date_sub"(timestamp without time zone, interval) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - $2
$_$;


ALTER FUNCTION "public"."date_sub"(timestamp without time zone, interval) OWNER TO "postgres";

--
-- TOC entry 252 (class 1255 OID 16408)
-- Name: datediff("date", "date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "datediff"("date", "date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - $2
$_$;


ALTER FUNCTION "public"."datediff"("date", "date") OWNER TO "postgres";

--
-- TOC entry 253 (class 1255 OID 16409)
-- Name: day("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "day"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(DAY FROM DATE($1))::integer
$_$;


ALTER FUNCTION "public"."day"("date") OWNER TO "postgres";

--
-- TOC entry 254 (class 1255 OID 16410)
-- Name: dayname("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "dayname"("date") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT pg_catalog.to_char($1, 'FMDay')
$_$;


ALTER FUNCTION "public"."dayname"("date") OWNER TO "postgres";

--
-- TOC entry 255 (class 1255 OID 16411)
-- Name: dayofmonth("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "dayofmonth"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(DAY FROM DATE($1))::integer
$_$;


ALTER FUNCTION "public"."dayofmonth"("date") OWNER TO "postgres";

--
-- TOC entry 256 (class 1255 OID 16412)
-- Name: dayofweek("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "dayofweek"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(DOW FROM DATE($1))::integer + 1
$_$;


ALTER FUNCTION "public"."dayofweek"("date") OWNER TO "postgres";

--
-- TOC entry 257 (class 1255 OID 16413)
-- Name: dayofyear("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "dayofyear"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(DOY FROM DATE($1))::integer
$_$;


ALTER FUNCTION "public"."dayofyear"("date") OWNER TO "postgres";

--
-- TOC entry 258 (class 1255 OID 16414)
-- Name: from_days(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "from_days"(integer) RETURNS "date"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT ('0001-01-01'::date + $1 * INTERVAL '1 day')::date
$_$;


ALTER FUNCTION "public"."from_days"(integer) OWNER TO "postgres";

--
-- TOC entry 259 (class 1255 OID 16415)
-- Name: from_unixtime(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "from_unixtime"(bigint) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT pg_catalog.to_timestamp($1)::timestamp without time zone
$_$;


ALTER FUNCTION "public"."from_unixtime"(bigint) OWNER TO "postgres";

--
-- TOC entry 260 (class 1255 OID 16416)
-- Name: from_unixtime(bigint, "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "from_unixtime"(bigint, "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT date_format(from_unixtime($1), $2)
$_$;


ALTER FUNCTION "public"."from_unixtime"(bigint, "text") OWNER TO "postgres";

--
-- TOC entry 261 (class 1255 OID 16417)
-- Name: get_format("text", "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "get_format"("text", "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN $1 ILIKE 'DATE' THEN
      CASE WHEN $2 ILIKE 'USA' THEN '%m.%d.%Y'
      WHEN $2 ILIKE 'JIS' OR $2 ILIKE 'ISO' THEN '%Y-%m-%d'
      WHEN $2 ILIKE 'EUR' THEN '%d.%m.%Y'
      WHEN $2 ILIKE 'INTERNAL' THEN '%Y%m%d'
      ELSE NULL
      END
    WHEN $1 ILIKE 'DATETIME' THEN
      CASE WHEN $2 ILIKE 'USA' OR $2 ILIKE 'EUR' THEN '%Y-%m-%d-%H.%i.%s'
      WHEN $2 ILIKE 'JIS' OR $2 ILIKE 'ISO' THEN '%Y-%m-%d %H:%i:%s'
      WHEN $2 ILIKE 'INTERNAL' THEN '%Y%m%d%H%i%s'
      ELSE NULL
      END
    WHEN $1 ILIKE 'TIME' THEN
      CASE WHEN $2 ILIKE 'USA' THEN '%h:%i:%s %p'
      WHEN $2 ILIKE 'JIS' OR $2 ILIKE 'ISO' THEN '%H:%i:%s'
      WHEN $2 ILIKE 'EUR' THEN 'H.%i.%S'
      WHEN $2 ILIKE 'INTERNAL' THEN '%H%i%s'
      ELSE NULL
      END
    ELSE
      NULL
    END
$_$;


ALTER FUNCTION "public"."get_format"("text", "text") OWNER TO "postgres";

--
-- TOC entry 262 (class 1255 OID 16418)
-- Name: hour(interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "hour"(interval) RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT (HOUR FROM $1)::integer
$_$;


ALTER FUNCTION "public"."hour"(interval) OWNER TO "postgres";

--
-- TOC entry 263 (class 1255 OID 16419)
-- Name: last_day(timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "last_day"(timestamp without time zone) RETURNS "date"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN EXTRACT(MONTH FROM $1) = 12 THEN
      (((EXTRACT(YEAR FROM $1) + 1) operator(pg_catalog.||) '-01-01')::date - INTERVAL '1 day')::date
    ELSE
      ((EXTRACT(YEAR FROM $1) operator(pg_catalog.||) '-' operator(pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1) operator(pg_catalog.||) '-01')::date - INTERVAL '1 day')::date
    END
$_$;


ALTER FUNCTION "public"."last_day"(timestamp without time zone) OWNER TO "postgres";

--
-- TOC entry 264 (class 1255 OID 16420)
-- Name: makedate(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "makedate"(integer, integer) RETURNS "date"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT CASE WHEN $2 > 0 THEN
    (($1 operator(pg_catalog.||) '-01-01')::date + ($2 - 1) * INTERVAL '1 day')::date
  ELSE
    NULL
  END
$_$;


ALTER FUNCTION "public"."makedate"(integer, integer) OWNER TO "postgres";

--
-- TOC entry 265 (class 1255 OID 16421)
-- Name: maketime(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "maketime"(integer, integer, integer) RETURNS interval
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT ($1 operator(pg_catalog.||) ':' operator(pg_catalog.||) $2 operator(pg_catalog.||) ':' operator(pg_catalog.||) $3)::interval
$_$;


ALTER FUNCTION "public"."maketime"(integer, integer, integer) OWNER TO "postgres";

--
-- TOC entry 266 (class 1255 OID 16422)
-- Name: microsecond(time without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "microsecond"(time without time zone) RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT (EXTRACT(MICROSECONDS FROM $1))::integer % 1000000
$_$;


ALTER FUNCTION "public"."microsecond"(time without time zone) OWNER TO "postgres";

--
-- TOC entry 267 (class 1255 OID 16423)
-- Name: minute(time without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "minute"(time without time zone) RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(MINUTES FROM $1)::integer
$_$;


ALTER FUNCTION "public"."minute"(time without time zone) OWNER TO "postgres";

--
-- TOC entry 268 (class 1255 OID 16424)
-- Name: month("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "month"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(MONTH FROM DATE($1))::integer
$_$;


ALTER FUNCTION "public"."month"("date") OWNER TO "postgres";

--
-- TOC entry 269 (class 1255 OID 16425)
-- Name: monthname("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "monthname"("date") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT pg_catalog.to_char($1, 'FMMonth')
$_$;


ALTER FUNCTION "public"."monthname"("date") OWNER TO "postgres";

--
-- TOC entry 270 (class 1255 OID 16426)
-- Name: period_add(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "period_add"(integer, integer) RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $_$
  DECLARE
    period text;
    base date;
    baseyear integer;
  BEGIN
      IF pg_catalog.length($1) < 4 THEN
        period := pg_catalog.lpad($1, 4, 0);
      ELSIF pg_catalog.length($1) = 5 THEN
        period := pg_catalog.lpad($1, 6, 0);
      ELSE
        period := $1;
      END IF;

      IF pg_catalog.length(period) = 4 THEN
        baseyear := SUBSTRING(period FROM 1 FOR 2);
        IF baseyear BETWEEN 70 AND 99 THEN
          baseyear := baseyear + 1900;
        ELSE
          baseyear := baseyear + 2000;
        END IF;
        base := (baseyear operator(pg_catalog.||) '-' operator(pg_catalog.||) SUBSTRING(period FROM 3) operator(pg_catalog.||) '-01')::date;
      ELSIF pg_catalog.length(period) = 6 THEN
        base := (SUBSTRING(period FROM 1 FOR 4) operator(pg_catalog.||) '-' operator(pg_catalog.||) SUBSTRING(period FROM 5) operator(pg_catalog.||) '-01')::date;
      ELSE
        RETURN NULL;
      END IF;

      base := base + (INTERVAL '1 month' * $2);
      RETURN pg_catalog.lpad(EXTRACT(YEAR FROM base), 4, '0') operator(pg_catalog.||) pg_catalog.lpad(EXTRACT(MONTH FROM base), 2, '0');
  END
$_$;


ALTER FUNCTION "public"."period_add"(integer, integer) OWNER TO "postgres";

--
-- TOC entry 272 (class 1255 OID 16427)
-- Name: period_diff(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "period_diff"(integer, integer) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $_$
  DECLARE
    baseyear integer;
    period1 text;
    period2 text;
    months1 integer;
    months2 integer;
  BEGIN
      IF pg_catalog.length($1::text) < 4 THEN
        period1 := pg_catalog.lpad($1, 4, 0);
      ELSIF pg_catalog.length($1::text) = 5 THEN
        period1 := pg_catalog.lpad($1, 6, 0);
      ELSE
        period1 := $1;
      END IF;

      IF pg_catalog.length(period1) = 4 THEN
        baseyear := SUBSTRING(period1 FROM 1 FOR 2);
        IF baseyear BETWEEN 70 AND 99 THEN
          baseyear := baseyear + 1900;
        ELSE
          baseyear := baseyear + 2000;
        END IF;
        months1 := baseyear * 12 + SUBSTRING(period1 FROM 3)::integer;
      ELSIF pg_catalog.length(period1) = 6 THEN
        months1 := SUBSTRING(period1 FROM 1 FOR 4)::integer * 12 + SUBSTRING(period1 FROM 5)::integer;
      ELSE
        RETURN NULL;
      END IF;

      IF pg_catalog.length($2::text) < 4 THEN
        period2 := pg_catalog.lpad($2, 4, 0);
      ELSIF pg_catalog.length($2::text) = 5 THEN
        period2 := pg_catalog.lpad($2, 6, 0);
      ELSE
        period2 := $2;
      END IF;

      IF pg_catalog.length(period2) = 4 THEN
        baseyear := SUBSTRING(period2 FROM 1 FOR 2);
        IF baseyear BETWEEN 70 AND 99 THEN
          baseyear := baseyear + 1900;
        ELSE
          baseyear := baseyear + 2000;
        END IF;
        months2 := baseyear * 12 + SUBSTRING(period2 FROM 3)::integer;
      ELSIF pg_catalog.length(period2) = 6 THEN
        months2 := SUBSTRING(period2 FROM 1 FOR 4)::integer * 12 + SUBSTRING(period2 FROM 5)::integer;
      ELSE
        RETURN NULL;
      END IF;

      RETURN months1 - months2;
  END
$_$;


ALTER FUNCTION "public"."period_diff"(integer, integer) OWNER TO "postgres";

--
-- TOC entry 273 (class 1255 OID 16428)
-- Name: quarter("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "quarter"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(QUARTER FROM DATE($1))::integer
$_$;


ALTER FUNCTION "public"."quarter"("date") OWNER TO "postgres";

--
-- TOC entry 274 (class 1255 OID 16429)
-- Name: sec_to_time(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "sec_to_time"(bigint) RETURNS interval
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 * INTERVAL '1 second'
$_$;


ALTER FUNCTION "public"."sec_to_time"(bigint) OWNER TO "postgres";

--
-- TOC entry 275 (class 1255 OID 16430)
-- Name: second(interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "second"(interval) RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(SECONDS FROM $1)::integer
$_$;


ALTER FUNCTION "public"."second"(interval) OWNER TO "postgres";

--
-- TOC entry 276 (class 1255 OID 16431)
-- Name: str_to_date("text", "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "str_to_date"("text", "text") RETURNS timestamp without time zone
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $_$
  DECLARE
    i int := 1;
    temp text := '';
    c text;
    n text; res text;
  BEGIN
    WHILE i <= pg_catalog.length($2) LOOP
      -- Look at current character
      c := SUBSTRING ($2 FROM i FOR 1);
      -- If it's a '%' and not the last character then process it as a placeholder
      IF c = '%' AND i != pg_catalog.length($2) THEN
        n := SUBSTRING ($2 FROM (i + 1) FOR 1);
        SELECT INTO res CASE
          WHEN n = 'a' THEN 'Dy'
          WHEN n = 'b' THEN 'Mon'
          WHEN n = 'c' THEN 'FMMM'
          WHEN n = 'D' THEN 'FMDDth'
          WHEN n = 'd' THEN 'DD'
          WHEN n = 'e' THEN 'FMDD'
          WHEN n = 'f' THEN 'US'
          WHEN n = 'H' THEN 'HH24'
          WHEN n = 'h' THEN 'HH12'
          WHEN n = 'I' THEN 'HH12'
          WHEN n = 'i' THEN 'MI'
          WHEN n = 'j' THEN 'DDD'
          WHEN n = 'k' THEN 'FMHH24'
          WHEN n = 'l' THEN 'FMHH12'
          WHEN n = 'M' THEN 'FMMonth'
          WHEN n = 'm' THEN 'MM'
          WHEN n = 'p' THEN 'AM'
          WHEN n = 'r' THEN 'HH12:MI:SS AM'
          WHEN n = 'S' THEN 'SS'
          WHEN n = 's' THEN 'SS'
          WHEN n = 'T' THEN 'HH24:MI:SS'
          WHEN n = 'U' THEN '?'
          WHEN n = 'u' THEN '?'
          WHEN n = 'V' THEN '?'
          WHEN n = 'v' THEN '?'
          WHEN n = 'W' THEN 'FMDay'
          WHEN n = 'w' THEN '?'
          WHEN n = 'X' THEN '?'
          WHEN n = 'x' THEN '?'
          WHEN n = 'Y' THEN 'YYYY'
          WHEN n = 'y' THEN 'YY'
          WHEN n = '%' THEN '%'
          ELSE NULL
        END;
        temp := temp operator(pg_catalog.||) res;
        i := i + 2;
      ELSE
        -- Otherwise just append the character to the string
        temp = temp operator(pg_catalog.||) c;
        i := i + 1;
      END IF;
    END LOOP;
    RETURN pg_catalog.to_timestamp($1, temp)::timestamp without time zone;
  END
$_$;


ALTER FUNCTION "public"."str_to_date"("text", "text") OWNER TO "postgres";

--
-- TOC entry 277 (class 1255 OID 16432)
-- Name: subdate(timestamp without time zone, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "subdate"(timestamp without time zone, integer) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - (INTERVAL '1 day' * $2)
$_$;


ALTER FUNCTION "public"."subdate"(timestamp without time zone, integer) OWNER TO "postgres";

--
-- TOC entry 278 (class 1255 OID 16433)
-- Name: subdate(timestamp without time zone, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "subdate"(timestamp without time zone, interval) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
    SELECT $1 - $2
$_$;


ALTER FUNCTION "public"."subdate"(timestamp without time zone, interval) OWNER TO "postgres";

--
-- TOC entry 279 (class 1255 OID 16434)
-- Name: subtime(interval, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "subtime"(interval, interval) RETURNS interval
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - $2
$_$;


ALTER FUNCTION "public"."subtime"(interval, interval) OWNER TO "postgres";

--
-- TOC entry 280 (class 1255 OID 16435)
-- Name: subtime(timestamp without time zone, interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "subtime"(timestamp without time zone, interval) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - $2
$_$;


ALTER FUNCTION "public"."subtime"(timestamp without time zone, interval) OWNER TO "postgres";

--
-- TOC entry 281 (class 1255 OID 16436)
-- Name: sysdate(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "sysdate"() RETURNS timestamp without time zone
    LANGUAGE "sql"
    AS $$
  SELECT pg_catalog.timeofday()::timestamp(0) without time zone
$$;


ALTER FUNCTION "public"."sysdate"() OWNER TO "postgres";

--
-- TOC entry 282 (class 1255 OID 16437)
-- Name: time_format(interval, "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "time_format"(interval, "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $_$
  DECLARE
    i int := 1;
    temp text := '';
    c text;
    n text;
    res text;
  BEGIN
    WHILE i <= pg_catalog.length($2) LOOP
      -- Look at current character
      c := SUBSTRING ($2 FROM i FOR 1);
      -- If it's a '%' and not the last character then process it as a placeholder
      IF c = '%' AND i != pg_catalog.length($2) THEN
        n := SUBSTRING ($2 FROM (i + 1) FOR 1);
        SELECT INTO res CASE
          WHEN n = 'a' THEN '0'
          WHEN n = 'b' THEN '0'
          WHEN n = 'c' THEN '0'
          WHEN n = 'D' THEN '0'
          WHEN n = 'd' THEN '0'
          WHEN n = 'e' THEN '0'
          WHEN n = 'f' THEN pg_catalog.to_char($1, 'US')
          WHEN n = 'H' THEN pg_catalog.to_char($1, 'HH24')
          WHEN n = 'h' THEN pg_catalog.lpad(pg_catalog.to_char($1, 'HH12')::integer % 12, 2, '0')
          WHEN n = 'I' THEN pg_catalog.lpad(pg_catalog.to_char($1, 'HH12')::integer % 12, 2, '0')
          WHEN n = 'i' THEN pg_catalog.to_char($1, 'MI')
          WHEN n = 'j' THEN '0'
          WHEN n = 'k' THEN pg_catalog.to_char($1, 'FMHH24')
          WHEN n = 'l' THEN (pg_catalog.to_char($1, 'FMHH12')::integer % 12)::text
          WHEN n = 'M' THEN '0'
          WHEN n = 'm' THEN '0'
          WHEN n = 'p' THEN pg_catalog.to_char($1, 'AM')
          WHEN n = 'r' THEN pg_catalog.lpad(pg_catalog.to_char($1, 'HH12')::integer % 12, 2, '0')
                              operator(pg_catalog.||)
                              pg_catalog.to_char($1, ':MI:SS ')
                              operator(pg_catalog.||)
                              CASE WHEN pg_catalog.to_char($1, 'FMHH24')::integer <= 11 THEN 'AM' ELSE 'PM' END
          WHEN n = 'S' THEN pg_catalog.to_char($1, 'SS')
          WHEN n = 's' THEN pg_catalog.to_char($1, 'SS')
          WHEN n = 'T' THEN pg_catalog.to_char($1, 'HH24:MI:SS')
          WHEN n = 'U' THEN '0'
          WHEN n = 'u' THEN '0'
          WHEN n = 'V' THEN '0'
          WHEN n = 'v' THEN '0'
          WHEN n = 'W' THEN '0'
          WHEN n = 'w' THEN '0'
          WHEN n = 'X' THEN '0'
          WHEN n = 'x' THEN '0'
          WHEN n = 'Y' THEN '0'
          WHEN n = 'y' THEN '0'
          WHEN n = '%' THEN pg_catalog.to_char($1, '%')
          ELSE NULL
        END;
        temp := temp operator(pg_catalog.||) res;
        i := i + 2;
      ELSE
        -- Otherwise just append the character to the string
        temp = temp operator(pg_catalog.||) c;
        i := i + 1;
      END IF;
    END LOOP;
    RETURN temp;
  END
$_$;


ALTER FUNCTION "public"."time_format"(interval, "text") OWNER TO "postgres";

--
-- TOC entry 283 (class 1255 OID 16438)
-- Name: time_to_sec(interval); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "time_to_sec"(interval) RETURNS bigint
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(epoch FROM $1)::bigint
$_$;


ALTER FUNCTION "public"."time_to_sec"(interval) OWNER TO "postgres";

--
-- TOC entry 284 (class 1255 OID 16439)
-- Name: timediff(time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "timediff"(time without time zone, time without time zone) RETURNS interval
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - $2
$_$;


ALTER FUNCTION "public"."timediff"(time without time zone, time without time zone) OWNER TO "postgres";

--
-- TOC entry 285 (class 1255 OID 16440)
-- Name: timediff(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "timediff"(timestamp without time zone, timestamp without time zone) RETURNS interval
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - $2
$_$;


ALTER FUNCTION "public"."timediff"(timestamp without time zone, timestamp without time zone) OWNER TO "postgres";

--
-- TOC entry 286 (class 1255 OID 16441)
-- Name: timestampadd("text", integer, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "timestampadd"("text", integer, timestamp without time zone) RETURNS timestamp without time zone
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $3 + ($2 operator(pg_catalog.||) ' ' operator(pg_catalog.||) $1)::interval
$_$;


ALTER FUNCTION "public"."timestampadd"("text", integer, timestamp without time zone) OWNER TO "postgres";

--
-- TOC entry 287 (class 1255 OID 16442)
-- Name: timestampdiff("text", timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "timestampdiff"("text", timestamp without time zone, timestamp without time zone) RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT CEIL(EXTRACT(epoch FROM ($3 - $2)) / EXTRACT(epoch FROM ('1 ' operator(pg_catalog.||) $1)::interval))::integer
$_$;


ALTER FUNCTION "public"."timestampdiff"("text", timestamp without time zone, timestamp without time zone) OWNER TO "postgres";

--
-- TOC entry 288 (class 1255 OID 16443)
-- Name: to_days("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "to_days"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT $1 - '0001-01-01'::date
$_$;


ALTER FUNCTION "public"."to_days"("date") OWNER TO "postgres";

--
-- TOC entry 289 (class 1255 OID 16444)
-- Name: unix_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "unix_timestamp"() RETURNS bigint
    LANGUAGE "sql"
    AS $$
  SELECT EXTRACT(EPOCH FROM LOCALTIMESTAMP)::bigint
$$;


ALTER FUNCTION "public"."unix_timestamp"() OWNER TO "postgres";

--
-- TOC entry 290 (class 1255 OID 16445)
-- Name: unix_timestamp(timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "unix_timestamp"(timestamp without time zone) RETURNS bigint
    LANGUAGE "sql"
    AS $_$
  SELECT EXTRACT(EPOCH FROM $1)::bigint
$_$;


ALTER FUNCTION "public"."unix_timestamp"(timestamp without time zone) OWNER TO "postgres";

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 185 (class 1259 OID 16446)
-- Name: posts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "posts" (
    "id" bigint NOT NULL,
    "title" character varying(255),
    "body" "text",
    "url_alias" character varying(255),
    "menu_order" integer,
    "link" character varying(255),
    "created_by" bigint,
    "created_ip" character varying(255),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(255),
    "modified_at" timestamp without time zone
);


ALTER TABLE "posts" OWNER TO "postgres";

--
-- TOC entry 291 (class 1255 OID 16452)
-- Name: uri("posts"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "uri"("posts") RETURNS "text"
    LANGUAGE "sql"
    AS $_$ SELECT '/read/' || DATE_FORMAT($1.created_at, '%Y/%m/%d') || '/' || $1.id || '-' || REPLACE(LOWER($1.title), ' ', '-') $_$;


ALTER FUNCTION "public"."uri"("posts") OWNER TO "postgres";

--
-- TOC entry 292 (class 1255 OID 16453)
-- Name: utc_date(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "utc_date"() RETURNS "date"
    LANGUAGE "sql"
    AS $$
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date
$$;


ALTER FUNCTION "public"."utc_date"() OWNER TO "postgres";

--
-- TOC entry 293 (class 1255 OID 16454)
-- Name: utc_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "utc_time"() RETURNS time without time zone
    LANGUAGE "sql"
    AS $$
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::time(0)
$$;


ALTER FUNCTION "public"."utc_time"() OWNER TO "postgres";

--
-- TOC entry 231 (class 1255 OID 16455)
-- Name: utc_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "utc_timestamp"() RETURNS timestamp without time zone
    LANGUAGE "sql"
    AS $$
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::timestamp(0)
$$;


ALTER FUNCTION "public"."utc_timestamp"() OWNER TO "postgres";

--
-- TOC entry 232 (class 1255 OID 16456)
-- Name: week("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "week"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT week($1, 0);
$_$;


ALTER FUNCTION "public"."week"("date") OWNER TO "postgres";

--
-- TOC entry 233 (class 1255 OID 16457)
-- Name: week("date", integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "week"("date", integer) RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT (_calc_week($1, _week_mode($2)))[1];
$_$;


ALTER FUNCTION "public"."week"("date", integer) OWNER TO "postgres";

--
-- TOC entry 234 (class 1255 OID 16458)
-- Name: weekday("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "weekday"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN EXTRACT(DOW FROM $1)::integer = 0 THEN
      6
    ELSE
      EXTRACT(DOW FROM $1)::integer - 1
    END
$_$;


ALTER FUNCTION "public"."weekday"("date") OWNER TO "postgres";

--
-- TOC entry 235 (class 1255 OID 16459)
-- Name: weekofyear("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "weekofyear"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT week($1, 3);
$_$;


ALTER FUNCTION "public"."weekofyear"("date") OWNER TO "postgres";

--
-- TOC entry 271 (class 1255 OID 16460)
-- Name: year("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "year"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT EXTRACT(YEAR FROM $1)::integer
$_$;


ALTER FUNCTION "public"."year"("date") OWNER TO "postgres";

--
-- TOC entry 221 (class 1255 OID 16461)
-- Name: yearweek("date"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "yearweek"("date") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
  SELECT yearweek($1, 0);
$_$;


ALTER FUNCTION "public"."yearweek"("date") OWNER TO "postgres";

--
-- TOC entry 294 (class 1255 OID 16462)
-- Name: yearweek("date", integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "yearweek"("qdate" "date", "mode" integer) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $$
  DECLARE
    _WEEK_YEAR CONSTANT integer := 2;
    a integer[] := _calc_week(qdate, _week_mode(mode | _WEEK_YEAR));
    week integer := a[1];
    year integer := a[2];
  BEGIN
    RETURN week + year * 100;
  END;
$$;


ALTER FUNCTION "public"."yearweek"("qdate" "date", "mode" integer) OWNER TO "postgres";

--
-- TOC entry 186 (class 1259 OID 16463)
-- Name: cashes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "cashes" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "period_id" bigint NOT NULL,
    "dop" "date",
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "cashes" OWNER TO "postgres";

--
-- TOC entry 187 (class 1259 OID 16466)
-- Name: cashes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "cashes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "cashes_id_seq" OWNER TO "postgres";

--
-- TOC entry 2567 (class 0 OID 0)
-- Dependencies: 187
-- Name: cashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "cashes_id_seq" OWNED BY "cashes"."id";


--
-- TOC entry 188 (class 1259 OID 16468)
-- Name: expenses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "expenses" (
    "id" bigint NOT NULL,
    "dot" "date" NOT NULL,
    "amount" integer NOT NULL,
    "description" "text",
    "created_by" bigint,
    "created_ip" character varying(255),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(255),
    "modified_at" timestamp without time zone
);


ALTER TABLE "expenses" OWNER TO "postgres";

--
-- TOC entry 189 (class 1259 OID 16474)
-- Name: expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "expenses_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "expenses_id_seq" OWNER TO "postgres";

--
-- TOC entry 2568 (class 0 OID 0)
-- Dependencies: 189
-- Name: expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "expenses_id_seq" OWNED BY "expenses"."id";


--
-- TOC entry 190 (class 1259 OID 16476)
-- Name: meetups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "meetups" (
    "id" bigint NOT NULL,
    "period_id" bigint,
    "user_id" bigint,
    "created_by" bigint,
    "created_ip" character varying(255),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(255),
    "modified_at" timestamp without time zone
);


ALTER TABLE "meetups" OWNER TO "postgres";

--
-- TOC entry 191 (class 1259 OID 16482)
-- Name: meetups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "meetups_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "meetups_id_seq" OWNER TO "postgres";

--
-- TOC entry 2569 (class 0 OID 0)
-- Dependencies: 191
-- Name: meetups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "meetups_id_seq" OWNED BY "meetups"."id";


--
-- TOC entry 192 (class 1259 OID 16484)
-- Name: modules; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "modules" (
    "id" bigint NOT NULL,
    "name" character varying(20) NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "modules" OWNER TO "postgres";

--
-- TOC entry 193 (class 1259 OID 16487)
-- Name: modules_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "modules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "modules_id_seq" OWNER TO "postgres";

--
-- TOC entry 2570 (class 0 OID 0)
-- Dependencies: 193
-- Name: modules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "modules_id_seq" OWNED BY "modules"."id";


--
-- TOC entry 194 (class 1259 OID 16489)
-- Name: mv_cashes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "mv_cashes" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "year_id" bigint NOT NULL,
    "01" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "02" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "03" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "04" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "05" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "06" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "07" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "08" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "09" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "10" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "11" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "12" character varying(3) DEFAULT 'x'::character varying NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone,
    CONSTRAINT "mv_cashes_01_check" CHECK ((("01")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_02_check" CHECK ((("02")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_03_check" CHECK ((("03")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_04_check" CHECK ((("04")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_05_check" CHECK ((("05")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_06_check" CHECK ((("06")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_07_check" CHECK ((("07")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_08_check" CHECK ((("08")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_09_check" CHECK ((("09")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_10_check" CHECK ((("10")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_11_check" CHECK ((("11")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"]))),
    CONSTRAINT "mv_cashes_12_check" CHECK ((("12")::"text" = ANY (ARRAY[('x'::character varying)::"text", ('0'::character varying)::"text", ('-10'::character varying)::"text", ('10'::character varying)::"text"])))
);


ALTER TABLE "mv_cashes" OWNER TO "postgres";

--
-- TOC entry 195 (class 1259 OID 16516)
-- Name: mv_cashes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "mv_cashes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "mv_cashes_id_seq" OWNER TO "postgres";

--
-- TOC entry 2571 (class 0 OID 0)
-- Dependencies: 195
-- Name: mv_cashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "mv_cashes_id_seq" OWNED BY "mv_cashes"."id";


--
-- TOC entry 196 (class 1259 OID 16518)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "users" (
    "id" bigint NOT NULL,
    "hash" character(97),
    "question" character varying(40),
    "answer" character varying(40),
    "last_login" timestamp without time zone,
    "last_password_change" timestamp without time zone,
    "role_id" bigint NOT NULL,
    "first" character varying(20) NOT NULL,
    "middle" character varying(20),
    "last" character varying(20),
    "alias" character varying(20),
    "pob" character varying(50),
    "dob" "date",
    "ktp_sim" character varying(30),
    "occupation" character varying(20),
    "address" character varying(100),
    "city" character varying(60),
    "province" character varying(60),
    "email" character varying(40),
    "phone" character varying(15),
    "forbiscom_id" character varying(30),
    "join" bigint,
    "permanent" bigint,
    "resign" bigint,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "users" OWNER TO "postgres";

--
-- TOC entry 197 (class 1259 OID 16524)
-- Name: mv_last_two_years_cashes; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW "mv_last_two_years_cashes" AS
 SELECT "m"."id",
    "p"."01" AS "prev_01",
    "p"."02" AS "prev_02",
    "p"."03" AS "prev_03",
    "p"."04" AS "prev_04",
    "p"."05" AS "prev_05",
    "p"."06" AS "prev_06",
    "p"."07" AS "prev_07",
    "p"."08" AS "prev_08",
    "p"."09" AS "prev_09",
    "p"."10" AS "prev_10",
    "p"."11" AS "prev_11",
    "p"."12" AS "prev_12",
    "c"."01" AS "cur_01",
    "c"."02" AS "cur_02",
    "c"."03" AS "cur_03",
    "c"."04" AS "cur_04",
    "c"."05" AS "cur_05",
    "c"."06" AS "cur_06",
    "c"."07" AS "cur_07",
    "c"."08" AS "cur_08",
    "c"."09" AS "cur_09",
    "c"."10" AS "cur_10",
    "c"."11" AS "cur_11",
    "c"."12" AS "cur_12"
   FROM (("users" "m"
     JOIN "mv_cashes" "p" ON ((("m"."id" = "p"."user_id") AND ("p"."year_id" = ("year"(('now'::"text")::"date") - 1)))))
     JOIN "mv_cashes" "c" ON ((("m"."id" = "c"."user_id") AND ("c"."year_id" = "year"(('now'::"text")::"date")))))
  WHERE ("m"."resign" IS NULL)
  WITH NO DATA;


ALTER TABLE "mv_last_two_years_cashes" OWNER TO "postgres";

--
-- TOC entry 198 (class 1259 OID 16529)
-- Name: mv_meetups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "mv_meetups" (
    "id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "year_id" bigint NOT NULL,
    "01" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "02" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "03" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "04" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "05" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "06" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "07" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "08" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "09" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "10" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "11" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "12" character varying(8) DEFAULT '-'::character varying NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone,
    CONSTRAINT "mv_meetups_01_check" CHECK ((("01")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_02_check" CHECK ((("02")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_03_check" CHECK ((("03")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_04_check" CHECK ((("04")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_05_check" CHECK ((("05")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_06_check" CHECK ((("06")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_07_check" CHECK ((("07")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_08_check" CHECK ((("08")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_09_check" CHECK ((("09")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_10_check" CHECK ((("10")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_11_check" CHECK ((("11")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"]))),
    CONSTRAINT "mv_meetups_12_check" CHECK ((("12")::"text" = ANY (ARRAY[('-'::character varying)::"text", ('x'::character varying)::"text", ('&#x2713;'::character varying)::"text"])))
);


ALTER TABLE "mv_meetups" OWNER TO "postgres";

--
-- TOC entry 199 (class 1259 OID 16556)
-- Name: mv_last_two_years_meetups; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW "mv_last_two_years_meetups" AS
 SELECT "m"."id",
    "p"."01" AS "prev_01",
    "p"."02" AS "prev_02",
    "p"."03" AS "prev_03",
    "p"."04" AS "prev_04",
    "p"."05" AS "prev_05",
    "p"."06" AS "prev_06",
    "p"."07" AS "prev_07",
    "p"."08" AS "prev_08",
    "p"."09" AS "prev_09",
    "p"."10" AS "prev_10",
    "p"."11" AS "prev_11",
    "p"."12" AS "prev_12",
    "c"."01" AS "cur_01",
    "c"."02" AS "cur_02",
    "c"."03" AS "cur_03",
    "c"."04" AS "cur_04",
    "c"."05" AS "cur_05",
    "c"."06" AS "cur_06",
    "c"."07" AS "cur_07",
    "c"."08" AS "cur_08",
    "c"."09" AS "cur_09",
    "c"."10" AS "cur_10",
    "c"."11" AS "cur_11",
    "c"."12" AS "cur_12"
   FROM (("users" "m"
     JOIN "mv_meetups" "p" ON ((("m"."id" = "p"."user_id") AND ("p"."year_id" = ("year"(('now'::"text")::"date") - 1)))))
     JOIN "mv_meetups" "c" ON ((("m"."id" = "c"."user_id") AND ("c"."year_id" = "year"(('now'::"text")::"date")))))
  WHERE ("m"."resign" IS NULL)
  WITH NO DATA;


ALTER TABLE "mv_last_two_years_meetups" OWNER TO "postgres";

--
-- TOC entry 200 (class 1259 OID 16561)
-- Name: mv_meetups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "mv_meetups_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "mv_meetups_id_seq" OWNER TO "postgres";

--
-- TOC entry 2572 (class 0 OID 0)
-- Dependencies: 200
-- Name: mv_meetups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "mv_meetups_id_seq" OWNED BY "mv_meetups"."id";


--
-- TOC entry 201 (class 1259 OID 16563)
-- Name: post_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "post_permissions" (
    "id" bigint NOT NULL,
    "role_id" bigint NOT NULL,
    "post_id" bigint NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(255) DEFAULT NULL::character varying,
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(255) DEFAULT NULL::character varying,
    "modified_at" timestamp without time zone
);


ALTER TABLE "post_permissions" OWNER TO "postgres";

--
-- TOC entry 202 (class 1259 OID 16571)
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "role_permissions" (
    "id" bigint NOT NULL,
    "role_id" bigint NOT NULL,
    "route_id" bigint NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "role_permissions" OWNER TO "postgres";

--
-- TOC entry 203 (class 1259 OID 16574)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "roles" (
    "id" bigint NOT NULL,
    "name" character varying(10) NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "roles" OWNER TO "postgres";

--
-- TOC entry 204 (class 1259 OID 16577)
-- Name: routes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "routes" (
    "id" bigint NOT NULL,
    "request_uri_pattern" character varying(255),
    "module_id" bigint,
    "module_method" character varying(20),
    "request_method" character varying(4) NOT NULL,
    "alias_pattern" character varying(255),
    "query" character varying(4000),
    "real_request_uri" character varying(255),
    "menu_order" integer,
    "link" character varying(255),
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone,
    CONSTRAINT "routes_request_method_check" CHECK ((("request_method")::"text" = ANY (ARRAY[('GET'::character varying)::"text", ('POST'::character varying)::"text"])))
);


ALTER TABLE "routes" OWNER TO "postgres";

--
-- TOC entry 205 (class 1259 OID 16584)
-- Name: mv_role_permissions; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW "mv_role_permissions" AS
 SELECT "rp"."id",
    "rp"."role_id",
    "rl"."name" AS "role",
    "rp"."route_id",
    "rt"."request_uri_pattern",
    "mo"."id" AS "module_id",
    "mo"."name" AS "module_name",
    "rt"."module_method",
    "rt"."request_method",
    "rt"."alias_pattern",
    "rt"."query",
    "rt"."real_request_uri",
    "rt"."menu_order",
    "rt"."link"
   FROM ((("role_permissions" "rp"
     JOIN "roles" "rl" ON (("rp"."role_id" = "rl"."id")))
     JOIN "routes" "rt" ON (("rp"."route_id" = "rt"."id")))
     JOIN "modules" "mo" ON (("rt"."module_id" = "mo"."id")))
  WHERE ((("mo"."name")::"text" <> 'Posts'::"text") OR (("rt"."module_method")::"text" <> 'do_show'::"text"))
UNION
 SELECT "pp"."id",
    "pp"."role_id",
    "rl"."name" AS "role",
    "rt"."id" AS "route_id",
    ((((('read\/'::"text" || "date_format"("p"."created_at", '%Y\/%m\/%d'::"text")) || '\/(?P<id>'::"text") || "p"."id") || ')-'::"text") || "replace"("lower"(("p"."title")::"text"), ' '::"text", '-'::"text")) AS "request_uri_pattern",
    "mo"."id" AS "module_id",
    "mo"."name" AS "module_name",
    "rt"."module_method",
    "rt"."request_method",
    COALESCE("p"."url_alias", ((((('read\/'::"text" || "date_format"("p"."created_at", '%Y\/%m\/%d'::"text")) || '\/(?P<id>'::"text") || "p"."id") || ')-'::"text"))::character varying, ("replace"("lower"(("p"."title")::"text"), ' '::"text", '-'::"text"))::character varying) AS "alias_pattern",
    "rt"."query",
    "uri"("p".*) AS "real_request_uri",
    "rt"."menu_order",
    "rt"."link"
   FROM (((("post_permissions" "pp"
     JOIN "posts" "p" ON (("pp"."post_id" = "p"."id")))
     JOIN "roles" "rl" ON (("pp"."role_id" = "rl"."id")))
     JOIN "modules" "mo" ON ((("mo"."name")::"text" = 'Posts'::"text")))
     JOIN "routes" "rt" ON ((("mo"."id" = "rt"."module_id") AND (("rt"."module_method")::"text" = 'show'::"text"))))
  WITH NO DATA;


ALTER TABLE "mv_role_permissions" OWNER TO "postgres";

--
-- TOC entry 219 (class 1259 OID 17011)
-- Name: mv_users; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW "mv_users" AS
 SELECT "u"."id",
    "u"."hash",
    "u"."last_login",
    "u"."last_password_change",
    "u"."first",
    "u"."middle",
    "u"."last",
    ((("u"."first")::"text" || COALESCE((' '::"text" || ("u"."middle")::"text"), ''::"text")) || COALESCE((' '::"text" || ("u"."last")::"text"), ''::"text")) AS "full_name",
    "u"."role_id",
    "r"."name" AS "role",
    "u"."alias",
    "u"."pob",
    "u"."dob",
    "floor"((((('now'::"text")::"date" - "u"."dob"))::numeric / 365.0)) AS "age",
    "u"."ktp_sim",
    "u"."occupation",
    "u"."address",
    "u"."city",
    "u"."province",
    (((COALESCE("u"."address", ''::character varying))::"text" || COALESCE((', '::"text" || ("u"."city")::"text"), ''::"text")) || COALESCE((', '::"text" || ("u"."province")::"text"), ''::"text")) AS "full_address",
    "u"."email",
    "u"."phone",
    "u"."forbiscom_id",
    "u"."join",
    "u"."permanent",
    "u"."resign",
    "period_diff"(COALESCE(("u"."resign")::integer, ("date_format"((('now'::"text")::"date")::timestamp without time zone, '%Y%m'::"text"))::integer), ("u"."join")::integer) AS "months",
    "round"((("period_diff"(COALESCE(("u"."resign")::integer, ("date_format"((('now'::"text")::"date")::timestamp without time zone, '%Y%m'::"text"))::integer), ("u"."join")::integer) / 12))::numeric, 2) AS "years",
        CASE
            WHEN ("u"."resign" IS NULL) THEN (
            CASE
                WHEN ("u"."permanent" IS NULL) THEN 'Calon '::"text"
                ELSE ''::"text"
            END || 'Anggota Resmi'::"text")
            ELSE ('Keluar Per '::"text" || "date_format"("str_to_date"(("u"."resign")::"text", '%Y%m'::"text"), '%M %Y'::"text"))
        END AS "status",
    "mc"."last_pay_period",
    COALESCE("mc"."paid", (0)::bigint) AS "paid",
        CASE
            WHEN (("mc"."last_pay_period")::"text" >= "date_format"((('now'::"text")::"date")::timestamp without time zone, '%Y%m'::"text")) THEN 0
            ELSE "period_diff"(("date_format"((('now'::"text")::"date")::timestamp without time zone, '%Y%m'::"text"))::integer, (COALESCE(("mc"."last_pay_period")::bigint, "u"."join"))::integer)
        END AS "months_of_debt",
        CASE
            WHEN (("u"."resign" IS NOT NULL) OR (COALESCE(("mc"."last_pay_period")::bigint, "u"."join") >= ("date_format"((('now'::"text")::"date")::timestamp without time zone, '%Y%m'::"text"))::integer)) THEN 0
            ELSE ("period_diff"(("date_format"((('now'::"text")::"date")::timestamp without time zone, '%Y%m'::"text"))::integer, (COALESCE(("mc"."last_pay_period")::bigint, "u"."join"))::integer) * 10000)
        END AS "debt",
    ((("c"."first")::"text" || COALESCE((' '::"text" || ("c"."middle")::"text"), ''::"text")) || COALESCE((' '::"text" || ("c"."last")::"text"), ''::"text")) AS "created_by",
    "u"."created_ip",
    "u"."created_at",
    ((("m"."first")::"text" || COALESCE((' '::"text" || ("m"."middle")::"text"), ''::"text")) || COALESCE((' '::"text" || ("m"."last")::"text"), ''::"text")) AS "modified_by",
    "u"."modified_ip",
    "u"."modified_at"
   FROM (((("users" "u"
     JOIN "roles" "r" ON (("u"."role_id" = "r"."id")))
     LEFT JOIN ( SELECT "cashes"."user_id",
            ("max"("cashes"."period_id"))::integer AS "last_pay_period",
            ("count"(1) * 10000) AS "paid"
           FROM "cashes"
          GROUP BY "cashes"."user_id") "mc" ON (("u"."id" = "mc"."user_id")))
     LEFT JOIN "users" "c" ON (("u"."created_by" = "c"."id")))
     LEFT JOIN "users" "m" ON (("u"."modified_by" = "m"."id")))
  WITH NO DATA;


ALTER TABLE "mv_users" OWNER TO "postgres";

--
-- TOC entry 206 (class 1259 OID 16600)
-- Name: periods; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "periods" (
    "id" bigint NOT NULL,
    "year_id" bigint NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "periods" OWNER TO "postgres";

--
-- TOC entry 207 (class 1259 OID 16603)
-- Name: periods_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "periods_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "periods_id_seq" OWNER TO "postgres";

--
-- TOC entry 2573 (class 0 OID 0)
-- Dependencies: 207
-- Name: periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "periods_id_seq" OWNED BY "periods"."id";


--
-- TOC entry 208 (class 1259 OID 16605)
-- Name: post_access_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "post_access_logs" (
    "id" bigint NOT NULL,
    "post_id" bigint NOT NULL,
    "user_id" bigint,
    "hits" integer,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "post_access_logs" OWNER TO "postgres";

--
-- TOC entry 209 (class 1259 OID 16608)
-- Name: post_access_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "post_access_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "post_access_logs_id_seq" OWNER TO "postgres";

--
-- TOC entry 2574 (class 0 OID 0)
-- Dependencies: 209
-- Name: post_access_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "post_access_logs_id_seq" OWNED BY "post_access_logs"."id";


--
-- TOC entry 210 (class 1259 OID 16610)
-- Name: post_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "post_permissions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "post_permissions_id_seq" OWNER TO "postgres";

--
-- TOC entry 2575 (class 0 OID 0)
-- Dependencies: 210
-- Name: post_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "post_permissions_id_seq" OWNED BY "post_permissions"."id";


--
-- TOC entry 211 (class 1259 OID 16612)
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "posts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "posts_id_seq" OWNER TO "postgres";

--
-- TOC entry 2576 (class 0 OID 0)
-- Dependencies: 211
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "posts_id_seq" OWNED BY "posts"."id";


--
-- TOC entry 212 (class 1259 OID 16614)
-- Name: role_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "role_permissions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "role_permissions_id_seq" OWNER TO "postgres";

--
-- TOC entry 2577 (class 0 OID 0)
-- Dependencies: 212
-- Name: role_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "role_permissions_id_seq" OWNED BY "role_permissions"."id";


--
-- TOC entry 213 (class 1259 OID 16616)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "roles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "roles_id_seq" OWNER TO "postgres";

--
-- TOC entry 2578 (class 0 OID 0)
-- Dependencies: 213
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "roles_id_seq" OWNED BY "roles"."id";


--
-- TOC entry 214 (class 1259 OID 16618)
-- Name: routes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "routes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "routes_id_seq" OWNER TO "postgres";

--
-- TOC entry 2579 (class 0 OID 0)
-- Dependencies: 214
-- Name: routes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "routes_id_seq" OWNED BY "routes"."id";


--
-- TOC entry 215 (class 1259 OID 16620)
-- Name: sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "sessions" (
    "id" character(32) NOT NULL,
    "user_id" bigint,
    "ip" character varying(40),
    "data" "text",
    "last_modified" integer
);


ALTER TABLE "sessions" OWNER TO "postgres";

--
-- TOC entry 216 (class 1259 OID 16626)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "users_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "users_id_seq" OWNER TO "postgres";

--
-- TOC entry 2580 (class 0 OID 0)
-- Dependencies: 216
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "users_id_seq" OWNED BY "users"."id";


--
-- TOC entry 217 (class 1259 OID 16628)
-- Name: years; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "years" (
    "id" bigint NOT NULL,
    "created_by" bigint,
    "created_ip" character varying(40),
    "created_at" timestamp without time zone,
    "modified_by" bigint,
    "modified_ip" character varying(40),
    "modified_at" timestamp without time zone
);


ALTER TABLE "years" OWNER TO "postgres";

--
-- TOC entry 218 (class 1259 OID 16631)
-- Name: years_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "years_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "years_id_seq" OWNER TO "postgres";

--
-- TOC entry 2581 (class 0 OID 0)
-- Dependencies: 218
-- Name: years_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "years_id_seq" OWNED BY "years"."id";


--
-- TOC entry 2216 (class 2604 OID 16633)
-- Name: cashes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "cashes" ALTER COLUMN "id" SET DEFAULT "nextval"('"cashes_id_seq"'::"regclass");


--
-- TOC entry 2217 (class 2604 OID 16634)
-- Name: expenses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "expenses" ALTER COLUMN "id" SET DEFAULT "nextval"('"expenses_id_seq"'::"regclass");


--
-- TOC entry 2218 (class 2604 OID 16635)
-- Name: meetups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "meetups" ALTER COLUMN "id" SET DEFAULT "nextval"('"meetups_id_seq"'::"regclass");


--
-- TOC entry 2219 (class 2604 OID 16636)
-- Name: modules id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "modules" ALTER COLUMN "id" SET DEFAULT "nextval"('"modules_id_seq"'::"regclass");


--
-- TOC entry 2232 (class 2604 OID 16637)
-- Name: mv_cashes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_cashes" ALTER COLUMN "id" SET DEFAULT "nextval"('"mv_cashes_id_seq"'::"regclass");


--
-- TOC entry 2258 (class 2604 OID 16638)
-- Name: mv_meetups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_meetups" ALTER COLUMN "id" SET DEFAULT "nextval"('"mv_meetups_id_seq"'::"regclass");


--
-- TOC entry 2278 (class 2604 OID 16639)
-- Name: periods id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "periods" ALTER COLUMN "id" SET DEFAULT "nextval"('"periods_id_seq"'::"regclass");


--
-- TOC entry 2279 (class 2604 OID 16640)
-- Name: post_access_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_access_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"post_access_logs_id_seq"'::"regclass");


--
-- TOC entry 2273 (class 2604 OID 16641)
-- Name: post_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_permissions" ALTER COLUMN "id" SET DEFAULT "nextval"('"post_permissions_id_seq"'::"regclass");


--
-- TOC entry 2215 (class 2604 OID 16642)
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "posts" ALTER COLUMN "id" SET DEFAULT "nextval"('"posts_id_seq"'::"regclass");


--
-- TOC entry 2274 (class 2604 OID 16643)
-- Name: role_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "role_permissions" ALTER COLUMN "id" SET DEFAULT "nextval"('"role_permissions_id_seq"'::"regclass");


--
-- TOC entry 2275 (class 2604 OID 16644)
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "roles" ALTER COLUMN "id" SET DEFAULT "nextval"('"roles_id_seq"'::"regclass");


--
-- TOC entry 2276 (class 2604 OID 16645)
-- Name: routes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "routes" ALTER COLUMN "id" SET DEFAULT "nextval"('"routes_id_seq"'::"regclass");


--
-- TOC entry 2245 (class 2604 OID 16646)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users" ALTER COLUMN "id" SET DEFAULT "nextval"('"users_id_seq"'::"regclass");


--
-- TOC entry 2280 (class 2604 OID 16647)
-- Name: years id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "years" ALTER COLUMN "id" SET DEFAULT "nextval"('"years_id_seq"'::"regclass");


--
-- TOC entry 2526 (class 0 OID 16463)
-- Dependencies: 186
-- Data for Name: cashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, 1, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 1, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 1, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 1, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 1, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, 1, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, 1, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, 1, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, 1, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, 1, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (11, 1, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, 1, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, 1, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (14, 1, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (15, 1, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (16, 1, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (17, 1, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (18, 1, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (19, 1, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (20, 1, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (21, 1, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (22, 1, 201410, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (23, 1, 201411, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (24, 1, 201412, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (25, 2, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (26, 2, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (27, 2, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (28, 2, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (29, 2, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (30, 2, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (31, 2, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (32, 2, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (33, 2, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (34, 2, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (35, 2, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (36, 2, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (37, 2, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (38, 2, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (39, 2, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (40, 3, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (41, 3, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (42, 3, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (43, 3, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (44, 3, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (45, 3, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (46, 3, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (47, 3, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (48, 3, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (49, 3, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (50, 3, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (51, 3, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (52, 4, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (53, 4, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (54, 4, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (55, 4, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (56, 4, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (57, 4, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:22', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (58, 4, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:23', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (59, 4, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:23', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (60, 4, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:23', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (61, 4, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:23', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (62, 4, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (63, 4, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (64, 4, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (65, 4, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (66, 4, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (67, 4, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (68, 4, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (69, 5, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (70, 5, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (71, 5, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (72, 5, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (73, 5, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (74, 6, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (75, 6, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (76, 6, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (77, 6, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (78, 6, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (79, 6, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (80, 6, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (81, 6, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (82, 6, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (83, 7, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (84, 7, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (85, 7, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (86, 7, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (87, 7, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (88, 7, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (89, 7, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (90, 7, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (91, 7, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (92, 7, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (93, 7, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (94, 7, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (95, 7, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (96, 7, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (97, 7, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (98, 7, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (99, 7, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (100, 7, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (101, 7, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (102, 7, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (103, 7, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (104, 7, 201410, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (105, 7, 201411, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (106, 7, 201412, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (107, 8, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (108, 8, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (109, 8, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (110, 8, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (111, 8, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (112, 8, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (113, 8, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (114, 8, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (115, 8, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (116, 8, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (117, 8, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (118, 8, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (119, 8, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (120, 8, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (121, 8, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (122, 8, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:24', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (123, 8, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (124, 8, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (125, 8, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (126, 8, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (127, 8, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (128, 8, 201410, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (129, 8, 201411, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (130, 8, 201412, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (131, 9, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (132, 9, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (133, 9, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (134, 9, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (135, 9, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (136, 9, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (137, 9, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (138, 9, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (139, 9, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (140, 9, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (141, 9, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:25', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (142, 9, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (143, 9, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (144, 9, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (145, 9, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (146, 9, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (147, 9, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (148, 9, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (149, 9, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (150, 9, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (151, 9, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (152, 9, 201410, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (153, 10, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (154, 10, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (155, 10, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (156, 10, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (157, 10, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (158, 12, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (159, 12, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (160, 12, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (161, 12, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (162, 12, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (163, 12, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (164, 12, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (165, 12, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (166, 12, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (167, 12, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (168, 12, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (169, 12, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (170, 12, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (171, 12, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (172, 12, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (173, 12, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (174, 12, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (175, 12, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (176, 13, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (177, 13, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (178, 13, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (179, 13, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (180, 13, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (181, 13, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (182, 13, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (183, 13, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (184, 13, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (185, 13, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (186, 13, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (187, 13, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (188, 13, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (189, 13, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (190, 13, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (191, 13, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (192, 13, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (193, 13, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (194, 13, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (195, 13, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (196, 13, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (197, 13, 201410, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (198, 13, 201411, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (199, 13, 201412, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (200, 14, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201, 14, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (202, 14, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (203, 14, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (204, 14, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (205, 14, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (206, 14, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (207, 14, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (208, 14, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (209, 14, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (210, 14, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (211, 14, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (212, 14, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (213, 14, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (214, 15, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (215, 15, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (216, 15, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (217, 15, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (218, 15, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (219, 15, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (220, 15, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (221, 15, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (222, 15, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (223, 15, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (224, 15, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (225, 15, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (226, 15, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (227, 15, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (228, 15, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (229, 16, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (230, 16, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (231, 16, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (232, 16, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (233, 16, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (234, 16, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (235, 16, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (236, 16, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (237, 16, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (238, 16, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (239, 16, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (240, 16, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (241, 16, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (242, 16, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (243, 16, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (244, 17, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (245, 17, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (246, 17, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (247, 17, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (248, 17, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:26', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (249, 17, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (250, 17, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (251, 17, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (252, 17, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (253, 17, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (254, 17, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (255, 17, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (256, 17, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (257, 17, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (258, 17, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (259, 17, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (260, 17, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (261, 17, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (262, 17, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (263, 17, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (264, 17, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (265, 17, 201410, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (266, 17, 201411, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (267, 17, 201412, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (268, 18, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (269, 18, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (270, 18, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (271, 18, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (272, 18, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (273, 18, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (274, 18, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (275, 18, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (276, 18, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (277, 18, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (278, 18, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (279, 18, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (280, 18, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (281, 18, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (282, 18, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (283, 18, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (284, 18, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (285, 19, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (286, 19, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (287, 19, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (288, 19, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (289, 19, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (290, 19, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (291, 19, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (292, 19, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (293, 19, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (294, 19, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (295, 19, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (296, 19, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (297, 19, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (298, 19, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (299, 19, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (300, 19, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (301, 19, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (302, 19, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (303, 19, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (304, 19, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (305, 19, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (306, 20, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (307, 20, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (308, 20, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (309, 20, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (310, 20, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (311, 20, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (312, 20, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (313, 20, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (314, 20, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (315, 20, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (316, 20, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (317, 20, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (318, 20, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:27', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (319, 20, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (320, 20, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (321, 20, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (322, 22, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (323, 22, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (324, 22, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (325, 22, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (326, 22, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (327, 23, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (328, 23, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (329, 23, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (330, 23, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (331, 23, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (332, 23, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (333, 23, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (334, 23, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (335, 23, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (336, 23, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (337, 24, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (338, 24, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (339, 24, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (340, 24, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (341, 24, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (342, 24, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (343, 24, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (344, 24, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (345, 24, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (346, 24, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (347, 25, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (348, 25, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (349, 25, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (350, 25, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (351, 25, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:28', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (352, 25, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (353, 25, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (354, 26, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (355, 26, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (356, 26, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (357, 27, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (358, 27, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (359, 27, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (360, 27, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (361, 27, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (362, 27, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (363, 27, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (364, 27, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (365, 27, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (366, 27, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (367, 27, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (368, 27, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (369, 28, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (370, 28, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (371, 28, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (372, 28, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (373, 28, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (374, 28, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (375, 28, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (376, 28, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (377, 28, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (378, 28, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (379, 28, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (380, 28, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (381, 28, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (382, 29, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (383, 29, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (384, 29, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (385, 29, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (386, 29, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (387, 29, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (388, 29, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (389, 29, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (390, 29, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (391, 29, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (392, 29, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (393, 29, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (394, 29, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (395, 29, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (396, 29, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (397, 29, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (398, 30, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (399, 30, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (400, 30, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (401, 30, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (402, 30, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (403, 30, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (404, 30, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (405, 30, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (406, 30, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (407, 31, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (408, 31, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (409, 31, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (410, 31, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (411, 31, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (412, 31, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (413, 31, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (414, 32, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (415, 32, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (416, 32, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (417, 32, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (418, 32, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (419, 33, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (420, 33, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (421, 33, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (422, 33, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (423, 33, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (424, 33, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (425, 33, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (426, 33, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (427, 33, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (428, 33, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (429, 33, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (430, 33, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (431, 33, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (432, 33, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (433, 34, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (434, 34, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (435, 34, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (436, 34, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (437, 34, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (438, 36, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (439, 36, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (440, 36, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (441, 36, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (442, 36, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (443, 36, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (444, 36, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (445, 36, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (446, 36, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (447, 36, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (448, 36, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (449, 36, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (450, 36, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (451, 36, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (452, 36, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:29', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (453, 36, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (454, 36, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (455, 36, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (456, 36, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (457, 36, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (458, 36, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (459, 37, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (460, 37, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (461, 38, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (462, 38, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (463, 38, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (464, 38, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (465, 38, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (466, 38, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (467, 39, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (468, 39, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (469, 39, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (470, 39, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (471, 39, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (472, 39, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (473, 39, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (474, 39, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (475, 39, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (476, 39, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (477, 40, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (478, 40, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (479, 40, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (480, 40, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (481, 40, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (482, 40, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (483, 40, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (484, 40, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (485, 40, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (486, 40, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (487, 40, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (488, 40, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (489, 40, 201409, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (490, 41, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (491, 41, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (492, 41, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (493, 41, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (494, 41, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (495, 41, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (496, 42, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (497, 42, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (498, 42, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (499, 42, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (500, 42, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (501, 42, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (502, 42, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (503, 42, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (504, 42, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (505, 42, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (506, 42, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (507, 42, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (508, 42, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (509, 42, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (510, 42, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (511, 42, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (512, 42, 201405, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (513, 42, 201406, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (514, 42, 201407, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (515, 42, 201408, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (516, 43, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (517, 43, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:30', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (518, 43, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:31', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (519, 43, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:31', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (520, 43, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:31', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (521, 43, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:31', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (522, 43, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:31', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (523, 44, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (524, 44, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (525, 44, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (526, 44, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (527, 44, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (528, 44, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (529, 44, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (530, 44, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (531, 44, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (532, 44, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (533, 44, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (534, 44, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (535, 45, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (536, 46, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (537, 46, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (538, 46, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (539, 46, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (540, 47, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (541, 47, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (542, 48, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (543, 50, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (544, 50, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (545, 50, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (546, 50, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (547, 50, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (548, 50, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (549, 50, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (550, 50, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (551, 50, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (552, 50, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (553, 50, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (554, 50, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (555, 50, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (556, 50, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (557, 50, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (558, 52, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (559, 53, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (560, 53, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (561, 53, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (562, 53, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (563, 59, 201301, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (564, 59, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (565, 59, 201303, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (566, 59, 201304, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (567, 59, 201305, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (568, 59, 201306, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (569, 59, 201307, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (570, 59, 201308, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (571, 59, 201309, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (572, 59, 201310, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (573, 59, 201311, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (574, 59, 201312, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (575, 60, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (576, 60, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (577, 60, 201403, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (578, 60, 201404, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (579, 62, 201401, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (580, 62, 201402, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (581, 64, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (582, 65, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (583, 66, 201302, '2014-04-30', 1, '::1', '2014-05-02 17:21:32', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (584, 60, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (585, 60, 201406, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (586, 45, 201402, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (587, 45, 201403, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (588, 45, 201404, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (589, 45, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (590, 27, 201401, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (591, 27, 201402, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (592, 27, 201403, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (593, 27, 201404, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (594, 27, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (595, 2, 201404, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (596, 2, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (597, 2, 201406, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (598, 28, 201402, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (599, 28, 201403, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (600, 28, 201404, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (601, 28, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (602, 15, 201404, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (603, 15, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (604, 15, 201406, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (605, 15, 201407, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (606, 15, 201408, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (607, 31, 201404, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (608, 31, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (609, 31, 201406, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (610, 34, 201306, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (611, 34, 201307, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (612, 39, 201311, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (613, 39, 201312, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (614, 5, 201309, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (615, 5, 201310, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (616, 5, 201311, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (617, 5, 201312, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (618, 6, 201310, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (619, 6, 201311, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (620, 6, 201312, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (621, 6, 201401, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (622, 6, 201402, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (623, 23, 201311, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (624, 23, 201312, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (625, 23, 201401, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (626, 23, 201402, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (627, 62, 201403, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (628, 53, 201405, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (629, 53, 201406, '2014-05-21', 2, '202.67.44.76', '2014-05-21 02:27:19', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (630, 38, 201401, '2014-05-24', 2, '114.125.40.148', '2014-05-24 21:10:55', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (631, 38, 201402, '2014-05-24', 2, '114.125.40.148', '2014-05-24 21:10:55', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (632, 38, 201403, '2014-05-24', 2, '114.125.40.148', '2014-05-24 21:10:55', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (633, 38, 201404, '2014-05-24', 2, '114.125.40.148', '2014-05-24 21:10:55', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (634, 38, 201405, '2014-05-24', 2, '114.125.40.148', '2014-05-24 21:10:55', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (635, 37, 201309, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (636, 29, 201405, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (637, 29, 201406, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (638, 3, 201401, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (639, 3, 201402, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (640, 3, 201403, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (641, 3, 201404, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (642, 3, 201405, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (643, 3, 201406, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (644, 3, 201407, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (645, 31, 201407, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (646, 31, 201408, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (647, 33, 201403, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (648, 33, 201404, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (649, 33, 201405, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (650, 33, 201406, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (651, 34, 201308, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (652, 54, 201301, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (653, 54, 201302, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (654, 54, 201303, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (655, 16, 201404, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (656, 16, 201405, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (657, 16, 201406, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (658, 20, 201405, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (659, 20, 201406, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (660, 43, 201308, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (661, 52, 201402, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (662, 52, 201403, '2014-07-02', 2, '202.67.44.68', '2014-07-02 10:49:45', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (663, 46, 201405, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (664, 46, 201406, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (665, 46, 201407, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (666, 12, 201407, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (667, 12, 201408, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (668, 12, 201409, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (669, 12, 201410, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (670, 12, 201411, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (671, 12, 201412, '2014-07-11', 2, '202.67.45.37', '2014-07-11 12:49:51', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (672, 25, 201308, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (673, 39, 201401, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (674, 39, 201402, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (675, 39, 201403, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (676, 18, 201406, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (677, 62, 201404, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (678, 62, 201405, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (679, 14, 201403, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (680, 14, 201404, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (681, 14, 201405, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);
INSERT INTO "cashes" ("id", "user_id", "period_id", "dop", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (682, 43, 201309, '2014-07-22', 2, '202.67.45.34', '2014-07-22 08:34:12', NULL, NULL, NULL);


--
-- TOC entry 2582 (class 0 OID 0)
-- Dependencies: 187
-- Name: cashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"cashes_id_seq"', 683, false);


--
-- TOC entry 2528 (class 0 OID 16468)
-- Dependencies: 188
-- Data for Name: expenses; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, '2013-03-11', 110000, 'Beli kado pesta Muhammad Januar Pradipta.', 1, '::1', '2014-04-21 12:52:10', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, '2013-04-14', 300000, 'Rp. 220.000,- untuk uang pengadaan spanduk dan plakat ke Batubara, Rp. 80.000,- untuk tambahan honor crew Putra Melayu & Batubara.', 1, '::1', '2014-04-21 12:55:36', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, '2013-06-24', 125000, 'Uang makan di warjan bersama Tamu dari Jakarta & Bandung.', 1, '::1', '2014-04-21 12:58:40', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, '2013-06-29', 450000, 'Pengadaan kaos dan plakat untuk ulang tahun Intra.', 1, '::1', '2014-04-21 13:03:36', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, '2013-07-13', 425000, 'Buka puasa bersama Medan Bisser.', 1, '::1', '2014-04-21 14:00:06', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, '2013-09-01', 40000, 'Sisa uang kado.', 1, '::1', '2014-04-21 14:01:21', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, '2013-09-22', 400000, 'Transport Om Donny Kadarusman.', 1, '::1', '2014-04-21 14:02:33', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, '2013-09-30', 383000, 'Sumbangan untuk korban bencana alam Sinabung.', 1, '::1', '2014-04-21 14:03:47', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, '2013-10-12', 200000, 'Cinderamata CV. Batang Pane Baru.', 1, '::1', '2014-04-21 14:05:11', NULL, NULL, NULL);
INSERT INTO "expenses" ("id", "dot", "amount", "description", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, '2013-11-15', 1000000, 'Pembuatan stiker.', 1, '::1', '2014-04-21 14:06:16', 1, '::1', '2015-09-28 07:43:21');


--
-- TOC entry 2583 (class 0 OID 0)
-- Dependencies: 189
-- Name: expenses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"expenses_id_seq"', 1, false);


--
-- TOC entry 2530 (class 0 OID 16476)
-- Dependencies: 190
-- Data for Name: meetups; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, 201405, 60, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 201405, 45, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 201405, 27, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 201405, 2, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 201405, 28, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, 201405, 51, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, 201405, 15, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, 201405, 30, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, 201405, 31, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, 201405, 33, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (11, 201405, 46, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, 201405, 34, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, 201405, 55, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (14, 201405, 39, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (15, 201405, 47, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (16, 201405, 50, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (17, 201405, 54, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (18, 201405, 40, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (19, 201405, 4, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (20, 201405, 23, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (21, 201405, 8, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (22, 201405, 20, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (23, 201405, 18, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (24, 201405, 62, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (25, 201405, 57, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (26, 201405, 53, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (27, 201405, 1, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (28, 201405, 19, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (29, 201405, 43, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (30, 201405, 12, 2, '202.67.45.42', '2014-05-19 03:31:01', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (31, 201406, 37, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (32, 201406, 26, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (33, 201406, 27, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (34, 201406, 2, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (35, 201406, 28, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (36, 201406, 15, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (37, 201406, 29, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (38, 201406, 7, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (39, 201406, 3, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (40, 201406, 30, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (41, 201406, 31, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (42, 201406, 33, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (43, 201406, 46, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (44, 201406, 34, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (45, 201406, 39, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (46, 201406, 47, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (47, 201406, 50, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (48, 201406, 54, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (49, 201406, 40, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (50, 201406, 23, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (51, 201406, 10, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (52, 201406, 16, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (53, 201406, 8, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (54, 201406, 20, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (55, 201406, 18, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (56, 201406, 56, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (57, 201406, 42, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (58, 201406, 43, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (59, 201406, 52, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (60, 201406, 44, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (61, 201406, 12, 2, '202.67.45.38', '2014-06-29 01:09:23', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (62, 201407, 25, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (63, 201407, 2, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (64, 201407, 28, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (65, 201407, 15, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (66, 201407, 7, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (67, 201407, 30, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (68, 201407, 39, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (69, 201407, 5, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (70, 201407, 6, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (71, 201407, 40, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (72, 201407, 23, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (73, 201407, 8, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (74, 201407, 20, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (75, 201407, 18, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (76, 201407, 62, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (77, 201407, 42, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (78, 201407, 19, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (79, 201407, 14, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (80, 201407, 43, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (81, 201407, 12, 42, '202.67.45.37', '2014-07-11 12:40:19', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (82, 201408, 60, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (83, 201408, 25, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (84, 201408, 27, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (85, 201408, 29, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (86, 201408, 3, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (87, 201408, 31, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (88, 201408, 33, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (89, 201408, 55, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (90, 201408, 39, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (91, 201408, 47, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (92, 201408, 54, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (93, 201408, 40, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (94, 201408, 8, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (95, 201408, 20, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (96, 201408, 18, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (97, 201408, 62, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (98, 201408, 57, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (99, 201408, 42, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (100, 201408, 14, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (101, 201408, 43, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (102, 201408, 12, 2, '202.67.45.39', '2014-08-31 15:53:12', NULL, NULL, NULL);
INSERT INTO "meetups" ("id", "period_id", "user_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (103, 201408, 37, 2, '202.67.45.39', '2014-08-31 15:59:15', NULL, NULL, NULL);


--
-- TOC entry 2584 (class 0 OID 0)
-- Dependencies: 191
-- Name: meetups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"meetups_id_seq"', 103, true);


--
-- TOC entry 2532 (class 0 OID 16484)
-- Dependencies: 192
-- Data for Name: modules; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "modules" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 'Users', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "modules" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 'Monthly_Cashes', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "modules" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, 'Sessions', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "modules" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, 'Posts', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "modules" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (25, 'Meetups', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "modules" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (31, 'Home', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "modules" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (161, 'Expenses', NULL, NULL, NULL, NULL, NULL, NULL);


--
-- TOC entry 2585 (class 0 OID 0)
-- Dependencies: 193
-- Name: modules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"modules_id_seq"', 1, false);


--
-- TOC entry 2534 (class 0 OID 16489)
-- Dependencies: 194
-- Data for Name: mv_cashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 64, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, 64, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, 59, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, 59, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, 59, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, 60, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, 66, 2013, 'x', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, 66, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (14, 66, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (15, 24, 2013, 'x', 'x', 'x', 'x', 'x', 'x', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (16, 24, 2014, '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (17, 24, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (18, 25, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (20, 25, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (21, 45, 2014, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (22, 45, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (23, 26, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', '10', '10', '10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (24, 26, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (25, 26, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (27, 27, 2014, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (28, 27, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (29, 2, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (30, 2, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (31, 2, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (32, 28, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (34, 28, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (35, 51, 2013, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (36, 51, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (37, 51, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (38, 15, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (39, 15, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (41, 29, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (42, 29, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (43, 29, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (44, 7, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (45, 7, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (46, 7, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (47, 9, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (49, 9, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (50, 3, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (51, 3, 2014, '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (52, 3, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (53, 30, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (55, 30, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (56, 31, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (57, 31, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (58, 31, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (59, 32, 2013, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (60, 32, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (61, 32, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (63, 33, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 37, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 64, 2013, 'x', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (68, 34, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (69, 34, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (70, 34, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (71, 65, 2013, 'x', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (72, 65, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (74, 13, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (75, 13, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (76, 13, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (77, 55, 2013, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (78, 55, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (79, 55, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (81, 39, 2014, '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (82, 39, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (83, 47, 2014, '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (84, 47, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (85, 50, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (86, 50, 2014, '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (88, 63, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (89, 63, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (90, 5, 2013, 'x', 'x', 'x', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (91, 5, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (92, 5, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (93, 54, 2013, '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (95, 54, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (96, 6, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (97, 6, 2014, '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (98, 6, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (99, 40, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (100, 40, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (101, 40, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (103, 4, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (104, 4, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (105, 23, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (106, 23, 2014, '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (107, 23, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (108, 10, 2013, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (110, 10, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (111, 16, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (112, 16, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (113, 16, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (114, 8, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (115, 8, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (117, 36, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (118, 36, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (119, 36, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (120, 20, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (121, 20, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (122, 20, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (123, 18, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (125, 18, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (126, 62, 2014, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (66, 46, 2014, '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (67, 46, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (130, 21, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (131, 38, 2013, 'x', 'x', 'x', 'x', 'x', 'x', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (133, 38, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (134, 57, 2013, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (135, 57, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (136, 57, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (137, 53, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (138, 53, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (140, 56, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (141, 56, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (142, 1, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (143, 1, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (144, 1, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (145, 41, 2013, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (147, 41, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (148, 42, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (149, 42, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (150, 42, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (151, 19, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (152, 19, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (153, 19, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (155, 14, 2014, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (156, 14, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (157, 43, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (158, 43, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (159, 43, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (160, 52, 2014, '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (162, 61, 2013, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (163, 61, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (164, 61, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (165, 44, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (166, 44, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (167, 44, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (169, 48, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (170, 12, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (171, 12, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (172, 12, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (173, 17, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (174, 17, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, 37, 2013, 'x', 'x', 'x', 'x', 'x', 'x', '10', '10', '10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 37, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (11, 60, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (19, 25, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (26, 27, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (33, 28, 2014, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (40, 15, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (48, 9, 2014, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (54, 30, 2014, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (62, 33, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (64, 33, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (65, 67, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (128, 21, 2013, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (129, 21, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (73, 65, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (80, 39, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (87, 50, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (94, 54, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (102, 4, 2013, 'x', 'x', 'x', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (109, 10, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (116, 8, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (124, 18, 2014, '10', '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (127, 62, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (132, 38, 2014, '10', '10', '10', '10', '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (139, 56, 2013, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (146, 41, 2014, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (154, 14, 2013, '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', '10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (161, 52, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (168, 48, 2014, '10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');
INSERT INTO "mv_cashes" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (175, 17, 2015, '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '-10', '0', '0', '0', 1, '::1', '2015-09-27 13:44:47', 1, '::1', '2015-09-27 19:28:36');


--
-- TOC entry 2586 (class 0 OID 0)
-- Dependencies: 195
-- Name: mv_cashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"mv_cashes_id_seq"', 175, true);


--
-- TOC entry 2538 (class 0 OID 16529)
-- Dependencies: 198
-- Data for Name: mv_meetups; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 37, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 64, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, 64, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, 59, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, 59, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, 59, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (11, 60, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, 66, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (14, 66, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (15, 66, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (16, 24, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (17, 24, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (19, 25, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (20, 25, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (21, 25, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (22, 45, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (23, 45, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (24, 26, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (26, 26, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (27, 27, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (28, 27, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (29, 27, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (30, 2, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (32, 2, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (33, 28, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (34, 28, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (35, 28, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (36, 51, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (38, 51, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (39, 15, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (40, 15, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (41, 15, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (42, 29, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (44, 29, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (45, 7, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (46, 7, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (47, 7, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (48, 9, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (50, 9, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (51, 3, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (52, 3, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (53, 3, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (54, 30, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (55, 30, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (57, 31, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (58, 31, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (59, 31, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (60, 32, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (61, 32, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (63, 33, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (64, 33, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (65, 33, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (66, 67, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (67, 46, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (69, 34, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (70, 34, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (71, 34, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (72, 65, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (73, 65, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (75, 13, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (76, 13, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 37, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (79, 55, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (80, 55, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (82, 39, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (83, 39, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (84, 47, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (85, 47, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (86, 50, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (88, 50, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (89, 63, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (90, 63, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (91, 5, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (92, 5, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (94, 54, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (95, 54, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (96, 54, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (97, 6, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (98, 6, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (99, 6, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (101, 40, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (102, 40, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (103, 4, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (104, 4, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (105, 4, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (107, 23, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (108, 23, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (109, 10, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (110, 10, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (111, 10, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (113, 16, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (114, 16, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (115, 8, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (116, 8, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (117, 8, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (119, 36, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (120, 36, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (121, 20, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (122, 20, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (123, 20, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (125, 18, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (126, 18, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (127, 62, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (128, 62, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (129, 21, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (130, 21, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (132, 38, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (133, 38, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (134, 38, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (135, 57, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (136, 57, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (138, 53, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (139, 53, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (140, 56, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (141, 56, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (142, 56, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (144, 1, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (145, 1, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (146, 41, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (147, 41, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (148, 41, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (150, 42, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (151, 42, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (78, 55, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (154, 19, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (155, 14, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (161, 52, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (162, 52, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (163, 61, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (164, 61, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (165, 61, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (166, 44, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (167, 44, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (168, 44, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (169, 48, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (170, 48, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (171, 12, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (172, 12, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (173, 12, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (174, 17, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (175, 17, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (176, 17, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 37, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, 64, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, 60, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (18, 24, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (25, 26, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (31, 2, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (37, 51, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (43, 29, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (49, 9, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (56, 30, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (62, 32, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (68, 46, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (74, 65, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (77, 13, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (81, 39, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (87, 50, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (93, 5, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (100, 40, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (106, 23, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (112, 16, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (118, 36, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (124, 18, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (131, 21, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (137, 57, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (143, 1, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (149, 42, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (152, 19, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (153, 19, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (156, 14, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (157, 14, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (158, 43, 2013, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (159, 43, 2014, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');
INSERT INTO "mv_meetups" ("id", "user_id", "year_id", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (160, 43, 2015, 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 1, '::1', '2015-09-27 13:59:24', 1, '::1', '2015-09-27 19:28:47');


--
-- TOC entry 2587 (class 0 OID 0)
-- Dependencies: 200
-- Name: mv_meetups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"mv_meetups_id_seq"', 176, true);


--
-- TOC entry 2546 (class 0 OID 16600)
-- Dependencies: 206
-- Data for Name: periods; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201301, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201302, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201303, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201304, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201305, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201306, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201307, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201308, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201309, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201310, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201311, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201312, 2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201401, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201402, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201403, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201404, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201405, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201406, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201407, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201408, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201409, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201410, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201411, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201412, 2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201501, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201502, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201503, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201504, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201505, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201506, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201507, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201508, 2015, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "periods" ("id", "year_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201509, 2015, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- TOC entry 2588 (class 0 OID 0)
-- Dependencies: 207
-- Name: periods_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"periods_id_seq"', 1, false);


--
-- TOC entry 2548 (class 0 OID 16605)
-- Dependencies: 208
-- Data for Name: post_access_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 1, NULL, 319, NULL, '114.125.40.201', '2014-05-01 08:11:22', NULL, '::1', '2015-09-22 15:53:48');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 2, 8, 6, 8, '192.168.1.100', '2014-05-01 09:38:41', 8, '192.168.8.7, 110.232.95.148', '2014-06-07 09:53:59');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, 2, 12, 1, 12, '202.67.45.35', '2014-05-01 11:04:59', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, 2, 16, 3, 16, '112.215.65.131', '2014-05-01 17:27:20', 16, '112.215.66.79', '2014-06-14 05:47:52');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, 3, 16, 2, 16, '112.215.65.131', '2014-05-01 17:28:30', 16, '112.215.65.109', '2014-05-05 03:56:54');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, 2, 42, 4, 42, '202.67.45.44', '2014-05-02 06:49:18', 42, '39.227.35.128', '2014-05-22 03:23:27');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, 3, 42, 2, 42, '202.67.45.44', '2014-05-02 06:49:56', 42, '202.67.45.43', '2014-05-06 05:36:50');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (11, 1, 8, 2, 8, '192.168.1.100', '2014-05-03 11:48:37', 8, '192.168.1.100', '2014-05-03 11:48:57');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, 1, 42, 3, 42, '202.67.45.34', '2014-05-07 10:04:21', 42, '39.226.139.252', '2014-05-14 08:32:43');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, 1, 23, 1, 23, '202.67.44.76', '2014-05-19 14:11:08', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (14, 2, 23, 2, 23, '202.67.44.76', '2014-05-19 14:16:11', 23, '202.67.44.76', '2014-05-19 14:28:59');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (15, 1, 9, 1, 9, '114.79.32.235', '2014-05-19 14:23:54', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (16, 3, 23, 1, 23, '202.67.44.76', '2014-05-19 14:28:28', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (17, 1, 12, 2, 12, '202.67.45.4', '2014-05-19 14:56:59', 12, '202.67.45.46', '2014-07-15 13:15:41');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (18, 1, 47, 3, 47, '36.77.2.153', '2014-05-20 14:36:54', 47, '36.77.0.51', '2014-07-20 07:53:56');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (19, 2, 47, 2, 47, '36.77.2.153', '2014-05-20 14:36:56', 47, '36.77.0.51', '2014-07-20 07:53:58');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (20, 3, 47, 3, 47, '36.77.2.153', '2014-05-20 14:45:05', 47, '36.77.0.51', '2014-07-20 07:54:06');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (21, 1, 19, 1, 19, '39.224.8.110', '2014-05-21 07:48:04', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (22, 1, 28, 1, 28, '36.68.153.191', '2014-05-21 08:14:27', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (23, 2, 28, 2, 28, '36.68.153.191', '2014-05-21 08:14:37', 28, '36.68.153.191', '2014-05-21 08:42:33');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (24, 3, 28, 2, 28, '36.68.153.191', '2014-05-21 08:42:37', 28, '180.250.27.166', '2014-05-24 13:55:23');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (25, 3, 53, 1, 53, '123.108.98.64', '2014-05-21 09:09:02', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (26, 1, 53, 2, 53, '123.108.98.64', '2014-05-21 09:11:22', 53, '123.108.98.64', '2014-05-21 09:13:58');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (27, 2, 39, 1, 39, '39.228.183.173', '2014-05-21 09:47:14', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (28, 3, 39, 1, 39, '39.228.183.173', '2014-05-21 09:48:03', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (29, 2, 54, 1, 54, '202.67.45.47', '2014-05-21 12:08:55', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (30, 2, 38, 3, 38, '180.251.33.120', '2014-05-22 02:46:42', 38, '180.251.75.102', '2014-07-05 09:30:17');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (31, 1, 38, 2, 38, '180.251.33.120', '2014-05-22 02:46:48', 38, '180.251.75.102', '2014-07-05 09:29:59');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (32, 2, 46, 1, 46, '103.31.45.106', '2014-05-22 09:48:44', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (33, 1, 46, 2, 46, '103.31.45.106', '2014-05-22 09:49:35', 46, '103.31.45.106', '2014-05-26 06:46:58');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (34, 2, 59, 3, 59, '36.76.159.131', '2014-05-22 13:29:43', 59, '36.76.159.131', '2014-05-22 13:37:30');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (35, 3, 59, 2, 59, '36.76.159.131', '2014-05-22 13:34:23', 59, '180.251.41.4', '2014-05-22 13:37:00');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (36, 1, 59, 1, 59, '36.76.159.131', '2014-05-22 13:35:15', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (37, 1, 55, 3, 55, '202.162.199.59', '2014-05-23 03:02:15', 55, '202.162.199.59', '2014-05-23 03:06:29');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (38, 1, 20, 3, 20, '36.68.123.166', '2014-05-24 07:04:23', 20, '36.76.128.42', '2014-06-13 09:13:20');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (39, 1, 16, 2, 16, '36.86.22.114', '2014-05-24 19:21:44', 16, '112.215.66.68', '2014-06-14 05:47:48');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (40, 1, 4, 1, 4, '125.162.52.107', '2014-06-05 13:34:31', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (41, 2, 4, 1, 4, '125.162.52.107', '2014-06-05 13:34:52', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (42, 3, 20, 1, 20, '36.76.128.42', '2014-06-13 09:13:06', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (43, 2, 20, 1, 20, '36.76.128.42', '2014-06-13 09:13:13', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (44, 3, 38, 2, 38, '180.251.75.102', '2014-07-05 09:27:26', 38, '180.251.75.102', '2014-07-05 09:30:12');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 2, 1, 55, 1, '127.0.0.1', '2014-04-30 09:01:12', 1, '::1', '2015-10-05 02:44:00');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (47, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:50:55', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (49, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:51:22', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (51, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:54:25', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (57, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:57:02', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (58, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:57:04', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (59, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:57:05', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (60, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:57:07', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (61, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:57:08', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, 1, 1, 71, 1, '127.0.0.1', '2014-03-28 01:36:13', 1, '127.0.0.1', '2017-03-18 17:16:46');
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (48, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:51:05', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (50, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:54:10', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (52, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:54:33', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (45, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:03:29', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (46, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:03:42', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (53, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:54:38', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (54, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:55:03', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (55, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:56:03', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (56, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 16:57:01', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (62, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:28', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (63, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:31', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (64, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:32', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (65, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:33', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (66, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:34', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (67, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:35', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (68, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:35', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (69, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:36', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (70, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:37', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (71, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:38', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (72, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:38', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (73, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:39', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (74, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:39', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (75, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:40', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (76, 1, NULL, 1, NULL, '127.0.0.1', '2017-03-18 17:12:41', NULL, NULL, NULL);
INSERT INTO "post_access_logs" ("id", "post_id", "user_id", "hits", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 3, 1, 91, 1, '127.0.0.1', '2014-04-30 09:24:50', 1, '127.0.0.1', '2017-03-18 17:16:15');


--
-- TOC entry 2589 (class 0 OID 0)
-- Dependencies: 209
-- Name: post_access_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"post_access_logs_id_seq"', 76, true);


--
-- TOC entry 2541 (class 0 OID 16563)
-- Dependencies: 201
-- Data for Name: post_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, 1, 1, 1, '127.0.0.1', '2014-04-30 21:29:17', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 2, 1, 1, '127.0.0.1', '2014-04-30 21:29:40', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 3, 1, 1, '127.0.0.1', '2014-04-30 21:29:57', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 1, 2, 1, '127.0.0.1', '2014-04-30 21:30:25', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 2, 2, 1, '127.0.0.1', '2014-04-30 21:30:49', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, 1, 3, 1, '127.0.0.1', '2014-04-30 21:31:30', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, 2, 3, 1, '127.0.0.1', '2014-04-30 21:31:33', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, 1, 4, 1, '127.0.0.1', '2014-04-30 21:32:03', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, 2, 4, 1, '127.0.0.1', '2014-04-30 21:32:05', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, 3, 4, 1, '127.0.0.1', '2014-04-30 21:32:08', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (11, 1, 5, 1, '127.0.0.1', '2014-04-30 21:32:53', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, 2, 5, 1, '127.0.0.1', '2014-04-30 21:32:56', NULL, NULL, NULL);
INSERT INTO "post_permissions" ("id", "role_id", "post_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, 3, 5, 1, '127.0.0.1', '2014-04-30 21:32:59', NULL, NULL, NULL);


--
-- TOC entry 2590 (class 0 OID 0)
-- Dependencies: 210
-- Name: post_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"post_permissions_id_seq"', 1, false);


--
-- TOC entry 2525 (class 0 OID 16446)
-- Dependencies: 185
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "posts" ("id", "title", "body", "url_alias", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, 'Tentang Kami', 'Medan Bisser adalah sebuah komunitas pecinta BIS yang berasal dari Medan, Sumatera Utara.<br>
Berdiri pada tanggal 9 September 2009 di Warung Jamboo 35 dan<br>bernaung di bawah <a href="http://www.bismania.com">www.bismania.com</a> (komunitas pencinta bis pertama di Indonesia)<br>
dengan situs resmi :
<ul>
<li><a href="http://www.facebook.com/groups/medanbisser">http://www.facebook.com/groups/medanbisser</a> (sebagai forum berdiskusi)</li>
<li><a href="http://www.medanbisser.com">www.medanbisser.com</a> (sebagai database internal organisasi)</li>
</ul>
Medan Bisser bertujuan sebagai berikut :
<ul>
<li>Wadah penghimpun para pecinta, pengamat, penggemar, penikmat bus yang berasal dari Medan dan sekitarnya,<br>
agar dapat dengan mudah berbagi informasi dengan tidak menganggu privasi atau merugikan nama baik perusahaan bis.</li>
<li>Meningkatkan wawasan para anggota mengenai dunia bis.</li>
<li>Menyelenggarakan aktivitas sosial yang bermanfaat bagi masyarakat.</li>
</ul>
Medan Bisser menyelenggarakan berbagai kegiatan antara lain :
<ul>
<li>Kopdar resmi bulanan.</li>
<li>Kunjungan ke Pool.</li>
<li>Touring bersama.</li>
<li>Kegiatan sosial yang dipandang perlu dilakukan dan bersifat situasional.</li>
<li>Hunting bersama dengan tidak menggangu ketertiban / kepentingan umum.</li>
</ul>
Untuk info lebih lanjut, silahkan hubungi <a href="mailto:info@medanbisser.com">info@medanbisser.com</a>.', 'about-us', 7, '<a href="/about-us">Tentang Kami</a>', 1, '127.0.0.1', '2014-03-28 01:36:13', 1, '127.0.0.1', '2014-03-28 01:36:19');
INSERT INTO "posts" ("id", "title", "body", "url_alias", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, 'Halaman Tidak Ditemukan', '<h4 style="color:red">Halaman tidak ditemukan, silahkan klik <a href="/home">di sini</a> untuk kembali ke halaman depan.</h4>', '404', NULL, NULL, 1, '127.0.0.1', '2014-04-30 16:39:56', NULL, NULL, NULL);
INSERT INTO "posts" ("id", "title", "body", "url_alias", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, 'Akses Ditolak', '<h4 style="color:red">Akses ditolak, untuk membuka halaman tersebut silahkan login dengan hak akses yang lebih tinggi.<br>
Klik <a href="/home">di sini</a> untuk kembali ke halaman depan.</h3>', '403', NULL, NULL, 1, '127.0.0.1', '2014-04-30 16:40:02', NULL, NULL, NULL);
INSERT INTO "posts" ("id", "title", "body", "url_alias", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 'Anggaran Rumah Tangga', '<p><a href="/articles-of-association">Anggaran Dasar</a></p>

<h3 class="bold-centered-block">ANGGARAN RUMAH TANGGA<br>
MEDAN BISSER</h3>

<h4 class="bold-centered-block">BAB I<br>
KEANGGOTAAN</h4>

<h5 class="bold-centered-block">Pasal 1<br>
Persyaratan</h5>
<ol>
<li>Menyerahkan data berikut: nama di KTP, nama panggilan, tempat/tanggal lahir, nomor KTP/SIM/Induk Pelajar, Alamat, Email, Telpon, ID forum <a href="http://www.bismania.com">www.bismania.com</a> dan foto terbaru untuk dimasukkan ke database <a href="/">www.medanbisser.com</a>.</li>
<li>Membayar iuran bulanan sebesar Rp. 10.000,- (sepuluh ribu rupiah).</li>
<li>Mengikuti kopdar bulanan, minimal 2 (dua) bulan sekali untuk yang berdomisili di Medan dan daerah dengan waktu tempuh kurang dari 6 (enam) jam perjalanan dari Medan, dan minimal 3 (tiga) bulan sekali untuk yang berdomisili di daerah dengan waktu tempuh 6 (enam) jam perjalanan (atau lebih) dari Medan.</li>
</ol>

<h5 class="bold-centered-block">Pasal 2<br>
Jenis Keanggotaan</h5>
<ol>
<li>Calon Anggota Resmi<br>
Masa bergabung kurang dari 6 bulan.</li>
<li>Anggota Resmi<br>
Masa bergabung minimal 6 bulan, selama menjadi calon anggota resmi rutin ikut kopdar, tidak menunggak uang kas dan tidak sedang menjalani sanksi pelanggaran AD/ART.</li>
</ol>

<h5 class="bold-centered-block">Pasal 3<br>
Hak Anggota</h5>
<ol>
<li>Khusus untuk calon anggota resmi, tidak memiliki hak memilih pada setiap rapat yang memerlukan pengambilan keputusan.</li>
<li>Mengajukan saran dan pendapatnya sebagai upaya kemajuan serta pengembangan organisasi.</li>
<li>Mendapatkan ID card. ID card yang sah adalah bila nomor ID ada dan status keanggotaannya masih aktif di <a href="/">www.medanbisser.com</a>.</li>
<li>Mendapatkan seragam untuk yang sudah menjadi anggota resmi.</li>
<li>Mempunyai hak untuk mengikuti kegiatan-kegiatan yang diselenggarakan oleh Medan Bisser.</li>
</ol>

<h5 class="bold-centered-block">Pasal 4<br>
Kewajiban Anggota</h5>
<ol>
<li>Menjalankan peraturan yang telah ditetapkan dalam AD/ART dan selalu menjaga nama baik organisasi.</li>
<li>Menjaga hubungan baik sesama anggota.</li>
<li>Wajib mengikuti kopdar yang diadakan di hari minggu pada minggu kedua setiap bulannya minimal 2 (dua) bulan sekali untuk yang berdomisili di Medan dan daerah dengan waktu tempuh kurang dari 6 (enam) jam perjalanan dari Medan, dan minimal 3 (tiga) bulan sekali untuk yang berdomisili di daerah dengan waktu tempuh 6 (enam) jam perjalanan (atau lebih) dari Medan.</li>
<li>Membayar iuran rutin yang jumlahnya Rp. 10.000,- (sepuluh ribu rupiah) kepada pengurus setiap bulannya.</li>
<li>Membawa ID card ketika melakukan kegiatan yang mengatasnamakan Medan Bisser.</li>
<li>Menunjukan ID card ketika melakukan kunjungan ke PO.</li>
<li>Tidak merugikan nama baik organisasi, privasi/nama baik PO yang diliput dan nama baik crew PO yang diliput.</li>
<li>Tidak menggunakan nama Medan Bisser untuk keuntungan pribadi (termasuk "bebas dari biaya").</li>
<li>Tidak meng-upload foto/video bis yang sedang rusak, kebut-kebutan, kecelakaan dan menaikkan atau menurunkan paket/penumpang di luar loket/perwakilan resmi.</li>
<li>Tidak terlibat secara sengaja dalam segala bentuk tindakan kriminal.</li>
<li>Aktif berpartisipasi dalam forum di <a href="http://www.bismania.com">www.bismania.com</a>.</li>
</ol>

<h5 class="bold-centered-block">Pasal 5<br>
Status Keanggotaan</h5>

<h6 class="bold-centered-block">Ayat 1</h6>
Setiap anggota bisa berhenti dari keanggotaannya apabila memenuhi salah satu unsur berikut :
<ol>
<li>Meninggal dunia.</li>
<li>Atas permintaan sendiri (maka hak-haknya dalam organisasi hilang).</li>
<li>Tidak lagi memenuhi syarat-syarat keanggotaan.</li>
</ol>

<h6 class="bold-centered-block">Ayat 2</h6>
Untuk anggota yang sudah keluar, status keanggotaannya di <a href="http://www.medanbisser.com">www.medanbisser.com</a> berubah menjadi non aktif dengan tujuan menghindari penyalahgunaan ID card/seragam.

<h4 class="bold-centered-block">BAB II<br>
SANKSI</h4>

<h5 class="bold-centered-block">Pasal 6</h5>
Pelanggaran AD/RT dikenai sanksi sebagai berikut :
<ol>
<li>Surat Peringatan (SP) I (pertama) berupa teguran secara tertulis.</li>
<li>Surat Peringatan (SP) II (kedua) berupa teguran keras secara tertulis.</li>
<li>Surat Peringatan (SP) III (ketiga) berupa pemberhentian secara tidak hormat anggota yang bersangkutan dan disampaikan secara tertulis.</li>
</ol>

<h5 class="bold-centered-block">Pasal 7</h5>
Untuk calon anggota resmi yang menerima SP I atau SP II, masa evaluasi keanggotaaannya mundur 6 bulan, terhitung sejak pemberian SP.

<h5 class="bold-centered-block">Pasal 8</h5>
Jenis pelanggaran yang diberikan sanksi berupa SP I adalah sebagai berikut :
<ol>
<li>Tidak membayar iuran rutin selama 2 (dua) bulan.</li>
<li>Tidak menghadiri kopdar bulanan selama 3 (tiga) bulan berturut-turut untuk yang berdomisili di Medan dan daerah dengan waktu tempuh kurang dari 6 (enam) jam perjalanan dari Medan, dan 4 (empat) bulan berturut-turut untuk yg berdomisili di daerah dengan waktu tempuh 6 jam perjalanan (atau lebih) dari Medan.</li>
<li>Tidak membawa atau menunjukkan ID card ketika melakukan kegiatan yang mengatasnamakan Medan Bisser.</li>
<li>Meng-upload foto/video bis yang sedang rusak, kebut-kebutan, kecelakaan dan menaikkan atau menurunkan paket/penumpang.</li>
<li>Melakukan tindakan secara sengaja atau tidak yang dapat merugikan nama baik organisasi, privasi/nama baik PO yang diliput dan nama baik crew PO yang diliput.</li>
<li>Tidak menjaga hubungan baik sesama anggota.</li>
</ol>

<h5 class="bold-centered-block">Pasal 9</h5>
Jenis pelanggaran yang diberikan sanksi berupa SP II adalah sebagai berikut :
<ol>
<li>Mengulangi kesalahan yang sama walaupun sudah diberikan SP I, kecuali pada jenis pelanggaran pada pasal 8 poin 4, akan langsung diberikan SP III.</li>
<li>Tidak membayar iuran rutin selama 4 (empat) bulan.</li>
<li>Tidak menghadiri kopdar bulanan selama 4 (empat) bulan berturut-turut tanpa pemberitahuan resmi untuk yang berdomisili di Medan dan daerah dengan waktu tempuh kurang dari 6 (enam) jam perjalanan dari Medan dan 5 (lima) bulan berturut-turut tanpa pemberitahuan resmi untuk yg berdomisili di daerah dengan waktu tempuh 6 jam perjalanan (atau lebih) dari Medan.</li>
<li>Menggunakan nama Medan Bisser untuk keuntungan pribadi (termasuk "bebas dari biaya").</li>
</ol>

<h5 class="bold-centered-block">Pasal 10</h5>
Jenis pelanggaran yang diberikan sanksi berupa SP III adalah sebagai berikut :
<ol>
<li>Mengulangi kesalahan yang sama walaupun sudah diberikan SP II.</li>
<li>Tidak membayar iuran rutin selama 6 (enam) bulan.</li>
<li>Tidak menghadiri kopdar bulanan selama 5 (lima) bulan berturut-turut tanpa pemberitahuan resmi untuk yang berdomisili di Medan dan daerah dengan waktu tempuh kurang dari 6 (enam) jam perjalanan dari Medan, dan 6 (enam) bulan berturut-turut tanpa pemberitahuan resmi untuk yg berdomisili di daerah dengan waktu tempuh 6 jam perjalanan (atau lebih) dari Medan.</li>
<li>Meng-upload foto/video bis yang sedang rusak, kebut-kebutan, kecelakaan dan menaikkan atau menurunkan paket/penumpang di luar area loket/perwakilan resmi, walaupun sudah diberikan SP I.</li>
<li>Melakukan segala bentuk tindakan kriminal.</li>
</ol>

<h5 class="bold-centered-block">Pasal 11</h5>
Pengawasan dan pengevaluasian terhadap aktivitas seluruh anggota dilakukan oleh penasihat dan pengurus harian organisasi.

<h4 class="bold-centered-block">BAB III<br>
KEPENGURUSAN</h4>

<h5 class="bold-centered-block">Pasal 11</h5>
Pertemuan pada tanggal 9 Maret 2014 di Medan telah memilih pengurus harian organisasi "Medan Bisser" untuk periode 2014 - 2015 sebagai berikut :
<ul>
<li>Moderator : ASRUL ARIFIN SIREGAR</li>
<li>Ketua : M. FAZRIAN SIREGAR</li>
<li>Wakil Ketua : M. REZA PAHLEVI</li>
<li>Sekretaris : AYU ADISTIANI LUBIS</li>
<li>Bendahara : ASRUL ARIFIN SIREGAR</li>
<li>Humas : SUHARDI HASIBUAN</li>
</ul>

<h5 class="bold-centered-block">Pasal 12</h5>
<h6 class="bold-centered-block">Ayat 1</h6>
Tugas pokok penasihat adalah :
<ol>
<li>Untuk moderator, sebagai penanggung jawab <a href="http://www.bismania.com">www.bismania.com</a> yang ditunjuk oleh Administrator <a href="http://www.bismania.com">www.bismania.com</a> untuk area SUMUT.
<li>Membuat keputusan untuk menyelesaikan konflik yang tidak bisa diselesaikan secara internal organisasi.</li>
<li>Menyusun dan menetapkan klausula-klausula perubahan AD/ART, dan merekomendasikan kepentingan strategis lainnya.</li>
<li>Melakukan pengawasan terhadap ketetapan hasil rapat, pelaksanaan AD/ART dan program kerja yang telah ditetapkan oleh pengurus secara berkala dan berkesinambungan.</li>
<li>Memberikan pertimbangan dan nasehat baik diminta maupun tidak diminta  kepada pengurus untuk melancarkan pelaksanaan kebijakan.</li>
<li>Berwenang untuk mengusulkan rapat evaluasi dengan syarat disetujui minimal ½ + 1 (setengah ditambah satu) dari seluruh penasihat kepada pengurus.</li>
<li>Melaksanakan amanah yang telah ditetapkan dalam AD/ART.
</ol>

<h6 class="bold-centered-block">Ayat 2</h6>
Tugas pokok ketua adalah :
<ol>
<li>Memimpin dan mengendalikan jalannya organisasi dengan berkoordinasi kepada penasihat.</li>
<li>Mewakili Organisasi ke luar maupun ke dalam.</li>
<li>Memimpin pelaksanaan program kerja organisasi.</li>
<li>Menandatangani surat-surat penting organisasi.</li>
<li>Mengatasi dan bertanggung jawab terhadap segala permasalahan atas pelaksanaan tugas yang dijalankan oleh para pengurus.</li>
<li>Mengadakan evaluasi terhadap semua kegiatan yang telah dilaksanakan oleh para pengurus.</li>
<li>Melaporkan dan mempertanggungjawabkan tugas kepengurusan organisasi kepada Administrator dan Anggota.</li>
<li>Memberikan sanksi kepada seluruh anggota yang melakukan pelanggaran, setelah terlebih dahulu mengevaluasi dan berkoordinasi dengan para Administrator serta seluruh Pengurus organisasi.</li>
</ol>

<h6 class="bold-centered-block">Ayat 3</h6>
Tugas pokok wakil ketua adalah :
<ol>
<li>Membantu penuh ketua dalam menjalankan program kerja.</li>
<li>Melaksanakan tugas ketua jika ketua tidak dapat menjalankan tugasnya/non aktif.</li>
<li>Mewakili ketua jika yang bersangkutan tidak hadir/berhalangan.</li>
<li>Mengelola dan menyediakan seluruh logistik/kelengkapan organisasi dan program kerja.</li>
<li>Inventarisasi anggota.</li>
<li>Melaporkan dan mempertanggung jawabkan pelaksanaan tugasnya kepada Penasihat dan Ketua.</li>
</ol>

<h6 class="bold-centered-block">Ayat 4</h6>
Tugas pokok sekretaris adalah :
<ol>
<li>Mewakili ketua apabila yang bersangkutan tidak hadir/berhalangan.</li>
<li>Memberikan pelayanan teknis administratoristratif.</li>
<li>Membuat notulen dan daftar hadir rapat/pertemuan.</li>
<li>Mengerjakan seluruh pekerjaan sekretariat, yaitu mengadakan surat-menyurat serta pengarsipannya dan membuat laporan organisasi.</li>
<li>Melaporkan dan mempertanggung- jawabkan pelaksanaan tugasnya kepada Penasihat dan Ketua.</li>
</ol>

<h6 class="bold-centered-block">Ayat 5</h6>
Tugas pokok bendahara adalah :
<ol>
<li>Bertanggungjawab atas administrasi keuangan organisasi.</li>
<li>Membuat laporan keuangan organisasi secara berkala sehingga dapat diperiksa bila diperlukan.</li>
<li>Menandatangani bukti-bukti pengeluaran dan penerimaan uang.</li>
<li>Menerima  dan menyimpan uang  milik organisasi.</li>
<li>Mengeluarkan uang sesuai dengan keperluan berdasarkan persetujuan ketua.</li>
<li>Melaporkan dan mempertanggungjawabkan pelaksanaan tugasnya kepada Penasihat dan Ketua.</li>
</ol>

<h6 class="bold-centered-block">Ayat 6</h6>
Tugas pokok humas adalah :
<ol>
<li>Mengevaluasi kekuatan dan kelemahan organisasi serta tantangan dan peluang yang dimiliki oleh organisasi.</li>
<li>Merencanakan, melaksanakan serta mengevaluasi berbagai kegiatan organisasi terutama yang melibatkan pihak luar organisasi.</li>
<li>Memastikan seluruh anggota organisasi untuk tidak melakukan suatu tindakan yang dapat mencemarkan nama baik organisasi.</li>
<li>Memberikan masukan kepada elemen organisasi mengenai perkembangan lingkungan internal dan eksternal organisasi yang dapat mempengaruhi citra organisasi dimata masyarakat dan PO bis.</li>
<li>Menjadi komunikator yang baik dalam hal memediasi segala sesuatu ketika organisasi sedang mengalami permasalahan baik internal maupun eksternal.</li>
<li>Membantu bagian-bagian lain dengan menganalisis masalah-masalah komunikasi, menulis dan menerbitkannya, memberikan keterangan baik secara audio visual maupun melalui bentuk media lainnya.</li>
<li>Mengoptimalkan arus informasi yang baik dan berjalan dua arah melalui berbagai media komunikasi yang tersedia.</li>
<li>Melaporkan dan mempertanggung- jawabkan pelaksanaan tugasnya kepada Penasihat dan Ketua.</li>
</ol>

<h5 class="bold-centered-block">Pasal 13</h5>
Pengurus melaksanakan semua hal-hal yang ditetapkan dalam AD/ART organisasi "Medan Bisser" dan mempertanggungjawabkan hasil kegiatan kepada anggota melalui rapat anggota.

<h4 class="bold-centered-block">BAB IV<br>
RAPAT</h4>

<h5 class="bold-centered-block">Pasal 14</h5>
Rapat dinyatakan sah apabila dihadiri oleh :
<ol>
<li>Sekurang-kurangnya 1/3 (satu per tiga) dari jumlah anggota.</li>
<li>Seluruh pengurus.</li>
</ol>

<h4 class="bold-centered-block">BAB V<br>
PEMBUBARAN ORGANISASI</h4>

<h5 class="bold-centered-block">Pasal 15</h5>
Pembubaran organisasi "Medan Bisser" dilakukan apabila tujuan organisasi tidak tercapai dan tidak memungkinkan lagi dilakukan atau diwujudkan.

<h4 class="bold-centered-block">BAB VI<br>
PENUTUP</h4>

<h5 class="bold-centered-block">Pasal 16</h5>
Hal-hal yang belum diatur dalam Anggaran Rumah Tangga (ART) ini akan diatur melalui rapat anggota.

<h5 class="bold-centered-block">Pasal 17</h5>
Anggaran Rumah Tangga (ART) organisasi "Medan Bisser" ini mulai berlaku sejak tanggal ditetapkan.
<br>
<br>
<br>
<strong>
DITETAPKAN DI 	: MEDAN<br>
PADA TANGGAL	: 18 MEI 2014<br>
<br>
PENGURUS<br>
<br>
<div class="row">
<div class="col-xs-6 col-md-4">Ketua</div>
<div class="col-xs-6 col-md-4">Moderator</div>
<div class="col-xs-6 col-md-4">Sekretaris</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">M. Fazrian Siregar</div>
<div class="col-xs-6 col-md-4">Asrul Arifin Siregar</div>
<div class="col-xs-6 col-md-4">Ayu Adistiani Lubis</div>
</div>
</strong>', 'association-bylaws', NULL, NULL, 1, '127.0.0.1', '2014-04-30 09:24:50', 1, '::1', '2015-09-27 15:45:10');
INSERT INTO "posts" ("id", "title", "body", "url_alias", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 'Anggaran Dasar', '<p><a href="/association-bylaws">Anggaran Rumah Tangga</a></p>

<h3 class="bold-centered-block">ANGGARAN DASAR<br>
MEDAN BISSER</h3>

<h4 class="bold-centered-block">BAB I<br>
NAMA, TEMPAT, KEDUDUKAN, WAKTU DAN LOGO</h4>

<h5 class="bold-centered-block">Pasal 1<br>
Nama Organisasi</h5>
Organisasi komunitas ini diberi nama "Medan Bisser", yang dideklarasikan pada tanggal 9 September 2009 di warung Jamboo 35, Medan.

<h5 class="bold-centered-block">Pasal 2<br>
Tempat dan Kedudukan</h5>

<h6 class="bold-centered-block">Ayat 1</h6>
Pengurus organisasi "Medan Bisser" ini berkedudukan di kota Medan Provinsi Sumatera Utara dengan alamat sekretariat Jln. Sisingamangaraja Km 7 No. 48 Marendal, dan tidak dimungkinkan membuka korwil atau cabang di tempat lain.

<h6 class="bold-centered-block">Ayat 2</h6>
Organisasi "Medan Bisser" berada di bawah naungan Forum www.bismania.com (Forbiscom) dengan situs resmi : <a href="http://www.facebook.com/groups/medanbisser">www.facebook.com/groups/medanbisser</a> sebagai forum berdiskusi, dan
<a href="http://www.medanbisser.com">www.medanbisser.com</a> sebagai database internal organisasi (daftar anggota, iuran/pengeluaran uang kas, absensi kopdar bulanan, data SP anggota & dokumen internal organisasi).

<h5 class="bold-centered-block">Pasal 3<br>
Waktu</h5>
Masa berlaku organisasi "Medan Bisser" ini tidak terbatas mulai dari sejak dibentuk.

<h5 class="bold-centered-block">Pasal 4<br>
Logo</h5>
Organisasi "Medan Bisser" memiliki logo resmi sebagai berikut :<br>
<img src="/images/logomb.png" style="display:block;margin-left:auto;margin-right:auto;">

<h4 class="bold-centered-block">BAB II<br>
ASAS DAN TUJUAN</h4>

<h5 class="bold-centered-block">Pasal 5</h5>
Organisasi "Medan Bisser" berdasarkan Pancasila dan Undang-Undang Dasar 1945. Pendirian Organisasi "Medan Bisser" didasarkan pada rasa kekeluargaan dan kerjasama anggotanya.

<h5 class="bold-centered-block">Pasal 6</h5>
Organisasi "Medan Bisser" mempunyai tujuan sebagai berikut :
<ol>
<li>Wadah penghimpun para pecinta, pengamat, penggemar, penikmat bus yang berasal dari Medan dan sekitarnya, agar dapat dengan mudah berbagi informasi dengan tidak menganggu privasi atau merugikan nama baik perusahaan bis.</li>
<li>Meningkatkan wawasan para anggota mengenai dunia bis.</li>
<li>Menyelenggarakan aktivitas sosial yang bermanfaat bagi masyarakat.</li>
</ol>

<h4 class="bold-centered-block">BAB III<br>
BENTUK DAN SIFAT</h4>

<h5 class="bold-centered-block">Pasal 7</h5>
Organisasi "Medan Bisser" berbentuk kumpulan komunitas.

<h5 class="bold-centered-block">Pasal 8</h5>
Organisasi "Medan Bisser" bersifat komunitas sosial non-politik dan semata-mata melaksanakan kegiatan berdasarkan tujuan organisasi. Keanggotaanya bersifat sukarela, terbuka dan tanpa paksaan oleh pihak manapun dan dengan alasan apapun.

<h4 class="bold-centered-block">BAB IV<br>
KEGIATAN</h4>

<h5 class="bold-centered-block">Pasal 9</h5>
Organisasi "Medan Bisser" menyelenggarakan berbagai kegiatan yang terkait dengan tujuan organisasi, antara lain :
<ol>
<li>Kopdar resmi bulanan.</li>
<li>Kunjungan ke Pool.</li>
<li>Touring bersama.</li>
<li>Kegiatan sosial yang dipandang perlu dilakukan dan bersifat situasional.</li>
<li>Hunting bersama dengan tidak mengganggu ketertiban / kepentingan umum.</li>
</ol>

<h4 class="bold-centered-block">BAB V<br>
KEANGGOTAAN</h4>

<h5 class="bold-centered-block">Pasal 10</h5>
<h6 class="bold-centered-block">Ayat 1</h6>
Keanggotaan organisasi "Medan Bisser" terdiri atas calon anggota resmi dan anggota resmi, keanggotaan ini termasuk untuk <i>crew</i> PO.

<h6 class="bold-centered-block">Ayat 2</h6>
Calon anggota resmi adalah anggota yang bergabung dalam organisasi "Medan Bisser" kurang dari 6 (enam) bulan.

<h6 class="bold-centered-block">Ayat 3</h6>
Anggota resmi, adalah anggota yang sudah bergabung minimal 6 bulan,memiliki ID forum di www.bismania.com, telah melunasi uang kas minimal bulan berjalan dan hadir pada kopdar resmi bulanan.

<h6 class="bold-centered-block">Ayat 4</h6>
Setiap anggota baik calon anggota resmi maupun anggota resmi mempunyai kewajiban mentaati Anggaran Dasar dan Anggaran Rumah Tangga (AD/ART) serta peraturan - peraturan yang berlaku dalam organisasi "Medan Bisser".

<h6 class="bold-centered-block">Ayat 5</h6>
Setiap anggota baik calon anggota resmi maupun anggota resmi harus memelihara solidaritas dan rasa kesetiakawanan sosial antar anggota.

<h4 class="bold-centered-block">BAB VI<br>
STRUKTUR ORGANISASI</h4>

<h5 class="bold-centered-block">Pasal 11</h5>
<h6 class="bold-centered-block">Ayat 1</h6>
Penasehat, yaitu para administrator dan moderator pada situs <a href="http://www.facebook.com/groups/medanbisser">www.facebook.com/groups/medanbisser</a>.

<h6 class="bold-centered-block">Ayat 2</h6>
Pengurus harian, terdiri atas :
<ol>
<li>Ketua.</li>
<li>Wakil Ketua.</li>
<li>Sekretaris.</li>
<li>Bendahara.</li>
<li>Humas.</li>
</ol>

<h5 class="bold-centered-block">Pasal 12<br>
Periode Kepengurusan</h5>

<h6 class="bold-centered-block">Ayat 1</h6>
Periode masa bakti kepengurusan Organisasi "Medan Bisser" adalah 1 (satu) tahun, dan akan dipilih kembali melalui rapat anggota.

<h6 class="bold-centered-block">Ayat 2</h6>
Khusus untuk jabatan Ketua yang terpilih hanya boleh menjabat selama 2 (dua) periode demi regenerasi organisasi.

<h4 class="bold-centered-block">BAB VII<br>
PERBENDAHARAAN</h4>

<h5 class="bold-centered-block">Pasal 13</h5>
Keuangan organisasi "Medan Bisser" diperoleh dari :
<ol>
<li>Iuran bulanan anggota.</li>
<li>Sumbangan-sumbangan yang tidak mengikat.</li>
<li>Usaha-usaha yang diperoleh secara sah dan tidak bertentangan dengan ketentuan-ketentuan yang berlaku.</li>
</ol>

<h5 class="bold-centered-block">Pasal 14</h5>
Tahun buku Organisasi "Medan Bisser" adalah menurut kalender berjalan sesuai periode kepengurusan.

<h4 class="bold-centered-block">BAB VIII<br>
RAPAT</h4>

<h5 class="bold-centered-block">Pasal 15</h5>
Rapat Anggota

<h6 class="bold-centered-block">Ayat 1</h6>
Rapat anggota merupakan badan tertinggi dalam Organisasi "Medan Bisser".

<h6 class="bold-centered-block">Ayat 3</h6>
Rapat anggota memilih, mengangkat dan mengesahkan pengurus baru setiap 1 (satu) tahun.

<h6 class="bold-centered-block">Ayat 4</h6>
Rapat anggota menetapkan program kerja yang harus dilaksanakan oleh pengurus.

<h6 class="bold-centered-block">Ayat 5</h6>
Rapat anggota dihadiri oleh calon anggota resmi dan anggota resmi.

<h6 class="bold-centered-block">Ayat 6</h6>
Keputusan dalam rapat anggota diambil dengan musyawarah mufakat dan/atau suara terbanyak.

<h5 class="bold-centered-block">Pasal 16</h5>
Rapat Pengurus

<h6 class="bold-centered-block">Ayat 1</h6>
Rapat pengurus dilaksanakan untuk membahas perkembangan dan pengevaluasian aktivitas organisasi.

<h6 class="bold-centered-block">Ayat 2</h6>
Rapat pengurus dihadiri oleh para pengurus harian serta penasihat organisasi.

<h6 class="bold-centered-block">Ayat 3</h6>
Waktu pelaksanaan rapat pengurus dapat dilakukan kapan saja sesuai dengan kebutuhan.

<h5 class="bold-centered-block">Pasal 17</h5>
Rapat Evaluasi

<h6 class="bold-centered-block">Ayat 1</h6>
Rapat evaluasi dapat dilaksanakan setiap dua bulan sekali sebagai pertanggungjawaban pengurus dan evaluasi perkembangan organisasi, dapat dilakukan bersamaan dengan kopdar resmi bulanan.

<h6 class="bold-centered-block">Ayat 2</h6>
Rapat evaluasi dihadiri oleh para pengurus harian serta penasihat organisasi dan sekurang-kurangnya 1/3 (satu per tiga) dari jumlah anggota.

<h4 class="bold-centered-block">BAB IX<br>
PERUBAHAN ANGGARAN DASAR DAN PERUBAHAN ORGANISASI</h4>

<h5 class="bold-centered-block">Pasal 17<br>
Perubahan Anggaran Dasar</h5>

<h6 class="bold-centered-block">Ayat 1</h6>
Perubahan atau penyempurnaan Anggaran Dasar (AD) dan Anggaran Rumah Tangga (ART) organisasi dapat dilakukan sesuai dengan perkembangan organisasi.

<h6 class="bold-centered-block">Ayat 2</h6>
Rapat perubahan atau penyempurnaan Anggaran Dasar (AD) dan Anggaran Rumah Tangga (ART) organisasi harus melalui rapat anggota dengan syarat dihadiri minimal 2/3 (dua per tiga) dari jumlah anggota dan mendapat persetujuan ½ + 1 (setengah ditambah satu) dari jumlah peserta rapat.

<h5 class="bold-centered-block">Pasal 18<br>
Perubahan Organisasi</h5>
Perubahan organisasi hanya dapat dilakukan melalui keputusan rapat yang diadakan secara khusus yang dihadiri oleh sekurang-kurangnya 2/3 (dua per tiga) dari jumlah anggota dan mendapat persetujuan ½ + 1 (setengah ditambah satu) dari jumlah peserta rapat

<h4 class="bold-centered-block">BAB X<br>
LAIN-LAIN</h4>

<h5 class="bold-centered-block">Pasal 19</h5>
Hal-hal lain yang belum diatur dalam Anggaran dasar ini akan diatur dalam Anggaran Rumah Tangga yang tidak bertentangan dengan makna dari Anggaran Dasar.

<h5 class="bold-centered-block">Pasal 20</h5>
<h6 class="bold-centered-block">Ayat 1</h6>
Rapat dilaksanakan di Medan pada tanggal 18 Mei 2014.

<h6 class="bold-centered-block">Ayat 2</h6>
Anggaran Dasar ini berlaku terhitung mulai tanggal ditetapkan oleh rapat anggota.
<br>
<br>
<br>
<strong>
DITETAPKAN DI 	: MEDAN<br>
PADA TANGGAL	: 18 MEI 2014<br>
<br>
PENGURUS<br>
<br>
<div class="row">
<div class="col-xs-6 col-md-4">Ketua</div>
<div class="col-xs-6 col-md-4">Moderator</div>
<div class="col-xs-6 col-md-4">Sekretaris</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
<div class="col-xs-6 col-md-4">&nbsp;</div>
</div>
<div class="row">
<div class="col-xs-6 col-md-4">M. Fazrian Siregar</div>
<div class="col-xs-6 col-md-4">Asrul Arifin Siregar</div>
<div class="col-xs-6 col-md-4">Ayu Adistiani Lubis</div>
</div>
</strong>', 'articles-of-association', 6, '<a href="/articles-of-association">AD/RT</a>', 1, '127.0.0.1', '2014-04-30 09:01:12', 1, '127.0.0.1', '2014-05-25 20:11:45');


--
-- TOC entry 2591 (class 0 OID 0)
-- Dependencies: 211
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"posts_id_seq"', 1, false);


--
-- TOC entry 2542 (class 0 OID 16571)
-- Dependencies: 202
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (128, 1, 8, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (129, 1, 9, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (130, 1, 12, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (131, 1, 13, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (132, 1, 14, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (133, 1, 15, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (134, 1, 20, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (135, 1, 21, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (136, 1, 22, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (137, 1, 23, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (138, 1, 24, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (139, 1, 26, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (140, 1, 28, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (141, 1, 30, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (142, 1, 98, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (143, 1, 102, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (144, 1, 101, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (145, 1, 137, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (146, 1, 133, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (147, 1, 134, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (148, 1, 135, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (149, 1, 132, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (150, 1, 157, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (151, 1, 158, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (152, 1, 162, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (153, 1, 163, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (154, 1, 164, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (155, 1, 165, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (156, 1, 166, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (157, 2, 20, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (158, 2, 21, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (159, 2, 22, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (160, 2, 23, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (161, 2, 24, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (162, 2, 26, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (163, 2, 28, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (164, 2, 30, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (165, 2, 8, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (166, 2, 9, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (167, 2, 98, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (168, 2, 162, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (169, 3, 16, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (170, 3, 17, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (171, 3, 28, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (172, 3, 30, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (173, 177, 8, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (174, 177, 9, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (175, 177, 12, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (176, 177, 13, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (177, 177, 14, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (178, 177, 15, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (179, 177, 20, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (180, 177, 21, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (181, 177, 22, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (182, 177, 23, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (183, 177, 24, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (184, 177, 26, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (185, 177, 28, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (186, 177, 30, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (187, 177, 98, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (188, 177, 102, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (189, 177, 101, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (190, 177, 157, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (191, 177, 158, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (192, 177, 162, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (193, 177, 163, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (194, 177, 164, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (195, 177, 165, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (196, 177, 166, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (197, 178, 8, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (198, 178, 9, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (199, 178, 12, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (200, 178, 13, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (201, 178, 14, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (202, 178, 15, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (203, 178, 20, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (204, 178, 21, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (205, 178, 22, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (206, 178, 23, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (207, 178, 24, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (208, 178, 26, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (209, 178, 28, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (210, 178, 30, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (211, 178, 98, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (212, 178, 157, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (213, 178, 158, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (214, 178, 162, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (224, 2, 12, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "role_permissions" ("id", "role_id", "route_id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (225, 3, 13, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- TOC entry 2592 (class 0 OID 0)
-- Dependencies: 212
-- Name: role_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"role_permissions_id_seq"', 1, false);


--
-- TOC entry 2543 (class 0 OID 16574)
-- Dependencies: 203
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "roles" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, 'Admin', NULL, '::1', '2015-09-25 06:17:21.366', NULL, NULL, NULL);
INSERT INTO "roles" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, 'Anggota', NULL, '::1', '2015-09-25 06:17:21.366', NULL, NULL, NULL);
INSERT INTO "roles" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, 'Anonymous', NULL, '::1', '2015-09-25 06:17:21.366', NULL, NULL, NULL);
INSERT INTO "roles" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (177, 'Bendahara', NULL, '::1', '2015-09-25 06:17:21.366', NULL, NULL, NULL);
INSERT INTO "roles" ("id", "name", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (178, 'Pengurus', NULL, '::1', '2015-09-25 06:17:21.366', NULL, NULL, NULL);


--
-- TOC entry 2593 (class 0 OID 0)
-- Dependencies: 213
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"roles_id_seq"', 1, false);


--
-- TOC entry 2544 (class 0 OID 16577)
-- Dependencies: 204
-- Data for Name: routes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (162, 'expenses', 161, 'index', 'GET', NULL, 'SELECT * FROM expenses', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, 'users\/(?P<id>\d+)', 4, 'show', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, 'users\/new', 4, 'new', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, 'users\/create', 4, 'create', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (14, 'users\/(?P<id>\d+)\/edit', 4, 'edit', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (15, 'users\/(?P<id>\d+)\/update', 4, 'update', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (16, 'sessions\/create', 6, 'create', 'POST', 'login', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (17, 'sessions\/new', 6, 'new', 'GET', 'login', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (20, 'sessions\/delete', 6, 'delete', 'GET', 'logout', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (21, 'sessions\/my-profile', 6, 'my_profile', 'GET', 'my-profile', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (22, 'sessions\/new-password', 6, 'new_password', 'GET', 'new-password', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (23, 'sessions\/change-password', 6, 'change_password', 'POST', 'change-password', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (101, 'monthly-cashes\/save', 5, 'save', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (102, 'monthly-cashes\/edit', 5, 'edit', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (132, 'posts\/create', 7, 'create', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (134, 'posts\/(?P<id>\d+)\/update', 7, 'update', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (135, 'posts\/(?P<id>\d+)\/delete', 7, 'delete', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (137, 'posts\/new', 7, 'new', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (158, 'meetups\/save', 25, 'save', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (163, 'expenses\/new', 161, 'new', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (165, 'expenses\/(?P<id>\d+)\/edit', 161, 'edit', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (166, 'expenses\/(?P<id>\d+)\/update', 161, 'update', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (167, 'posts\/(?P<id>\d+)', 7, 'show', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (133, 'posts\/(?P<id>\d+)\/edit', 7, 'edit', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (157, 'meetups\/edit', 25, 'edit', 'GET', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (164, 'expenses\/create', 161, 'create', 'POST', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (28, 'home', 31, 'index', 'GET', NULL, NULL, NULL, 1, '<a href="/home">Halaman Depan</a>', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, 'users', 4, 'index', 'GET', NULL, 'SELECT * FROM mv_users', NULL, 2, '<a href="/users">Anggota</a>', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (30, 'home\/search', 31, 'search', 'POST', 'search', 'SELECT * FROM mv_users WHERE resign IS NULL', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (26, 'meetups', 25, 'index', 'GET', NULL, 'SELECT * FROM mv_users u LEFT JOIN mv_last_two_years_meetups m USING(id)', NULL, 4, '<a href="/meetups">Kopdar</a>', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (98, 'monthly-cashes', 5, 'index', 'GET', NULL, 'SELECT * FROM mv_users u LEFT JOIN mv_last_two_years_cashes c USING(id) WHERE u.resign IS NULL', NULL, 3, '<a href="/monthly-cashes">Kas</a>', NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "routes" ("id", "request_uri_pattern", "module_id", "module_method", "request_method", "alias_pattern", "query", "real_request_uri", "menu_order", "link", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (24, 'posts', 7, 'index', 'GET', NULL, 'SELECT * FROM posts p JOIN post_permissions pp ON p.id = pp.post_id JOIN roles r ON pp.role_id = r.id LEFT JOIN mv_users c ON p.created_by = c.id LEFT JOIN mv_users m ON p.modified_by = m.id', NULL, 5, '<a href="/posts">Konten</a>', NULL, NULL, NULL, NULL, NULL, NULL);


--
-- TOC entry 2594 (class 0 OID 0)
-- Dependencies: 214
-- Name: routes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"routes_id_seq"', 1, false);


--
-- TOC entry 2555 (class 0 OID 16620)
-- Dependencies: 215
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 2536 (class 0 OID 16518)
-- Dependencies: 196
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (6, '$2y$12$71fc4c535998ba323d61fuxSnDQkU1R0l0ykmXpjg8reVRbuipYFS', NULL, NULL, NULL, NULL, 2, 'Muchammad', 'Tohir', 'Lubis', 'Toink Lubis', 'Tamiang', '1983-07-22', '1213082207830002', 'Karyawan Swasta', 'Jl. Rrel No. 6 Tembung Pasar X', 'Medan', 'Sumatera Utara', 'toinkloebis@yahoo.co.id', '081396714287', 'brakeshoe', 201301, 201407, NULL, 1, '::1', '2013-10-13 12:11:36', 1, '::1', '2014-04-21 03:35:26');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (7, '$2y$12$bfa91948a40b6c6cab4e4uUM2JCvURLlgFAJajom5FKLZQrpsrP5S', NULL, NULL, NULL, NULL, 2, 'Edi', 'Tiawarman', 'Chaniago', 'Edi', 'Medan', '1979-01-20', '1271062001790001', 'Wiraswasta', 'Jl. Purwosari Gg. Keluarga Komplek Pelangi Asri Blok A - 4 Krakatau', 'Medan', 'Sumatera Utara', 'editiawarmanchaniago@yahoo.co.id', '085297979902', 'Edi.chan', 201301, 201307, NULL, 1, '::1', '2013-10-13 12:28:52', 1, '::1', '2014-04-19 23:45:22');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (8, '$2y$12$fc4a0cd26ddc128721f5aOFnWt2aI2HtFIed0BWa4wsDRmxBOpfqm', NULL, NULL, '2014-08-18 10:18:55', '2014-04-28 10:53:30', 2, 'Muhammad', 'Rezki', 'Chaniago', 'Rizki', 'Medan', '1984-04-24', '1271122404840006', 'Wiraswasta', 'Jl. Titi Pahlawan Gg. Mekar No. 75 B', 'Medan', 'Sumatera Utara', 'kinoy.chaniago@yahoo.com', '082160910984', 'mhd_rezki', 201301, 201307, NULL, 1, '::1', '2013-10-13 12:34:30', 1, '127.0.0.1', '2014-05-01 08:37:34');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (9, '$2y$12$1babdfeb974821675413cuAPIu.2EIoRahBqpKqM8cd4J23q.6PB2', NULL, NULL, '2014-05-19 14:20:47', NULL, 2, 'Fandryansyah', NULL, 'Mawanto', 'Andry', 'Parapat', '1985-04-11', '1218021104850004', 'Honorer', 'Lingkungan VII Kelurahan Tualang', 'Perbaungan', 'Sumatera Utara', 'fandryan_syah@yahoo.co.id', '081393907600', 'andry bk234jv', 201301, 201307, NULL, 1, '::1', '2013-10-13 12:39:41', 1, '::1', '2014-04-20 00:02:33');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (10, '$2y$12$9321f2b11de150a38bbffuXIOi6C4BVR19ghpmOfsH2i3ZDJCXW0K', NULL, NULL, NULL, NULL, 2, 'Muhammad', 'Iqbal', 'Pulungan', 'Iqbal', 'Medan', '1996-06-12', '1207261206960012', 'Pelajar', 'Jl. Prima Gg. Nusa Indah Pasar 7 Tembung', 'Medan', 'Sumatera Utara', 'muhammadiqbal_pulungan@yahoo.com', '081370328711', 'Iqbal Pulungan', 201301, 201301, NULL, 1, '::1', '2013-10-13 12:44:38', 42, '39.228.183.173', '2014-05-21 09:55:38');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (12, '$2y$12$af61fedcf776e0226e884uq.eQVNzrhqfVNJi8MDVKJ2lYLGHtpeK', NULL, NULL, '2014-07-15 13:15:09', '2014-05-01 11:03:34', 2, 'Yunus', NULL, 'Siregar', 'Yunus', 'Medan', '1981-06-17', '1271111706810002', 'Karyawan Swasta', 'Jl. Brigjen Zein Hamid Gg. Salak No 25 Kel. Titi Kuning, Kec. Medan Johor', 'Medan', 'Sumatera Utara', 'nex_covot@yahoo.co.id', '081362306400', 'jeebee', 201301, 201307, NULL, 1, '::1', '2013-10-13 12:50:26', 1, '::1', '2014-04-21 03:36:04');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (13, '$2y$12$24529e3396049b9aa8e5cOzff7OTSDIo0dN.5gZUwjhAQtEC3AOmi', NULL, NULL, NULL, NULL, 2, 'Khairul', NULL, 'Amni', 'Amri', 'Bandar Pulau', '1992-05-01', '1209150105920001', 'Karyawan Swasta', 'Jl. Bhakti No. 21', 'Bandar Pulau', 'Sumatera Utara', 'khairulamni28@yahoo.com', '08126542946', NULL, 201301, NULL, NULL, 1, '::1', '2013-10-13 12:58:35', 1, '::1', '2013-10-13 12:58:55');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (14, '$2y$12$f0a834f35d0a060f2f588OKVBMrrBQcuT690uwkVe34fcTUpoXp0S', NULL, NULL, '2014-05-21 08:00:49', '2014-05-21 08:03:42', 2, 'Suheriyanto', NULL, 'Ginting', 'Heriy', 'Bp. Mandoge', '1992-01-30', '1209173001920002', 'Mahasiswa', 'Dsn VIII Desa Suka Makmur, Bp. Mandoge, Asahan', 'Mandoge', 'Sumatera Utara', 'suheriyantogm@gmail.com', '081264511230', 'Suheriyanto Ginting', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:05:52', 1, '::1', '2014-04-21 03:34:38');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (15, '$2y$12$21c9a97d2798561b98544uyTtcRICEocUcB40PVY0LriwQ5aeRpBK', NULL, NULL, NULL, NULL, 2, 'Bibing', 'Sugana Wasya', 'Lubis', 'Bibing', 'Medan', '1983-01-14', '1271091401830001', 'Wiraswasta', 'Jl. Tuar No. 37 Amplas', 'Medan', 'Sumatera Utara', 'bibings@yahoo.com', '08126470051', 'bibing', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:08:31', 1, '::1', '2014-04-19 23:43:13');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (16, '$2y$12$501763c51024391d715d2ecBT4o76EuPsBwMmoDRQfrk2tdnlBDo6', NULL, NULL, '2014-07-01 06:34:00', '2014-04-28 12:32:13', 2, 'Muhammad', 'Januar', 'Pradipta', 'Nanang', 'Porsea', '1988-01-05', '1207230501880002', 'Pegawai BUMN', 'Komp. Griya Firza Blok C No. 36, Kel.Telaga Sari, Kec. Sunggal, Kab. Deli Serdang', 'Medan', 'Sumatera Utara', 'nanangpradipta0303@gmail.com', '082168728570', 'nanangmedan', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:12:06', 1, '::1', '2014-04-19 23:21:04');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (17, '$2y$12$dfd4731518d79fc3aaf9auu91f1wGyPyrJdn96qgneoLbbzfClkKG', NULL, NULL, NULL, NULL, 2, 'Yusa', NULL, 'Fachrizal', 'Yusa', 'Kualasimpang', '1978-05-27', '127113270578004', 'Karyawan Swasta', 'Jl. Tuar Indah 4 No. 291 Griya Martubung, Kel. Besar, Kec. Medan Labuhan', 'Medan', 'Sumatera Utara', 'yusafahrizal@gmail.com', '082368842401', 'inkote_mdn', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:16:23', 1, '39.229.158.115', '2014-05-05 17:18:21');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (18, '$2y$12$e2784f02d8af531f953d8OeC1Khqv.kshNs/i0l28SQDHH9QTsIkO', NULL, NULL, NULL, NULL, 2, 'Namebat', NULL, 'Sinaga', 'Lambat Leegacy', 'Medan', '1999-02-23', '9992046173', 'Pelajar', 'Jl. Printis Komp. Tembung Permai Indah No. 15, Kec. Percut Sei Tuan, Kab. Deli Serdang', 'Medan', 'Sumatera Utara', 'snamebat@yahoo.com', '081264378260', 'Namebat', 201301, 201401, NULL, 1, '::1', '2013-10-13 13:22:28', 42, '114.125.47.143', '2014-05-21 07:42:06');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (19, '$2y$12$550e9dae172e8698d4d3eO8oAQSGkoIuEI.FwtxQ3DHm4CI2BpBNW', NULL, NULL, '2014-05-21 07:47:37', '2014-05-21 07:46:55', 2, 'Suharyana', NULL, 'Akbar', 'Yana', 'Banda Aceh', '1992-05-13', '117403130519920003', 'Mahasiswa', 'Jl. Syiah Kuala Lr. Tripida, Kec. Langsa', 'Langsa', 'Nanggroe Aceh Darussalam', 'suharyana.akbar@gmail.com', '085270878751', 'Akbar13', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:28:37', 1, '::1', '2014-04-21 03:33:19');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (20, '$2y$12$ca3a218959817877a1538uxpCHHCUqOOK4BV/qAVydhDjaTLZem/i', NULL, NULL, '2014-07-22 09:28:34', '2014-05-21 05:18:39', 2, 'Munawar', NULL, 'Boyhaqqi', 'Munawar', 'Medan', '1983-10-09', '1271100910830004', 'Karyawan Swasta', 'Jl. Rahmadsyah Gang Langgar No. 20', 'Medan', 'Sumatera Utara', 'munawarnawar47@yahoo.com', '081376266633', 'munawar_boyhaqqi', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:28:39', 1, '::1', '2014-04-21 03:24:51');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (21, '$2y$12$c7bf738792131f978c6cdOFiSSJEyJtxeTCJYZFi125w7QwzoelDm', NULL, NULL, NULL, NULL, 2, 'Oomar', 'Syarif', 'Pakpahan', 'Omar', 'Padang Sidimpuan', '1979-10-19', '1277011910790005', 'Karyawan Swasta', 'Jl. Suprapto Gg. Setia Budi No. 46D', 'Padang Sidimpuan', 'Sumatera Utara', 'oom_sy@yahoo.com', '081361621910', 'Oomar', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:31:24', 1, '::1', '2014-04-21 03:29:48');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (3, '$2y$12$2f005d9ca91f84c0b9c8buQJ/UXCFHw5lMP8EW5enprvyjS2EmOgy', NULL, NULL, NULL, NULL, 2, 'Fernando', NULL, 'Sinaga', 'Nando Sinaga', 'Lubuk Basung', '1980-04-21', '1217092104800003', 'Wiraswasta', 'Jl. Besar Simanindo Desa Dosroha, Kec. Simanindo', 'Simanindo', 'Sumatera Utara', 'nandosinaga210480@gmail.com', '081360272770', 'sibangnaga', 201301, 201307, NULL, 1, '::1', '2013-10-13 11:59:36', 1, '127.0.0.1', '2014-04-28 14:51:21');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (4, '$2y$12$48dfda76f7708a02e40d1uOhUiOHtseZZ7ZL8vlxMm76E80xMBaK2', NULL, NULL, '2014-06-05 13:37:23', '2014-06-05 13:25:28', 2, 'Muhammad', 'Fauzi', 'Purba', 'Fauzi', 'Medan', '1988-07-29', '1207262907880010', 'Karyawan Swasta', 'Jl. Kenari Blok V No.27 (Komplek Medan Estate Permai) Dusun 9 Desa Medan Estate', 'Percut Sei Tuan', 'Sumatera Utara', 'fauzipurba14@yahoo.com', '085760939797', 'Fauzi Purba', 201304, 201310, NULL, 1, '::1', '2013-10-13 12:05:01', 1, '::1', '2014-04-20 00:07:36');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (5, '$2y$12$d74fdee9db7ae545380eaukhOnHGZolZcGuaJHYyGDXUWHRWGuEPq', NULL, NULL, NULL, NULL, 2, 'Mhd.', 'Irwansyah', 'Sinaga', 'Iwan', 'Medan', '1985-03-21', '1271132103850001', 'PNS', 'Pasar 5 Marelan, Gg. Sedulur', 'Medan', 'Sumatera Utara', 'i_oneguys09@yahoo.com', '081397870033', 'Irwansyah Nias', 201304, 201310, NULL, 1, '::1', '2013-10-13 12:08:30', 42, '114.125.40.14', '2014-05-12 11:27:04');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (26, '$2y$12$1ba2d8cd59e8eb16a4fbaOj9BC5tUghDIYXs/hhyvFXCZmvEnr7H.', NULL, NULL, NULL, NULL, 2, 'Ari', NULL, 'Setiawan', 'Ari New Livery', 'Tebing Tinggi', '1993-07-19', '1218161907930001', 'Mahasiswa', 'Desa Paya Pesir, Sergai', 'Tebing Tinggi', 'Sumatera Utara', 'aricom91@yahoo.co.id', '081990511818', 'Arysetiawan1525', 201309, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:52:25');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (27, '$2y$12$e6fbd5e70b2fd415559b2upWMu6m.zP8DjiGh96PTYr4NpZ8XLDBS', NULL, NULL, NULL, NULL, 2, 'Arif', 'Budiman', 'Nasution', 'Arif Nesta', 'Medan', '1973-06-19', '0201011906730002', 'Karyawan Swasta', 'Medan Percut KM.22', 'Medan', 'Sumatera Utara', 'nesta.arif@yahoo.com', '081361759931', 'ARIF NESTA', 201301, 201307, NULL, NULL, NULL, NULL, 1, '::1', '2014-04-19 23:29:29');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (28, '$2y$12$16b58478bfeb8e00d7bbaO5KOgWzAibWPXc6NizbkFy772zCWdgAy', NULL, NULL, '2014-07-12 03:15:03', '2014-04-30 07:57:14', 178, 'Ayu', 'Adistiani', 'Lubis', 'Yue', 'Medan', '1990-12-18', '1271105812900000', 'Guru', 'Jl. Gedung Arca Gg. Jawa No. 2', 'Medan', 'Sumatera Utara', 'ayu_adistiani@yahoo.com', '081376127911', 'yueTheLubis', 201301, 201307, NULL, NULL, NULL, NULL, 1, '127.0.0.1', '2014-05-25 09:54:24');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (29, '$2y$12$413ae7e0e832c683c375cOoPMPDkMK8f9ncrWuqx.0IsKz3xhB7Na', NULL, NULL, NULL, NULL, 2, 'Chandra', 'Utama', 'Pane', 'CUP', 'Medan', '1982-10-24', '3175102410820003', 'Wiraswasta', 'Jl. Menteng 7 Gg. Madrasah No. 1', 'Medan', 'Sumatera Utara', 'chandra.u.pane@facebook.com', '081369366737', 'Chandra Utama pane', 201301, 201307, NULL, NULL, NULL, NULL, 42, '202.67.45.34', '2014-05-07 10:02:55');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (30, '$2y$12$9b2ff7147d20b3dc03cc5u20ynFXuSxeZzXXOf5lItqfhHtaxsrSK', NULL, NULL, '2014-05-20 05:58:54', '2014-05-19 14:34:06', 2, 'Gilang', NULL, 'Rezky', 'Gilang', 'Mayang', '1992-09-28', '1208082809920002', 'Karyawan Swasta', 'Jl. Pengilar Gg. Pengilar 6 No.11B, Amplas', 'Medan', 'Sumatera Utara', 'gilang.rizky.94@facebook.com', '085262606260', 'Gilang Rezky', 201309, 201402, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:51:17');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (31, '$2y$12$91defb33180983574ee10uTNGKR/gXHEpTyPsJ.eD9EXAt2PxFYTi', NULL, NULL, NULL, NULL, 2, 'Hamzah', NULL, 'Sormin', 'Hamzah', 'Pematang Siantar', '1975-08-01', '12720301087500002', 'Wiraswasta', 'Jl. Perak No. O5 BLK Kel Baru', 'Siantar', 'Sumatera Utara', 'hamzah.sormin@yahoo.com', '081361394841', 'Hamzah04', 201309, 201403, NULL, NULL, NULL, NULL, 42, '114.125.47.143', '2014-05-21 07:40:36');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (32, '$2y$12$bde0b905d257abed07219uY/KNBsVNdIHUt1mIGpZOO3lUszXmW4q', NULL, NULL, NULL, NULL, 2, 'Harry', NULL, 'Yandi', 'Calcutha', NULL, NULL, NULL, 'Karyawan Swasta', 'Jl. Mistar No. 02, Ayahanda', 'Medan', 'Sumatera Utara', 'harryyandi@gmail.com1', '0813763326021', NULL, 201301, 201307, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (33, '$2y$12$48a93540abea36dd2edaauykLZrBqIH6EpwhBj9DfHpIGl2aj0Fti', NULL, NULL, NULL, NULL, 2, 'Hartono', NULL, 'Nababan', 'Karoseri', 'Siborong-borong', '1985-01-27', '1202102701850001', 'Karyawan Swasta', 'Gg. Sejahtera, Patumbak', 'Medan', 'Sumatera Utara', 'hartono.nababan.77@facebook.com', '082167113822', 'hartono_starliner', 201301, 201305, NULL, NULL, NULL, NULL, 1, '39.227.178.233', '2014-05-25 00:48:59');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (34, '$2y$12$66ad9954dddaa08896aa2uG2KkvwyDae3sp5Gt/Ai1DYP5yGfV3yi', NULL, NULL, NULL, NULL, 2, 'Indra', NULL, 'Soritua', 'Jepang', 'Tanjung Balai', '1993-05-03', '1271140305930000', 'Mahasiswa', 'Jl. Sei Kapuas Komp. Kapuas Indah Blok B No. 4', 'Medan', 'Sumatera Utara', 'takumi.fujiwara.790@facebook.com', '087766114144', 'Indra_fujiwara', 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 17:54:05');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (36, '$2y$12$0bcd906fd4189932fb87dOXkcns7KvqX8CryhlDkRbO4S7do22Hre', NULL, NULL, NULL, NULL, 2, 'Muhammad', NULL, 'Syakir', 'Syakir', 'Medan', '1971-09-15', '3173071509710002', 'Wiraswasta', 'Wisma 77 - Lt.12, Slipi', 'Jakarta Barat', 'DKI Jakarta', 'msyakir77@gmail.com', '081347711817', NULL, 201301, 201307, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:49:46');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (38, '$2y$12$a974b46c3081e1b75e71auPTAD7jrghBNXlZMJG0HUTz2pUEb74L.', NULL, NULL, '2014-07-05 09:21:09', '2014-05-22 02:47:42', 2, 'Putra', 'Agung', 'Siregar', 'Putra', 'Gunung Tua', '1983-02-28', '12200422830002', 'PNS', 'Jl. MRG. Batang Pane Lk. IV Psr Gunungtua Kec. Padang Bolak Kab. Padang Lawas Utara', 'Gunung Tua', 'Sumatera Utara', 'ucok_labo@yahoo.com', '08126358837', 'Putra83', 201307, 201401, NULL, NULL, NULL, NULL, 1, '127.0.0.1', '2014-05-01 08:32:15');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (39, '$2y$12$6256a3e486d87833878f0u2cxIjeEm.UeNjBpU41OVhyYN/o2qHj2', NULL, NULL, '2014-05-21 09:46:19', '2014-05-21 09:44:23', 2, 'M', 'Raja Akbar', 'Ritonga', 'Raja', 'Medan', '1991-01-10', '1271211001910003', 'Mahasiswa', 'Jl. Setiabudi Pasar 3 Komplek PT. Bank Sumut', 'Medan', 'Sumatera Utara', 'rajaa8riitonga@ymail.com', '085359556619', 'bungRaja', 201301, 201407, NULL, 1, '::1', '2013-10-13 12:47:09', 1, '::1', '2014-04-21 03:31:15');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (40, '$2y$12$5ba95025eb68e4844eb2buFDbYoILQJLc7Xr3CGHmi6iRwZ4Z6SJG', NULL, NULL, '2014-04-30 09:07:57', '2014-04-30 09:05:56', 178, 'Muhamad', 'Reza', 'Fahlevi', 'Reza', 'Lhokseumawe', '1994-08-27', '1271092808940002', 'Mahasiswa', 'Jl. SM Raja KM. 8 Gg Iklas, Amplas', 'Medan', 'Sumatera Utara', 'jack_2790@yahoo.com', '083199646095', 'reza_fahlevi', 201309, 201307, NULL, NULL, NULL, NULL, 1, '127.0.0.1', '2014-05-25 09:54:24');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (41, '$2y$12$1b135d535a4d3c49cbe8cu.FGAVzJYTs/ruSFiAn85/Yb9bwL6.Ri', NULL, NULL, NULL, NULL, 2, 'Rylan', 'L.', 'Toruan', 'Rylan', 'Surabaya', '1983-05-06', '3578210605830001', 'Karyawan Swasta', 'Komplek TVRI No. 32 Dukuh Pakis', 'Surabaya', 'Jawa Timur', 'rylan.lumbantoruan@yahoo.com', '082125053775', NULL, 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:01:24');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (42, '$2y$12$c7947397e9f4814baf1e6uP/wqnfDJ/jEfOE5xhfFIADUh0ohHquO', NULL, NULL, '2014-07-20 10:49:56', '2014-04-29 13:20:57', 178, 'Suhardi', NULL, 'Hasibuan', 'Suhardi', 'Hutanopan', '1978-11-15', '1271041511780008', 'Karyawan Swasta', 'Jl. Rawa Cangkuk Gg Kemiri No. 4', 'Medan', 'Sumatera Utara', 'margalagala@yahoo.co.id', '081260806093', 'Suhardi_Hasibuan', 201301, 201307, NULL, NULL, NULL, NULL, 1, '127.0.0.1', '2014-05-25 09:54:24');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (43, '$2y$12$99da0e6822afde4535712uUrBHBwQC.UnsfJDn7GdRi2myg8uhyA2', NULL, NULL, NULL, NULL, 2, 'Syahrul', NULL, 'Habib', 'Habib', 'Jambi', '1990-09-12', '1504041209900003', 'Mahasiswa', 'Jl. Pukat 4 No. 42, Aksara', 'Medan', 'Sumatera Utara', 'syahrulbib@yahoo.com', '085268089710', 'syahrul habib', 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:03:24');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (44, '$2y$12$7bcd8911f8c100de084e1egqed1Fqg1X0u9eqef9hla.M.nIpW7t.', NULL, NULL, NULL, NULL, 2, 'Veri', 'Agung', 'Setiawan', 'Mas Bro', 'Magelang', '1982-05-14', '1219021405820003', 'Karyawan Swasta', 'Tg. Gading, Sei Suka', 'Kab. Batu Bara', 'Sumatera Utara', 'very_as@yahoo.co.id', '081260305226', NULL, 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.121.248', '2014-05-02 15:28:01');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (22, '$2y$12$918ff71a7aa42f861148cOyM5NsNpYcqYh3kp.HWDefWjNL25RkXG', NULL, NULL, NULL, NULL, 2, 'Iwan', NULL, NULL, 'Bang Landong', NULL, '1974-08-05', NULL, 'Wiraswasta', 'Jl. Imam Bonjol Gg. Sungai III NO. 6', 'Padang Sidimpuan', 'Sumatera Utara', 'landongbang@yahoo.com', '081260665707', 'bang', 201307, NULL, 201311, 1, '::1', '2013-10-13 13:34:02', 1, '::1', '2013-10-13 13:34:11');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (24, '$2y$12$135172ee11040b84f1e0ee9F.Fedb4u4STNJQzmFljnfTZf.wNi0S', NULL, NULL, NULL, NULL, 2, 'Andi', NULL, 'Siregar', 'Andi Kendil', 'Gunung Tua', '1983-10-19', '122004191084003', 'Wiraswasta', 'Gunung Tua Kab. Padang Lawas Utara', 'Gunung Tua', 'Sumatera Utara', 'andi.kendil@ymail.com', '081293585373', 'Aspak', 201307, 201402, NULL, NULL, NULL, NULL, 1, '114.125.42.69', '2014-05-11 18:17:07');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (25, '$2y$12$cceb6bd24399b2c0648dfu5PQy4ASV9qWQxGq/8BlCoGlyuOf38jm', NULL, NULL, NULL, NULL, 2, 'Andreas', 'Christo', 'Pakpahan', 'Andreas', 'Tj. Selamat', '1995-04-01', '1207230104950010', 'Mahasiswa', 'Jl. Tanjung Selamat Perum. Griya Tanjung Selamat Blok E12', 'Medan', 'Sumatera Utara', 'andrina20@yahoo.com', '089613241433', 'Androla', 201301, 201301, NULL, NULL, NULL, NULL, 42, '202.67.45.43', '2014-05-06 06:29:29');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (53, '$2y$12$74cdf60003f7adbe9e1c4uiQ8zoAflLxEsrBUlOyMdBwSQi.QYJrW', NULL, NULL, '2014-06-10 09:21:57', NULL, 2, 'Rizki', NULL, 'Ananda', 'Ampoen', 'Aceh Utara', '1989-05-25', '890506140087', 'Wiraswasta', 'Jl. T. Nyak Arief Lor. Aria No. 17', 'Banda Aceh', 'Nanggroe Aceh Darussalam', 'riezka89@yahoo.com', '08126955558990', 'Ampon89', 201401, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:16:50');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (54, '$2y$12$265d2439f01c760206cfau3fwhWBfNVlHKwTY7YKE.gNzfJdHk7gu', NULL, NULL, '2014-08-16 10:06:05', '2014-05-21 11:27:02', 2, 'Mohamad', 'Dhyo', 'Ramadhan', 'Dhyo', 'Medan', '2000-01-02', '244/SMPN 7 Binjai/2013', 'Pelajar', 'Jl. Cangkir No. 26, Kel.Nangka', 'Binjai Utara', 'Sumatera Utara', 'ramadhandhyo@gmail.com', '087891900353', 'Mohamad Dhyo Ramadha', 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:18:17');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (55, '$2y$12$eb22c48840c4c7683a1d1uJZoZoGhpkWQpdK3lYEp3bwIwcSWFUzi', NULL, NULL, '2014-05-23 02:58:37', '2014-05-21 09:42:32', 2, 'Kurniawan', NULL, NULL, 'Slamet', 'Kp. Mandailing', '1993-02-28', '1205030706890001', 'Karyawan Swasta', 'Desa Sido Makmur, Kecamatan Kuala', 'Kab. Langkat', 'Sumatera Utara', 'kurniawan_inginselamat@gmail.com', '087869044393', 'Kurniawan_Medan', 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:19:27');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (56, '$2y$12$9ce34995e11da67679572utK5NDajc8gyrLcWedX17mRc0pfkGeFO', NULL, NULL, NULL, NULL, 2, 'Roby', NULL, 'Andrian', 'Roby', 'Medan', '1993-11-11', '1201041111930001', 'Karyawan Swasta', 'Jl. Lembaga Pemasyarakatan, Tanjung Gusta', 'Medan', 'Sumatera Utara', 'randrian716@gmail.com', '083194735557', NULL, 201301, NULL, NULL, NULL, NULL, NULL, 1, '127.0.0.1', '2014-04-28 14:47:16');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (57, '$2y$12$6b925cb52bef3957ead93unoHTVFUG4DOlgXL3j4StPpuCQ1XvCYe', NULL, NULL, NULL, NULL, 2, 'Ralph', 'Chandra', 'Timothy', 'Chandra', 'P. Siantar', '1988-09-17', '1271181709890001', 'Karyawan Swasta', 'Jl. Mapilindo No. 45', 'Medan', 'Sumatera Utara', 'machan89@gmail.com', '082370044300', 'Chandra_Manurung', 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:21:02');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (59, '$2y$12$259d18154806905d17c39uKaYCjhGEdu/6ZSfqAys3NbkZYpU7zoS', NULL, NULL, '2014-05-22 13:27:16', NULL, 2, 'Ahmad', NULL, 'Salman', 'Salman', 'Tanjung Tiram', '1980-10-25', '1219062510800004', 'Wiraswasta', 'Jl. Merdeka No. 108', 'Tanjung Tiram', 'Sumatera Utara', 'putra_melayu82@yahoo.com', '08126516982', 'Alang_Bento', 201301, 201307, NULL, NULL, NULL, NULL, 1, '39.225.14.196', '2014-05-06 05:15:14');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (60, '$2y$12$87b482264016b08c32c0fuhmpSCS2Q./ZGb6sTOw/hr8Udye9XJb.', NULL, NULL, NULL, NULL, 2, 'Ali', 'Affan', 'Nasution', 'Ali', 'Jakarta', '1997-02-06', '976/SMK_Yapis/DT/2013', 'Pelajar', 'Jl. Stm Ujung No. 116', 'Medan', 'Sumatera Utara', 'aliaffannst@gmail.com', '087867943450', 'Ali Affan Nasution', 201401, NULL, NULL, NULL, NULL, NULL, 1, '39.225.218.199', '2014-05-13 18:28:10');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (61, '$2y$12$bd0e830e0e505ec832131u1o3JT8s4nEgy/Da8Zrcs/jg2DBEyX1.', NULL, NULL, NULL, NULL, 2, 'Triwandes', NULL, 'Saragih', 'Wandes', 'Tinjowan', '1994-12-31', '1208303112950008', 'Mahasiswa', 'Ujung Padang', 'Kab. Simalungun', 'Sumatera Utara', 'ganteng_saragih@yahoo.co.id', '081262918990', 'cragih', 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.225.218.199', '2014-05-13 18:26:18');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (62, '$2y$12$692eff3fc1ba92734fcdfOj0LdLOaBtbh0FpnVdVc34/CH3Ws8sQW', NULL, NULL, NULL, NULL, 2, 'Oky', 'Arbian', 'Syahputra', 'Okky', 'Medan', '1996-10-13', '1207051310960003', 'Pelajar', 'Tuntungan 1, Kec. Pancur Batu Gg. Bina karya', 'Medan', 'Sumatera Utara', 'okky13arbian@gmail.com', '082165763599', 'Arbian', 201401, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:35:49');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (63, '$2y$12$e291ff02f37a9094bc086uZdStgigL8w3WNTzUjwsqThJE5MPNwcC', NULL, NULL, NULL, NULL, 2, 'Mhd.', 'Alfarizi', 'Harahap', 'Alfarizi', 'Ulu Air', '1988-06-16', '1222041606880008', 'Wiraswasta', 'Dusun Karang Sari, Kec. Sungai', 'Kanan Kab. LABUSEL', 'Sumatera Utara', 'alfarizyhara@yahoo.com', '08126323039', 'al_farizi', 201401, NULL, NULL, 1, '114.125.40.201', '2014-05-01 15:36:11', 1, '39.229.158.115', '2014-05-05 18:26:00');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (64, '$2y$12$5e1957f6880b9956337fduwli6r50C9eSzvtV/uiXI7/lLg3Ku2Yq', NULL, NULL, NULL, NULL, 2, 'Ahmad', NULL, NULL, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 201302, NULL, NULL, 1, '39.233.92.129', '2014-05-02 22:41:17', NULL, NULL, NULL);
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (65, '$2y$12$fdb17777fd76cf99c91e1u6hg4mrzdd7B0h51O0wjfeCHITju.HRu', NULL, NULL, NULL, NULL, 2, 'Ivan', NULL, NULL, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 201302, NULL, NULL, 1, '39.233.92.129', '2014-05-02 22:43:11', NULL, NULL, NULL);
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (66, '$2y$12$33ef9577bd4f3c4a79755uMOFSJtN.sb8vfUeGjGZ47MyvwrVQS96', NULL, NULL, NULL, NULL, 2, 'Alif', NULL, NULL, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 201302, NULL, NULL, 1, '39.233.92.129', '2014-05-02 22:43:49', NULL, NULL, NULL);
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (67, '$2y$12$3a5328decb8901ab6083duYMAHdp5npmK6O9owCOKV1I3pGWDq7Du', NULL, NULL, NULL, NULL, 2, 'Hermita', 'Sari', 'Lubis', 'Mita', 'Medan', '1986-12-27', '085327', 'Wiraswasta', 'Arengka Indah', 'Pekanbaru', 'Riau', 'mita@situmorang.org', '085327', 'meethaazza', 201501, 201507, NULL, 1, '::1', '2015-09-25 21:05:09', 1, '::1', '2015-09-27 05:13:08');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (51, '$2y$12$c62776ca754c1771f1e29u610gYsLzCK2TB8DH511p1d9tQepVyeS', NULL, NULL, NULL, NULL, 2, 'Azuar', 'Syah', 'Sembiring', 'Zuar', 'Binjai', '1993-01-27', '1275012701930005', 'Mahasiswa', 'Jl. Teuku Amir Hamzah No. 160', 'Binjai', 'Sumatera Utara', 'azuar_sembiring@yahoo.com', '087713828867', 'Azuar Sembiring', 201301, NULL, NULL, NULL, NULL, NULL, 42, '202.67.45.43', '2014-05-06 08:12:42');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2, '$2y$12$3ee5d3feb6de176fe1091eNqcUzg5I7kLsgRKyeYPU074ivNVPh7O', NULL, NULL, '2014-08-31 15:45:47', '2014-04-28 15:32:43', 177, 'Asrul', 'Arifin', 'Siregar', 'Asrul', 'Medan', '1986-05-20', '1271142005860002', 'Guru', 'Jl. Aksara Gang Sepakat No. 29', 'Medan', 'Sumatera Utara', 'asrul_alonso@yahoo.com', '081396735267', 'alonso', 201301, 201307, NULL, 1, '::1', '2013-09-27 05:36:24', 1, '127.0.0.1', '2014-05-25 09:53:21');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (47, '$2y$12$d19c83c12799dd7b453caufHjcK0h3M7jlQ142Nz0Aprvy9dnA34e', NULL, NULL, '2014-08-10 09:02:04', NULL, 2, 'Mardi', 'Johan', 'Malau', 'Marjo', 'Tebing Tinggi', '1995-05-04', NULL, 'Wiraswasta', 'Jl. Stasiun lama', 'Tebing Tinggi', 'Sumatera Utara', 'mardijohanmalau@gmail.com', '081990452028', 'Mardi Johan Malau', 201401, NULL, NULL, NULL, NULL, NULL, 1, '39.227.178.233', '2014-05-25 00:56:07');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (48, '$2y$12$3626cdf2f5e7171a6cc92OdPVDhhuhrzrBLmMATGDh5.CRXgM4Jfm', NULL, NULL, NULL, NULL, 2, 'Welly', NULL, 'Purba', 'Welly', 'Siantar', '1996-07-23', '1272022307960000', 'Pelajar', 'Jl. Mawar No. 16B', 'Siantar', 'Sumatera Utara', 'wellpurba@yahoo.com', '082368496275', 'Welly Purba', 201401, NULL, NULL, NULL, NULL, NULL, 1, '39.225.218.199', '2014-05-13 18:27:11');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (50, '$2y$12$7dc56e67a1c9e18ffa1f5uCkNESF3kM3KJOGWEIE7ACuWK3lf9VZa', NULL, NULL, NULL, NULL, 2, 'Maruba', NULL, 'Sitohang', 'MTG', 'Silampuyang', '1980-11-05', '1271040511800007', 'Karyawan Swasta', 'Jl. Menteng VII Gg. Garuda II No. 17A', 'Medan', 'Sumatera Utara', 'sitohangnaburju@rocketmail.com', '081371142931', NULL, 201301, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:14:04');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (37, '$2y$12$6fcb6ab51063fc3a3375auCQO3L8n7L8n/NlQRv.0MiqXf0WgZU2K', NULL, NULL, NULL, NULL, 2, 'Aburizal', 'Munadi', 'Ahmad', 'Munadi', 'Tebing tinggi', '1995-08-01', '1276001089000001', 'Pelajar', 'Jl. Gatot Subroto km 5 Pabatu', 'Tebing Tinggi', 'Sumatera Utara', 'munadirizal02@gmai.com', '083196457359', 'Munadi Rizal', 201307, NULL, NULL, NULL, NULL, NULL, 1, '::1', '2015-09-28 07:18:14');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (52, '$2y$12$e27188f759c893a7039cbutTJH37h.jP8Y1jtIq/PHJzNADHqgIea', NULL, NULL, '2015-09-27 08:39:04', NULL, 2, 'Tri', NULL, 'Widyastuti', 'Widi', 'Peranap', '1994-12-23', '1402146312940003', 'Mahasiswa', 'Asrama Kavaleri Asam Kumbang', 'Medan', 'Sumatera Utara', 'triwidyastuti94@yahoo.co.id', '081264922219', 'Tri Widyastuti', 201401, NULL, NULL, NULL, NULL, NULL, 1, '::1', '2015-09-27 19:28:22');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (45, '$2y$12$e7bf4ec48513845d17f6deY11tvGceFw4cQG3nhSGRwW2VCEdapn2', NULL, NULL, NULL, NULL, 2, 'Anggi', 'Gratsia', 'Orisa', 'Anggi', 'Jakarta', '1988-03-02', '1271190203880002', 'Mahasiswa', 'Jl. Agenda No. 39', 'Medan', 'Sumatera Utara', 'sib.gibonk@yahoo.com', '081375325772', 'Anggi Gibonk Sibarani', 201401, NULL, NULL, NULL, NULL, NULL, 1, '39.229.158.115', '2014-05-05 18:48:15');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (23, '$2y$12$6274ffde3533d3a882f53u4BqV2b1UHQ.cHrzHIqEKijpccAyGmea', NULL, NULL, '2014-05-19 14:28:15', '2014-05-19 14:27:33', 178, 'Muhammad', 'Fazrian', 'Siregar', 'Rian', 'Medan', '1992-08-13', '1220041308920001', 'Mahasiswa', 'Jl. Letjen Jamin Ginting Lor. IX, Sumber, P. Bulan', 'Medan', 'Sumatera Utara', 'muhammadfazrian.siregar@yahoo.co.id', '081265130797', 'ryan.siregar', 201301, 201307, NULL, 1, '::1', '2013-10-13 13:37:32', 1, '127.0.0.1', '2014-05-25 09:54:24');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (46, '$2y$12$56e87313f332f0e831765O.sxNrdQ0zU4B6TBoWNPb0lpcfB7.4TW', NULL, NULL, '2014-06-05 07:24:12', NULL, 2, 'Heru', NULL, 'Nugraha', 'Heru', 'Lhoksukon Aceh Utara', '1985-12-12', '1275041212850008', 'Karyawan Swasta', 'Jl. SM. Raja Gg. Jihat No. 2', 'Binjai', 'Sumatera Utara', 'heru_nugraha12@yahoo.com', '081361236293', 'heru_nugraha', 201401, NULL, NULL, NULL, NULL, NULL, 1, '127.0.0.1', '2014-05-01 08:29:47');
INSERT INTO "users" ("id", "hash", "question", "answer", "last_login", "last_password_change", "role_id", "first", "middle", "last", "alias", "pob", "dob", "ktp_sim", "occupation", "address", "city", "province", "email", "phone", "forbiscom_id", "join", "permanent", "resign", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (1, '$2y$12$nhcrKaCkXtZ9NBL5jrAda.SWOVfydjRkv5Hf/Q6G8Z567e2bKH24u', 'Hang awe hanyu?', 'Hang ina', '2017-03-18 17:12:46', '2017-03-18 17:21:43', 1, 'Roy', 'M. F.', 'Situmorang', 'Roy', 'Silumboyah', '1981-06-06', '1211070606810004', 'Programmer', 'Jl. Mandala By Pass Gg. Orba No. 41A', 'Medan', 'Sumatera Utara', 'roy.situmorang@gmail.com', '085233494271', 'darkstar', 201301, 201307, NULL, NULL, '::1', '2013-09-24 09:58:58', 1, '127.0.0.1', '2017-03-18 17:21:43');


--
-- TOC entry 2595 (class 0 OID 0)
-- Dependencies: 216
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"users_id_seq"', 67, true);


--
-- TOC entry 2557 (class 0 OID 16628)
-- Dependencies: 217
-- Data for Name: years; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "years" ("id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2013, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "years" ("id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2014, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "years" ("id", "created_by", "created_ip", "created_at", "modified_by", "modified_ip", "modified_at") VALUES (2015, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- TOC entry 2596 (class 0 OID 0)
-- Dependencies: 218
-- Name: years_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"years_id_seq"', 1, false);


--
-- TOC entry 2286 (class 2606 OID 16651)
-- Name: cashes cashes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "cashes"
    ADD CONSTRAINT "cashes_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2288 (class 2606 OID 16653)
-- Name: cashes cashes_user_id_period_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "cashes"
    ADD CONSTRAINT "cashes_user_id_period_id_key" UNIQUE ("user_id", "period_id");


--
-- TOC entry 2290 (class 2606 OID 16655)
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2292 (class 2606 OID 16657)
-- Name: meetups meetups_period_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "meetups"
    ADD CONSTRAINT "meetups_period_id_user_id_key" UNIQUE ("period_id", "user_id");


--
-- TOC entry 2294 (class 2606 OID 16659)
-- Name: meetups meetups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "meetups"
    ADD CONSTRAINT "meetups_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2296 (class 2606 OID 16661)
-- Name: modules modules_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "modules"
    ADD CONSTRAINT "modules_name_key" UNIQUE ("name");


--
-- TOC entry 2298 (class 2606 OID 16663)
-- Name: modules modules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "modules"
    ADD CONSTRAINT "modules_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2300 (class 2606 OID 16665)
-- Name: mv_cashes mv_cashes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_cashes"
    ADD CONSTRAINT "mv_cashes_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2302 (class 2606 OID 16667)
-- Name: mv_cashes mv_cashes_user_id_year_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_cashes"
    ADD CONSTRAINT "mv_cashes_user_id_year_id_key" UNIQUE ("user_id", "year_id");


--
-- TOC entry 2317 (class 2606 OID 16669)
-- Name: mv_meetups mv_meetups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_meetups"
    ADD CONSTRAINT "mv_meetups_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2319 (class 2606 OID 16671)
-- Name: mv_meetups mv_meetups_user_id_year_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_meetups"
    ADD CONSTRAINT "mv_meetups_user_id_year_id_key" UNIQUE ("user_id", "year_id");


--
-- TOC entry 2341 (class 2606 OID 16673)
-- Name: periods periods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "periods"
    ADD CONSTRAINT "periods_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2343 (class 2606 OID 16675)
-- Name: post_access_logs post_access_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_access_logs"
    ADD CONSTRAINT "post_access_logs_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2345 (class 2606 OID 16677)
-- Name: post_access_logs post_access_logs_post_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_access_logs"
    ADD CONSTRAINT "post_access_logs_post_id_user_id_key" UNIQUE ("post_id", "user_id");


--
-- TOC entry 2321 (class 2606 OID 16679)
-- Name: post_permissions post_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_permissions"
    ADD CONSTRAINT "post_permissions_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2323 (class 2606 OID 16681)
-- Name: post_permissions post_permissions_role_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_permissions"
    ADD CONSTRAINT "post_permissions_role_id_post_id_key" UNIQUE ("role_id", "post_id");


--
-- TOC entry 2282 (class 2606 OID 16683)
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "posts"
    ADD CONSTRAINT "posts_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2325 (class 2606 OID 16685)
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "role_permissions"
    ADD CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2327 (class 2606 OID 16687)
-- Name: role_permissions role_permissions_role_id_route_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "role_permissions"
    ADD CONSTRAINT "role_permissions_role_id_route_id_key" UNIQUE ("role_id", "route_id");


--
-- TOC entry 2331 (class 2606 OID 16689)
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "roles"
    ADD CONSTRAINT "roles_name_key" UNIQUE ("name");


--
-- TOC entry 2333 (class 2606 OID 16691)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2335 (class 2606 OID 16693)
-- Name: routes routes_menu_order_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "routes"
    ADD CONSTRAINT "routes_menu_order_key" UNIQUE ("menu_order");


--
-- TOC entry 2337 (class 2606 OID 16695)
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "routes"
    ADD CONSTRAINT "routes_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2339 (class 2606 OID 16697)
-- Name: routes routes_request_uri_pattern_request_method_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "routes"
    ADD CONSTRAINT "routes_request_uri_pattern_request_method_key" UNIQUE ("request_uri_pattern", "request_method");


--
-- TOC entry 2347 (class 2606 OID 16699)
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2305 (class 2606 OID 16701)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");


--
-- TOC entry 2307 (class 2606 OID 16703)
-- Name: users users_forbiscom_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_forbiscom_id_key" UNIQUE ("forbiscom_id");


--
-- TOC entry 2309 (class 2606 OID 16705)
-- Name: users users_ktp_sim_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_ktp_sim_key" UNIQUE ("ktp_sim");


--
-- TOC entry 2312 (class 2606 OID 16707)
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_phone_key" UNIQUE ("phone");


--
-- TOC entry 2314 (class 2606 OID 16709)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2349 (class 2606 OID 16711)
-- Name: years years_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "years"
    ADD CONSTRAINT "years_pkey" PRIMARY KEY ("id");


--
-- TOC entry 2283 (class 1259 OID 16712)
-- Name: cashes_created_by_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "cashes_created_by_idx" ON "cashes" USING "btree" ("created_by");


--
-- TOC entry 2284 (class 1259 OID 16713)
-- Name: cashes_modified_by_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "cashes_modified_by_idx" ON "cashes" USING "btree" ("modified_by");


--
-- TOC entry 2315 (class 1259 OID 16714)
-- Name: mv_last_two_years_cashes_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "mv_last_two_years_cashes_id_idx" ON "mv_last_two_years_cashes" USING "btree" ("id");


--
-- TOC entry 2350 (class 1259 OID 17019)
-- Name: mv_users_full_name_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "mv_users_full_name_idx" ON "mv_users" USING "btree" ("full_name");


--
-- TOC entry 2351 (class 1259 OID 17020)
-- Name: mv_users_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "mv_users_id_idx" ON "mv_users" USING "btree" ("id");


--
-- TOC entry 2352 (class 1259 OID 17021)
-- Name: mv_users_resign_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "mv_users_resign_idx" ON "mv_users" USING "btree" ("resign");


--
-- TOC entry 2328 (class 1259 OID 16718)
-- Name: roles_created_by_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "roles_created_by_idx" ON "roles" USING "btree" ("created_by");


--
-- TOC entry 2329 (class 1259 OID 16719)
-- Name: roles_modified_by_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "roles_modified_by_idx" ON "roles" USING "btree" ("modified_by");


--
-- TOC entry 2303 (class 1259 OID 16720)
-- Name: users_created_by_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "users_created_by_idx" ON "users" USING "btree" ("created_by");


--
-- TOC entry 2310 (class 1259 OID 16721)
-- Name: users_modified_by_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "users_modified_by_idx" ON "users" USING "btree" ("modified_by");


--
-- TOC entry 2358 (class 2606 OID 16722)
-- Name: cashes cashes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "cashes"
    ADD CONSTRAINT "cashes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2355 (class 2606 OID 16727)
-- Name: cashes cashes_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "cashes"
    ADD CONSTRAINT "cashes_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2356 (class 2606 OID 16732)
-- Name: cashes cashes_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "cashes"
    ADD CONSTRAINT "cashes_period_id_fkey" FOREIGN KEY ("period_id") REFERENCES "periods"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2357 (class 2606 OID 16737)
-- Name: cashes cashes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "cashes"
    ADD CONSTRAINT "cashes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2359 (class 2606 OID 16742)
-- Name: expenses expenses_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "expenses"
    ADD CONSTRAINT "expenses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2360 (class 2606 OID 16747)
-- Name: expenses expenses_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "expenses"
    ADD CONSTRAINT "expenses_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2361 (class 2606 OID 16752)
-- Name: meetups meetups_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "meetups"
    ADD CONSTRAINT "meetups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE;


--
-- TOC entry 2362 (class 2606 OID 16757)
-- Name: meetups meetups_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "meetups"
    ADD CONSTRAINT "meetups_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE;


--
-- TOC entry 2363 (class 2606 OID 16762)
-- Name: meetups meetups_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "meetups"
    ADD CONSTRAINT "meetups_period_id_fkey" FOREIGN KEY ("period_id") REFERENCES "periods"("id") ON UPDATE CASCADE;


--
-- TOC entry 2364 (class 2606 OID 16767)
-- Name: meetups meetups_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "meetups"
    ADD CONSTRAINT "meetups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON UPDATE CASCADE;


--
-- TOC entry 2365 (class 2606 OID 16772)
-- Name: modules modules_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "modules"
    ADD CONSTRAINT "modules_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2366 (class 2606 OID 16777)
-- Name: modules modules_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "modules"
    ADD CONSTRAINT "modules_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2367 (class 2606 OID 16782)
-- Name: mv_cashes mv_cashes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_cashes"
    ADD CONSTRAINT "mv_cashes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2368 (class 2606 OID 16787)
-- Name: mv_cashes mv_cashes_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_cashes"
    ADD CONSTRAINT "mv_cashes_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2369 (class 2606 OID 16792)
-- Name: mv_cashes mv_cashes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_cashes"
    ADD CONSTRAINT "mv_cashes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2370 (class 2606 OID 16797)
-- Name: mv_cashes mv_cashes_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_cashes"
    ADD CONSTRAINT "mv_cashes_year_id_fkey" FOREIGN KEY ("year_id") REFERENCES "years"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2377 (class 2606 OID 16802)
-- Name: mv_meetups mv_meetups_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_meetups"
    ADD CONSTRAINT "mv_meetups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2378 (class 2606 OID 16807)
-- Name: mv_meetups mv_meetups_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_meetups"
    ADD CONSTRAINT "mv_meetups_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2379 (class 2606 OID 16812)
-- Name: mv_meetups mv_meetups_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_meetups"
    ADD CONSTRAINT "mv_meetups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2380 (class 2606 OID 16817)
-- Name: mv_meetups mv_meetups_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "mv_meetups"
    ADD CONSTRAINT "mv_meetups_year_id_fkey" FOREIGN KEY ("year_id") REFERENCES "years"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2394 (class 2606 OID 16822)
-- Name: periods periods_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "periods"
    ADD CONSTRAINT "periods_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2395 (class 2606 OID 16827)
-- Name: periods periods_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "periods"
    ADD CONSTRAINT "periods_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2396 (class 2606 OID 16832)
-- Name: periods periods_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "periods"
    ADD CONSTRAINT "periods_year_id_fkey" FOREIGN KEY ("year_id") REFERENCES "years"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2397 (class 2606 OID 16837)
-- Name: post_access_logs post_access_logs_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_access_logs"
    ADD CONSTRAINT "post_access_logs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2398 (class 2606 OID 16842)
-- Name: post_access_logs post_access_logs_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_access_logs"
    ADD CONSTRAINT "post_access_logs_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2399 (class 2606 OID 16847)
-- Name: post_access_logs post_access_logs_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_access_logs"
    ADD CONSTRAINT "post_access_logs_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2400 (class 2606 OID 16852)
-- Name: post_access_logs post_access_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_access_logs"
    ADD CONSTRAINT "post_access_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2381 (class 2606 OID 16857)
-- Name: post_permissions post_permissions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_permissions"
    ADD CONSTRAINT "post_permissions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2382 (class 2606 OID 16862)
-- Name: post_permissions post_permissions_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_permissions"
    ADD CONSTRAINT "post_permissions_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2383 (class 2606 OID 16867)
-- Name: post_permissions post_permissions_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_permissions"
    ADD CONSTRAINT "post_permissions_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2384 (class 2606 OID 16872)
-- Name: post_permissions post_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "post_permissions"
    ADD CONSTRAINT "post_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2353 (class 2606 OID 16877)
-- Name: posts posts_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "posts"
    ADD CONSTRAINT "posts_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2354 (class 2606 OID 16882)
-- Name: posts posts_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "posts"
    ADD CONSTRAINT "posts_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2385 (class 2606 OID 16887)
-- Name: role_permissions role_permissions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "role_permissions"
    ADD CONSTRAINT "role_permissions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2386 (class 2606 OID 16892)
-- Name: role_permissions role_permissions_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "role_permissions"
    ADD CONSTRAINT "role_permissions_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2387 (class 2606 OID 16897)
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "role_permissions"
    ADD CONSTRAINT "role_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2388 (class 2606 OID 16902)
-- Name: role_permissions role_permissions_route_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "role_permissions"
    ADD CONSTRAINT "role_permissions_route_id_fkey" FOREIGN KEY ("route_id") REFERENCES "routes"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2389 (class 2606 OID 16907)
-- Name: roles roles_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "roles"
    ADD CONSTRAINT "roles_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2390 (class 2606 OID 16912)
-- Name: roles roles_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "roles"
    ADD CONSTRAINT "roles_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2391 (class 2606 OID 16917)
-- Name: routes routes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "routes"
    ADD CONSTRAINT "routes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2392 (class 2606 OID 16922)
-- Name: routes routes_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "routes"
    ADD CONSTRAINT "routes_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2393 (class 2606 OID 16927)
-- Name: routes routes_module_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "routes"
    ADD CONSTRAINT "routes_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "modules"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2401 (class 2606 OID 16932)
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "sessions"
    ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2371 (class 2606 OID 16937)
-- Name: users users_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2372 (class 2606 OID 16942)
-- Name: users users_join_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_join_fkey" FOREIGN KEY ("join") REFERENCES "periods"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2373 (class 2606 OID 16947)
-- Name: users users_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2374 (class 2606 OID 16952)
-- Name: users users_permanent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_permanent_fkey" FOREIGN KEY ("permanent") REFERENCES "periods"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2375 (class 2606 OID 16957)
-- Name: users users_resign_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_resign_fkey" FOREIGN KEY ("resign") REFERENCES "periods"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2376 (class 2606 OID 16962)
-- Name: users users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "users"
    ADD CONSTRAINT "users_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2402 (class 2606 OID 16967)
-- Name: years years_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "years"
    ADD CONSTRAINT "years_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2403 (class 2606 OID 16972)
-- Name: years years_modified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "years"
    ADD CONSTRAINT "years_modified_by_fkey" FOREIGN KEY ("modified_by") REFERENCES "users"("id") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2537 (class 0 OID 16524)
-- Dependencies: 197 2561
-- Name: mv_last_two_years_cashes; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: postgres
--

REFRESH MATERIALIZED VIEW "mv_last_two_years_cashes";


--
-- TOC entry 2539 (class 0 OID 16556)
-- Dependencies: 199 2561
-- Name: mv_last_two_years_meetups; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: postgres
--

REFRESH MATERIALIZED VIEW "mv_last_two_years_meetups";


--
-- TOC entry 2545 (class 0 OID 16584)
-- Dependencies: 205 2561
-- Name: mv_role_permissions; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: postgres
--

REFRESH MATERIALIZED VIEW "mv_role_permissions";


--
-- TOC entry 2559 (class 0 OID 17011)
-- Dependencies: 219 2561
-- Name: mv_users; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: postgres
--

REFRESH MATERIALIZED VIEW "mv_users";


-- Completed on 2017-03-19 00:24:44 WIB

--
-- PostgreSQL database dump complete
--

