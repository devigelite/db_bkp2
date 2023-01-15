--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3 (Debian 13.3-1.pgdg110+1)
-- Dumped by pg_dump version 13.3 (Debian 13.3-1.pgdg110+1)

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
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: appointment_request_status_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.appointment_request_status_type AS ENUM (
    'WAITINGFORNURSETOACCEPT',
    'ACCEPTED',
    'REJECTED',
    'CANCELLED'
);


ALTER TYPE public.appointment_request_status_type OWNER TO postgres;

--
-- Name: appointment_schedule_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.appointment_schedule_type AS ENUM (
    'ONCE',
    'DAILY',
    'WEEKLY'
);


ALTER TYPE public.appointment_schedule_type OWNER TO postgres;

--
-- Name: appointment_status_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.appointment_status_type AS ENUM (
    'WAITINGFORNURSETOACCEPT',
    'ACCEPTED',
    'REJECTED',
    'CANCELLED'
);


ALTER TYPE public.appointment_status_type OWNER TO postgres;

--
-- Name: appointment_visit_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.appointment_visit_type AS ENUM (
    'SINGLE_VISIT',
    'RECURRING_VISIT',
    'LIVE_IN_CARE'
);


ALTER TYPE public.appointment_visit_type OWNER TO postgres;

--
-- Name: days; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.days AS ENUM (
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT'
);


ALTER TYPE public.days OWNER TO postgres;

--
-- Name: languages; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.languages AS ENUM (
    'Tamil',
    'English',
    'Hindi'
);


ALTER TYPE public.languages OWNER TO postgres;

--
-- Name: nurse_service_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.nurse_service_type AS ENUM (
    'HOUSE_HOLD_TASKS',
    'PERSONAL_CARE',
    'COMPANION_SHIP',
    'TRANSPORTATION',
    'MOBILITY_ASSISTANCE',
    'SPECIALIZED_CARE',
    'PHYSICAL_EXAMINATIONS',
    'NURSE_CONSULTATIONS'
);


ALTER TYPE public.nurse_service_type OWNER TO postgres;

--
-- Name: nurse_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.nurse_type AS ENUM (
    'NURSE',
    'NURSING ASSISTANCE'
);


ALTER TYPE public.nurse_type OWNER TO postgres;

--
-- Name: payment_methods; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.payment_methods AS ENUM (
    'GPAY',
    'PHONEPE',
    'CASH'
);


ALTER TYPE public.payment_methods OWNER TO postgres;

--
-- Name: schedule; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.schedule AS ENUM (
    '00:00',
    '01:00',
    '02:00',
    '03:00',
    '04:00',
    '05:00',
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00'
);


ALTER TYPE public.schedule OWNER TO postgres;

--
-- Name: user_relationship_with_patient; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_relationship_with_patient AS ENUM (
    'SELF',
    'PARENTS',
    'SPOUSE',
    'GRAND_PARENTS',
    'FRIENDS',
    'RELATIVES'
);


ALTER TYPE public.user_relationship_with_patient OWNER TO postgres;

--
-- Name: user_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_type AS ENUM (
    'NURSE',
    'PATIENT',
    'USER'
);


ALTER TYPE public.user_type OWNER TO postgres;

--
-- Name: ap_nurse_appointment_book_liveincare(uuid[], character varying, uuid, uuid, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_nurse_appointment_book_liveincare(nurseids uuid[], bookingid character varying, patientid uuid, userid uuid, appointment_start_date date, appointment_end_date date) RETURNS TABLE(booking_result json)
    LANGUAGE plpgsql
    AS $$
 
declare 
 book_result json;
 --nurse_id_arr uuid[] = nurseids;
 nurseid uuid; 
 start_date date;
 end_date date;
 appointmentid int;
 appointment_date date;
 BEGIN

  start_date = appointment_start_date;
  end_date = appointment_end_date;
  appointment_date = appointment_start_date;
  
  IF EXISTS (select appointment_requests.appointment_request_id  from appointment_requests  
   where appointment_requests.nurse_id = ANY (nurseids) and appointment_requests.appointment_date = start_date
   and appointment_requests.patient_id = patientid and (appointment_visit_type = 'LIVE_IN_CARE'  
   or appointment_visit_type = 'SINGLE_VISIT')                    
   LIMIT 1) 
   
   THEN
     
     book_result = json_build_object('booking_status','failed','reason','appointment request already exists');
     return query select book_result;
  ELSE
    IF EXISTS (select appointments.appointment_id  from appointments appointments 
    inner join nurses on nurses.nurse_id = appointments.nurse_id
    inner join appointment_sessions on appointment_sessions.appointment_id = appointments.appointment_id
    where nurses.nurse_id = ALL (nurseids) and appointment_sessions.appointment_date in (start_date, end_date)
    LIMIT 1) THEN
      book_result = json_build_object('booking_status','failed','reason','nurse have appointments already');
      return query select book_result;
    ELSE
      FOREACH nurseid IN ARRAY nurseids
      LOOP 
       RAISE NOTICE '%', nurseid;

       INSERT INTO public.appointment_requests(
       booking_id, appointment_date, appointment_request_status, 
       nurse_id, patient_id, user_id, appointment_visit_type, appointment_start_date, appointment_end_date, 
       appointment_session_count,
        created_at, updated_at)
  VALUES (bookingid, start_date, 'WAITINGFORNURSETOACCEPT', nurseid , 
         patientid, userid, 'LIVE_IN_CARE', 
         appointment_start_date, appointment_end_date, 1, now(), now());

      END LOOP;
      book_result = json_build_object('booking_status','success','reason','');

      return query select book_result;
    END IF;
  END IF;
  
--select * from nurses
--select * from patients

--select * from users
  
  
--DROP FUNCTION nurse_appointment_book_liveincare(uuid,date,date)

--drop function nurse_appointment_book_liveincare(json) 

--select * from nurse_appointment_book_liveincare(ARRAY['ee58f1f1-eb8b-4567-a15d-ddfc670252d6']::uuid[], '2022-11-11', '2022-11-12')
/*

select * from appointment_requests

--delete from appointment_requests where appointment_request_id in (8,9,10)

--update appointment_requests set appointment_date = '2022-10-18' where appointment_request_id = 7
select * from appointment_sessions
nurseids uuid[],
 bookingid character varying,
 patientid uuid,
 userid uuid,
 appointment_start_date date,
 appointment_end_date date

select appointment_requests.appointment_request_id  from appointment_requests  
   where appointment_requests.nurse_id = ANY (ARRAY['ee58f1f1-eb8b-4567-a15d-ddfc670252d6']::uuid[]) 
   and appointment_requests.appointment_date = '2022-11-18'
   and appointment_requests.patient_id = 'd29e837b-44d2-4c59-9100-c6471a1ba5e6' and (appointment_visit_type = 'LIVE_IN_CARE'  
   or appointment_visit_type = 'SINGLE_VISIT')
   
select * from ap_nurse_appointment_book_liveincare(ARRAY['ee58f1f1-eb8b-4567-a15d-ddfc670252d6']::uuid[], 'booking-123-567-123', 
'd29e837b-44d2-4c59-9100-c6471a1ba5e6',
'4294ebd4-3498-4a23-bd89-87c126483cf9','2022-11-18', '2022-11-18') 
*/
--return query select * from temp_table_group_by_date;
 END;
$$;


ALTER FUNCTION public.ap_nurse_appointment_book_liveincare(nurseids uuid[], bookingid character varying, patientid uuid, userid uuid, appointment_start_date date, appointment_end_date date) OWNER TO postgres;

--
-- Name: ap_nurse_appointment_book_recurring(uuid[], character varying, uuid, uuid, date, date, date[], integer[], character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_nurse_appointment_book_recurring(nurseids uuid[], bookingid character varying, patientid uuid, userid uuid, appointment_start_date date, appointment_end_date date, appointment_dates date[], days integer[], appointment_start_time character varying, appointment_end_time character varying) RETURNS TABLE(booking_result json)
    LANGUAGE plpgsql
    AS $$
 
declare 
 book_result json;
 
 nurseid uuid; 
 start_time int;
 end_time int;
 start_date date;
 end_date date;
 appointmentid int;
 appointment_date date;
 BEGIN

  select LEFT(appointment_start_time,2) into start_time;
  
  select LEFT(appointment_end_time,2) into end_time;
  
  start_date = appointment_start_date;
  end_date = appointment_end_date;
  appointment_date = appointment_start_date;
  raise notice '%', appointment_dates;
  
 IF EXISTS (select * from appointment_requests where appointment_requests.nurse_id = ANY (nurseids)
     and appointment_requests.patient_id = patient_id and appointment_requests.user_id = user_id
     and appointment_requests.appointment_start_date = start_date and appointment_requests.appointment_end_date = end_date
     and ((appointment_visit_type = 'LIVE_IN_CARE') or ( appointment_visit_type in ('SINGLE_VISIT', 'RECURRING_VISIT') and 
     LEFT(appointment_requests.appointment_start_time, 2)::int = start_time and LEFT(appointment_requests.appointment_end_time, 2)::int = end_time))
      ) 
 THEN
  book_result = json_build_object('booking_status','failed','reason','appointment request already exists');
  return query select book_result;
 ELSE
  IF EXISTS (select * from appointment_sessions appointment_sessions
   inner join appointments on appointments.appointment_id = appointment_sessions.appointment_id
   where appointments.nurse_id = ANY (nurseids)
   and appointment_sessions.appointment_date = ANY (appointment_dates)
   and ((LEFT(appointment_sessions.appointment_booked_start_time, 2)::int <= start_time
   and LEFT(appointment_sessions.appointment_booked_end_time, 2)::int >= end_time) or 
   (LEFT(appointment_sessions.appointment_booked_start_time, 2)::int >= start_time
   and LEFT(appointment_sessions.appointment_booked_end_time, 2)::int <= end_time) or 
   ( start_time > LEFT(appointment_sessions.appointment_booked_start_time, 2)::int 
    and start_time < LEFT(appointment_sessions.appointment_booked_end_time, 2)::int) or 
   ( end_time > LEFT(appointment_sessions.appointment_booked_start_time, 2)::int 
    and end_time < LEFT(appointment_sessions.appointment_booked_end_time, 2)::int))
   and appointments.appointment_visit_type in ('RECURRING_VISIT','SINGLE_VISIT')
   union
   select * from appointment_sessions appointment_sessions
   inner join appointments on appointments.appointment_id = appointment_sessions.appointment_id
   where appointments.nurse_id = ANY (nurseids)
   and (appointments.appointment_start_date between start_date and end_date or 
     appointments.appointment_end_date between start_date and end_date)
   and appointments.appointment_visit_type in ('LIVE_IN_CARE') 
      LIMIT 1)

  THEN
    book_result = json_build_object('booking_status','failed','reason','appointment already exists');
    return query select book_result;
  ELSE
     FOREACH nurseid IN ARRAY nurseids
     LOOP
      RAISE NOTICE '%', nurseid;

      INSERT INTO public.appointment_requests(
  booking_id, appointment_date, appointment_session_count, appointment_request_status, 
      nurse_id, patient_id, user_id, appointment_visit_type, appointment_start_date, appointment_end_date, 
      appointment_start_time, appointment_end_time, days, appointment_dates, created_at, updated_at)
  VALUES (bookingid, appointment_date, 1, 'WAITINGFORNURSETOACCEPT', nurseid, 
        patientid, userid, 'RECURRING_VISIT', 
        appointment_start_date, appointment_end_date, 
        appointment_start_time, appointment_end_time, 
        days,appointment_dates,
        now(), now());

     END LOOP;
     book_result = json_build_object('booking_status','success','reason','');

     return query select book_result;

  END IF;

 END IF;
 
 END;
$$;


ALTER FUNCTION public.ap_nurse_appointment_book_recurring(nurseids uuid[], bookingid character varying, patientid uuid, userid uuid, appointment_start_date date, appointment_end_date date, appointment_dates date[], days integer[], appointment_start_time character varying, appointment_end_time character varying) OWNER TO postgres;

--
-- Name: ap_nurse_appointment_book_singlevisit(uuid[], character varying, uuid, uuid, date, date, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_nurse_appointment_book_singlevisit(nurseids uuid[], bookingid character varying, patientid uuid, userid uuid, appointment_start_date date, appointment_end_date date, appointment_start_time character varying, appointment_end_time character varying) RETURNS TABLE(booking_result json)
    LANGUAGE plpgsql
    AS $$ 
declare 
 book_result json;
 
 nurseid uuid; 
 start_time int;
 end_time int;
 start_date date;
 end_date date;
 appointmentid int;
 appointment_date date;
 BEGIN

  select LEFT(appointment_start_time,2) into start_time;
  
  select LEFT(appointment_end_time,2) into end_time;
  
  start_date = appointment_start_date;
  end_date = appointment_end_date;
  appointment_date = appointment_start_date;
  
  
  
  IF EXISTS (select appointment_requests.appointment_request_id  from appointment_requests  
   where appointment_requests.nurse_id = ANY (nurseids) and appointment_requests.appointment_date = start_date
   and appointment_requests.patient_id = patientid and ((appointment_visit_type = 'SINGLE_VISIT'  
      and LEFT(appointment_requests.appointment_start_time,2)::int = start_time 
       and LEFT(appointment_requests.appointment_end_time,2)::int = end_time) or
       (appointment_visit_type = 'LIVE_IN_CARE'))
   LIMIT 1) 
   
   THEN
    
     book_result = json_build_object('booking_status','failed','reason','appointment request already exists');
     return query select book_result;
  ELSE
     IF EXISTS (select appointments.appointment_id  from appointments appointments 
    inner join nurses on nurses.nurse_id = appointments.nurse_id
    inner join appointment_sessions on appointment_sessions.appointment_id = appointments.appointment_id
    where nurses.nurse_id = ALL (nurseids) and appointment_sessions.appointment_date in (start_date, end_date)
    and ( (LEFT(appointment_booked_start_time,2)::int <= start_time and LEFT(appointment_booked_end_time,2)::int >= end_time)
        or (LEFT(appointment_booked_start_time,2)::int >= start_time and LEFT(appointment_booked_end_time,2)::int <= end_time)
     )      
    LIMIT 1) THEN  
      book_result = json_build_object('booking_status','failed','reason','nurse have appointments already');
      return query select book_result;
    ELSE
      FOREACH nurseid IN ARRAY nurseids
      LOOP
       RAISE NOTICE '%', nurseid;

       INSERT INTO public.appointment_requests(
       booking_id, appointment_date, appointment_session_count, appointment_request_status, 
       nurse_id, patient_id, user_id, appointment_visit_type, appointment_start_date, appointment_end_date, 
       appointment_start_time, appointment_end_time, created_at, updated_at)
  VALUES (bookingid, appointment_date, 1, 'WAITINGFORNURSETOACCEPT', nurseid, 
         patientid, userid, 'SINGLE_VISIT', 
         appointment_start_date, appointment_end_date, 
         appointment_start_time, appointment_end_time,
         now(), now());

      END LOOP;
      book_result = json_build_object('booking_status','success','reason','');

      return query select book_result;
    END IF;
  END IF;


 END;
$$;


ALTER FUNCTION public.ap_nurse_appointment_book_singlevisit(nurseids uuid[], bookingid character varying, patientid uuid, userid uuid, appointment_start_date date, appointment_end_date date, appointment_start_time character varying, appointment_end_time character varying) OWNER TO postgres;

--
-- Name: ap_nurse_appointment_request_accept(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_nurse_appointment_request_accept(nurseid uuid, appointment_request_id integer) RETURNS TABLE(booking_result json)
    LANGUAGE plpgsql
    AS $$
 
declare 
 book_result json;
 
 appointment_req_id int;
 bookingid varchar(50);
 appointment_type appointment_visit_type;
 session_seq int;
 appointment_dates date[];
 appointment_date_local date;
 BEGIN
      
    appointment_req_id = appointment_request_id;
    
    select booking_id, appointment_visit_type, appointment_requests.appointment_dates into bookingid, appointment_type, appointment_dates from appointment_requests where appointment_requests.appointment_request_id = appointment_req_id;

    IF EXISTS (select * from appointment_requests where booking_id = bookingid 
      and appointment_request_status in ('ACCEPTED', 'CANCELLED')) THEN
 
   book_result = json_build_object('request_status','failed','reason','Appointment request already Accepted or Cancelled');
   return query select book_result;
 
    ELSE
     
         update appointment_requests set appointment_request_status = 'ACCEPTED' 
   where appointment_requests.appointment_request_id = appointment_req_id;
 
   INSERT INTO public.appointment_request_status(
   appointment_request_id, booking_id, nurse_id, created_at, updated_at, appointment_request_status)
VALUES (appointment_req_id, bookingid, nurseid, now(), now(), 'ACCEPTED');
   
   INSERT INTO public.appointments(
      booking_id, appointment_date, appointment_status, appointment_session_count, nurse_id, 
      patient_id, user_id, created_at, updated_at, appointment_visit_type, appointment_start_date, appointment_end_date)
    select booking_id, appointment_requests.appointment_date, 'ACCEPTED', 1, nurse_id, patient_id, user_id, now(), now(), 
   appointment_visit_type, appointment_start_date, appointment_end_date from appointment_requests
   where appointment_requests.appointment_request_id = appointment_req_id;
   
   IF (appointment_type = 'SINGLE_VISIT' or appointment_type = 'LIVE_IN_CARE') THEN
    INSERT INTO public.appointment_sessions(
    appointment_id, appointment_booked_start_time, appointment_booked_end_time,
    appointment_date, appointment_session, appointment_slot_time, appointment_session_status, created_at, updated_at)
select appointments.appointment_id, appointment_requests.appointment_start_time, appointment_requests.appointment_end_time, 
    appointment_requests.appointment_date,appointments.appointment_session_count, appointment_requests.appointment_start_time, 'UPCOMING', 
    now(), now() from appointment_requests
    inner join appointments on appointments.booking_id = appointment_requests.booking_id
    where appointment_requests.appointment_request_id = appointment_req_id;
   ELSE
    session_seq = 1;  
    FOREACH appointment_date_local IN ARRAY appointment_dates
      LOOP
       
       INSERT INTO public.appointment_sessions(
      appointment_id, appointment_booked_start_time, appointment_booked_end_time,
      appointment_date, appointment_session, appointment_slot_time, appointment_session_status, created_at, updated_at)
select appointments.appointment_id, appointment_requests.appointment_start_time, appointment_requests.appointment_end_time, 
      appointment_date_local, session_seq, appointment_requests.appointment_start_time, 'UPCOMING', 
      now(), now() from appointment_requests
      inner join appointments on appointments.booking_id = appointment_requests.booking_id
      where appointment_requests.appointment_request_id = appointment_req_id;
      
      session_seq = session_seq + 1;

      END LOOP;
   
   END IF;
   book_result = json_build_object('request_status','success','reason','');
   return query select book_result;
 

    END IF;
END;
$$;


ALTER FUNCTION public.ap_nurse_appointment_request_accept(nurseid uuid, appointment_request_id integer) OWNER TO postgres;

--
-- Name: ap_nurse_appointment_request_info(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_nurse_appointment_request_info(nurseid uuid, appointment_request_id integer) RETURNS TABLE(appointment_req_id integer, appointment_request_status public.appointment_request_status_type, appointment_session_count integer, nurse_id uuid, nurse_name character varying, nurse_avg_rating double precision, nurse_rating_count integer, nurse_location character varying, nurse_distance double precision, nurse_experience integer, nurse_gender character varying, nurse_age integer, appointment_date date, appointment_visit_type public.appointment_visit_type, appointment_start_date date, appointment_end_date date, appointment_patient_symptoms character varying, appointment_specific_request character varying, total_payment_amount bigint, fees_per_session bigint, patient_id uuid, patient_name character varying, patient_gender character varying, patient_age integer, patient_avg_rating double precision, patient_location character varying, patient_phone character varying, patient_email character varying, appointment_start_time character varying, appointment_end_time character varying, days integer[])
    LANGUAGE plpgsql
    AS $$
 
declare 
 appointment_req_id int;
 BEGIN
      
    appointment_req_id = appointment_request_id;
    
    return query
    select ar.appointment_request_id appointment_req_id, ar.appointment_request_status,
  ar.appointment_session_count, nurses.nurse_id, nurses.nurse_name, nurses.nurse_avg_rating,
  nurses.nurse_rating_count, nurses.nurse_location, Round(ST_Distance(user_geolocation, nurses.nurse_geolocation)/1000) nurse_distance, 
  nurses.nurse_experience, nurses.nurse_gender, nurses.nurse_age, ar.appointment_date, ar.appointment_visit_type,
  ar.appointment_start_date, ar.appointment_end_date, ar.appointment_patient_symptoms, 
  ar.appointment_specific_request, ar.total_payment_amount, ar.fees_per_session, 
  patients.patient_id, patients.patient_name, patients.patient_gender, patients.patient_age,
  patients.patient_avg_rating, patients.patient_location, patients.patient_phone, patients.patient_email,
  ar.appointment_start_time, ar.appointment_end_time, ar.days
  from appointment_requests ar
  inner join nurses on nurses.nurse_id = ar.nurse_id
  inner join patients on patients.patient_id = ar.patient_id
  inner join users on users.user_id = ar.user_id
  where ar.appointment_request_id = appointment_req_id
        and ar.Appointment_Visit_Type in ('SINGLE_VISIT', 'LIVE_IN_CARE', 'RECURRING_VISIT');

 END;
 
$$;


ALTER FUNCTION public.ap_nurse_appointment_request_info(nurseid uuid, appointment_request_id integer) OWNER TO postgres;

--
-- Name: ap_nurse_appointment_request_reject(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_nurse_appointment_request_reject(nurseid uuid, appointment_request_id integer) RETURNS TABLE(booking_result json)
    LANGUAGE plpgsql
    AS $$
 
declare 
 book_result json;
 
 appointment_req_id int;
 bookingid varchar(50);
 BEGIN
      
    appointment_req_id = appointment_request_id;
    
    select booking_id into bookingid from appointment_requests where appointment_requests.appointment_request_id = appointment_req_id;

    IF EXISTS (select * from appointment_requests where booking_id = bookingid 
      and appointment_request_status in ('ACCEPTED', 'CANCELLED')) THEN
 
   book_result = json_build_object('request_status','failed','reason','Appointment request already Accepted or Cancelled');
   return query select book_result;
 
    ELSE
     
         update appointment_requests set appointment_request_status = 'REJECTED' 
   where appointment_requests.appointment_request_id = appointment_req_id;
 
   INSERT INTO public.appointment_request_status(
   appointment_request_id, booking_id, nurse_id, created_at, updated_at, appointment_request_status)
VALUES (appointment_req_id, bookingid, nurseid, now(), now(), 'REJECTED');
   
   book_result = json_build_object('request_status','success','reason','');
   return query select book_result;
 


    END IF;
END;
$$;


ALTER FUNCTION public.ap_nurse_appointment_request_reject(nurseid uuid, appointment_request_id integer) OWNER TO postgres;

--
-- Name: ap_nurse_appointment_session_end(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_nurse_appointment_session_end(_appointment_session_id integer, _appointment_end_time character varying) RETURNS TABLE(booking_result json)
    LANGUAGE plpgsql
    AS $$
declare 
 book_result json;
 _appointment_id int;
 BEGIN
 
  IF EXISTS (select * from appointment_sessions where appointment_session_id = _appointment_session_id) THEN

     update appointment_sessions set appointment_session_status='COMPLETED',appointment_actual_end_time=_appointment_end_time,
     appointment_actual_end_time_with_date=now() where appointment_session_id=_appointment_session_id;

     select appointment_id into _appointment_id from appointment_sessions where appointment_session_id = _appointment_session_id;

     IF EXISTS(select * from appointment_sessions where appointment_id = _appointment_id and appointment_session_status <>'COMPLETED'
      and appointment_session_status <>'CANCELLED') THEN
       raise notice 'do not update';
     ELSE
       raise notice 'update';
       update appointments set appointment_status = 'COMPLETED';
     END IF;

     book_result = json_build_object('request_status','success','reason','');
     return query select book_result;

  ELSE
   book_result = json_build_object('request_status','failed','reason','Appointment session does not exist');
   return query select book_result;
  END IF;
--select * from ap_nurse_appointment_session_end(19,'13:00')
END;
$$;


ALTER FUNCTION public.ap_nurse_appointment_session_end(_appointment_session_id integer, _appointment_end_time character varying) OWNER TO postgres;

--
-- Name: ap_user_appointment_request_info(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_user_appointment_request_info(_user_id uuid, _appointment_request_id integer) RETURNS TABLE(appointment_req_id integer, appointment_request_status public.appointment_request_status_type, appointment_session_count integer, nurse_id uuid, nurse_name character varying, nurse_avg_rating double precision, nurse_rating_count integer, nurse_location character varying, nurse_distance double precision, nurse_experience integer, nurse_gender character varying, appointment_visit_type public.appointment_visit_type, appointment_date date, appointment_start_date date, appointment_end_date date, appointment_start_time character varying, appointment_end_time character varying, days integer[], appointment_patient_symptoms character varying, appointment_specific_request character varying, fees_per_session bigint, patient_id uuid, patient_name character varying, patient_gender character varying, payment_method public.payment_methods, patient_avg_rating double precision, patient_rating_count integer, patient_location character varying, patient_phone character varying, patient_email character varying, patient_more_description character varying, total_payment_amount bigint, booking_id character varying, user_relationship_with_patient public.user_relationship_with_patient, patient_dob date, nurse_dob date, nurse_latitude double precision, nurse_longitude double precision)
    LANGUAGE plpgsql
    AS $$
 
declare 
 _patient_id uuid;
 _patient_rating_avg double precision;
 _patient_rating_count integer;
 BEGIN
   
   select appointment_requests.patient_id into _patient_id from appointment_requests where appointment_request_id = _appointment_request_id;
   
   select sum(patient_rating)/count(patient_rating), count(patient_rating) 
   into _patient_rating_avg, _patient_rating_count from patient_ratings
   where patient_ratings.patient_id = _patient_id
   group by patient_ratings.patient_id;
   
   IF _patient_rating_avg is NULL THEN
    _patient_rating_avg = 0;
   END IF;
   
   IF _patient_rating_count is NULL THEN
    _patient_rating_count = 0;
   END IF;
    
    return query
    select ar.appointment_request_id appointment_req_id, ar.appointment_request_status,
  ar.appointment_session_count, nurses.nurse_id, nurses.nurse_name, nurses.nurse_avg_rating,
  nurses.nurse_rating_count, nurses.nurse_location, Round(ST_Distance(user_geolocation, nurses.nurse_geolocation)/1000) nurse_distance, 
  nurses.nurse_experience, nurses.nurse_gender, ar.appointment_visit_type, ar.appointment_date,
  ar.appointment_start_date, ar.appointment_end_date, ar.appointment_start_time,ar.appointment_end_time,ar.days,
  ar.appointment_patient_symptoms, ar.appointment_specific_request, ar.fees_per_session, 
  patients.patient_id, patients.patient_name, patients.patient_gender,ar.payment_method,
  _patient_rating_avg, _patient_rating_count, patients.patient_location, patients.patient_phone, patients.patient_email,
  patients.patient_more_description,ar.fees_per_session*ar.appointment_session_count total_payment_amount,ar.booking_id,
  patients.user_relationship_with_patient, patients.patient_dob,nurses.nurse_dob,nurses.nurse_latitude,nurses.nurse_longitude
  from appointment_requests ar
  inner join nurses on nurses.nurse_id = ar.nurse_id
  inner join patients on patients.patient_id = ar.patient_id
  inner join users on users.user_id = ar.user_id
  where ar.appointment_request_id = _appointment_request_id and ar.user_id = _user_id
        and ar.Appointment_Visit_Type in ('SINGLE_VISIT', 'LIVE_IN_CARE', 'RECURRING_VISIT');
  
END;
 
$$;


ALTER FUNCTION public.ap_user_appointment_request_info(_user_id uuid, _appointment_request_id integer) OWNER TO postgres;

--
-- Name: ap_user_patient_update(uuid, character varying, character varying, date, integer, character varying, character varying, double precision, double precision, character varying, character varying, character varying, character varying, character varying, boolean, public.user_relationship_with_patient); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_user_patient_update(_user_id uuid, _patient_phone character varying, _patient_name character varying, _patient_dob date, _patient_age integer, _patient_email character varying, _patient_gender character varying, _patient_latitude double precision, _patient_longitude double precision, _patient_location character varying, _patient_address_line character varying, _patient_city character varying, _patient_state character varying, _patient_pincode character varying, _whatsapp_same_as_contact_phone boolean, _user_relationship_with_patient public.user_relationship_with_patient) RETURNS TABLE(update_result json)
    LANGUAGE plpgsql
    AS $$
 
declare 
    update_result json;
    _user_phone character varying(20);
    _patient_id uuid;
    _whatsapp_phone character varying(20);
    BEGIN
    
        _whatsapp_phone = NULL;
        
        raise notice 'user phone, %', _user_phone;
        IF EXISTS(select user_id from users where user_id = _user_id) THEN
            
            IF _whatsapp_same_as_contact_phone IS TRUE THEN
                _whatsapp_phone = _patient_phone;
            END IF;

            insert into patients(patient_id,patient_age,patient_dob,patient_email,patient_gender,
            patient_name,patient_phone,patient_whatsapp_phone,user_id,user_relationship_with_patient)
            values(gen_random_uuid(),_patient_age,_patient_dob,_patient_email,_patient_gender,_patient_name,
       _patient_phone,_whatsapp_phone,_user_id,_user_relationship_with_patient)
            ON CONFLICT ON CONSTRAINT patients_unique_key DO
            UPDATE SET patient_age=_patient_age, patient_dob=_patient_dob,patient_email=_patient_email,patient_gender=_patient_gender,
            patient_name=_patient_name,patient_phone=_patient_phone,patient_whatsapp_phone=_whatsapp_phone,
   user_relationship_with_patient=_user_relationship_with_patient;

            select patient_id into _patient_id from patients where user_id = _user_id and patient_phone = _patient_phone 
   and user_relationship_with_patient=_user_relationship_with_patient;

            insert into user_address(user_address_id,patient_id,user_address_line,user_city,user_state,user_id,user_pincode,
            user_location,user_latitude,user_longitude,user_geolocation)
            values(gen_random_uuid(),_patient_id,_patient_address_line,_patient_city,_patient_state,_user_id,_patient_pincode,
            _patient_location,_patient_latitude,_patient_longitude, ST_Point(_patient_longitude,_patient_latitude))
            ON CONFLICT ON CONSTRAINT user_address_patient_id_unique_key DO
            UPDATE SET patient_id=_patient_id,user_address_line=_patient_address_line, user_city=_patient_city,
            user_state=_patient_state,user_pincode=_patient_pincode,user_location=_patient_location,
            user_latitude=_patient_latitude,user_longitude=_patient_longitude,user_geolocation=ST_Point(_patient_longitude,_patient_latitude);

            update_result = json_build_object('update_status','success','reason','');
            return query select update_result;
        ELSE
              update_result = json_build_object('update_status','failed','reason','user does not exist');
              return query select update_result;
        END IF;
        
    END;
$$;


ALTER FUNCTION public.ap_user_patient_update(_user_id uuid, _patient_phone character varying, _patient_name character varying, _patient_dob date, _patient_age integer, _patient_email character varying, _patient_gender character varying, _patient_latitude double precision, _patient_longitude double precision, _patient_location character varying, _patient_address_line character varying, _patient_city character varying, _patient_state character varying, _patient_pincode character varying, _whatsapp_same_as_contact_phone boolean, _user_relationship_with_patient public.user_relationship_with_patient) OWNER TO postgres;

--
-- Name: ap_user_update(uuid, character varying, date, integer, character varying, character varying, double precision, double precision, character varying, character varying, character varying, character varying, character varying, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ap_user_update(_user_id uuid, _user_name character varying, _user_dob date, _user_age integer, _user_email character varying, _user_gender character varying, _user_latitude double precision, _user_longitude double precision, _user_location character varying, _user_address_line character varying, _user_city character varying, _user_state character varying, _user_pincode character varying, _whatsapp_same_as_contact_phone boolean) RETURNS TABLE(update_result json)
    LANGUAGE plpgsql
    AS $$
 
declare 
 update_result json;
 _user_phone character varying(20);
 _patient_id uuid;
 _whatsapp_phone character varying(20);
 BEGIN
 
  _whatsapp_phone = NULL;
  
  raise notice 'user phone, %', _user_phone;
  IF EXISTS(select user_id from users where user_id = _user_id) THEN
   select user_phone into _user_phone from users where user_id = _user_id;
   IF _whatsapp_same_as_contact_phone IS TRUE THEN
    _whatsapp_phone = _user_phone;
   END IF;

   UPDATE users SET user_dob=_user_dob,user_age=_user_age, user_email=_user_email, 
   user_gender=_user_gender,user_name=_user_name, user_whatsapp_phone=_whatsapp_phone
   where user_id=_user_id;

   insert into patients(patient_id,patient_age,patient_dob,patient_email,patient_gender,
   patient_name,patient_phone,patient_whatsapp_phone,user_id,user_relationship_with_patient)
values(gen_random_uuid(),_user_age,_user_dob,_user_email,_user_gender, _user_name,_user_phone,_whatsapp_phone,_user_id,'SELF')
   ON CONFLICT ON CONSTRAINT patients_unique_key DO
   UPDATE SET patient_age=_user_age, patient_dob=_user_dob,patient_email=_user_email,patient_gender=_user_gender,
   patient_name=_user_name,patient_whatsapp_phone=_whatsapp_phone,user_id=_user_id,user_relationship_with_patient='SELF';

   select patient_id into _patient_id from patients where user_id = _user_id and user_relationship_with_patient='SELF';

   insert into user_address(user_address_id,patient_id,user_address_line,user_city,user_state,user_id,user_pincode,
   user_location,user_latitude,user_longitude,user_geolocation)
values(gen_random_uuid(),_patient_id,_user_address_line,_user_city,_user_state,_user_id,_user_pincode,
   _user_location,_user_latitude,_user_longitude, ST_Point(_user_longitude,_user_latitude))
   ON CONFLICT ON CONSTRAINT user_address_patient_id_unique_key DO
   UPDATE SET patient_id=_patient_id,user_address_line=_user_address_line, user_city=_user_city,
   user_state=_user_state,user_id=_user_id, user_pincode=_user_pincode,user_location=_user_location,
   user_latitude=_user_latitude,user_longitude=_user_longitude,user_geolocation=ST_Point(_user_longitude,_user_latitude);

   update_result = json_build_object('update_status','success','reason','');
   return query select update_result;
  ELSE
     update_result = json_build_object('update_status','failed','reason','user does not exist');
     return query select update_result;
  END IF;
  

 END;
$$;


ALTER FUNCTION public.ap_user_update(_user_id uuid, _user_name character varying, _user_dob date, _user_age integer, _user_email character varying, _user_gender character varying, _user_latitude double precision, _user_longitude double precision, _user_location character varying, _user_address_line character varying, _user_city character varying, _user_state character varying, _user_pincode character varying, _whatsapp_same_as_contact_phone boolean) OWNER TO postgres;

--
-- Name: nurse_appointment_book_liveincare(uuid[], date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.nurse_appointment_book_liveincare(nurseids uuid[], appointment_start_date date, appointment_end_date date) RETURNS TABLE(booking_result json)
    LANGUAGE plpgsql
    AS $$ 
declare 
 book_result json;
 
 nurseid uuid; 
 BEGIN

  
  
  IF EXISTS (select appointments.appointment_id  from appointments appointments 
  inner join nurses on nurses.nurse_id = appointments.nurse_id
  inner join appointment_sessions on appointment_sessions.appointment_id = appointments.appointment_id
  where nurses.nurse_id = ALL (nurseids) and appointment_sessions.appointment_date in (appointment_start_date, appointment_end_date)
  LIMIT 1) THEN
    book_result = json_build_object('booking_status','failed','reason','nurse have appointments already');
    return query select book_result;
  ELSE
    FOREACH nurseid IN ARRAY nurseids
    LOOP 
     RAISE NOTICE '%', nurseid;
    END LOOP;
    book_result = json_build_object('booking_status','success','reason','');
    
    return query select book_result;
  END IF;
  
  
  
  
 END;
$$;


ALTER FUNCTION public.nurse_appointment_book_liveincare(nurseids uuid[], appointment_start_date date, appointment_end_date date) OWNER TO postgres;

--
-- Name: nurse_appointment_request_info(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.nurse_appointment_request_info(nurseid uuid, appointment_request_id integer) RETURNS TABLE(appointment_req_id integer, appointment_request_status public.appointment_request_status_type, appointment_session_count integer, nurse_id uuid, nurse_name character varying, nurse_avg_rating double precision, nurse_rating_count integer, nurse_location character varying, nurse_distance double precision, nurse_experience integer, nurse_gender character varying, nurse_age integer, appointment_date date, appointment_visit_type public.appointment_visit_type, appointment_start_date date, appointment_end_date date, appointment_patient_symptoms character varying, appointment_specific_request character varying, total_payment_amount bigint, fees_per_session bigint, patient_id uuid, patient_name character varying, patient_gender character varying, patient_age integer, patient_avg_rating double precision, patient_location character varying, patient_phone character varying, patient_email character varying, appointment_start_time character varying, appointment_end_time character varying)
    LANGUAGE plpgsql
    AS $$
 
declare 
 
 appointment_req_id int;
 
 BEGIN
      
    appointment_req_id = appointment_request_id;
    
    return query
    select ar.appointment_request_id appointment_req_id, ar.appointment_request_status,
  ar.appointment_session_count, nurses.nurse_id, nurses.nurse_name, nurses.nurse_avg_rating,
  nurses.nurse_rating_count, nurses.nurse_location, Round(ST_Distance(user_geolocation, nurses.nurse_geolocation)/1000) nurse_distance, 
  nurses.nurse_experience, nurses.nurse_gender, nurses.nurse_age, ar.appointment_date, ar.appointment_visit_type,
  ar.appointment_start_date, ar.appointment_end_date, ar.appointment_patient_symptoms, 
  ar.appointment_specific_request, ar.total_payment_amount, ar.fees_per_session, 
  patients.patient_id, patients.patient_name, patients.patient_gender, patients.patient_age,
  patients.patient_avg_rating, patients.patient_location, patients.patient_phone, patients.patient_email,
  ar.appointment_start_time, ar.appointment_end_time
  from appointment_requests ar
  inner join appointments on ar.booking_id = appointments.booking_id
  inner join nurses on nurses.nurse_id = ar.nurse_id
  inner join patients on patients.patient_id = ar.patient_id
  inner join users on users.user_id = ar.user_id
  where ar.appointment_request_id = appointment_req_id
        and (ar.Appointment_Visit_Type = 'SINGLE_VISIT' or ar.Appointment_Visit_Type ='LIVE_IN_CARE');

   
 END;
 
$$;


ALTER FUNCTION public.nurse_appointment_request_info(nurseid uuid, appointment_request_id integer) OWNER TO postgres;

--
-- Name: nurse_earnings_daywise(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.nurse_earnings_daywise(nurseid uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$ 
DECLARE
rec record;
       BEGIN
   
   DROP TABLE IF EXISTS temp_table_group_by_date;
   CREATE TEMP TABLE IF NOT EXISTS temp_table_group_by_date AS
   select appointment_sessions.appointment_date, sum(nurse_earnings.nurse_earning) from nurses
   inner join nurse_earnings on nurse_earnings.nurse_id = nurses.nurse_id
   inner join appointment_sessions on appointment_sessions.appointment_session_id = nurse_earnings.appointment_session_id
   inner join appointments on appointments.appointment_id = appointment_sessions.appointment_id
   where nurses.nurse_id  = nurseid
   and appointment_sessions.appointment_date between '2022-11-03' and '2022-11-08'
   group by appointment_sessions.appointment_date,nurse_earnings.nurse_earning ,nurses.nurse_id;

   FOR rec IN
      SELECT *
      FROM temp_table_group_by_date
     
      LOOP
    
    raise notice '%',rec.appointment_date;
    
    select json_agg(json_build_object(appointments.booking_id, nurse_earnings.nurse_earning,
    appointment_sessions.appointment_slot_time, patients.patient_name, nurse_earnings.payment_method))
    from nurses
    inner join nurse_earnings on nurse_earnings.nurse_id = nurses.nurse_id
    inner join appointment_sessions on appointment_sessions.appointment_session_id = nurse_earnings.appointment_session_id
    inner join appointments on appointments.appointment_id = appointment_sessions.appointment_id
    inner join patients on patients.patient_id = appointments.patient_id
    where nurses.nurse_id  = nurseid
    and appointment_sessions.appointment_date = rec.appointment_date;
    
    
    
   END LOOP;

   
        END;
$$;


ALTER FUNCTION public.nurse_earnings_daywise(nurseid uuid) OWNER TO postgres;

--
-- Name: nurse_earnings_daywise(uuid, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.nurse_earnings_daywise(nurseid uuid, duration character varying) RETURNS TABLE(appointment_date date, total_earning_today bigint, appointment_details json)
    LANGUAGE plpgsql
    AS $$ 

 BEGIN

        IF duration = 'This_Week' THEN 
   return query
   select appointment_sessions.appointment_date,sum(nurse_earnings.nurse_earning) total_earning_today,
   json_agg(json_build_object('booking_id',appointments.booking_id,'nurse_earning',nurse_earnings.nurse_earning,
   'appointment_slot_time',appointment_sessions.appointment_slot_time, 'patient_name',patients.patient_name)) as appointment_details
   from nurses
   inner join nurse_earnings on nurse_earnings.nurse_id = nurses.nurse_id
   inner join appointment_sessions on appointment_sessions.appointment_session_id = nurse_earnings.appointment_session_id
   inner join appointments on appointments.appointment_id = appointment_sessions.appointment_id
   inner join patients on patients.patient_id = appointments.patient_id
   where nurses.nurse_id  = nurseid
   and appointment_sessions.appointment_date >=date_trunc('week', now())
   group by appointment_sessions.appointment_date;
  ELSEIF duration = 'This_Month' THEN 
   return query
   select appointment_sessions.appointment_date,sum(nurse_earnings.nurse_earning) total_earning_today,
   json_agg(json_build_object('booking_id',appointments.booking_id,'nurse_earning',nurse_earnings.nurse_earning,
   'appointment_slot_time',appointment_sessions.appointment_slot_time, 'patient_name',patients.patient_name)) as appointment_details
   from nurses
   inner join nurse_earnings on nurse_earnings.nurse_id = nurses.nurse_id
   inner join appointment_sessions on appointment_sessions.appointment_session_id = nurse_earnings.appointment_session_id
   inner join appointments on appointments.appointment_id = appointment_sessions.appointment_id
   inner join patients on patients.patient_id = appointments.patient_id
   where nurses.nurse_id  = nurseid
   and appointment_sessions.appointment_date >=date_trunc('month', now())
   group by appointment_sessions.appointment_date;
  END IF;

 END;
$$;


ALTER FUNCTION public.nurse_earnings_daywise(nurseid uuid, duration character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appointment_request_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_request_status (
    appointment_request_status_id integer NOT NULL,
    appointment_request_id integer NOT NULL,
    booking_id character varying(50) NOT NULL,
    nurse_id uuid NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    appointment_request_status public.appointment_request_status_type
);


ALTER TABLE public.appointment_request_status OWNER TO postgres;

--
-- Name: appointment_request_status_appointment_request_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment_request_status ALTER COLUMN appointment_request_status_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_request_status_appointment_request_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: appointment_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_requests (
    appointment_request_id integer NOT NULL,
    booking_id character varying(50) NOT NULL,
    appointment_date date NOT NULL,
    appointment_session_count integer NOT NULL,
    nurse_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    user_id uuid NOT NULL,
    appointment_visit_type public.appointment_visit_type,
    appointment_start_date date,
    appointment_end_date date,
    appointment_start_time character varying(10),
    appointment_end_time character varying(10),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    appointment_request_status public.appointment_request_status_type,
    appointment_patient_symptoms character varying(1000),
    appointment_specific_request character varying(1000),
    total_payment_amount bigint,
    fees_per_session bigint,
    days integer[],
    appointment_dates date[],
    payment_method public.payment_methods
);


ALTER TABLE public.appointment_requests OWNER TO postgres;

--
-- Name: appointment_requests_appointment_request_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment_requests ALTER COLUMN appointment_request_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_requests_appointment_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: appointment_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_sessions (
    appointment_session_id integer NOT NULL,
    appointment_id integer NOT NULL,
    appointment_actual_end_time character varying(10),
    appointment_actual_start_time character varying(10),
    appointment_booked_end_time character varying(10) NOT NULL,
    appointment_booked_start_time character varying(10) NOT NULL,
    appointment_date date NOT NULL,
    appointment_session integer NOT NULL,
    appointment_slot_time character varying(10) NOT NULL,
    appointment_session_status character varying(50) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    appointment_session_cancelled_by public.user_type,
    appointment_session_reason character varying(100),
    appointment_actual_start_time_with_date timestamp without time zone,
    appointment_actual_end_time_with_date timestamp without time zone
);


ALTER TABLE public.appointment_sessions OWNER TO postgres;

--
-- Name: appointment_sessions_appointment_session_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment_sessions ALTER COLUMN appointment_session_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_sessions_appointment_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: appointment_slots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_slots (
    slot_id integer NOT NULL,
    slots character varying[] NOT NULL
);


ALTER TABLE public.appointment_slots OWNER TO postgres;

--
-- Name: appointment_slots_nurse_default; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_slots_nurse_default (
    slot_id integer NOT NULL,
    nurse_id uuid NOT NULL,
    slot_frequency character varying[],
    slots character varying[],
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.appointment_slots_nurse_default OWNER TO postgres;

--
-- Name: appointment_slots_nurse_default_slot_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment_slots_nurse_default ALTER COLUMN slot_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_slots_nurse_default_slot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: appointment_slots_nurse_specific; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_slots_nurse_specific (
    slot_id integer NOT NULL,
    nurse_id uuid,
    slot_date date,
    slots character varying[],
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.appointment_slots_nurse_specific OWNER TO postgres;

--
-- Name: appointment_slots_nurse_specific_slot_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment_slots_nurse_specific ALTER COLUMN slot_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_slots_nurse_specific_slot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    appointment_id integer NOT NULL,
    booking_id character varying(50),
    appointment_date date NOT NULL,
    appointment_status character varying(50) NOT NULL,
    appointment_session_count integer NOT NULL,
    nurse_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    appointment_visit_type public.appointment_visit_type,
    appointment_start_date date,
    appointment_end_date date,
    appointment_patient_symptoms character varying(1000),
    appointment_specific_request character varying(1000)
);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: appointments_appointment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointments ALTER COLUMN appointment_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointments_appointment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurse_address; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_address (
    nurse_address_id uuid NOT NULL,
    nurse_id uuid,
    nurse_address_type character varying(100),
    nurse_area character varying(100),
    nurse_city character varying(100),
    nurse_door_no_block character varying(100),
    nurse_pincode character varying(10),
    nurse_road character varying(100),
    nurse_state character varying(50),
    nurse_street character varying(100)
);


ALTER TABLE public.nurse_address OWNER TO postgres;

--
-- Name: nurse_earnings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_earnings (
    nurse_earnings_id integer NOT NULL,
    nurse_id uuid,
    appointment_id integer,
    appointment_session_id integer,
    booking_id character varying(50),
    nurse_earning integer,
    payment_method public.payment_methods,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.nurse_earnings OWNER TO postgres;

--
-- Name: nurse_earnings_nurse_earnings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurse_earnings ALTER COLUMN nurse_earnings_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurse_earnings_nurse_earnings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurse_education; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_education (
    nurse_education_id integer NOT NULL,
    nurse_education_name character varying(200) NOT NULL
);


ALTER TABLE public.nurse_education OWNER TO postgres;

--
-- Name: nurse_education_nurse_education_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurse_education ALTER COLUMN nurse_education_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurse_education_nurse_education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurse_fees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_fees (
    nurse_fees_id integer NOT NULL,
    nurse_id uuid,
    minimum_distance integer,
    distance_unit character varying(10),
    minimum_session_fee integer,
    session_fee_currency character varying(10),
    charges_for_extra_distance integer
);


ALTER TABLE public.nurse_fees OWNER TO postgres;

--
-- Name: nurse_fees_nurse_fees_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurse_fees ALTER COLUMN nurse_fees_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurse_fees_nurse_fees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurse_ratings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_ratings (
    nurse_ratings_id integer NOT NULL,
    nurse_id uuid,
    patient_id uuid,
    user_id uuid,
    appointment_id integer,
    appointment_session_id integer,
    nurse_rating integer,
    nurse_rating_comments character varying(2000),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.nurse_ratings OWNER TO postgres;

--
-- Name: nurse_ratings_nurse_ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurse_ratings ALTER COLUMN nurse_ratings_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurse_ratings_nurse_ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurse_service_type_values; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_service_type_values (
    nurse_service_type_value_id integer NOT NULL,
    nurse_service_type public.nurse_service_type,
    nurse_service_type_name character varying(200),
    nurse_service_type_description character varying(1000)
);


ALTER TABLE public.nurse_service_type_values OWNER TO postgres;

--
-- Name: nurse_service_type_values_nurse_service_type_value_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurse_service_type_values ALTER COLUMN nurse_service_type_value_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurse_service_type_values_nurse_service_type_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurse_skills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_skills (
    nurse_skill_id integer NOT NULL,
    nurse_skill_name character varying(200) NOT NULL
);


ALTER TABLE public.nurse_skills OWNER TO postgres;

--
-- Name: nurse_skills_nurse_skill_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurse_skills ALTER COLUMN nurse_skill_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurse_skills_nurse_skill_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurse_slots_recurring; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse_slots_recurring (
    slot_id integer NOT NULL,
    nurse_id uuid NOT NULL,
    slot_frequency public.days[],
    slot_start_time public.schedule,
    slot_end_time public.schedule,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.nurse_slots_recurring OWNER TO postgres;

--
-- Name: nurse_slots_recurring_slot_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurse_slots_recurring ALTER COLUMN slot_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurse_slots_recurring_slot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nurses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurses (
    nurse_id uuid NOT NULL,
    nurse_age integer,
    nurse_dob date,
    nurse_email character varying(50),
    nurse_firstname character varying(20),
    nurse_gender character varying(10),
    nurse_lastname character varying(20),
    nurse_latitude double precision,
    nurse_location character varying(50),
    nurse_longitude double precision,
    nurse_name character varying(50),
    nurse_password character varying(200),
    nurse_phone character varying(20),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    nurse_geolocation public.geography(Point,4326),
    nurse_type public.nurse_type,
    nurse_avg_rating double precision,
    nurse_experience integer,
    nurse_rating_count integer,
    nurse_whatsapp_phone character varying(20),
    nurse_verified boolean,
    nurse_is_licensed boolean,
    nurse_description character varying(2000),
    nurse_languages_known public.languages[],
    nurse_service_type public.nurse_service_type[],
    nurse_education_id integer,
    nurse_skill_id integer,
    is_criminal_record_checked boolean
);


ALTER TABLE public.nurses OWNER TO postgres;

--
-- Name: nurses_service_type_subscription; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurses_service_type_subscription (
    nurses_service_type_subscription_id integer NOT NULL,
    nurse_service_type_value_id integer,
    nurse_id uuid
);


ALTER TABLE public.nurses_service_type_subscription OWNER TO postgres;

--
-- Name: nurses_service_type_subscript_nurses_service_type_subscript_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.nurses_service_type_subscription ALTER COLUMN nurses_service_type_subscription_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nurses_service_type_subscript_nurses_service_type_subscript_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: otp_for_appointment_session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.otp_for_appointment_session (
    otp_for_appointment_session_id integer NOT NULL,
    user_id uuid NOT NULL,
    user_phone character varying(20) NOT NULL,
    appointment_session_id integer NOT NULL,
    otp character varying(100) NOT NULL,
    created_at timestamp without time zone
);


ALTER TABLE public.otp_for_appointment_session OWNER TO postgres;

--
-- Name: otp_for_appointment_session_otp_for_appointment_session_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.otp_for_appointment_session ALTER COLUMN otp_for_appointment_session_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.otp_for_appointment_session_otp_for_appointment_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: otp_phone; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.otp_phone (
    user_phone character varying(20),
    otp character varying(100),
    created_at timestamp without time zone
);


ALTER TABLE public.otp_phone OWNER TO postgres;

--
-- Name: patient_ratings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patient_ratings (
    patient_ratings_id integer NOT NULL,
    patient_id uuid,
    nurse_id uuid,
    user_id uuid,
    appointment_id integer,
    appointment_session_id integer,
    patient_rating integer,
    patient_rating_comments character varying(2000),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.patient_ratings OWNER TO postgres;

--
-- Name: patient_ratings_patient_ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.patient_ratings ALTER COLUMN patient_ratings_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.patient_ratings_patient_ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    patient_id uuid NOT NULL,
    patient_age integer,
    patient_dob date,
    patient_email character varying(50),
    patient_firstname character varying(20),
    patient_gender character varying(10),
    patient_lastname character varying(20),
    patient_latitude double precision,
    patient_location character varying(50),
    patient_longitude double precision,
    patient_name character varying(50),
    patient_phone character varying(20),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    user_id uuid,
    self_or_others boolean,
    patient_avg_rating double precision,
    patient_ratings double precision,
    user_relationship_with_patient public.user_relationship_with_patient,
    patient_whatsapp_phone character varying(20),
    patient_more_description character varying(2000)
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    payment_id integer NOT NULL,
    user_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    booking_id character varying(50) NOT NULL,
    payment_method public.payment_methods NOT NULL,
    appointment_session_count integer NOT NULL,
    fees_per_session bigint,
    total_payment_amount bigint,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.payments ALTER COLUMN payment_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.payments_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_address; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_address (
    user_address_id uuid NOT NULL,
    user_id uuid NOT NULL,
    user_city character varying(100) NOT NULL,
    user_pincode character varying(10) NOT NULL,
    user_state character varying(50) NOT NULL,
    patient_id uuid,
    user_address_line character varying(200),
    user_latitude double precision,
    user_longitude double precision,
    user_geolocation public.geography(Point,4326),
    user_location character varying(50)
);


ALTER TABLE public.user_address OWNER TO postgres;

--
-- Name: user_ratings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_ratings (
    user_ratings_id integer NOT NULL,
    nurse_id uuid,
    patient_id uuid,
    user_id uuid,
    appointment_id integer,
    appointment_session_id integer,
    user_rating integer,
    user_rating_comments character varying(2000),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.user_ratings OWNER TO postgres;

--
-- Name: user_ratings_user_ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.user_ratings ALTER COLUMN user_ratings_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.user_ratings_user_ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id uuid NOT NULL,
    user_age integer,
    user_dob date,
    user_email character varying(50),
    user_firstname character varying(20),
    user_gender character varying(10),
    user_lastname character varying(20),
    user_latitude double precision,
    user_location character varying(50),
    user_longitude double precision,
    user_name character varying(50),
    user_password character varying(200),
    user_phone character varying(20),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    user_geolocation public.geography(Point,4326),
    user_avg_rating double precision,
    user_whatsapp_phone character varying(20)
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Data for Name: appointment_request_status; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_request_status (appointment_request_status_id, appointment_request_id, booking_id, nurse_id, created_at, updated_at, appointment_request_status) FROM stdin;
4	7	booking-123-567-123	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-11-18 07:19:22.625362	2022-11-18 07:19:22.625362	ACCEPTED
5	17	7115-783958-3899	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-11-18 07:52:13.074166	2022-11-18 07:52:13.074166	ACCEPTED
6	13	7115-711725-3108	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-11-18 14:30:30.62272	2022-11-18 14:30:30.62272	ACCEPTED
7	14	7115-711682-7483	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-11-18 14:50:54.862458	2022-11-18 14:50:54.862458	REJECTED
11	28	7184-001696-3023	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-12-05 08:14:13.054062	2022-12-05 08:14:13.054062	ACCEPTED
12	29	7184-002032-9595	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-12-05 08:43:22.894358	2022-12-05 08:43:22.894358	ACCEPTED
13	30	7184-064646-3655	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-12-05 11:42:00.009	2022-12-05 11:42:00.009	ACCEPTED
14	31	7184-999660-7807	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-12-06 13:33:49.194206	2022-12-06 13:33:49.194206	ACCEPTED
17	33	7180-110918-9451	a7605712-45f2-4dcd-b068-02a86db57d0a	2023-01-02 12:28:03.883054	2023-01-02 12:28:03.883054	ACCEPTED
18	34	7180-111999-3905	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-02 13:35:19.904786	2023-01-02 13:35:19.904786	ACCEPTED
19	38	7180-864020-6313	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 10:17:41.926441	2023-01-03 10:17:41.926441	ACCEPTED
20	39	7180-860180-9131	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 10:45:34.823384	2023-01-03 10:45:34.823384	ACCEPTED
21	40	7180-865706-4585	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 12:16:35.108618	2023-01-03 12:16:35.108618	ACCEPTED
28	35	7180-118969-6396	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:22:01.965405	2023-01-03 13:22:01.965405	ACCEPTED
29	36	7180-864093-5969	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:24:20.15516	2023-01-03 13:24:20.15516	ACCEPTED
30	37	7180-864034-2767	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:26:56.520385	2023-01-03 13:26:56.520385	ACCEPTED
32	42	7180-830339-2436	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:29:33.061944	2023-01-03 13:29:33.061944	ACCEPTED
33	43	7180-830175-1491	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:30:43.063753	2023-01-03 13:30:43.063753	ACCEPTED
34	44	7180-830864-8847	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:32:35.784687	2023-01-03 13:32:35.784687	ACCEPTED
35	45	7180-830514-1048	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:34:36.188509	2023-01-03 13:34:36.188509	ACCEPTED
36	46	7180-830223-2755	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:36:51.920891	2023-01-03 13:36:51.920891	ACCEPTED
41	47	7180-839332-9520	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-03 13:46:06.647753	2023-01-03 13:46:06.647753	ACCEPTED
43	4	booking-123-567-980	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2023-01-06 07:23:26.816174	2023-01-06 07:23:26.816174	ACCEPTED
44	59	7180-252289-7489	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-06 07:28:01.313311	2023-01-06 07:28:01.313311	ACCEPTED
45	61	7189-069419-7158	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 06:10:01.4611	2023-01-09 06:10:01.4611	ACCEPTED
46	62	7189-066895-4298	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 06:12:37.440694	2023-01-09 06:12:37.440694	REJECTED
47	63	7189-080191-6416	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 13:58:27.773162	2023-01-09 13:58:27.773162	ACCEPTED
48	64	7189-080574-2979	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 14:00:52.65187	2023-01-09 14:00:52.65187	ACCEPTED
49	67	7189-086154-5355	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 14:36:40.345855	2023-01-09 14:36:40.345855	ACCEPTED
50	66	7189-086358-1481	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 14:38:09.391112	2023-01-09 14:38:09.391112	ACCEPTED
51	65	7189-086318-2285	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 14:40:00.518352	2023-01-09 14:40:00.518352	ACCEPTED
52	68	7189-083388-0687	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-09 14:46:24.85727	2023-01-09 14:46:24.85727	ACCEPTED
53	69	7189-905570-2430	456e72c0-d2cc-41ed-806b-e64c4ccf43df	2023-01-10 10:09:52.655035	2023-01-10 10:09:52.655035	ACCEPTED
54	78	7189-604266-1337	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-11 07:09:21.933054	2023-01-11 07:09:21.933054	ACCEPTED
55	79	7189-600598-4859	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-11 07:40:47.683343	2023-01-11 07:40:47.683343	ACCEPTED
56	82	7189-346385-7607	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-12 06:23:35.77746	2023-01-12 06:23:35.77746	ACCEPTED
57	83	7189-346801-9721	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-12 06:27:13.726047	2023-01-12 06:27:13.726047	ACCEPTED
58	84	7189-343491-5035	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	2023-01-12 06:30:58.182107	2023-01-12 06:30:58.182107	ACCEPTED
\.


--
-- Data for Name: appointment_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_requests (appointment_request_id, booking_id, appointment_date, appointment_session_count, nurse_id, patient_id, user_id, appointment_visit_type, appointment_start_date, appointment_end_date, appointment_start_time, appointment_end_time, created_at, updated_at, appointment_request_status, appointment_patient_symptoms, appointment_specific_request, total_payment_amount, fees_per_session, days, appointment_dates, payment_method) FROM stdin;
28	7184-001696-3023	2022-12-21	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-21	2022-12-30	13:00	14:00	2022-12-05 07:47:14.609122	2022-12-05 07:47:14.609122	ACCEPTED	\N	\N	\N	\N	{0,1,2}	{2022-12-25,2022-12-26,2022-12-27}	\N
5	booking-123-567-444	2022-11-17	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-17	2022-11-17	10:00	11:00	2022-11-11 07:27:22.096822	2022-11-11 07:27:22.096822	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	\N	\N
15	7115-786060-9656	2022-11-21	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-21	2022-11-21	10:00	11:00	2022-11-11 13:44:02.401711	2022-11-11 13:44:02.401711	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	\N	\N
16	7115-786229-7703	2022-11-22	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-22	2022-11-22	10:00	11:00	2022-11-11 13:56:33.173619	2022-11-11 13:56:33.173619	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	\N	\N
11	booking-123-567-123	2022-11-18	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	LIVE_IN_CARE	2022-11-18	2022-11-18	10:00	11:00	2022-11-11 10:31:41.076678	2022-11-11 10:31:41.076678	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	\N	\N
12	7115-713916-8723	2022-11-19	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	LIVE_IN_CARE	2022-11-19	2022-11-19	10:00	11:00	2022-11-11 11:16:04.798146	2022-11-11 11:16:04.798146	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	\N	\N
7	booking-123-567-123	2022-10-18	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	LIVE_IN_CARE	2022-11-18	2022-11-18	10:00	11:00	2022-11-11 07:46:07.991944	2022-11-11 07:46:07.991944	ACCEPTED	\N	\N	\N	\N	{0,1,2}	\N	\N
17	7115-783958-3899	2022-11-23	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	LIVE_IN_CARE	2022-11-23	2022-11-23	10:00	11:00	2022-11-11 14:03:07.635098	2022-11-11 14:03:07.635098	ACCEPTED	\N	\N	\N	\N	{0,1,2}	\N	\N
13	7115-711725-3108	2022-11-19	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-19	2022-11-19	10:00	11:00	2022-11-11 11:29:58.629318	2022-11-11 11:29:58.629318	ACCEPTED	\N	\N	\N	\N	{0,1,2}	\N	\N
29	7184-002032-9595	2022-12-21	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-21	2022-12-30	10:00	11:00	2022-12-05 08:34:19.443461	2022-12-05 08:34:19.443461	ACCEPTED	\N	\N	\N	\N	{0,1,2}	{2022-12-25,2022-12-26,2022-12-27}	\N
14	7115-711682-7483	2022-11-20	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-20	2022-11-20	10:00	11:00	2022-11-11 11:34:39.162288	2022-11-11 11:34:39.162288	REJECTED	\N	\N	\N	\N	{0,1,2}	\N	\N
18	7112-220555-1125	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 14:54:48.738021	2022-12-02 14:54:48.738021	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
19	7112-226997-5898	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:18:51.969999	2022-12-02 15:18:51.969999	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
20	7112-226997-5898	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:30:43.388403	2022-12-02 15:30:43.388403	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
21	7112-226997-5898	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:32:24.991007	2022-12-02 15:32:24.991007	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
22	7112-226997-5898	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:33:03.229569	2022-12-02 15:33:03.229569	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
23	7112-223074-3646	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:33:30.636075	2022-12-02 15:33:30.636075	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
24	7112-223074-3646	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:34:01.390167	2022-12-02 15:34:01.390167	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
25	7112-223966-9340	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:35:44.43627	2022-12-02 15:35:44.43627	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
26	7112-223614-3739	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:37:40.599269	2022-12-02 15:37:40.599269	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
27	7112-223379-1870	2022-12-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-04	2022-12-20	10:00	11:00	2022-12-02 15:38:33.855103	2022-12-02 15:38:33.855103	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	{0,1,2}	{2022-12-04,2022-12-05,2022-12-06,2022-12-11,2022-12-12,2022-12-13,2022-12-18,2022-12-19,2022-12-20}	\N
30	7184-064646-3655	2022-12-21	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-21	2022-12-30	20:00	21:00	2022-12-05 11:40:04.612861	2022-12-05 11:40:04.612861	ACCEPTED	\N	\N	\N	\N	{0,1,2}	{2022-12-25,2022-12-26,2022-12-27}	\N
31	7184-999660-7807	2023-12-11	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2023-12-11	2023-12-20	20:00	23:00	2022-12-06 13:30:42.294555	2022-12-06 13:30:42.294555	ACCEPTED	\N	\N	\N	\N	{0,1,2}	{2023-12-11,2023-12-12,2023-12-17,2023-12-18,2023-12-19}	\N
32	7180-110730-6367	2023-11-19	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-11-19	2023-11-19	10:00	11:00	2023-01-02 12:22:32.457844	2023-01-02 12:22:32.457844	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
33	7180-110918-9451	2023-11-19	1	a7605712-45f2-4dcd-b068-02a86db57d0a	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-11-19	2023-11-19	10:00	11:00	2023-01-02 12:26:07.308849	2023-01-02 12:26:07.308849	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
34	7180-111999-3905	2023-11-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-11-19	2023-11-19	10:00	11:00	2023-01-02 13:32:13.532806	2023-01-02 13:32:13.532806	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
38	7180-864020-6313	2023-01-21	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2023-01-21	2023-01-30	20:00	23:00	2023-01-03 10:04:52.459034	2023-01-03 10:04:52.459034	ACCEPTED	\N	\N	\N	\N	{2}	{}	\N
39	7180-860180-9131	2023-11-20	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-11-20	2023-11-20	10:00	12:00	2023-01-03 10:44:32.366254	2023-01-03 10:44:32.366254	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
40	7180-865706-4585	2022-11-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-19	2022-11-19	10:00	20:00	2023-01-03 12:15:24.08833	2023-01-03 12:15:24.08833	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
41	7180-834310-0223	2023-01-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	LIVE_IN_CARE	2023-01-19	2023-01-19	\N	\N	2023-01-03 12:56:02.299301	2023-01-03 12:56:02.299301	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
35	7180-118969-6396	2023-10-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-10-19	2023-10-19	10:00	11:00	2023-01-02 13:49:03.453931	2023-01-02 13:49:03.453931	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
36	7180-864093-5969	2022-11-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-19	2022-11-19	10:00	11:00	2023-01-03 10:03:55.834727	2023-01-03 10:03:55.834727	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
37	7180-864034-2767	2022-12-21	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	RECURRING_VISIT	2022-12-21	2022-12-30	20:00	23:00	2023-01-03 10:04:10.927955	2023-01-03 10:04:10.927955	ACCEPTED	\N	\N	\N	\N	{0}	{2022-12-25}	\N
42	7180-830339-2436	2022-02-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-02-19	2022-02-19	10:00	11:00	2023-01-03 13:29:13.905727	2023-01-03 13:29:13.905727	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
43	7180-830175-1491	2022-02-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-02-19	2022-02-19	12:00	13:00	2023-01-03 13:30:18.603431	2023-01-03 13:30:18.603431	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
44	7180-830864-8847	2022-02-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-02-19	2022-02-19	13:00	14:00	2023-01-03 13:32:20.7709	2023-01-03 13:32:20.7709	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
45	7180-830514-1048	2022-02-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-02-19	2022-02-19	14:00	15:00	2023-01-03 13:34:20.620458	2023-01-03 13:34:20.620458	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
46	7180-830223-2755	2022-02-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-02-19	2022-02-19	15:00	16:00	2023-01-03 13:36:35.918848	2023-01-03 13:36:35.918848	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
47	7180-839332-9520	2022-02-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-02-19	2022-02-19	16:00	17:00	2023-01-03 13:45:59.390026	2023-01-03 13:45:59.390026	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
48	7180-831410-0993	2023-02-19	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-02-19	2023-02-19	10:00	20:00	2023-01-03 14:27:42.233613	2023-01-03 14:27:42.233613	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
49	7180-577790-2677	2023-02-19	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-02-19	2023-02-19	10:00	20:00	2023-01-04 05:45:32.941859	2023-01-04 05:45:32.941859	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
50	7180-596109-8648	2023-04-01	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-04-01	2023-04-01	02:00	12:00	2023-01-04 12:17:03.740945	2023-01-04 12:17:03.740945	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
51	7180-567029-1539	2023-01-04	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	LIVE_IN_CARE	2023-01-04	2023-01-05	\N	\N	2023-01-04 14:08:13.685397	2023-01-04 14:08:13.685397	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
52	7180-567166-8393	2023-01-10	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	LIVE_IN_CARE	2023-01-10	2023-01-18	\N	\N	2023-01-04 14:14:04.75414	2023-01-04 14:14:04.75414	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
53	7180-567272-2291	2023-01-16	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	LIVE_IN_CARE	2023-01-16	2023-01-18	\N	\N	2023-01-04 14:18:39.993632	2023-01-04 14:18:39.993632	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
54	7180-560041-0295	2023-01-18	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	LIVE_IN_CARE	2023-01-18	2023-01-25	\N	\N	2023-01-04 14:23:26.293879	2023-01-04 14:23:26.293879	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
55	7180-560676-8030	2023-01-02	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-01-02	2023-01-02	08:00	10:00	2023-01-04 14:26:54.725595	2023-01-04 14:26:54.725595	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
56	7180-206373-8849	2023-01-05	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-01-05	2023-01-05	12:00	18:00	2023-01-05 13:15:15.771752	2023-01-05 13:15:15.771752	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
57	7180-257312-6610	2023-01-06	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-01-06	2022-01-06	10:00	11:00	2023-01-06 05:06:09.446706	2023-01-06 05:06:09.446706	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
58	7180-252422-8785	2023-01-07	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-07	2023-01-07	10:00	11:00	2023-01-06 07:11:39.71794	2023-01-06 07:11:39.71794	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
4	booking-123-567-980	2022-11-06	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2022-11-06	2022-11-06	10:00	11:00	2022-11-11 07:26:06.956987	2022-11-11 07:26:06.956987	ACCEPTED	\N	\N	\N	\N	{0,1,2}	\N	\N
59	7180-252289-7489	2023-01-07	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-07	2023-01-07	10:00	11:00	2023-01-06 07:26:13.108239	2023-01-06 07:26:13.108239	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
60	7189-060231-8913	2023-01-09	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-01-09	2023-01-09	10:00	11:00	2023-01-09 05:42:36.737207	2023-01-09 05:42:36.737207	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
61	7189-069419-7158	2023-01-09	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-09	2023-01-09	10:00	11:00	2023-01-09 05:44:23.168391	2023-01-09 05:44:23.168391	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
62	7189-066895-4298	2023-01-10	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-10	2023-01-10	10:00	11:00	2023-01-09 06:12:18.096849	2023-01-09 06:12:18.096849	REJECTED	\N	\N	\N	\N	\N	\N	\N
63	7189-080191-6416	2023-10-01	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-10-01	2023-10-01	10:00	11:00	2023-01-09 13:57:16.406644	2023-01-09 13:57:16.406644	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
64	7189-080574-2979	2023-01-11	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-11	2023-01-11	10:00	11:00	2023-01-09 14:00:10.932339	2023-01-09 14:00:10.932339	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
67	7189-086154-5355	2023-01-14	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-14	2023-01-14	10:00	11:00	2023-01-09 14:31:20.858548	2023-01-09 14:31:20.858548	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
66	7189-086358-1481	2023-01-13	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-13	2023-01-13	10:00	11:00	2023-01-09 14:29:47.609048	2023-01-09 14:29:47.609048	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
65	7189-086318-2285	2023-01-12	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-12	2023-01-12	10:00	11:00	2023-01-09 14:29:27.998511	2023-01-09 14:29:27.998511	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
68	7189-083388-0687	2023-01-15	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-15	2023-01-15	10:00	11:00	2023-01-09 14:46:17.248194	2023-01-09 14:46:17.248194	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
70	7189-902696-2286	2023-01-10	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	15c6d0bc-2e93-4ffa-b036-9762b706bc06	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-01-10	2023-01-10	12:00	18:00	2023-01-10 05:43:54.998135	2023-01-10 05:43:54.998135	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
71	7189-963995-6009	2023-01-10	1	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-01-10	2023-01-10	08:00	09:00	2023-01-10 10:08:58.422568	2023-01-10 10:08:58.422568	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
69	7189-905570-2430	2022-11-19	1	456e72c0-d2cc-41ed-806b-e64c4ccf43df	15c6d0bc-2e93-4ffa-b036-9762b706bc06	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2022-11-19	2022-11-19	10:00	11:00	2023-01-10 05:33:32.905983	2023-01-10 05:33:32.905983	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
72	7189-963134-9741	2023-01-10	1	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-01-10	2023-01-10	10:00	11:00	2023-01-10 10:14:10.310573	2023-01-10 10:14:10.310573	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
73	7189-963125-1648	2023-10-01	1	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-10-01	2023-10-01	10:00	11:00	2023-01-10 10:14:58.64126	2023-01-10 10:14:58.64126	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
74	7189-963894-0135	2023-10-01	1	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-10-01	2023-10-01	10:00	11:00	2023-01-10 10:15:30.2659	2023-01-10 10:15:30.2659	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
75	7189-963539-3043	2023-01-10	1	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-10	2023-01-10	10:00	11:00	2023-01-10 10:17:33.521295	2023-01-10 10:17:33.521295	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
76	7189-963204-6901	2023-01-11	1	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-11	2023-01-11	10:00	11:00	2023-01-10 10:18:40.433155	2023-01-10 10:18:40.433155	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
77	7189-604551-0059	2023-01-11	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	SINGLE_VISIT	2023-01-11	2023-01-11	08:00	09:00	2023-01-11 07:08:06.229472	2023-01-11 07:08:06.229472	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
78	7189-604266-1337	2023-01-11	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-11	2023-01-11	06:00	07:00	2023-01-11 07:09:04.65626	2023-01-11 07:09:04.65626	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
79	7189-600598-4859	2023-01-11	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-11	2023-01-11	14:00	16:00	2023-01-11 07:40:37.078456	2023-01-11 07:40:37.078456	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
80	7189-344774-7366	2023-01-12	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	15c6d0bc-2e93-4ffa-b036-9762b706bc06	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-01-12	2023-01-12	12:00	18:00	2023-01-12 05:08:30.154918	2023-01-12 05:08:30.154918	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
81	7189-344073-4585	2023-01-13	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	227974bd-a434-4ed7-b79f-7cda1f748f49	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	SINGLE_VISIT	2023-01-13	2023-01-13	01:00	03:00	2023-01-12 05:10:15.087877	2023-01-12 05:10:15.087877	WAITINGFORNURSETOACCEPT	\N	\N	\N	\N	\N	\N	\N
82	7189-346385-7607	2023-01-12	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	SINGLE_VISIT	2023-01-12	2023-01-14	05:00	06:00	2023-01-12 06:22:58.142317	2023-01-12 06:22:58.142317	ACCEPTED	\N	\N	\N	\N	\N	\N	\N
83	7189-346801-9721	2023-01-12	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	RECURRING_VISIT	2023-01-12	2023-01-20	20:00	23:00	2023-01-12 06:25:26.354028	2023-01-12 06:25:26.354028	ACCEPTED	\N	\N	\N	\N	{0}	{2023-01-15}	\N
84	7189-343491-5035	2023-01-21	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	RECURRING_VISIT	2023-01-21	2023-01-25	20:00	23:00	2023-01-12 06:30:36.827078	2023-01-12 06:30:36.827078	ACCEPTED	\N	\N	\N	\N	{0,1,2}	{2023-01-22,2023-01-23,2023-01-24}	\N
\.


--
-- Data for Name: appointment_sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_sessions (appointment_session_id, appointment_id, appointment_actual_end_time, appointment_actual_start_time, appointment_booked_end_time, appointment_booked_start_time, appointment_date, appointment_session, appointment_slot_time, appointment_session_status, created_at, updated_at, appointment_session_cancelled_by, appointment_session_reason, appointment_actual_start_time_with_date, appointment_actual_end_time_with_date) FROM stdin;
1	1	\N	\N	15:00	14:00	2022-11-04	1	14:00	COMPLETED	2022-10-14 12:37:03.399113	2022-10-14 12:37:03.399113	\N	\N	\N	\N
2	1	\N	\N	15:00	14:00	2022-11-05	2	14:00	COMPLETED	2022-10-14 12:37:16.725576	2022-10-14 12:37:16.725576	\N	\N	\N	\N
3	2	\N	\N	15:00	14:00	2022-11-06	1	14:00	COMPLETED	2022-10-14 13:10:15.97534	2022-10-14 13:10:15.97534	\N	\N	\N	\N
4	2	\N	\N	15:00	14:00	2022-11-07	2	14:00	COMPLETED	2022-10-14 13:10:30.517402	2022-10-14 13:10:30.517402	\N	\N	\N	\N
5	3	\N	\N	13:00	12:00	2022-11-06	1	12:00	COMPLETED	2022-11-08 05:23:06.618941	2022-11-08 05:23:06.618941	\N	\N	\N	\N
6	3	\N	\N	13:00	12:00	2022-11-07	2	12:00	COMPLETED	2022-11-08 05:23:11.108785	2022-11-08 05:23:11.108785	\N	\N	\N	\N
8	5	\N	\N	11:00	10:00	2022-10-18	1	10:00	UPCOMING	2022-11-18 07:19:22.625362	2022-11-18 07:19:22.625362	\N	\N	\N	\N
9	6	\N	\N	11:00	10:00	2022-11-23	1	10:00	UPCOMING	2022-11-18 07:52:13.074166	2022-11-18 07:52:13.074166	\N	\N	\N	\N
10	7	\N	\N	11:00	10:00	2022-11-19	1	10:00	UPCOMING	2022-11-18 14:30:30.62272	2022-11-18 14:30:30.62272	\N	\N	\N	\N
11	10	\N	\N	14:00	13:00	2022-12-25	1	13:00	UPCOMING	2022-12-05 08:14:13.054062	2022-12-05 08:14:13.054062	\N	\N	\N	\N
12	10	\N	\N	14:00	13:00	2022-12-26	1	13:00	UPCOMING	2022-12-05 08:14:13.054062	2022-12-05 08:14:13.054062	\N	\N	\N	\N
13	10	\N	\N	14:00	13:00	2022-12-27	1	13:00	UPCOMING	2022-12-05 08:14:13.054062	2022-12-05 08:14:13.054062	\N	\N	\N	\N
14	11	\N	\N	11:00	10:00	2022-12-25	1	10:00	UPCOMING	2022-12-05 08:43:22.894358	2022-12-05 08:43:22.894358	\N	\N	\N	\N
15	11	\N	\N	11:00	10:00	2022-12-26	1	10:00	UPCOMING	2022-12-05 08:43:22.894358	2022-12-05 08:43:22.894358	\N	\N	\N	\N
16	11	\N	\N	11:00	10:00	2022-12-27	1	10:00	UPCOMING	2022-12-05 08:43:22.894358	2022-12-05 08:43:22.894358	\N	\N	\N	\N
17	12	\N	\N	21:00	20:00	2022-12-25	1	20:00	UPCOMING	2022-12-05 11:42:00.009	2022-12-05 11:42:00.009	\N	\N	\N	\N
19	12	\N	\N	21:00	20:00	2022-12-27	3	20:00	UPCOMING	2022-12-05 11:42:00.009	2022-12-05 11:42:00.009	\N	\N	\N	\N
20	13	\N	\N	23:00	20:00	2023-12-11	1	20:00	UPCOMING	2022-12-06 13:33:49.194206	2022-12-06 13:33:49.194206	\N	\N	\N	\N
21	13	\N	\N	23:00	20:00	2023-12-12	2	20:00	UPCOMING	2022-12-06 13:33:49.194206	2022-12-06 13:33:49.194206	\N	\N	\N	\N
22	13	\N	\N	23:00	20:00	2023-12-17	3	20:00	UPCOMING	2022-12-06 13:33:49.194206	2022-12-06 13:33:49.194206	\N	\N	\N	\N
23	13	\N	\N	23:00	20:00	2023-12-18	4	20:00	UPCOMING	2022-12-06 13:33:49.194206	2022-12-06 13:33:49.194206	\N	\N	\N	\N
24	13	\N	\N	23:00	20:00	2023-12-19	5	20:00	UPCOMING	2022-12-06 13:33:49.194206	2022-12-06 13:33:49.194206	\N	\N	\N	\N
25	14	\N	\N	11:00	10:00	2023-11-19	1	10:00	UPCOMING	2023-01-02 12:28:03.883054	2023-01-02 12:28:03.883054	\N	\N	\N	\N
26	15	\N	\N	11:00	10:00	2023-11-19	1	10:00	UPCOMING	2023-01-02 13:35:19.904786	2023-01-02 13:35:19.904786	\N	\N	\N	\N
18	12	15:00	13:00	21:00	20:00	2022-12-26	2	20:00	COMPLETED	2022-12-05 11:42:00.009	2022-12-05 11:42:00.009	\N	\N	2023-01-02 15:14:46.195069	2023-01-02 15:15:26.362191
27	17	\N	\N	12:00	10:00	2023-11-20	1	10:00	UPCOMING	2023-01-03 10:45:34.823384	2023-01-03 10:45:34.823384	\N	\N	\N	\N
28	18	\N	\N	20:00	10:00	2022-11-19	1	10:00	UPCOMING	2023-01-03 12:16:35.108618	2023-01-03 12:16:35.108618	\N	\N	\N	\N
35	25	\N	\N	11:00	10:00	2023-10-19	1	10:00	UPCOMING	2023-01-03 13:22:01.965405	2023-01-03 13:22:01.965405	\N	\N	\N	\N
36	26	\N	\N	11:00	10:00	2022-11-19	1	10:00	UPCOMING	2023-01-03 13:24:20.15516	2023-01-03 13:24:20.15516	\N	\N	\N	\N
37	27	\N	\N	23:00	20:00	2022-12-25	1	20:00	UPCOMING	2023-01-03 13:26:56.520385	2023-01-03 13:26:56.520385	\N	\N	\N	\N
39	29	\N	\N	11:00	10:00	2022-02-19	1	10:00	UPCOMING	2023-01-03 13:29:33.061944	2023-01-03 13:29:33.061944	\N	\N	\N	\N
40	30	\N	\N	13:00	12:00	2022-02-19	1	12:00	UPCOMING	2023-01-03 13:30:43.063753	2023-01-03 13:30:43.063753	\N	\N	\N	\N
41	31	\N	\N	14:00	13:00	2022-02-19	1	13:00	UPCOMING	2023-01-03 13:32:35.784687	2023-01-03 13:32:35.784687	\N	\N	\N	\N
42	32	\N	\N	15:00	14:00	2022-02-19	1	14:00	UPCOMING	2023-01-03 13:34:36.188509	2023-01-03 13:34:36.188509	\N	\N	\N	\N
43	33	\N	\N	16:00	15:00	2022-02-19	1	15:00	UPCOMING	2023-01-03 13:36:51.920891	2023-01-03 13:36:51.920891	\N	\N	\N	\N
48	38	\N	\N	17:00	16:00	2022-02-19	1	16:00	UPCOMING	2023-01-03 13:46:06.647753	2023-01-03 13:46:06.647753	\N	\N	\N	\N
50	40	\N	\N	11:00	10:00	2022-11-06	1	10:00	UPCOMING	2023-01-06 07:23:26.816174	2023-01-06 07:23:26.816174	\N	\N	\N	\N
51	41	\N	\N	11:00	10:00	2023-01-07	1	10:00	UPCOMING	2023-01-06 07:28:01.313311	2023-01-06 07:28:01.313311	\N	\N	\N	\N
52	42	\N	18:49	11:00	10:00	2023-01-09	1	10:00	STARTED	2023-01-09 06:10:01.4611	2023-01-09 06:10:01.4611	\N	\N	2023-01-09 13:19:31.719439	\N
53	43	\N	19:56	11:00	10:00	2023-10-01	1	10:00	STARTED	2023-01-09 13:58:27.773162	2023-01-09 13:58:27.773162	\N	\N	2023-01-09 14:26:07.728356	\N
54	44	\N	19:58	11:00	10:00	2023-01-11	1	10:00	STARTED	2023-01-09 14:00:52.65187	2023-01-09 14:00:52.65187	\N	\N	2023-01-09 14:28:11.236132	\N
55	45	\N	20:06	11:00	10:00	2023-01-14	1	10:00	STARTED	2023-01-09 14:36:40.345855	2023-01-09 14:36:40.345855	\N	\N	2023-01-09 14:36:54.556479	\N
56	46	\N	20:08	11:00	10:00	2023-01-13	1	10:00	STARTED	2023-01-09 14:38:09.391112	2023-01-09 14:38:09.391112	\N	\N	2023-01-09 14:38:22.985642	\N
57	47	\N	20:10	11:00	10:00	2023-01-12	1	10:00	STARTED	2023-01-09 14:40:00.518352	2023-01-09 14:40:00.518352	\N	\N	2023-01-09 14:40:15.635662	\N
58	48	\N	15:36	11:00	10:00	2023-01-15	1	10:00	STARTED	2023-01-09 14:46:24.85727	2023-01-09 14:46:24.85727	\N	\N	2023-01-10 10:06:01.207153	\N
59	49	\N	\N	11:00	10:00	2022-11-19	1	10:00	UPCOMING	2023-01-10 10:09:52.655035	2023-01-10 10:09:52.655035	\N	\N	\N	\N
60	50	\N	\N	07:00	06:00	2023-01-11	1	06:00	UPCOMING	2023-01-11 07:09:21.933054	2023-01-11 07:09:21.933054	\N	\N	\N	\N
61	51	\N	\N	16:00	14:00	2023-01-11	1	14:00	UPCOMING	2023-01-11 07:40:47.683343	2023-01-11 07:40:47.683343	\N	\N	\N	\N
62	52	\N	\N	06:00	05:00	2023-01-12	1	05:00	UPCOMING	2023-01-12 06:23:35.77746	2023-01-12 06:23:35.77746	\N	\N	\N	\N
63	53	\N	\N	23:00	20:00	2023-01-15	1	20:00	UPCOMING	2023-01-12 06:27:13.726047	2023-01-12 06:27:13.726047	\N	\N	\N	\N
64	54	\N	\N	23:00	20:00	2023-01-22	1	20:00	UPCOMING	2023-01-12 06:30:58.182107	2023-01-12 06:30:58.182107	\N	\N	\N	\N
65	54	\N	\N	23:00	20:00	2023-01-23	2	20:00	UPCOMING	2023-01-12 06:30:58.182107	2023-01-12 06:30:58.182107	\N	\N	\N	\N
66	54	\N	\N	23:00	20:00	2023-01-24	3	20:00	UPCOMING	2023-01-12 06:30:58.182107	2023-01-12 06:30:58.182107	\N	\N	\N	\N
\.


--
-- Data for Name: appointment_slots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_slots (slot_id, slots) FROM stdin;
1	{00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00}
\.


--
-- Data for Name: appointment_slots_nurse_default; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_slots_nurse_default (slot_id, nurse_id, slot_frequency, slots, created_at, updated_at) FROM stdin;
1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	{MON,TUE,WED}	{00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00}	2022-10-14 12:32:48.884814	2022-10-14 12:32:48.884814
\.


--
-- Data for Name: appointment_slots_nurse_specific; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_slots_nurse_specific (slot_id, nurse_id, slot_date, slots, created_at, updated_at) FROM stdin;
1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2022-10-20	{00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00}	2022-10-14 12:32:55.993117	2022-10-14 12:32:55.993117
\.


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointments (appointment_id, booking_id, appointment_date, appointment_status, appointment_session_count, nurse_id, patient_id, user_id, created_at, updated_at, appointment_visit_type, appointment_start_date, appointment_end_date, appointment_patient_symptoms, appointment_specific_request) FROM stdin;
1	boooking-1234-fghi	2022-10-13	COMPLETED	2	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-10-14 12:35:09.346874	2022-10-14 12:35:09.346874	RECURRING_VISIT	\N	\N	\N	\N
2	boooking-1234-abc	2022-10-17	COMPLETED	2	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-10-14 12:45:03.941962	2022-10-14 12:45:03.941962	RECURRING_VISIT	\N	\N	\N	\N
3	boooking-1234	2022-10-06	ONGOING	2	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-11-08 05:15:46.122847	2022-11-08 05:15:46.122847	RECURRING_VISIT	\N	\N	\N	\N
5	booking-123-567-123	2022-10-18	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-11-18 07:19:22.625362	2022-11-18 07:19:22.625362	LIVE_IN_CARE	2022-11-18	2022-11-18	\N	\N
6	7115-783958-3899	2022-11-23	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-11-18 07:52:13.074166	2022-11-18 07:52:13.074166	LIVE_IN_CARE	2022-11-23	2022-11-23	\N	\N
7	7115-711725-3108	2022-11-19	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-11-18 14:30:30.62272	2022-11-18 14:30:30.62272	SINGLE_VISIT	2022-11-19	2022-11-19	\N	\N
10	7184-001696-3023	2022-12-21	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-12-05 08:14:13.054062	2022-12-05 08:14:13.054062	RECURRING_VISIT	2022-12-21	2022-12-30	\N	\N
11	7184-002032-9595	2022-12-21	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-12-05 08:43:22.894358	2022-12-05 08:43:22.894358	RECURRING_VISIT	2022-12-21	2022-12-30	\N	\N
12	7184-064646-3655	2022-12-21	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-12-05 11:42:00.009	2022-12-05 11:42:00.009	RECURRING_VISIT	2022-12-21	2022-12-30	\N	\N
13	7184-999660-7807	2023-12-11	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2022-12-06 13:33:49.194206	2022-12-06 13:33:49.194206	RECURRING_VISIT	2023-12-11	2023-12-20	\N	\N
14	7180-110918-9451	2023-11-19	ACCEPTED	1	a7605712-45f2-4dcd-b068-02a86db57d0a	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	2023-01-02 12:28:03.883054	2023-01-02 12:28:03.883054	SINGLE_VISIT	2023-11-19	2023-11-19	\N	\N
15	7180-111999-3905	2023-11-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	2023-01-02 13:35:19.904786	2023-01-02 13:35:19.904786	SINGLE_VISIT	2023-11-19	2023-11-19	\N	\N
16	7180-864020-6313	2023-01-21	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 10:17:41.926441	2023-01-03 10:17:41.926441	RECURRING_VISIT	2023-01-21	2023-01-30	\N	\N
17	7180-860180-9131	2023-11-20	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 10:45:34.823384	2023-01-03 10:45:34.823384	SINGLE_VISIT	2023-11-20	2023-11-20	\N	\N
18	7180-865706-4585	2022-11-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 12:16:35.108618	2023-01-03 12:16:35.108618	SINGLE_VISIT	2022-11-19	2022-11-19	\N	\N
25	7180-118969-6396	2023-10-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	2023-01-03 13:22:01.965405	2023-01-03 13:22:01.965405	SINGLE_VISIT	2023-10-19	2023-10-19	\N	\N
26	7180-864093-5969	2022-11-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:24:20.15516	2023-01-03 13:24:20.15516	SINGLE_VISIT	2022-11-19	2022-11-19	\N	\N
27	7180-864034-2767	2022-12-21	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:26:56.520385	2023-01-03 13:26:56.520385	RECURRING_VISIT	2022-12-21	2022-12-30	\N	\N
29	7180-830339-2436	2022-02-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:29:33.061944	2023-01-03 13:29:33.061944	SINGLE_VISIT	2022-02-19	2022-02-19	\N	\N
30	7180-830175-1491	2022-02-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:30:43.063753	2023-01-03 13:30:43.063753	SINGLE_VISIT	2022-02-19	2022-02-19	\N	\N
31	7180-830864-8847	2022-02-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:32:35.784687	2023-01-03 13:32:35.784687	SINGLE_VISIT	2022-02-19	2022-02-19	\N	\N
32	7180-830514-1048	2022-02-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:34:36.188509	2023-01-03 13:34:36.188509	SINGLE_VISIT	2022-02-19	2022-02-19	\N	\N
33	7180-830223-2755	2022-02-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:36:51.920891	2023-01-03 13:36:51.920891	SINGLE_VISIT	2022-02-19	2022-02-19	\N	\N
38	7180-839332-9520	2022-02-19	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-03 13:46:06.647753	2023-01-03 13:46:06.647753	SINGLE_VISIT	2022-02-19	2022-02-19	\N	\N
40	booking-123-567-980	2022-11-06	ACCEPTED	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	2023-01-06 07:23:26.816174	2023-01-06 07:23:26.816174	SINGLE_VISIT	2022-11-06	2022-11-06	\N	\N
41	7180-252289-7489	2023-01-07	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-06 07:28:01.313311	2023-01-06 07:28:01.313311	SINGLE_VISIT	2023-01-07	2023-01-07	\N	\N
42	7189-069419-7158	2023-01-09	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-09 06:10:01.4611	2023-01-09 06:10:01.4611	SINGLE_VISIT	2023-01-09	2023-01-09	\N	\N
43	7189-080191-6416	2023-10-01	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-09 13:58:27.773162	2023-01-09 13:58:27.773162	SINGLE_VISIT	2023-10-01	2023-10-01	\N	\N
44	7189-080574-2979	2023-01-11	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-09 14:00:52.65187	2023-01-09 14:00:52.65187	SINGLE_VISIT	2023-01-11	2023-01-11	\N	\N
45	7189-086154-5355	2023-01-14	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-09 14:36:40.345855	2023-01-09 14:36:40.345855	SINGLE_VISIT	2023-01-14	2023-01-14	\N	\N
46	7189-086358-1481	2023-01-13	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-09 14:38:09.391112	2023-01-09 14:38:09.391112	SINGLE_VISIT	2023-01-13	2023-01-13	\N	\N
47	7189-086318-2285	2023-01-12	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-09 14:40:00.518352	2023-01-09 14:40:00.518352	SINGLE_VISIT	2023-01-12	2023-01-12	\N	\N
48	7189-083388-0687	2023-01-15	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-09 14:46:24.85727	2023-01-09 14:46:24.85727	SINGLE_VISIT	2023-01-15	2023-01-15	\N	\N
49	7189-905570-2430	2022-11-19	ACCEPTED	1	456e72c0-d2cc-41ed-806b-e64c4ccf43df	15c6d0bc-2e93-4ffa-b036-9762b706bc06	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	2023-01-10 10:09:52.655035	2023-01-10 10:09:52.655035	SINGLE_VISIT	2022-11-19	2022-11-19	\N	\N
50	7189-604266-1337	2023-01-11	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-11 07:09:21.933054	2023-01-11 07:09:21.933054	SINGLE_VISIT	2023-01-11	2023-01-11	\N	\N
51	7189-600598-4859	2023-01-11	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-11 07:40:47.683343	2023-01-11 07:40:47.683343	SINGLE_VISIT	2023-01-11	2023-01-11	\N	\N
52	7189-346385-7607	2023-01-12	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-12 06:23:35.77746	2023-01-12 06:23:35.77746	SINGLE_VISIT	2023-01-12	2023-01-14	\N	\N
53	7189-346801-9721	2023-01-12	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-12 06:27:13.726047	2023-01-12 06:27:13.726047	RECURRING_VISIT	2023-01-12	2023-01-20	\N	\N
54	7189-343491-5035	2023-01-21	ACCEPTED	1	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	b7389fb3-bc1a-445b-b655-54c96981c513	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	2023-01-12 06:30:58.182107	2023-01-12 06:30:58.182107	RECURRING_VISIT	2023-01-21	2023-01-25	\N	\N
\.


--
-- Data for Name: nurse_address; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_address (nurse_address_id, nurse_id, nurse_address_type, nurse_area, nurse_city, nurse_door_no_block, nurse_pincode, nurse_road, nurse_state, nurse_street) FROM stdin;
4f609a24-dafc-472a-af2f-47149d9d6579	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	Home	6th Avenue	Chennai	701	600001	2nd Main Road	TamilNadu	5th Street
\.


--
-- Data for Name: nurse_earnings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_earnings (nurse_earnings_id, nurse_id, appointment_id, appointment_session_id, booking_id, nurse_earning, payment_method, created_at, updated_at) FROM stdin;
1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	1	1	boooking-1234-fghi	1000	GPAY	2022-11-07 12:38:20.631078	2022-11-07 12:38:20.631078
2	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	1	2	boooking-1234-fghi	1000	GPAY	2022-11-07 12:40:09.21208	2022-11-07 12:40:09.21208
3	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2	3	boooking-1234-abc	1000	GPAY	2022-11-07 12:40:23.105504	2022-11-07 12:40:23.105504
4	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	2	4	boooking-1234-abc	1000	GPAY	2022-11-07 12:40:31.527676	2022-11-07 12:40:31.527676
5	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	3	5	boooking-1234	1000	GPAY	2022-11-08 05:29:48.330867	2022-11-08 05:29:48.330867
\.


--
-- Data for Name: nurse_education; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_education (nurse_education_id, nurse_education_name) FROM stdin;
1	Medical Graduate
\.


--
-- Data for Name: nurse_fees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_fees (nurse_fees_id, nurse_id, minimum_distance, distance_unit, minimum_session_fee, session_fee_currency, charges_for_extra_distance) FROM stdin;
1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	10	KM	500	INR	100
13	ec34e54c-a787-4931-ad70-9b24c3a786ae	10	KM	1515	INR	1000
21	bf535695-49a0-4b62-ae3b-e9be9e65dcd8	10	KM	1428	INR	1000
\.


--
-- Data for Name: nurse_ratings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_ratings (nurse_ratings_id, nurse_id, patient_id, user_id, appointment_id, appointment_session_id, nurse_rating, nurse_rating_comments, created_at, updated_at) FROM stdin;
1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	5	5	4	Nurse is very helpful	2023-01-15 12:37:22.946727	2023-01-15 12:37:22.946727
\.


--
-- Data for Name: nurse_service_type_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_service_type_values (nurse_service_type_value_id, nurse_service_type, nurse_service_type_name, nurse_service_type_description) FROM stdin;
1	HOUSE_HOLD_TASKS	House Hold Tasks	House Hold and More
2	PERSONAL_CARE	Personal Care	Personal Care and More
3	COMPANION_SHIP	Companionship	Companionship and More
4	TRANSPORTATION	Transportation	Transportation and More
5	MOBILITY_ASSISTANCE	Mobility Assistance	Mobility Assistance and More
6	SPECIALIZED_CARE	Specialized Care	Specialized Care and More
7	PHYSICAL_EXAMINATIONS	Physical Examinations	Physical Examinations and More
8	NURSE_CONSULTATIONS	Nurse Consultations	Physical Examinations and More
\.


--
-- Data for Name: nurse_skills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_skills (nurse_skill_id, nurse_skill_name) FROM stdin;
1	Certified Home Health Aide
\.


--
-- Data for Name: nurse_slots_recurring; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse_slots_recurring (slot_id, nurse_id, slot_frequency, slot_start_time, slot_end_time, created_at, updated_at) FROM stdin;
1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	{SUN,MON,TUE}	10:00	18:00	2022-10-30 15:44:07.0442	2022-10-30 15:44:07.0442
\.


--
-- Data for Name: nurses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurses (nurse_id, nurse_age, nurse_dob, nurse_email, nurse_firstname, nurse_gender, nurse_lastname, nurse_latitude, nurse_location, nurse_longitude, nurse_name, nurse_password, nurse_phone, created_at, updated_at, nurse_geolocation, nurse_type, nurse_avg_rating, nurse_experience, nurse_rating_count, nurse_whatsapp_phone, nurse_verified, nurse_is_licensed, nurse_description, nurse_languages_known, nurse_service_type, nurse_education_id, nurse_skill_id, is_criminal_record_checked) FROM stdin;
18803b4e-6683-11ed-b767-0242ac110002	24	1997-01-01	def@elite.com	\N	MALE	\N	\N	1,2nd Street,Anna Nagar	\N	YYY	\N	918144528548	2022-11-17 14:22:23.40142	2022-11-17 14:22:23.40142	0101000020E6100000F13F4349920D544048DFA46950482A40	NURSE	4	5	6	918144528548	t	t	Mrs.YYY is a well experienced nurse in Cardio	{Tamil,English,Hindi}	{HOUSE_HOLD_TASKS,PERSONAL_CARE}	1	1	t
ee58f1f1-eb8b-4567-a15d-ddfc670252d6	23	1997-01-01	abc@elite.com	xxx	MALE	zzz	13.121699	2nd Street Iyappa Nagar	80.201	XXX	$2a$10$/.KM65.mIz/hSddtJy8wMeuO3A1j.5EJQAjcSJwyc5XTQ4daT964e	919566202701	2022-08-25 06:59:59.145	2022-08-25 06:59:59.145	0101000020E6100000BE9F1A2FDD0C54406CE9D1544F3E2A40	NURSE	4.5	5	4	919566202701	t	t	Mrs.XYZ is a well experienced nurse in Cardio	{Tamil,English,Hindi}	{HOUSE_HOLD_TASKS,PERSONAL_CARE}	1	1	t
b0ac5549-7533-4b8c-867c-93a948c9fff4	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	919566202702	2022-12-30 21:35:58.653	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7b56e4c8-693b-44d0-9c16-a0c0cdba8e86	23	1997-01-01	abc@elite.com	xxx	MALE	zzz	13.121699	2nd Street Iyappa Nagar	80.201	XXX	$2a$10$aJdtH5NQUfY7zksxQQeNF.3YbP1duaZpznWVHxurskBaZ7A58Fegm	919566202703	2022-12-30 21:36:11.944385	\N	0101000020E6100000BE9F1A2FDD0C54406CE9D1544F3E2A40	\N	\N	5	\N	919566202703	\N	\N	\N	\N	\N	\N	\N	\N
5496be06-06c6-4d52-9bfd-9c69a3327987	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1111111111	2023-01-02 06:36:44.000314	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bb3d4ace-4dac-4bb6-848c-c4116ba2429a	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1111211111	2023-01-02 09:27:43.350903	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
a7605712-45f2-4dcd-b068-02a86db57d0a	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	7753356445	2023-01-02 12:17:58.052792	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
ec34e54c-a787-4931-ad70-9b24c3a786ae	23	1997-01-01	abc@elite.com	xxx	MALE	zzz	13.121699	2nd Street Iyappa Nagar	80.201	XXX	$2a$10$ufM0Ma5EFzh2DaYatJyUEO8/u.E3DoJCZXsMgimYfbnBdvzjbsOz2	5884018716	2023-01-02 09:37:15.036223	\N	0101000020E6100000BE9F1A2FDD0C54406CE9D1544F3E2A40	\N	\N	5	\N	919566202701	\N	\N	\N	\N	\N	\N	\N	\N
21e250a7-ba1b-497d-b378-11d3729ebbd8	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0282828283	2023-01-02 12:59:12.789064	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
03bf8134-3a6e-45a2-8dad-b3f8cb65f9fd	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2111111111	2023-01-04 11:17:51.810615	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bf535695-49a0-4b62-ae3b-e9be9e65dcd8	28	1994-03-13		shyam	Male		13.121699	51-6,Ragavan Colony 1st Link Street,Ashok Nagar	80.201	shyam	$2a$10$AX4cC7jDNzhb9/8ap9N6BesPOmsvenm8x4eRmCv3p28jk2GyZAasS	9943960728	2023-01-02 05:16:28.020746	\N	0101000020E6100000BE9F1A2FDD0C54406CE9D1544F3E2A40	\N	\N	2	\N	9943960728	\N	\N	\N	\N	\N	\N	\N	\N
456e72c0-d2cc-41ed-806b-e64c4ccf43df	23	1997-01-01	abc@elite.com	xxx	MALE	zzz	13.121699	2nd Street Iyappa Nagar	80.201	XXX	$2a$10$cHjqmCfS8nhho2JkgsOunuysNZoSi2WouySPXkZR6wZSgxCs91Ubi	9916522058	2023-01-04 05:21:52.805413	\N	0101000020E6100000BE9F1A2FDD0C54406CE9D1544F3E2A40	\N	\N	5	\N	919566202701	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: nurses_service_type_subscription; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurses_service_type_subscription (nurses_service_type_subscription_id, nurse_service_type_value_id, nurse_id) FROM stdin;
1	1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6
2	2	ee58f1f1-eb8b-4567-a15d-ddfc670252d6
\.


--
-- Data for Name: otp_for_appointment_session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.otp_for_appointment_session (otp_for_appointment_session_id, user_id, user_phone, appointment_session_id, otp, created_at) FROM stdin;
1	4294ebd4-3498-4a23-bd89-87c126483cf9	918144528548	18	$2a$10$EY1ld7ZLrFG9HmrHKlDSGeu6nxIg3kmbquvWD3CFMwJKShiQeATLW	2023-01-02 15:13:28.920816
4	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	52	$2a$10$QHZCMXFbDC70onl2mO/8EeITor0H6WegkDquykhodp1iQUTZrQ1Gm	2023-01-09 10:27:45.388498
20	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	53	$2a$10$YVEoxG1TjP/dCfAcM4aUg.8xDa/Cho//Mhe6RgyTM9qWyCxjBHJJO	2023-01-09 14:25:51.907941
21	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	54	$2a$10$QosQ2xCHfvWXoN.HcsR0WOZrzTDKNc1AU4s4X1KqWqbGIYpUX3XF6	2023-01-09 14:28:08.69455
22	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	55	$2a$10$W0QhSkAy/SZRXB640gvp2.IKcGMJPdvQu9C0pXvG3AzHu60x8vcHO	2023-01-09 14:36:49.534452
23	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	56	$2a$10$7GubswISua/z94Q/9RTEwe0MJ2J3Fqf7yyk0M7GfRi3eku7oMk5Q2	2023-01-09 14:38:20.287123
24	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	57	$2a$10$/S5DXca1qF1BuxvidiOdGumnBoETi4TzrO1b57dI.pQAwxIBXQEb6	2023-01-09 14:40:13.124524
25	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	58	$2a$10$pE7DSXYRvgubBoAMixwn0uKNzGjXjGZuYNXjofA.kq7Nw1bvLSVji	2023-01-10 07:24:48.177129
37	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	60	$2a$10$b7OMLx4aJeQ1bLwrLvTpwOOEGVO47miCpoI8DKJD.QPw6D1KMrx1O	2023-01-11 13:21:10.513243
47	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	9943960728	62	$2a$10$Fn87Ktavt08OwJC1rL.aR.eVj7byzisFZ68vf3CugoEr3Hb9u1dxG	2023-01-12 11:25:23.084497
\.


--
-- Data for Name: otp_phone; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.otp_phone (user_phone, otp, created_at) FROM stdin;
1111211111	$2a$10$4uUt/l1ZD0LybbCxqMKhPeoOgeRyzL46QxpcUHv95jtiabi6hOu3K	2023-01-02 09:27:43.449493
6392391838	$2a$10$dvXr4hcM9DIl/utPGpVpQuoRdmXfDWPuhU8a8ujeIPKv0k0wr1QMy	2022-12-29 08:31:58.413757
5884018716	$2a$10$Va8BhQLTTVUIuxxATxuGvO75zkGvnpZWB3qFqqZlStQYg2pg495O2	2023-01-02 09:37:15.134238
7753356445	$2a$10$ewynN/95sypo0Wkv6aIpeudVOSFwS8tWJhlH4pyYRutGrZj5hsh3e	2023-01-02 12:17:58.149156
0282828283	$2a$10$7b6K6DYX5Elw5XLs2BBqWeFxNjFnhhUYW90hcTN.X/SzItZO/T9Ce	2023-01-02 12:59:12.898396
9916522059	$2a$10$IC3FM7x1eBAxMhx5KuIejeHg/CAtzi6U3n4/6EmJuQI5FAI6I1Q/q	2023-01-03 05:07:54.722078
0838822863	$2a$10$I9S6dIoazx8qCEmAq.AhEeJTnPmyucc/DfV8xUKuf0hhuZ9AJEM5i	2022-12-29 12:15:43.4293
9991652205	$2a$10$GeBAYnJZqKqr4nVpD.A3Se3YO0/EccG0EkbX45WeMV4TZ3h1lQfEu	2023-01-03 05:14:00.414564
919566202702	$2a$10$wlNMwvG3HImvKb9QmsI5SeGVQYO8XWcMGDcYrYWCPqu5Qcu70yZ.C	2022-12-30 21:35:58.763398
919566202703	$2a$10$tghjFqqYekj7vwiHQUTiku64qh2aHrg5wxTTY1Cdbe/dbD0eJp.gS	2022-12-30 21:36:12.045037
9943960728	$2a$10$jo9h8l32.QEVJgGQjzJN2.cU0ETXgCiQ92BMnejVa3nAeuxynGEX.	2023-01-02 05:16:28.18189
9916522058	$2a$10$yz22cJ/ryaBtTSE0uBeT8O5mNK.5LImsfsnQi7U.8sV5ztuKgIG9K	2022-12-28 11:06:33.565879
2111111111	$2a$10$ppNS3QBbEyYyuyn5ltzijuRFxfoYRxoQPsp/Wz2qVy6ho1ntvt9fS	2023-01-04 11:17:51.907168
1111111111	$2a$10$Pr7QKjCgBpcO9tFp7xP.D.CMAnfsBWaUECgaqgOEUkRMPl.q6mOAK	2023-01-02 06:36:44.12635
919566202701	$2a$10$WfP3hkaffqtEAtJIOF2edOrXPLUgZheY2MLZDetjiIsBH2CGx6gjK	2022-12-13 06:09:12.165809
\.


--
-- Data for Name: patient_ratings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patient_ratings (patient_ratings_id, patient_id, nurse_id, user_id, appointment_id, appointment_session_id, patient_rating, patient_rating_comments, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patients (patient_id, patient_age, patient_dob, patient_email, patient_firstname, patient_gender, patient_lastname, patient_latitude, patient_location, patient_longitude, patient_name, patient_phone, created_at, updated_at, user_id, self_or_others, patient_avg_rating, patient_ratings, user_relationship_with_patient, patient_whatsapp_phone, patient_more_description) FROM stdin;
c4117309-ba96-4c78-839f-f5d168943808	0	2023-06-01	email@gmail.com	\N	Male	\N	\N	\N	\N	Elite	9916522059	\N	\N	4c0f1f74-7694-44dc-a1a9-4cce7e1fc580	\N	\N	\N	SELF	9916522059	\N
b7389fb3-bc1a-445b-b655-54c96981c513	21	2002-01-01	abc@elite.com	\N	MALE	\N	\N	\N	\N	xxx	91566202702	\N	\N	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	\N	\N	\N	PARENTS	91566202702	\N
8dd2c580-91f6-49a9-9cb9-f2d5a96a96cb	21	2002-01-01	abc@elite.com	\N	Male	\N	\N	\N	\N	xxx	91566202702	\N	\N	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	\N	\N	\N	SELF	9916522058	\N
22856efa-5883-4a86-83d1-26ee4a95757b	21	2002-01-01	abc@elite.com	\N	MALE	\N	\N	\N	\N	xxx	919566202701	\N	\N	aea21e8e-fc36-4964-b779-d47c1af727e5	\N	\N	\N	SELF	919566202701	\N
7cb15c06-2548-4f7d-a257-f6c5bf4e86b3	21	2002-01-01	abc@elite.com	\N	MALE	\N	\N	\N	\N	xxx	91566202702	\N	\N	aea21e8e-fc36-4964-b779-d47c1af727e5	\N	\N	\N	PARENTS	91566202702	\N
15c6d0bc-2e93-4ffa-b036-9762b706bc06	21	2002-01-01	\N	\N	Male	\N	\N	\N	\N	grandparents	91566202702	\N	\N	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	\N	\N	\N	GRAND_PARENTS	91566202702	\N
44e556e5-cd97-4a04-9f22-96968c318344	21	2002-01-01	\N	\N	Male	\N	\N	\N	\N	test Tt	91566202702	\N	\N	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	\N	\N	\N	PARENTS	91566202702	\N
227974bd-a434-4ed7-b79f-7cda1f748f49	0	2023-09-01	\N	\N	Male	\N	\N	\N	\N	Test friends	9916522853	\N	\N	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	\N	\N	\N	FRIENDS	9916522853	\N
38431b31-fe56-479e-9d6e-885022407b3a	0	2023-09-01	\N	\N	Male	\N	\N	\N	\N	Tesvs relative	9916522056	\N	\N	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	\N	\N	\N	RELATIVES	9916522056	\N
1d7f4437-1057-4d2a-b010-a8418d8b45ee	0	2023-09-01	\N	\N	Male	\N	\N	\N	\N	Siva balan	9916522053	\N	\N	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	\N	\N	\N	SPOUSE	9916522053	\N
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (payment_id, user_id, patient_id, booking_id, payment_method, appointment_session_count, fees_per_session, total_payment_amount, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: user_address; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_address (user_address_id, user_id, user_city, user_pincode, user_state, patient_id, user_address_line, user_latitude, user_longitude, user_geolocation, user_location) FROM stdin;
54f7e25d-d390-4937-a71e-ad0cab521eac	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	Chennai	600098	Tamil Nadu	15c6d0bc-2e93-4ffa-b036-9762b706bc06	51-6,Ragavan Colony 1st Link Street,Ashok Nagar	13.0293291	80.2158934	0101000020E6100000061B8D32D10D544069A44A39040F2A40	51-6,Ragavan Colony 1st Link Street,Ashok Nagar,
4a824684-9968-49dd-bd54-69beee2eae69	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	Chennai	600078	Tamil Nadu	227974bd-a434-4ed7-b79f-7cda1f748f49	28-A,1st Street,West Jafferkhanpet	13.0293415	80.2159026	0101000020E6100000C5872359D10D5440C7D45DD9050F2A40	28-A,1st Street,West Jafferkhanpet
dbac7d61-296a-4777-b3a7-27df8f1326be	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	Chennai	600098	Tamil Nadu	38431b31-fe56-479e-9d6e-885022407b3a	51-6,Ragavan Colony 1st Link Street,Ashok Nagar	13.0293436	80.2159023	0101000020E61000006568E157D10D54409EB1D41F060F2A40	51-6,Ragavan Colony 1st Link Street,Ashok Nagar
184c9b6d-5d8a-45c1-9cf9-2519f962d593	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	Chennai	600098	Tamil Nadu	1d7f4437-1057-4d2a-b010-a8418d8b45ee	elite,Ragavan Colony 1st Link Street,,Ashok Nagar	13.0293373	80.2159017	0101000020E6100000A7295D55D10D54401B1B704C050F2A40	elite,Ragavan Colony 1st Link Street,,Ashok Nagar
9084bbe8-267e-4c3d-b578-cbff1c3f3049	4c0f1f74-7694-44dc-a1a9-4cce7e1fc580	Chennai	600098	Tamil Nadu	c4117309-ba96-4c78-839f-f5d168943808	51-6,Ragavan Colony 1st Link Street,Ashok Nagar	13.0293224	80.2158652	0101000020E61000000C9645BCD00D544099147A58030F2A40	
63729562-a41a-4b2c-97dc-06f83ed0ec60	1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	Chennai	600099	TamilNadu	b7389fb3-bc1a-445b-b655-54c96981c513	1st Street	80.201	13.121699	0101000020E61000006CE9D1544F3E2A40BE9F1A2FDD0C5440	abc location
aefbdfc0-65c1-4f60-877c-930bf6762154	aea21e8e-fc36-4964-b779-d47c1af727e5	Chennai	600099	TamilNadu	22856efa-5883-4a86-83d1-26ee4a95757b	1st Street	80.201	13.121699	0101000020E61000006CE9D1544F3E2A40BE9F1A2FDD0C5440	abc location
1f2fccb8-6bd6-41eb-8590-1fde3ba3ddc3	aea21e8e-fc36-4964-b779-d47c1af727e5	Chennai	600099	TamilNadu	7cb15c06-2548-4f7d-a257-f6c5bf4e86b3	1st Street	80.201	13.121699	0101000020E61000006CE9D1544F3E2A40BE9F1A2FDD0C5440	abc location
333a1991-f2ea-4f0f-aea3-7a0db8ab5a6a	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	Chennai	600098	Tamil Nadu	44e556e5-cd97-4a04-9f22-96968c318344	51-6,Ragavan Colony 1st Link Street,Ashok Nagar	13.0293329	80.2158754	0101000020E6100000B3C00DE7D00D5440C864CCB8040F2A40	51-6,Ragavan Colony 1st Link Street,Ashok Nagar
ecde4f50-b278-4fb0-b474-5bd415cf2fcd	8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	Chennai	600099	TamilNadu	8dd2c580-91f6-49a9-9cb9-f2d5a96a96cb	1st Street	80.201	13.121699	0101000020E61000006CE9D1544F3E2A40BE9F1A2FDD0C5440	
\.


--
-- Data for Name: user_ratings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_ratings (user_ratings_id, nurse_id, patient_id, user_id, appointment_id, appointment_session_id, user_rating, user_rating_comments, created_at, updated_at) FROM stdin;
1	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	4294ebd4-3498-4a23-bd89-87c126483cf9	1	1	4	Nurse is very helpful	2023-01-13 06:51:25.68106	2023-01-13 06:51:25.68106
2	ee58f1f1-eb8b-4567-a15d-ddfc670252d6	d29e837b-44d2-4c59-9100-c6471a1ba5e6	aea21e8e-fc36-4964-b779-d47c1af727e5	2	2	4	Nurse is very helpful	2023-01-13 06:52:23.983079	2023-01-13 06:52:23.983079
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, user_age, user_dob, user_email, user_firstname, user_gender, user_lastname, user_latitude, user_location, user_longitude, user_name, user_password, user_phone, created_at, updated_at, user_geolocation, user_avg_rating, user_whatsapp_phone) FROM stdin;
4294ebd4-3498-4a23-bd89-87c126483cf9	55	1977-01-01	xyz@elite.com	\N	MALE	\N	\N	\N	\N	XYZ	\N	918144528548	2022-08-31 13:20:59.248	2022-08-31 13:20:59.248	0101000020E6100000F9765C9E180D5440590927B38B3F2A40	4.5	918144528548
0bbd4dd4-743f-4510-ac98-de795bcc0214	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	9991652205	2023-01-03 05:14:00.313146	\N	\N	\N	\N
5f5e7032-6d05-42e5-b547-75edb8da527a	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	6392391838	2022-12-29 08:31:58.313866	\N	\N	\N	\N
21a0de5a-2e29-45ab-9a10-ce1cd37a12fb	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0838822863	2022-12-29 12:15:43.296051	\N	\N	\N	\N
4c0f1f74-7694-44dc-a1a9-4cce7e1fc580	0	2023-06-01	email@gmail.com	\N	Male	\N	\N	\N	\N	Elite	\N	9916522059	2023-01-03 05:07:54.571171	\N	\N	\N	9916522059
1f67c69d-1ac4-48a1-9c55-ce76ccb953d8	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	9943960728	2023-01-06 07:04:38.216437	\N	\N	\N	\N
aea21e8e-fc36-4964-b779-d47c1af727e5	21	2002-01-01	abc@elite.com	xxx	MALE	yyy	80.201	abc location	13.121699	xxx	$2a$10$0Q1mjfMyj7sIfFM9yQK/mOhXFncxaMaGIFlJ7mIyecffZ0lAxQj1W	919566202701	2022-12-15 13:41:49.196337	\N	0101000020E61000006CE9D1544F3E2A40BE9F1A2FDD0C5440	\N	919566202701
8495bc2d-4c52-43c5-9ca4-f9b8b09d5047	21	2002-01-01	abc@elite.com	undefined	Male	undefined	13.0293347	51-6,Ragavan Colony 1st Link Street,Ashok Nagar	80.2159017	xxx	$2a$10$PoBfT7JsF.vGUzESZ/nTbudnAW0rTwMyCw3ImLzEJ5PyMnjhZq92K	9916522058	2022-12-28 11:06:33.464433	\N	0101000020E6100000A7295D55D10D5440A44632F5040F2A40	\N	9916522058
\.


--
-- Name: appointment_request_status_appointment_request_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_request_status_appointment_request_status_id_seq', 58, true);


--
-- Name: appointment_requests_appointment_request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_requests_appointment_request_id_seq', 84, true);


--
-- Name: appointment_sessions_appointment_session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_sessions_appointment_session_id_seq', 66, true);


--
-- Name: appointment_slots_nurse_default_slot_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_slots_nurse_default_slot_id_seq', 1, true);


--
-- Name: appointment_slots_nurse_specific_slot_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_slots_nurse_specific_slot_id_seq', 1, true);


--
-- Name: appointments_appointment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointments_appointment_id_seq', 54, true);


--
-- Name: nurse_earnings_nurse_earnings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurse_earnings_nurse_earnings_id_seq', 5, true);


--
-- Name: nurse_education_nurse_education_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurse_education_nurse_education_id_seq', 1, true);


--
-- Name: nurse_fees_nurse_fees_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurse_fees_nurse_fees_id_seq', 23, true);


--
-- Name: nurse_ratings_nurse_ratings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurse_ratings_nurse_ratings_id_seq', 1, true);


--
-- Name: nurse_service_type_values_nurse_service_type_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurse_service_type_values_nurse_service_type_value_id_seq', 8, true);


--
-- Name: nurse_skills_nurse_skill_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurse_skills_nurse_skill_id_seq', 1, true);


--
-- Name: nurse_slots_recurring_slot_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurse_slots_recurring_slot_id_seq', 1, true);


--
-- Name: nurses_service_type_subscript_nurses_service_type_subscript_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nurses_service_type_subscript_nurses_service_type_subscript_seq', 2, true);


--
-- Name: otp_for_appointment_session_otp_for_appointment_session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.otp_for_appointment_session_otp_for_appointment_session_id_seq', 48, true);


--
-- Name: patient_ratings_patient_ratings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patient_ratings_patient_ratings_id_seq', 1, false);


--
-- Name: payments_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_payment_id_seq', 1, false);


--
-- Name: user_ratings_user_ratings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_ratings_user_ratings_id_seq', 2, true);


--
-- Name: appointment_request_status appointment_request_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_request_status
    ADD CONSTRAINT appointment_request_status_pkey PRIMARY KEY (appointment_request_status_id);


--
-- Name: appointment_requests appointment_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_requests
    ADD CONSTRAINT appointment_requests_pkey PRIMARY KEY (appointment_request_id);


--
-- Name: appointment_sessions appointment_sessions_appointment_session_id_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_sessions
    ADD CONSTRAINT appointment_sessions_appointment_session_id_unique_key UNIQUE (appointment_session_id);


--
-- Name: appointment_slots_nurse_default appointment_slots_nurse_default_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_slots_nurse_default
    ADD CONSTRAINT appointment_slots_nurse_default_pkey PRIMARY KEY (slot_id);


--
-- Name: appointment_slots_nurse_specific appointment_slots_nurse_specific_nurse_id_slot_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_slots_nurse_specific
    ADD CONSTRAINT appointment_slots_nurse_specific_nurse_id_slot_date_key UNIQUE (nurse_id, slot_date);


--
-- Name: appointment_slots_nurse_specific appointment_slots_nurse_specific_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_slots_nurse_specific
    ADD CONSTRAINT appointment_slots_nurse_specific_pkey PRIMARY KEY (slot_id);


--
-- Name: appointment_slots appointment_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_slots
    ADD CONSTRAINT appointment_slots_pkey PRIMARY KEY (slot_id);


--
-- Name: appointments appointments_booking_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_booking_id_key UNIQUE (booking_id);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (appointment_id);


--
-- Name: nurse_address nurse_address_nurse_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_address
    ADD CONSTRAINT nurse_address_nurse_id_key UNIQUE (nurse_id);


--
-- Name: nurse_address nurse_address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_address
    ADD CONSTRAINT nurse_address_pkey PRIMARY KEY (nurse_address_id);


--
-- Name: nurse_earnings nurse_earnings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_earnings
    ADD CONSTRAINT nurse_earnings_pkey PRIMARY KEY (nurse_earnings_id);


--
-- Name: nurse_education nurse_education_nurse_education_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_education
    ADD CONSTRAINT nurse_education_nurse_education_name_key UNIQUE (nurse_education_name);


--
-- Name: nurse_education nurse_education_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_education
    ADD CONSTRAINT nurse_education_pkey PRIMARY KEY (nurse_education_id);


--
-- Name: nurse_fees nurse_fees_nurse_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_fees
    ADD CONSTRAINT nurse_fees_nurse_id_key UNIQUE (nurse_id);


--
-- Name: nurse_fees nurse_fees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_fees
    ADD CONSTRAINT nurse_fees_pkey PRIMARY KEY (nurse_fees_id);


--
-- Name: nurse_ratings nurse_ratings_appointment_session_id_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_ratings
    ADD CONSTRAINT nurse_ratings_appointment_session_id_unique_key UNIQUE (appointment_session_id);


--
-- Name: nurse_ratings nurse_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_ratings
    ADD CONSTRAINT nurse_ratings_pkey PRIMARY KEY (nurse_ratings_id);


--
-- Name: nurse_service_type_values nurse_service_type_values_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_service_type_values
    ADD CONSTRAINT nurse_service_type_values_pkey PRIMARY KEY (nurse_service_type_value_id);


--
-- Name: nurse_slots_recurring nurse_slots_recurring_default_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_slots_recurring
    ADD CONSTRAINT nurse_slots_recurring_default_pkey PRIMARY KEY (slot_id);


--
-- Name: nurses nurses_nurse_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurses
    ADD CONSTRAINT nurses_nurse_phone_key UNIQUE (nurse_phone);


--
-- Name: nurses nurses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurses
    ADD CONSTRAINT nurses_pkey PRIMARY KEY (nurse_id);


--
-- Name: nurses_service_type_subscription nurses_service_type_subscription_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurses_service_type_subscription
    ADD CONSTRAINT nurses_service_type_subscription_pkey PRIMARY KEY (nurses_service_type_subscription_id);


--
-- Name: otp_for_appointment_session otp_for_appointment_session_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.otp_for_appointment_session
    ADD CONSTRAINT otp_for_appointment_session_unique_key UNIQUE (appointment_session_id);


--
-- Name: otp_phone otp_phone_phone_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.otp_phone
    ADD CONSTRAINT otp_phone_phone_unique_key UNIQUE (user_phone);


--
-- Name: patient_ratings patient_ratings_appointment_session_id_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_ratings
    ADD CONSTRAINT patient_ratings_appointment_session_id_unique_key UNIQUE (appointment_session_id);


--
-- Name: patient_ratings patient_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_ratings
    ADD CONSTRAINT patient_ratings_pkey PRIMARY KEY (patient_ratings_id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (patient_id);


--
-- Name: patients patients_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_unique_key UNIQUE (user_id, user_relationship_with_patient);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (payment_id);


--
-- Name: payments payments_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_unique_key UNIQUE (booking_id);


--
-- Name: user_address user_address_patient_id_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_address
    ADD CONSTRAINT user_address_patient_id_unique_key UNIQUE (patient_id);


--
-- Name: user_address user_address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_address
    ADD CONSTRAINT user_address_pkey PRIMARY KEY (user_address_id);


--
-- Name: user_ratings user_ratings_appointment_session_id_unique_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_ratings
    ADD CONSTRAINT user_ratings_appointment_session_id_unique_key UNIQUE (appointment_session_id);


--
-- Name: user_ratings user_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_ratings
    ADD CONSTRAINT user_ratings_pkey PRIMARY KEY (user_ratings_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: otp_phone_user_phone_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX otp_phone_user_phone_idx ON public.otp_phone USING btree (user_phone);


--
-- Name: patients_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX patients_user_id_idx ON public.patients USING btree (user_id);


--
-- Name: payments_booking_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX payments_booking_id_idx ON public.payments USING btree (booking_id);


--
-- Name: payments_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX payments_user_id_idx ON public.payments USING btree (user_id);


--
-- Name: user_address_patient_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_address_patient_id_idx ON public.user_address USING btree (patient_id);


--
-- Name: user_address_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_address_user_id_idx ON public.user_address USING btree (user_id);


--
-- Name: appointment_sessions fk_appointment_sessions_appointment_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_sessions
    ADD CONSTRAINT fk_appointment_sessions_appointment_id FOREIGN KEY (appointment_id) REFERENCES public.appointments(appointment_id);


--
-- Name: nurse_earnings fk_nurse_earnings_appointment_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_earnings
    ADD CONSTRAINT fk_nurse_earnings_appointment_id FOREIGN KEY (appointment_id) REFERENCES public.appointments(appointment_id);


--
-- Name: nurse_earnings fk_nurse_earnings_appointment_session_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_earnings
    ADD CONSTRAINT fk_nurse_earnings_appointment_session_id FOREIGN KEY (appointment_session_id) REFERENCES public.appointment_sessions(appointment_session_id);


--
-- Name: nurse_earnings fk_nurse_earnings_booking_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_earnings
    ADD CONSTRAINT fk_nurse_earnings_booking_id FOREIGN KEY (booking_id) REFERENCES public.appointments(booking_id);


--
-- Name: nurse_earnings fk_nurse_earnings_nurse_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_earnings
    ADD CONSTRAINT fk_nurse_earnings_nurse_id FOREIGN KEY (nurse_id) REFERENCES public.nurses(nurse_id);


--
-- Name: nurse_ratings fk_nurse_ratings_appointment_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_ratings
    ADD CONSTRAINT fk_nurse_ratings_appointment_id FOREIGN KEY (appointment_id) REFERENCES public.appointments(appointment_id);


--
-- Name: nurse_ratings fk_nurse_ratings_appointment_session_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse_ratings
    ADD CONSTRAINT fk_nurse_ratings_appointment_session_id FOREIGN KEY (appointment_session_id) REFERENCES public.appointment_sessions(appointment_session_id);


--
-- Name: nurses_service_type_subscription fk_nurses_service_type_subscription_nurse_service_type_value_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurses_service_type_subscription
    ADD CONSTRAINT fk_nurses_service_type_subscription_nurse_service_type_value_id FOREIGN KEY (nurse_service_type_value_id) REFERENCES public.nurse_service_type_values(nurse_service_type_value_id);


--
-- Name: patient_ratings fk_patient_ratings_appointment_session_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_ratings
    ADD CONSTRAINT fk_patient_ratings_appointment_session_id FOREIGN KEY (appointment_session_id) REFERENCES public.appointment_sessions(appointment_session_id);


--
-- Name: user_ratings fk_user_ratings_appointment_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_ratings
    ADD CONSTRAINT fk_user_ratings_appointment_id FOREIGN KEY (appointment_id) REFERENCES public.appointments(appointment_id);


--
-- Name: user_ratings fk_user_ratings_appointment_session_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_ratings
    ADD CONSTRAINT fk_user_ratings_appointment_session_id FOREIGN KEY (appointment_session_id) REFERENCES public.appointment_sessions(appointment_session_id);


--
-- PostgreSQL database dump complete
--

