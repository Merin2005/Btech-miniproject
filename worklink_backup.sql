--
-- PostgreSQL database dump
--

\restrict pOkdK8u7rDHREqcgsEYYbq383Q39ibuBE2mHa74OIvAgqqAeeYIwevjHl1nGvXM

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

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
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: set_arrival_deadline(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_arrival_deadline() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF NEW.urgency = 'urgent' THEN
          NEW.arrival_deadline := NEW.created_at + INTERVAL '30 minutes';
        ELSIF NEW.urgency = 'scheduled' AND NEW.scheduled_time IS NOT NULL THEN
          NEW.arrival_deadline := NEW.scheduled_time + INTERVAL '30 minutes';
        END IF;
        RETURN NEW;
      END;
      $$;


ALTER FUNCTION public.set_arrival_deadline() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_actions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admin_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    admin_id uuid,
    target_user_id uuid,
    action_type character varying(50) NOT NULL,
    reason text,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.admin_actions OWNER TO postgres;

--
-- Name: admin_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admin_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    admin_id uuid,
    user_id uuid,
    sender_id uuid,
    message text NOT NULL,
    sent_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.admin_messages OWNER TO postgres;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.applications (
    id integer NOT NULL,
    job_id uuid NOT NULL,
    worker_id uuid NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.applications OWNER TO postgres;

--
-- Name: applications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.applications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.applications_id_seq OWNER TO postgres;

--
-- Name: applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.applications_id_seq OWNED BY public.applications.id;


--
-- Name: assigned_workers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assigned_workers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    worker_id uuid,
    assigned_at timestamp without time zone DEFAULT now(),
    entry_time timestamp without time zone,
    exit_time timestamp without time zone,
    entry_photo_url text,
    completion_photo_url text,
    latitude double precision,
    longitude double precision,
    location_updated_at timestamp with time zone
);


ALTER TABLE public.assigned_workers OWNER TO postgres;

--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chat_messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    sender_id uuid,
    message text NOT NULL,
    sent_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.chat_messages OWNER TO postgres;

--
-- Name: commitment_bonds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.commitment_bonds (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    worker_id uuid,
    bond_amount numeric(10,2) NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying,
    no_show_probability numeric(5,2) DEFAULT 0.00,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT commitment_bonds_status_check CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('released'::character varying)::text, ('forfeited'::character varying)::text])))
);


ALTER TABLE public.commitment_bonds OWNER TO postgres;

--
-- Name: dispute_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dispute_messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    dispute_id uuid,
    sender_id uuid,
    sender_role character varying(10) NOT NULL,
    message text NOT NULL,
    sent_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.dispute_messages OWNER TO postgres;

--
-- Name: disputes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disputes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid,
    reported_id uuid,
    job_id uuid,
    reason character varying(100) NOT NULL,
    description text,
    status character varying(20) DEFAULT 'open'::character varying,
    resolution text,
    resolved_by uuid,
    resolved_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.disputes OWNER TO postgres;

--
-- Name: emergency_backups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emergency_backups (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    backup_worker_id uuid,
    notified_at timestamp without time zone DEFAULT now(),
    status character varying(20) DEFAULT 'notified'::character varying,
    CONSTRAINT emergency_backups_status_check CHECK (((status)::text = ANY (ARRAY[('notified'::character varying)::text, ('accepted'::character varying)::text, ('declined'::character varying)::text, ('ignored'::character varying)::text])))
);


ALTER TABLE public.emergency_backups OWNER TO postgres;

--
-- Name: job_applications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.job_applications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    worker_id uuid,
    status character varying(20) DEFAULT 'pending'::character varying,
    applied_at timestamp without time zone DEFAULT now(),
    CONSTRAINT job_applications_status_check CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('accepted'::character varying)::text, ('rejected'::character varying)::text])))
);


ALTER TABLE public.job_applications OWNER TO postgres;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid,
    title character varying(150) NOT NULL,
    labor_type character varying(100) NOT NULL,
    description text NOT NULL,
    rate numeric(10,2) NOT NULL,
    location text NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    workers_needed integer DEFAULT 1,
    urgency character varying(15) NOT NULL,
    scheduled_time timestamp without time zone,
    photo_url text,
    status character varying(20) DEFAULT 'open'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    arrival_deadline timestamp with time zone,
    wait_until timestamp with time zone,
    CONSTRAINT jobs_status_check CHECK (((status)::text = ANY (ARRAY[('open'::character varying)::text, ('assigned'::character varying)::text, ('in_progress'::character varying)::text, ('completed'::character varying)::text, ('cancelled'::character varying)::text]))),
    CONSTRAINT jobs_urgency_check CHECK (((urgency)::text = ANY (ARRAY[('urgent'::character varying)::text, ('scheduled'::character varying)::text])))
);


ALTER TABLE public.jobs OWNER TO postgres;

--
-- Name: otps; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.otps (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    worker_id uuid,
    otp_code character varying(6) NOT NULL,
    is_used boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    expires_at timestamp without time zone DEFAULT (now() + '00:10:00'::interval)
);


ALTER TABLE public.otps OWNER TO postgres;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    customer_id uuid,
    worker_id uuid,
    amount numeric(10,2),
    payment_sent boolean DEFAULT false,
    payment_received boolean DEFAULT false,
    sent_at timestamp without time zone,
    received_at timestamp without time zone
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: portfolio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.portfolio (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    worker_id uuid,
    photo_url text NOT NULL,
    job_title character varying(150),
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.portfolio OWNER TO postgres;

--
-- Name: ratings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ratings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    job_id uuid,
    customer_id uuid,
    worker_id uuid,
    score integer NOT NULL,
    review text,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT ratings_score_check CHECK (((score >= 1) AND (score <= 5)))
);


ALTER TABLE public.ratings OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    full_name character varying(100) NOT NULL,
    email character varying(100) NOT NULL,
    phone character varying(15) NOT NULL,
    password_hash text NOT NULL,
    role character varying(10) NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    is_banned boolean DEFAULT false,
    ban_reason text,
    warn_count integer DEFAULT 0,
    is_online boolean DEFAULT false,
    address text,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY (ARRAY[('customer'::character varying)::text, ('worker'::character varying)::text, ('admin'::character varying)::text])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: worker_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.worker_profiles (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    skills text[] NOT NULL,
    is_online boolean DEFAULT false,
    rating numeric(3,2) DEFAULT 0.00,
    total_ratings integer DEFAULT 0,
    latitude numeric(10,7),
    longitude numeric(10,7),
    created_at timestamp without time zone DEFAULT now(),
    bio text,
    hourly_rate numeric(10,2)
);


ALTER TABLE public.worker_profiles OWNER TO postgres;

--
-- Name: applications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications ALTER COLUMN id SET DEFAULT nextval('public.applications_id_seq'::regclass);


--
-- Data for Name: admin_actions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admin_actions (id, admin_id, target_user_id, action_type, reason, created_at) FROM stdin;
0ac28f45-d9eb-433b-8f5a-7c469f02e2b9	f8d63afd-5e92-47df-8546-93982952a2eb	6965a121-ed6b-41fd-b50c-a88fc1c5c826	warn	irresponsible 	2026-03-26 20:32:15.223541
233b575b-55fb-432c-99ee-2bf418692089	f8d63afd-5e92-47df-8546-93982952a2eb	0394eaa6-ce6d-4812-b507-a9f843d4df32	ban	irresponsible	2026-03-26 20:33:42.712723
9804d9cb-3598-4398-bfe6-e6e471996079	f8d63afd-5e92-47df-8546-93982952a2eb	0394eaa6-ce6d-4812-b507-a9f843d4df32	unban	User unbanned by admin	2026-03-26 20:33:56.092289
8a73117d-9319-4970-9a58-0c81a9db6f7c	f8d63afd-5e92-47df-8546-93982952a2eb	\N	resolve_dispute	Will notify worker	2026-03-29 18:50:06.258112
d6ed48e8-5de5-4b3b-bab8-0c8c38698d6a	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	warn	Please make sure to be in contact with worker during the scheduled time	2026-03-29 18:55:58.267957
5d0c71da-9faa-49d3-8bac-2a14e136d9cc	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	ban	Being irresponsible	2026-03-29 18:56:37.309455
700c70ea-b137-4413-ae02-d7dbb1f6911e	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	unban	User unbanned by admin	2026-03-29 18:57:05.425489
7845c303-0ef8-4f9f-bd10-fdb4a1e81fd5	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	warn	irresponsible	2026-03-30 06:20:43.209335
4cb6e604-3ccb-4790-b990-9d7f9b04cbc2	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	ban	irresponsible	2026-03-30 06:20:55.505196
b55e5c55-89d0-45cf-a08e-4ac195b69b29	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	warn	irresponsible	2026-03-30 06:31:36.05918
a8aaa0d3-20e6-4864-8f55-93335eb0b49d	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	ban	irresponsible	2026-03-30 06:31:48.426992
c3456092-c57d-4d36-a503-68bc2f8e3f67	f8d63afd-5e92-47df-8546-93982952a2eb	\N	resolve_dispute	Work is completed	2026-03-30 06:32:26.077102
8c634c5a-4fef-4877-9eb6-ef3b1ff6262d	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	unban	User unbanned by admin	2026-03-30 11:26:09.577501
8e854cac-9783-4eb3-9a8f-6a827edfef49	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	ban	irresponsible	2026-03-30 11:26:23.049622
c2f76458-94fc-47cf-952e-f63ba4d07321	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	unban	User unbanned by admin	2026-03-30 11:26:32.511235
77dfce91-5412-4cc1-9f74-12396a601cc6	f8d63afd-5e92-47df-8546-93982952a2eb	\N	resolve_dispute	resolved	2026-03-30 11:26:49.959202
05b8346b-5433-4624-9af2-96c50c8b94ec	f8d63afd-5e92-47df-8546-93982952a2eb	\N	resolve_dispute	Solved	2026-03-30 11:29:41.421389
2fa98d2d-395a-41c0-829c-d4a358d548bd	f8d63afd-5e92-47df-8546-93982952a2eb	6965a121-ed6b-41fd-b50c-a88fc1c5c826	warn	Lateness	2026-03-30 11:30:20.487799
73da84f9-d69f-4f39-97e5-92f4d2f8d5c0	f8d63afd-5e92-47df-8546-93982952a2eb	6965a121-ed6b-41fd-b50c-a88fc1c5c826	ban	Lateness	2026-03-30 11:30:35.489597
ddf2ca4d-dfc5-4110-8948-ee3f90095ecc	f8d63afd-5e92-47df-8546-93982952a2eb	6965a121-ed6b-41fd-b50c-a88fc1c5c826	unban	User unbanned by admin	2026-03-30 11:31:45.325902
643c151c-6bc1-466c-90d1-4ab895cf5155	f8d63afd-5e92-47df-8546-93982952a2eb	0394eaa6-ce6d-4812-b507-a9f843d4df32	warn	Poor quality work	2026-03-30 16:02:43.271479
fcc3b403-d60e-409a-9b3b-f87645d10c56	f8d63afd-5e92-47df-8546-93982952a2eb	0394eaa6-ce6d-4812-b507-a9f843d4df32	ban	poor work quality	2026-03-30 16:02:52.620099
f38e8a2d-c29f-4b24-b552-e87460dddf61	f8d63afd-5e92-47df-8546-93982952a2eb	0394eaa6-ce6d-4812-b507-a9f843d4df32	unban	User unbanned by admin	2026-03-30 16:02:58.861477
ff0b0b04-dcdf-44c1-9867-e105541f2feb	f8d63afd-5e92-47df-8546-93982952a2eb	\N	resolve_dispute	Will notify working	2026-04-01 10:17:01.654677
003198ba-32e2-427e-86b3-88a51d5da2c5	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	warn	Should try to reach the destination earlier	2026-04-01 10:22:13.193647
80266a1e-7034-493a-8d5e-c48f54eabe19	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	Irresponsible	2026-04-01 10:23:05.297813
70eb61e4-1163-4f45-9a5d-422a46bba26e	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-01 10:23:49.4568
383e4b61-8254-4342-932e-0b9c1b544995	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	Irresponsible	2026-04-01 10:24:32.053297
24fad0de-26b7-4a8b-ba30-a72057cbc924	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-01 10:27:52.86105
1e842837-9b26-4f93-8582-e930ec725248	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	Irresponsible	2026-04-01 10:29:13.188811
ccc23c95-889e-483d-bd4d-4c1576317000	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-01 10:30:00.126368
61263f27-bf45-4c5c-a6e6-b750fc444bc8	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	Irresponsible	2026-04-01 10:31:13.313513
b98ae6c5-c1ab-489c-b247-565f449a8fe5	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-01 10:32:32.741921
0ef0163c-ee51-439d-82cb-b7df5a3c4939	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	warn	notify	2026-04-01 11:00:14.955133
aefbcae7-7c79-415c-8d50-841d2f4cbf68	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	irresponsible	2026-04-01 11:00:36.24705
fefd645b-59a7-4dc2-87bd-5bd917555721	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-01 19:04:39.918465
8f330895-733b-459f-9f93-0585b693c12e	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	irresponsible	2026-04-01 19:05:09.909229
71a5749c-83ff-4c66-8bfa-c7a1553d33ea	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-01 19:05:28.817149
72cb2e21-0efd-43e1-b4ce-12c60d8b6955	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	Irresponsible	2026-04-02 08:04:38.67893
c400e669-329f-4cff-8f75-a265d019f66d	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-02 08:04:47.860798
0d0c370f-4803-42e2-b241-774118939c2e	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	ban	irresponsible	2026-04-02 08:35:02.266255
e3bfe126-5c16-496f-9f84-9b9f5a6eae14	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	ban	Not reachable	2026-04-02 08:35:27.03231
d0966d50-0eee-4a1f-9cf9-3dc0b12aa479	f8d63afd-5e92-47df-8546-93982952a2eb	49bb73ef-c7ca-4966-a27a-a68d29f0b181	unban	User unbanned by admin	2026-04-02 08:35:42.754125
1f013edc-48f5-4334-a886-5e1a95a47295	f8d63afd-5e92-47df-8546-93982952a2eb	a390fd14-073b-41f4-a5cf-6e4b50f47f99	unban	User unbanned by admin	2026-04-02 08:35:46.615733
\.


--
-- Data for Name: admin_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admin_messages (id, admin_id, user_id, sender_id, message, sent_at) FROM stdin;
f4cb79da-65c2-4c2b-9e81-dba60ab60a99	f8d63afd-5e92-47df-8546-93982952a2eb	6965a121-ed6b-41fd-b50c-a88fc1c5c826	f8d63afd-5e92-47df-8546-93982952a2eb	hi	2026-03-31 07:05:33.568255+05:30
320e53e4-27ac-401c-9bb5-bad9acfe9be9	f8d63afd-5e92-47df-8546-93982952a2eb	0c1cd16a-c66f-4585-a998-e291335327a4	f8d63afd-5e92-47df-8546-93982952a2eb	hi	2026-03-31 07:05:41.922293+05:30
\.


--
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.applications (id, job_id, worker_id, status, created_at) FROM stdin;
10	b7c27a08-03ec-4f22-8b10-010ad77fe7fa	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-03-13 11:09:21.943159+05:30
11	60772025-f8aa-485a-a9a6-fd09293d256a	6965a121-ed6b-41fd-b50c-a88fc1c5c826	accepted	2026-03-13 11:37:41.716108+05:30
12	ee62afa9-5030-45ee-a109-45df39a77d9e	6965a121-ed6b-41fd-b50c-a88fc1c5c826	accepted	2026-03-13 11:45:00.16575+05:30
9	763616fb-c96c-4c8b-bc5d-55f78806b048	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-03-13 11:09:00.165241+05:30
13	e9e28b97-2f29-4c60-a1af-0dad602a546b	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-03-13 12:59:38.097757+05:30
14	85f93a22-8de9-416a-8bd8-6e8b62747ee3	6965a121-ed6b-41fd-b50c-a88fc1c5c826	accepted	2026-03-13 13:13:26.544334+05:30
15	e701134f-b71c-43e6-bb6a-2da41f8ec515	6965a121-ed6b-41fd-b50c-a88fc1c5c826	accepted	2026-03-13 13:14:14.826523+05:30
16	c98c8721-d6b3-487e-90f6-831a2ab39e94	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-03-13 14:04:43.231082+05:30
17	46daaa54-0db6-419d-9227-24f7c18eddfa	49bb73ef-c7ca-4966-a27a-a68d29f0b181	accepted	2026-03-20 19:39:01.333209+05:30
18	6b4e8b88-390f-4fb9-9c27-1f1c2f0523aa	0394eaa6-ce6d-4812-b507-a9f843d4df32	accepted	2026-03-20 19:44:17.797593+05:30
19	57962871-3156-4345-a5bc-8b63c2c5482d	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-03-25 15:33:32.675008+05:30
20	5ccaa9ce-850b-4364-9c90-57ec7950afc6	6965a121-ed6b-41fd-b50c-a88fc1c5c826	accepted	2026-03-27 08:56:19.311197+05:30
21	9258687b-9315-422a-a098-a4fa8b14bebe	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-03-27 09:16:18.526494+05:30
23	65a6225e-cbe2-4581-be53-d08dd18517f5	49bb73ef-c7ca-4966-a27a-a68d29f0b181	accepted	2026-03-27 11:42:21.96213+05:30
22	65a6225e-cbe2-4581-be53-d08dd18517f5	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	rejected	2026-03-27 11:30:33.813457+05:30
24	aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	0394eaa6-ce6d-4812-b507-a9f843d4df32	accepted	2026-03-27 13:50:38.520895+05:30
25	aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	49bb73ef-c7ca-4966-a27a-a68d29f0b181	rejected	2026-03-27 13:51:22.751698+05:30
26	a15a5709-036a-4b13-85f4-b4b1b630fbcd	6965a121-ed6b-41fd-b50c-a88fc1c5c826	accepted	2026-03-27 14:10:51.63718+05:30
27	a15a5709-036a-4b13-85f4-b4b1b630fbcd	0394eaa6-ce6d-4812-b507-a9f843d4df32	rejected	2026-03-27 14:10:55.077173+05:30
28	9e7d5898-bace-4261-a789-a88e42b19795	0394eaa6-ce6d-4812-b507-a9f843d4df32	accepted	2026-03-27 19:05:11.98703+05:30
29	9e7d5898-bace-4261-a789-a88e42b19795	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	rejected	2026-03-27 19:05:26.863217+05:30
30	72b97a95-fe5b-45aa-9d0a-d456df96cca8	0394eaa6-ce6d-4812-b507-a9f843d4df32	accepted	2026-03-28 21:23:21.352938+05:30
31	84bf3ad2-6a18-4d99-a8f5-174ed3e6a32b	49bb73ef-c7ca-4966-a27a-a68d29f0b181	accepted	2026-03-28 21:28:41.510927+05:30
33	34640b06-4ead-4863-ac93-64f721fe63e1	49bb73ef-c7ca-4966-a27a-a68d29f0b181	accepted	2026-03-30 12:06:30.191025+05:30
32	34640b06-4ead-4863-ac93-64f721fe63e1	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	rejected	2026-03-30 12:05:03.461525+05:30
34	7312e2ee-b9ca-44a5-a8ff-7ab4e9c02732	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-03-30 12:11:25.523973+05:30
35	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	accepted	2026-04-01 09:23:31.251978+05:30
36	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	6965a121-ed6b-41fd-b50c-a88fc1c5c826	rejected	2026-04-01 09:24:11.800318+05:30
37	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	49bb73ef-c7ca-4966-a27a-a68d29f0b181	rejected	2026-04-01 09:24:16.24411+05:30
38	3cb4d11b-8a62-4386-a565-59ceb02d891a	49bb73ef-c7ca-4966-a27a-a68d29f0b181	accepted	2026-04-01 09:31:16.59239+05:30
39	51628b37-f4c8-4ab9-839c-4612c138f27f	49bb73ef-c7ca-4966-a27a-a68d29f0b181	pending	2026-04-01 10:28:31.963596+05:30
40	34e3760b-9b66-450c-b4f7-f2f5e193b80a	49bb73ef-c7ca-4966-a27a-a68d29f0b181	accepted	2026-04-01 10:31:17.60853+05:30
41	34e3760b-9b66-450c-b4f7-f2f5e193b80a	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	rejected	2026-04-01 10:41:48.611387+05:30
42	51628b37-f4c8-4ab9-839c-4612c138f27f	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	pending	2026-04-02 08:15:15.023943+05:30
43	45c1d931-b9f6-40ac-9647-9c042e32d964	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-04-02 08:16:21.72216+05:30
44	66c6ee57-59a6-4ab9-9f82-bc7584c8d611	0394eaa6-ce6d-4812-b507-a9f843d4df32	accepted	2026-04-02 08:25:13.859136+05:30
45	9592c141-2224-4730-9367-c4b0cd915a41	0394eaa6-ce6d-4812-b507-a9f843d4df32	accepted	2026-04-02 08:27:09.530258+05:30
46	ebba0a0d-64db-4eaa-86ca-2d999a8ae6c6	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	accepted	2026-04-03 17:09:01.02775+05:30
47	fbb56d07-4b6e-4bbf-ad3e-8ab1a047b9db	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	accepted	2026-04-05 21:58:41.133234+05:30
48	23405e45-93b9-4f9e-97f7-7781db7824bc	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	accepted	2026-04-05 22:21:31.993873+05:30
49	3eda7106-4ca1-417a-9f40-52524af1f5db	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	accepted	2026-04-13 11:49:50.722849+05:30
50	3b56b109-2370-4e0f-9e83-2b0529106202	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	accepted	2026-04-13 12:00:53.163373+05:30
51	bc7b578c-8392-4e51-8350-adf848fa16e0	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	accepted	2026-04-13 12:04:02.138816+05:30
52	c06d4be1-77e0-4fc7-a30e-be71a6c4b0c3	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	accepted	2026-04-13 12:41:24.920786+05:30
53	b6b5ee73-13ca-406b-8230-a2cca818e337	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	accepted	2026-07-27 20:56:55.524856+05:30
\.


--
-- Data for Name: assigned_workers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.assigned_workers (id, job_id, worker_id, assigned_at, entry_time, exit_time, entry_photo_url, completion_photo_url, latitude, longitude, location_updated_at) FROM stdin;
c1d7ba97-4794-4f9c-862c-60521b7585d4	9258687b-9315-422a-a098-a4fa8b14bebe	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-28 22:11:43.868292	\N	\N	\N	\N	\N	\N	\N
923e7e4b-de96-48f1-94b2-0686af75bc73	9e7d5898-bace-4261-a789-a88e42b19795	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-27 19:05:45.97979	2026-03-28 22:13:57.478	2026-03-28 22:15:20.446	\N	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774716320440.jpeg	\N	\N	\N
6a9113a2-beb3-450c-9202-f8a838e55e74	72b97a95-fe5b-45aa-9d0a-d456df96cca8	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-28 21:23:38.78763	2026-03-29 07:47:03.438	2026-03-29 07:48:00.22	\N	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774750680213.jpg	\N	\N	\N
a0e5ba0f-4a51-4cbb-b639-3f7fc12f0193	b7c27a08-03ec-4f22-8b10-010ad77fe7fa	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-13 11:32:51.448843	2026-03-13 11:34:06.086314	2026-03-13 11:34:06.085	\N	http://localhost:5000/uploads/completion-aaaeea68-db66-4ebb-b89c-6dcb3297ff11-1773381846075.jpg	\N	\N	\N
25fbac5b-cdad-4afa-8c78-7e07580a20a5	b7c27a08-03ec-4f22-8b10-010ad77fe7fa	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-13 12:02:07.995405	\N	\N	\N	\N	\N	\N	\N
8e8462dd-12df-4946-91e2-84646fdc15ee	ee62afa9-5030-45ee-a109-45df39a77d9e	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-13 12:23:18.871484	\N	\N	\N	\N	\N	\N	\N
a023a02d-ef0c-4426-a943-203b38eceebe	b7c27a08-03ec-4f22-8b10-010ad77fe7fa	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-13 12:25:36.77259	\N	\N	\N	\N	\N	\N	\N
f7f0133c-c72b-4d6a-9fe6-1aca40cc97a1	e9e28b97-2f29-4c60-a1af-0dad602a546b	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-13 12:59:52.68643	\N	\N	\N	\N	\N	\N	\N
5eb4241c-d52c-4428-b7a2-3b1b610a581d	e701134f-b71c-43e6-bb6a-2da41f8ec515	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-13 13:14:37.867002	\N	\N	\N	\N	\N	\N	\N
06204727-98d9-4a8a-a8f9-8b1f00d656c7	763616fb-c96c-4c8b-bc5d-55f78806b048	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-13 14:56:13.165953	\N	\N	\N	\N	\N	\N	\N
b29d061b-37db-4c23-8a13-3c2165122b78	aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-27 13:51:41.474501	2026-03-29 08:00:05.339	2026-03-29 08:03:26.757	\N	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774751606697.jpg	\N	\N	\N
17205018-ab7a-4da6-af1f-93b1024a2f0b	6b4e8b88-390f-4fb9-9c27-1f1c2f0523aa	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-20 19:44:25.197261	2026-03-20 20:12:07.81	2026-03-20 20:15:12.976	\N	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774017912909.jpg	\N	\N	\N
64731518-1fdb-49ab-a207-de37bd6b13c3	a15a5709-036a-4b13-85f4-b4b1b630fbcd	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-27 14:11:20.043364	2026-03-29 13:18:43.41	2026-03-29 13:23:00.868	\N	http://localhost:5000/uploads/completion-6965a121-ed6b-41fd-b50c-a88fc1c5c826-1774770780783.jpg	9.726843508298755	76.72619299216228	2026-03-27 14:31:13.556661+05:30
033e31e5-bfbe-4c42-a565-67c336478449	34640b06-4ead-4863-ac93-64f721fe63e1	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-03-30 12:07:19.359846	2026-03-30 12:09:50.826	\N	\N	\N	\N	\N	\N
ff118f81-210f-4803-9765-5b8a4aa9d084	c98c8721-d6b3-487e-90f6-831a2ab39e94	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-13 14:06:24.460757	\N	\N	\N	\N	9.727012082783485	76.72631301728795	2026-03-25 10:20:42.491386+05:30
a5c692ab-534a-4a70-96d1-9332c8b7b2dc	7312e2ee-b9ca-44a5-a8ff-7ab4e9c02732	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-30 12:11:34.959439	2026-03-30 12:11:51.279	2026-03-30 12:12:40.872	\N	http://localhost:5000/uploads/completion-aaaeea68-db66-4ebb-b89c-6dcb3297ff11-1774852960865.jpg	\N	\N	\N
168880a5-7d15-4a14-9af8-668c507056eb	3cb4d11b-8a62-4386-a565-59ceb02d891a	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-04-01 09:31:25.467885	\N	\N	\N	\N	\N	\N	\N
ec5199a6-8b96-41a5-a340-ebf7e5798811	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	2026-04-01 09:24:33.691325	2026-04-01 09:43:40.735	2026-04-01 09:47:21.712	\N	http://localhost:5000/uploads/completion-a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb-1775017041598.jpg	\N	\N	\N
37506caa-39fc-473c-b119-40de0489f084	5ccaa9ce-850b-4364-9c90-57ec7950afc6	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-27 08:57:45.509707	2026-04-01 09:56:53.25	\N	\N	\N	9.726843508298755	76.72619299216228	2026-03-27 14:31:13.556661+05:30
5868b9b1-c721-48f9-8105-99126be7ac52	57962871-3156-4345-a5bc-8b63c2c5482d	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-25 15:37:14.228225	2026-03-25 15:43:19.092	2026-03-25 15:48:44.407	\N	http://localhost:5000/uploads/completion-aaaeea68-db66-4ebb-b89c-6dcb3297ff11-1774433924399.jpg	\N	\N	\N
94c99b4a-82af-4f0a-9fa9-82cefcd5d610	85f93a22-8de9-416a-8bd8-6e8b62747ee3	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-01 09:57:31.162234	\N	\N	\N	\N	\N	\N	\N
1937a3ae-b0f5-46e1-ab48-be04282a57d4	65a6225e-cbe2-4581-be53-d08dd18517f5	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-03-27 11:42:44.424956	\N	\N	\N	\N	\N	\N	\N
46e031fe-64f0-4f33-b5be-a7d6eee72d7b	46daaa54-0db6-419d-9227-24f7c18eddfa	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-01 09:59:27.792322	\N	\N	\N	\N	\N	\N	\N
0d43e055-560e-445d-8960-482c519fff1d	84bf3ad2-6a18-4d99-a8f5-174ed3e6a32b	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-01 10:02:13.077119	\N	\N	\N	\N	\N	\N	\N
7379c899-6b84-4117-b7eb-54f3a13768e7	34e3760b-9b66-450c-b4f7-f2f5e193b80a	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-04-01 10:42:12.743972	\N	\N	\N	\N	\N	\N	\N
df40332c-27b9-4822-b182-df512ef0daf6	45c1d931-b9f6-40ac-9647-9c042e32d964	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-02 08:16:34.3967	\N	\N	\N	\N	\N	\N	\N
79f62aef-973c-481c-b1d4-db07450bc90c	66c6ee57-59a6-4ab9-9f82-bc7584c8d611	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-04-02 08:25:20.500314	\N	\N	\N	\N	\N	\N	\N
90171b70-0b01-4f7c-bd32-4d8476a91b2a	9592c141-2224-4730-9367-c4b0cd915a41	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-04-02 08:27:16.469756	\N	\N	\N	\N	\N	\N	\N
cadf6b1e-2c6a-449c-a56d-aee71e0f09ca	ebba0a0d-64db-4eaa-86ca-2d999a8ae6c6	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-03 17:09:13.068261	\N	\N	\N	\N	\N	\N	\N
f0a0864f-1be5-4f2a-9b69-15fd3774c18f	fbb56d07-4b6e-4bbf-ad3e-8ab1a047b9db	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	2026-04-05 21:59:34.773462	\N	\N	\N	\N	\N	\N	\N
cbc663ba-f6a9-4f0d-b5ac-6870433587f1	23405e45-93b9-4f9e-97f7-7781db7824bc	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	2026-04-05 22:22:12.425622	2026-04-05 22:23:45.461	2026-04-05 22:25:46.748	\N	http://localhost:5000/uploads/completion-91729c91-80ab-4b0e-9a7d-40d4a5fba7a8-1775408146651.jpeg	\N	\N	\N
58ed1144-3de7-4e2a-a428-28fa889c46f3	3eda7106-4ca1-417a-9f40-52524af1f5db	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	2026-04-13 11:52:42.363627	\N	\N	\N	\N	\N	\N	\N
7c40fcdf-6340-4ce5-8f40-cbeaa07fbe21	3b56b109-2370-4e0f-9e83-2b0529106202	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	2026-04-13 12:01:33.352764	\N	\N	\N	\N	\N	\N	\N
5d0e940c-dc88-45f4-9998-151f3081cbc1	bc7b578c-8392-4e51-8350-adf848fa16e0	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	2026-04-13 12:04:25.871148	2026-04-13 12:06:39.056	2026-04-13 12:08:37.818	\N	http://localhost:5000/uploads/completion-91729c91-80ab-4b0e-9a7d-40d4a5fba7a8-1776062317778.jpeg	\N	\N	\N
c835fedd-2ded-4119-afd8-efeb6b926a16	c06d4be1-77e0-4fc7-a30e-be71a6c4b0c3	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	2026-04-13 12:41:45.499666	\N	\N	\N	\N	\N	\N	\N
87af9e6b-9783-4835-a8ab-465411dbe109	b6b5ee73-13ca-406b-8230-a2cca818e337	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	2026-07-27 20:57:34.052316	2026-07-27 20:58:06.378	2026-07-27 21:01:49.903	\N	http://localhost:5000/uploads/completion-91729c91-80ab-4b0e-9a7d-40d4a5fba7a8-1785166309820.jpg	\N	\N	\N
\.


--
-- Data for Name: chat_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chat_messages (id, job_id, sender_id, message, sent_at) FROM stdin;
96b80e1b-0a31-430f-822a-5ddb21e00aaa	763616fb-c96c-4c8b-bc5d-55f78806b048	49bb73ef-c7ca-4966-a27a-a68d29f0b181	hi	2026-03-13 13:02:00.533959
a5c6784f-3b43-4cde-8f1b-a2872290d624	763616fb-c96c-4c8b-bc5d-55f78806b048	4544b725-5aa4-4cc6-99b0-a4810f40e187	hlo	2026-03-13 13:02:07.745911
1cbc829b-00ab-4c5f-a462-b3b2ecd2f7a0	57962871-3156-4345-a5bc-8b63c2c5482d	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	hi	2026-03-25 15:34:18.922894
034b26fd-efbe-4318-a725-84c18f585f83	5ccaa9ce-850b-4364-9c90-57ec7950afc6	6965a121-ed6b-41fd-b50c-a88fc1c5c826	hi	2026-03-27 08:56:06.197857
54d6b283-5820-45cc-bde4-d841b5873fa5	9258687b-9315-422a-a098-a4fa8b14bebe	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	hi	2026-03-27 09:16:15.221571
1d527bdc-8e05-44ae-b2f9-8c0b78a3a91d	9258687b-9315-422a-a098-a4fa8b14bebe	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	hi	2026-03-27 09:19:30.946721
c921df7e-97d2-4ac0-b64e-42d114739ba3	9258687b-9315-422a-a098-a4fa8b14bebe	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	hi	2026-03-27 09:54:01.314435
6ef167b7-6cf0-4e08-b381-fb121e8fb8fb	34640b06-4ead-4863-ac93-64f721fe63e1	9a1232df-5dc0-462b-9cba-c088e1fdf90e	hi	2026-03-30 12:10:26.344829
8e70bdd0-30e1-4c6d-a940-ab546561aab9	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	86cf02fe-dc4a-4cfb-b016-4ec420d85291	hi	2026-04-01 09:45:45.345607
2d928b7f-d4d1-409c-86d5-9bf8dc51376a	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	hi	2026-04-01 09:45:49.124906
2b16438b-7e28-4cdd-b15b-1b1e26adca9c	3eda7106-4ca1-417a-9f40-52524af1f5db	d37e9244-7d69-4893-b85a-7dc96be55a4a	hello	2026-04-13 11:57:20.520525
77f69afc-0935-47e9-8b6d-92f729d37b31	3eda7106-4ca1-417a-9f40-52524af1f5db	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	hi	2026-04-13 11:57:27.186243
f71c72d6-529d-4bae-9854-a1b0e3158749	3eda7106-4ca1-417a-9f40-52524af1f5db	d37e9244-7d69-4893-b85a-7dc96be55a4a	Is the payment ok?	2026-04-13 11:58:01.125131
340a1675-f780-4586-92ba-3c14a4db66cf	3eda7106-4ca1-417a-9f40-52524af1f5db	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	yes	2026-04-13 11:58:10.108127
\.


--
-- Data for Name: commitment_bonds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.commitment_bonds (id, job_id, worker_id, bond_amount, status, no_show_probability, created_at) FROM stdin;
\.


--
-- Data for Name: dispute_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dispute_messages (id, dispute_id, sender_id, sender_role, message, sent_at) FROM stdin;
b07adf52-8b63-4aa7-831c-d59efc0f2340	2a3f5e41-6f1e-4921-a4b1-32b87dbab2b1	a390fd14-073b-41f4-a5cf-6e4b50f47f99	customer	hi	2026-04-01 07:13:55.363246
4f2da2ac-085d-4339-9942-41303a93bcc4	fa095b0a-deb0-4a08-a924-66149a174ad5	f8d63afd-5e92-47df-8546-93982952a2eb	admin	hi	2026-04-01 10:07:12.719223
1e965639-b0d4-4cf7-90b1-ae206add0ca3	5658e411-4acc-4c68-9490-31c95ff61da9	f8d63afd-5e92-47df-8546-93982952a2eb	admin	hiii	2026-04-01 10:17:21.870664
d1881bdb-ccd0-4020-ac2f-42639069e5b5	5658e411-4acc-4c68-9490-31c95ff61da9	49bb73ef-c7ca-4966-a27a-a68d29f0b181	worker	hlo	2026-04-01 10:17:32.161691
077f110e-6749-4cfb-95ae-564ff6e08399	5658e411-4acc-4c68-9490-31c95ff61da9	86cf02fe-dc4a-4cfb-b016-4ec420d85291	customer	hlo	2026-04-01 10:17:45.682168
31eab46a-6c61-4a98-bbe1-bc2e4f39a0c6	5658e411-4acc-4c68-9490-31c95ff61da9	f8d63afd-5e92-47df-8546-93982952a2eb	admin	Why didn't Suresh reach the destination?	2026-04-01 10:19:41.234784
009c3aef-0af1-4558-b304-8179ce21b8d6	2a3f5e41-6f1e-4921-a4b1-32b87dbab2b1	f8d63afd-5e92-47df-8546-93982952a2eb	admin	what happened	2026-04-04 08:00:11.0514
\.


--
-- Data for Name: disputes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.disputes (id, reporter_id, reported_id, job_id, reason, description, status, resolution, resolved_by, resolved_at, created_at) FROM stdin;
da2a4bf6-91d8-4d6e-aed4-dd8888af54e0	a390fd14-073b-41f4-a5cf-6e4b50f47f99	6965a121-ed6b-41fd-b50c-a88fc1c5c826	9258687b-9315-422a-a098-a4fa8b14bebe	Worker is irresponsible	Worker had not reached within given time	resolved	Will notify worker	f8d63afd-5e92-47df-8546-93982952a2eb	2026-03-29 18:50:06.253039	2026-03-29 18:48:52.337949
cf503171-1072-498d-8082-3bc48e45ecb2	6965a121-ed6b-41fd-b50c-a88fc1c5c826	a390fd14-073b-41f4-a5cf-6e4b50f47f99	9258687b-9315-422a-a098-a4fa8b14bebe	irresponsive	customer is irresponsive	resolved	resolved	f8d63afd-5e92-47df-8546-93982952a2eb	2026-03-30 11:26:49.957927	2026-03-29 18:54:56.427425
224f5f74-c824-4131-8061-75c5a9cc50ff	a390fd14-073b-41f4-a5cf-6e4b50f47f99	6965a121-ed6b-41fd-b50c-a88fc1c5c826	5ccaa9ce-850b-4364-9c90-57ec7950afc6	Lateness	Worker is late	open	\N	\N	\N	2026-03-30 11:28:06.522389
fa095b0a-deb0-4a08-a924-66149a174ad5	6965a121-ed6b-41fd-b50c-a88fc1c5c826	a390fd14-073b-41f4-a5cf-6e4b50f47f99	85f93a22-8de9-416a-8bd8-6e8b62747ee3	customer not reachable	Customer is not reachable	open	\N	f8d63afd-5e92-47df-8546-93982952a2eb	2026-03-30 11:29:41.417938	2026-03-30 06:34:14.589035
2a3f5e41-6f1e-4921-a4b1-32b87dbab2b1	a390fd14-073b-41f4-a5cf-6e4b50f47f99	0394eaa6-ce6d-4812-b507-a9f843d4df32	9e7d5898-bace-4261-a789-a88e42b19795	Poor quality work	Poor quality work	open	\N	\N	\N	2026-03-30 12:16:00.797115
5658e411-4acc-4c68-9490-31c95ff61da9	86cf02fe-dc4a-4cfb-b016-4ec420d85291	49bb73ef-c7ca-4966-a27a-a68d29f0b181	3cb4d11b-8a62-4386-a565-59ceb02d891a	Worker did not arrive	Worker did not arrive	open	\N	f8d63afd-5e92-47df-8546-93982952a2eb	2026-04-01 10:17:01.647989	2026-04-01 10:14:36.851558
\.


--
-- Data for Name: emergency_backups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.emergency_backups (id, job_id, backup_worker_id, notified_at, status) FROM stdin;
e4b61d04-917c-4370-ace5-8ac0f2dccf5c	60772025-f8aa-485a-a9a6-fd09293d256a	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-13 12:28:47.706379	notified
85c66c82-83ee-4a75-8fc1-c1a82c8e91fb	763616fb-c96c-4c8b-bc5d-55f78806b048	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-13 12:55:34.277887	notified
048be8cc-e4c2-43de-ae49-676e54fb02e0	763616fb-c96c-4c8b-bc5d-55f78806b048	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-03-13 12:55:34.352692	notified
254e299c-ae8a-4a79-ae9e-f186ad2958d0	763616fb-c96c-4c8b-bc5d-55f78806b048	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-13 12:55:34.422465	notified
35448805-091d-4b25-9f40-55a28b5ba42d	e701134f-b71c-43e6-bb6a-2da41f8ec515	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-13 13:20:35.445012	notified
4c15be7d-1813-4a66-9298-e319d9c36be5	e9e28b97-2f29-4c60-a1af-0dad602a546b	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-13 14:44:06.873186	notified
f89dd562-f2fc-4be9-9602-b85fc57289fe	e9e28b97-2f29-4c60-a1af-0dad602a546b	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-03-13 14:44:06.959031	notified
49080cd4-10b7-431e-adbb-a43605112b8a	e9e28b97-2f29-4c60-a1af-0dad602a546b	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-13 14:44:07.044083	notified
699f4838-55b9-43bd-b0c5-069fe6c5ca8d	85f93a22-8de9-416a-8bd8-6e8b62747ee3	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-20 19:38:09.319402	notified
515cf3a9-c3de-4ea2-9bda-a4ded54c01d0	85f93a22-8de9-416a-8bd8-6e8b62747ee3	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-20 19:38:09.26918	notified
18fa7c1a-7106-45ad-9cc5-af4317fa540d	46daaa54-0db6-419d-9227-24f7c18eddfa	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-20 19:40:25.221285	notified
3d2ac7e0-996d-4d3d-b305-7487ba955acb	ee62afa9-5030-45ee-a109-45df39a77d9e	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-20 19:41:50.263921	notified
8fb90d01-b67f-4756-9a91-21f731ffc7ce	c98c8721-d6b3-487e-90f6-831a2ab39e94	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-25 10:09:14.011635	notified
10ad673d-6b10-4a66-8a15-2fda64adb138	c98c8721-d6b3-487e-90f6-831a2ab39e94	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-25 10:09:13.952779	notified
73fa338e-c394-422c-87b9-16d07091566c	c98c8721-d6b3-487e-90f6-831a2ab39e94	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-03-25 10:09:14.10344	notified
f957c8b2-f2ac-4669-9976-a2b998303096	c98c8721-d6b3-487e-90f6-831a2ab39e94	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-03-25 10:09:14.114345	notified
afcb607b-2ace-41d4-9146-ed10403e2bb2	c98c8721-d6b3-487e-90f6-831a2ab39e94	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-25 10:09:14.205119	notified
06e0bf53-97dd-4463-aae6-73524815fd0f	5ccaa9ce-850b-4364-9c90-57ec7950afc6	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-27 09:08:39.619986	notified
36a0acc7-6f76-41da-b2e9-bfc47079ef45	9258687b-9315-422a-a098-a4fa8b14bebe	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-03-27 11:27:35.586563	notified
1624ba9b-65f2-4eee-86be-8ddc07ab8225	9258687b-9315-422a-a098-a4fa8b14bebe	49bb73ef-c7ca-4966-a27a-a68d29f0b181	2026-03-27 11:27:35.68399	notified
7d3d477e-8018-478c-9599-8db75a5944ea	9258687b-9315-422a-a098-a4fa8b14bebe	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-27 11:27:35.772013	notified
dfad8afc-d71d-4984-a8c8-081c8bbde2cc	9258687b-9315-422a-a098-a4fa8b14bebe	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-03-27 11:27:35.78325	notified
566f97ea-806a-41db-b1af-9e5c32928912	65a6225e-cbe2-4581-be53-d08dd18517f5	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-27 13:45:44.512731	notified
62a84271-4430-43fd-98dc-44e218a0b172	a15a5709-036a-4b13-85f4-b4b1b630fbcd	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-27 15:19:51.842097	notified
77663634-138b-4471-a430-fbfbd7bcdc2b	9e7d5898-bace-4261-a789-a88e42b19795	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-28 21:21:27.04889	notified
947c2888-145b-49c1-8e18-4c7154de9cac	9e7d5898-bace-4261-a789-a88e42b19795	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-28 21:21:27.101602	notified
a67dbb0f-9ea2-41f2-bd59-aebafefb8d0b	aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-28 21:21:57.746585	notified
4548fa97-b1ca-4ef5-bd78-e1138af5141a	72b97a95-fe5b-45aa-9d0a-d456df96cca8	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-28 22:05:00.516887	notified
4f3fc626-cf11-4caf-84ff-683b17bc2674	72b97a95-fe5b-45aa-9d0a-d456df96cca8	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-28 22:05:00.523067	notified
2ace0d0a-b1fb-4fca-82fc-e025bdd19508	84bf3ad2-6a18-4d99-a8f5-174ed3e6a32b	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-03-30 06:36:20.215062	notified
7b1dcc83-cbf9-4e15-aadc-6adc96dc7030	3cb4d11b-8a62-4386-a565-59ceb02d891a	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-01 10:13:42.029149	notified
ffa5b826-6ea5-4664-84e5-645e3db62553	3cb4d11b-8a62-4386-a565-59ceb02d891a	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-01 10:13:42.041467	notified
a0a41270-8be0-4cd9-bb0b-3104758175b3	9592c141-2224-4730-9367-c4b0cd915a41	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-02 12:45:19.601656	notified
66074955-90e7-4a4f-9315-d1c888a75fe5	9592c141-2224-4730-9367-c4b0cd915a41	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-02 12:45:19.602565	notified
75c66f3a-51ac-4f87-9138-80649f9c0fc6	45c1d931-b9f6-40ac-9647-9c042e32d964	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	2026-04-03 08:03:48.453411	notified
c0751dc1-0f2f-44fd-adc1-ae58d93d878b	45c1d931-b9f6-40ac-9647-9c042e32d964	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	2026-04-03 08:03:48.521367	notified
9ca9876f-665b-4c65-8705-ea3334683b41	45c1d931-b9f6-40ac-9647-9c042e32d964	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-04-03 08:03:48.5959	notified
77bb1d27-2a37-45df-8d40-5639574b179e	45c1d931-b9f6-40ac-9647-9c042e32d964	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-04-03 08:03:48.603607	notified
6d7870b8-c2b4-4911-b7ea-f5f720284c7f	45c1d931-b9f6-40ac-9647-9c042e32d964	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-04-03 08:03:48.687613	notified
6b22af94-ae3e-4112-b5fc-7ac424c48eb5	ebba0a0d-64db-4eaa-86ca-2d999a8ae6c6	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	2026-04-03 22:08:38.47843	notified
8b5944ef-5f21-4eac-ac98-4b60649bce79	ebba0a0d-64db-4eaa-86ca-2d999a8ae6c6	0394eaa6-ce6d-4812-b507-a9f843d4df32	2026-04-03 22:08:38.537541	notified
6f1763ad-e9e8-418f-b430-bfe77c1cc53e	ebba0a0d-64db-4eaa-86ca-2d999a8ae6c6	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2026-04-03 22:08:38.606803	notified
66c20807-75ee-4ab7-a069-37c1dca36ffe	66c6ee57-59a6-4ab9-9f82-bc7584c8d611	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-05 14:17:10.133345	notified
f9cf67f6-5c46-41b7-8c6f-dd7c9080d1e5	66c6ee57-59a6-4ab9-9f82-bc7584c8d611	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-05 14:17:10.133082	notified
e11e9e60-f14c-47f2-8643-7b6130628259	34e3760b-9b66-450c-b4f7-f2f5e193b80a	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-05 14:21:35.938274	notified
9546a9c5-5fe2-4f9b-8dee-f96bfcb59bb4	fbb56d07-4b6e-4bbf-ad3e-8ab1a047b9db	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-06 12:52:49.562416	notified
242d2c48-fa91-498d-a849-7b6619182ae5	3b56b109-2370-4e0f-9e83-2b0529106202	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-13 12:01:34.994587	notified
ddc8cab7-538e-42ab-ad2f-a6d1e92196ec	c06d4be1-77e0-4fc7-a30e-be71a6c4b0c3	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2026-04-13 12:45:13.168481	notified
\.


--
-- Data for Name: job_applications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.job_applications (id, job_id, worker_id, status, applied_at) FROM stdin;
\.


--
-- Data for Name: jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.jobs (id, customer_id, title, labor_type, description, rate, location, latitude, longitude, workers_needed, urgency, scheduled_time, photo_url, status, created_at, arrival_deadline, wait_until) FROM stdin;
e9e28b97-2f29-4c60-a1af-0dad602a546b	4544b725-5aa4-4cc6-99b0-a4810f40e187	Gardening	Landscaping	We need a gardener who can clean my yard.	2000.00	Ernakulam	\N	\N	1	scheduled	2026-03-13 13:01:00	\N	cancelled	2026-03-13 12:59:12.278508	2026-03-13 13:31:00+05:30	2026-03-20 19:49:59.666+05:30
ee62afa9-5030-45ee-a109-45df39a77d9e	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Install Ceiling Fan	electrical	New ceiling fan installation in bedroom	900.00	Thrissur	\N	\N	1	scheduled	2026-03-14 14:00:00	\N	cancelled	2026-03-13 08:59:29.666122	2026-03-14 14:30:00+05:30	\N
66c6ee57-59a6-4ab9-9f82-bc7584c8d611	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Plumbing	Plumbing	fix pipe	1000.00	Kottayam	\N	\N	1	scheduled	2026-04-02 08:28:00	\N	assigned	2026-04-02 08:24:44.730356	2026-04-02 08:58:00+05:30	\N
c98c8721-d6b3-487e-90f6-831a2ab39e94	0c1cd16a-c66f-4585-a998-e291335327a4	House Deep Clean	cleaning	 cleaning, 3 rooms	2500.00	Kochi	\N	\N	1	scheduled	2026-03-14 11:00:00	\N	cancelled	2026-03-13 09:03:36.555777	2026-03-14 11:30:00+05:30	\N
85f93a22-8de9-416a-8bd8-6e8b62747ee3	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Paint Living Room	painting	Full living room painting, 3 walls, light color preferred	2000.00	Kottayam	\N	\N	1	scheduled	2026-03-14 10:00:00	\N	assigned	2026-03-13 08:52:01.607174	2026-03-14 10:30:00+05:30	\N
3cb4d11b-8a62-4386-a565-59ceb02d891a	86cf02fe-dc4a-4cfb-b016-4ec420d85291	Driving	Driving	I want to reach airport	1000.00	Ernakulam	\N	\N	1	scheduled	2026-04-01 09:32:00	\N	assigned	2026-04-01 09:30:47.699391	2026-04-01 10:02:00+05:30	\N
46daaa54-0db6-419d-9227-24f7c18eddfa	4544b725-5aa4-4cc6-99b0-a4810f40e187	Deep Clean House	cleaning	Full house deep cleaning before family visit	1500.00	Ernakulam	\N	\N	1	scheduled	2026-03-14 10:00:00	\N	assigned	2026-03-13 08:55:44.637444	2026-03-14 10:30:00+05:30	\N
45c1d931-b9f6-40ac-9647-9c042e32d964	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Electrical	Electrical	Maintenance	1000.00	Ernakulam	\N	\N	1	scheduled	2026-04-02 08:16:00	\N	assigned	2026-04-02 08:15:02.496358	2026-04-02 08:46:00+05:30	\N
9592c141-2224-4730-9367-c4b0cd915a41	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Driving	Driving	Needs to reach at airport	1000.00	Ernakulam	\N	\N	1	scheduled	2026-04-02 09:00:00	\N	assigned	2026-04-02 08:26:47.864081	2026-04-02 09:30:00+05:30	\N
e9a24f34-5f54-4f91-911a-fb682512ec70	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Driving	Driving	I need to reach airport	200.00	Kottayam	\N	\N	1	scheduled	2026-04-03 03:00:00	\N	open	2026-04-03 22:07:18.547851	2026-04-03 03:30:00+05:30	\N
9d57ef93-13ac-4397-86d2-4a58ef988e6f	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Moving	Moving	Moving of goods	500.00	Ernakulam	\N	\N	1	scheduled	2026-04-05 18:15:00	\N	open	2026-04-05 18:25:25.083022	2026-04-05 18:45:00+05:30	\N
ebba0a0d-64db-4eaa-86ca-2d999a8ae6c6	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Driving	Driving	Needs to reach at airport	500.00	Ernakulam	\N	\N	1	urgent	\N	\N	assigned	2026-04-03 08:10:32.655614	2026-04-03 08:40:32.655614+05:30	\N
9e7d5898-bace-4261-a789-a88e42b19795	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Wiring	Electrical	Maintenance works	1000.00	Kottayam	\N	\N	1	urgent	\N	\N	completed	2026-03-27 19:04:28.050343	2026-03-27 19:34:28.050343+05:30	\N
aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	0c1cd16a-c66f-4585-a998-e291335327a4	Fix a leaking pipe	Plumbing	Fix a leaking pipe	1500.00	Kottayam	\N	\N	1	urgent	\N	\N	completed	2026-03-27 13:49:59.176367	2026-03-27 14:19:59.176367+05:30	\N
34640b06-4ead-4863-ac93-64f721fe63e1	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Delivery	Delivery	Grocery items	500.00	Ernakulam	\N	\N	1	urgent	\N	\N	in_progress	2026-03-30 12:01:18.767151	2026-03-30 12:31:18.767151+05:30	\N
b7c27a08-03ec-4f22-8b10-010ad77fe7fa	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Fix Kitchen Sink	plumbing	Kitchen sink is leaking badly, needs immediate repair	800.00	Kottayam	\N	\N	1	urgent	\N	http://localhost:5000/uploads/job-a390fd14-073b-41f4-a5cf-6e4b50f47f99-1773371997527.jpg	completed	2026-03-13 08:49:57.583846	2026-03-13 09:19:57.583846+05:30	\N
5ccaa9ce-850b-4364-9c90-57ec7950afc6	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Driving	Driving	Need a driver who owns a  safe, and reliable vehicle for shopping.	1000.00	Kottayam	\N	\N	1	urgent	\N	\N	in_progress	2026-03-25 20:53:15.52496	2026-03-25 21:23:15.52496+05:30	\N
763616fb-c96c-4c8b-bc5d-55f78806b048	4544b725-5aa4-4cc6-99b0-a4810f40e187	Electrical Wiring Fix	electrical	Short circuit in bedroom, needs urgent fix	1200.00	Ernakulam	\N	\N	1	urgent	\N	\N	cancelled	2026-03-13 08:53:46.460298	2026-03-13 09:23:46.460298+05:30	\N
84bf3ad2-6a18-4d99-a8f5-174ed3e6a32b	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Fix leaking pipe	Plumbing	Fix leaking pipe	1500.00	palai	\N	\N	1	urgent	\N	\N	assigned	2026-03-28 21:28:24.195598	2026-03-28 21:58:24.195598+05:30	\N
60772025-f8aa-485a-a9a6-fd09293d256a	0c1cd16a-c66f-4585-a998-e291335327a4	Bathroom Tile Fix	plumbing	Bathroom tiles cracked, water seeping through	1000.00	 Kochi	\N	\N	1	urgent	\N	http://localhost:5000/uploads/job-0c1cd16a-c66f-4585-a998-e291335327a4-1773372724435.jpg	cancelled	2026-03-13 09:02:04.544133	2026-03-13 09:32:04.544133+05:30	\N
65a6225e-cbe2-4581-be53-d08dd18517f5	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Gardening	Gardening	clean my yard	500.00	palai	\N	\N	1	urgent	\N	\N	cancelled	2026-03-27 11:30:10.47515	2026-03-27 12:00:10.47515+05:30	\N
51628b37-f4c8-4ab9-839c-4612c138f27f	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Plumbing	Plumbing	Need a plumber to fix pipe	1000.00	Ernakulam	\N	\N	1	urgent	\N	\N	open	2026-04-01 10:26:45.363229	2026-04-01 10:56:45.363229+05:30	\N
34e3760b-9b66-450c-b4f7-f2f5e193b80a	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Electrical	Electrical	Maintenance	1000.00	Ernakulam	\N	\N	1	urgent	\N	\N	assigned	2026-04-01 10:30:36.95428	2026-04-01 11:00:36.95428+05:30	\N
6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	86cf02fe-dc4a-4cfb-b016-4ec420d85291	Driving	Driving	I want to reach airport at 3 am 	1000.00	Ernakulam	\N	\N	2	urgent	\N	\N	completed	2026-04-01 09:21:07.734553	2026-04-01 09:51:07.734553+05:30	\N
6b4e8b88-390f-4fb9-9c27-1f1c2f0523aa	0c1cd16a-c66f-4585-a998-e291335327a4	Shopping	Shopping	Grocery Shopping 	500.00	palai	\N	\N	1	urgent	\N	\N	completed	2026-03-20 19:43:54.742698	2026-03-20 20:13:54.742698+05:30	\N
e701134f-b71c-43e6-bb6a-2da41f8ec515	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Repair Wooden Door	carpentry	Front door hinge broken, needs immediate fix	600.00	Thrissur	\N	\N	1	urgent	\N	http://localhost:5000/uploads/job-9a1232df-5dc0-462b-9cba-c088e1fdf90e-1773372481250.avif	cancelled	2026-03-13 08:58:01.303199	2026-03-13 09:28:01.303199+05:30	2026-03-25 13:49:45.348+05:30
57962871-3156-4345-a5bc-8b63c2c5482d	0c1cd16a-c66f-4585-a998-e291335327a4	Moving	Manual labour	I need help shifting goods	500.00	palai	\N	\N	1	urgent	\N	\N	completed	2026-03-13 14:13:04.613809	2026-03-13 14:43:04.613809+05:30	\N
72b97a95-fe5b-45aa-9d0a-d456df96cca8	0c1cd16a-c66f-4585-a998-e291335327a4	Delivery	Delivery	Fetch and deliver grocery from market	500.00	Kottayam	\N	\N	1	urgent	\N	\N	completed	2026-03-28 21:22:57.99256	2026-03-28 21:52:57.99256+05:30	\N
a15a5709-036a-4b13-85f4-b4b1b630fbcd	4544b725-5aa4-4cc6-99b0-a4810f40e187	Cleaning	Cleaning	Cleaning abandoned house 	2000.00	Kottayam	\N	\N	1	urgent	\N	\N	completed	2026-03-27 14:10:15.585503	2026-03-27 14:40:15.585503+05:30	\N
9258687b-9315-422a-a098-a4fa8b14bebe	a390fd14-073b-41f4-a5cf-6e4b50f47f99	Delivery	Delivery	pick up and deliver groceries	500.00	palai	\N	\N	1	urgent	\N	\N	cancelled	2026-03-27 09:14:43.660588	2026-03-27 09:44:43.660588+05:30	\N
7312e2ee-b9ca-44a5-a8ff-7ab4e9c02732	9a1232df-5dc0-462b-9cba-c088e1fdf90e	Delivery	Delivery	Delivery of food items	498.00	Kottayam	\N	\N	1	urgent	\N	\N	completed	2026-03-30 12:00:23.239772	2026-03-30 12:30:23.239772+05:30	\N
b6b5ee73-13ca-406b-8230-a2cca818e337	d37e9244-7d69-4893-b85a-7dc96be55a4a	delivery	Driving	drive	100.00	Kollapally,Kottayam	\N	\N	1	scheduled	2026-07-27 21:00:00	\N	completed	2026-07-27 20:56:01.897802	2026-07-27 21:00:00+05:30	\N
23405e45-93b9-4f9e-97f7-7781db7824bc	d37e9244-7d69-4893-b85a-7dc96be55a4a	Fix leakage	Plumbing	Fix leaking pipe	500.00	Kollapally,Kottayam	\N	\N	1	scheduled	2026-04-05 22:45:00	\N	completed	2026-04-05 22:20:54.630637	2026-04-05 22:45:00+05:30	\N
fbb56d07-4b6e-4bbf-ad3e-8ab1a047b9db	d37e9244-7d69-4893-b85a-7dc96be55a4a	Driver	Driving	Need to arrive safely	1000.00	Kollapally,Kottayam	\N	\N	1	scheduled	2026-04-05 22:00:00	\N	cancelled	2026-04-05 21:37:35.998012	2026-04-05 22:30:00+05:30	\N
3eda7106-4ca1-417a-9f40-52524af1f5db	d37e9244-7d69-4893-b85a-7dc96be55a4a	Painting	Painting	Need to paint a room	500.00	Kollapally,Kottayam	\N	\N	1	scheduled	2026-12-13 00:30:00	\N	assigned	2026-04-13 11:47:29.742453	2026-12-13 00:30:00+05:30	\N
3b56b109-2370-4e0f-9e83-2b0529106202	d37e9244-7d69-4893-b85a-7dc96be55a4a	Painting	Painting	Paint a room	500.00	Kollapally,Kottayam	\N	\N	1	scheduled	2026-04-13 00:30:00	\N	cancelled	2026-04-13 12:00:36.018315	2026-04-13 00:30:00+05:30	\N
bc7b578c-8392-4e51-8350-adf848fa16e0	d37e9244-7d69-4893-b85a-7dc96be55a4a	Painting	Painting	Need to paint a room	600.00	Kollapally,Kottayam	\N	\N	1	scheduled	2026-04-13 12:30:00	\N	completed	2026-04-13 12:03:04.351594	2026-04-13 12:30:00+05:30	\N
c06d4be1-77e0-4fc7-a30e-be71a6c4b0c3	d37e9244-7d69-4893-b85a-7dc96be55a4a	Driving	Driving	Drive a car	500.00	Kollapally,Kottayam	\N	\N	1	scheduled	2026-04-13 12:45:00	\N	cancelled	2026-04-13 12:41:13.479523	2026-04-13 12:45:00+05:30	\N
\.


--
-- Data for Name: otps; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.otps (id, job_id, worker_id, otp_code, is_used, created_at, expires_at) FROM stdin;
cc1c3a71-6bfe-4179-b185-8579f483b3f8	b7c27a08-03ec-4f22-8b10-010ad77fe7fa	\N	495626	t	2026-03-13 11:09:48.237664	2026-03-13 11:19:48.237664
e4a21a5d-6656-4336-9b72-2b26d7ec5f71	60772025-f8aa-485a-a9a6-fd09293d256a	\N	762478	f	2026-03-13 11:38:55.850806	2026-03-13 11:48:55.850806
a2f8b4ec-e65c-4837-888e-e62012495a24	ee62afa9-5030-45ee-a109-45df39a77d9e	\N	655268	f	2026-03-13 12:23:18.894523	2026-03-13 12:33:18.894523
823ef771-0aa7-4dc5-aec9-c7119315be47	e9e28b97-2f29-4c60-a1af-0dad602a546b	\N	729995	f	2026-03-13 12:59:52.693208	2026-03-13 13:09:52.693208
276891e7-6bae-42c5-8a69-c25edd2d43bc	763616fb-c96c-4c8b-bc5d-55f78806b048	\N	304215	t	2026-03-13 12:43:45.672821	2026-03-13 12:53:45.672821
3afc4a7c-0dd6-46fb-8648-e75aa7d48b09	e701134f-b71c-43e6-bb6a-2da41f8ec515	\N	358931	f	2026-03-13 13:14:37.874223	2026-03-13 13:24:37.874223
9bef408c-af4d-4ced-90be-4dc49545720a	c98c8721-d6b3-487e-90f6-831a2ab39e94	\N	956309	f	2026-03-13 14:06:24.477693	2026-03-13 14:16:24.477693
34c8a402-1f07-4ba7-ae15-0ac9e9a11842	763616fb-c96c-4c8b-bc5d-55f78806b048	\N	443541	t	2026-03-13 13:01:03.528061	2026-03-13 13:11:03.528061
91dbfe0d-8c65-42ac-9ec1-d8004f27c201	763616fb-c96c-4c8b-bc5d-55f78806b048	\N	450341	f	2026-03-13 14:56:13.087995	2026-03-13 15:06:13.087995
f7975e7d-012b-4d9d-acd5-8a9a7380e758	6b4e8b88-390f-4fb9-9c27-1f1c2f0523aa	\N	941507	t	2026-03-20 19:44:25.202612	2026-03-20 19:54:25.202612
c2b6cc9b-f4b4-4b42-9d6c-50ca96dc6d09	57962871-3156-4345-a5bc-8b63c2c5482d	\N	985618	t	2026-03-25 15:37:14.243328	2026-03-25 15:47:14.243328
4b2a0b6c-6b5a-4a9f-aa38-c95e9a3030b2	65a6225e-cbe2-4581-be53-d08dd18517f5	\N	561404	f	2026-03-27 11:42:44.434771	2026-03-27 11:52:44.434771
404fc48a-70f1-4153-9c82-21f24ef8a035	9258687b-9315-422a-a098-a4fa8b14bebe	\N	618890	t	2026-03-27 09:54:11.493142	2026-03-27 10:04:11.493142
9a8e933f-d0d4-4b15-8cef-44043c5b2c1b	9258687b-9315-422a-a098-a4fa8b14bebe	\N	832159	f	2026-03-28 22:11:43.80235	2026-03-28 22:21:43.80235
f3a7de24-ec57-402c-b924-43cd29343c81	9e7d5898-bace-4261-a789-a88e42b19795	\N	835523	t	2026-03-27 19:05:46.00566	2026-03-27 19:15:46.00566
998fd07f-ecb7-4ce6-a031-a2a7bbd3b152	72b97a95-fe5b-45aa-9d0a-d456df96cca8	\N	493120	t	2026-03-28 21:23:38.798283	2026-03-28 21:33:38.798283
2edb7022-d286-41a6-a090-0b1af4bdf536	aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	\N	949014	t	2026-03-27 13:51:41.482229	2026-03-27 14:01:41.482229
21d083e6-840a-429a-9f5b-afc2ede9a6c9	a15a5709-036a-4b13-85f4-b4b1b630fbcd	\N	609044	t	2026-03-27 14:11:20.062968	2026-03-27 14:21:20.062968
8c0a1833-ed90-4333-9e9b-fd53c15aa211	34640b06-4ead-4863-ac93-64f721fe63e1	\N	903073	t	2026-03-30 12:07:19.37449	2026-03-30 12:17:19.37449
99d634a4-f886-4009-8318-68da93495937	7312e2ee-b9ca-44a5-a8ff-7ab4e9c02732	\N	555035	t	2026-03-30 12:11:34.96539	2026-03-30 12:21:34.96539
48768960-6e25-495a-8b17-6b74a9902fde	3cb4d11b-8a62-4386-a565-59ceb02d891a	\N	341464	f	2026-04-01 09:31:25.475398	2026-04-01 09:41:25.475398
c9b4f566-4b32-437c-b113-0f6666771ac3	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	\N	961506	t	2026-04-01 09:24:33.698777	2026-04-01 09:34:33.698777
b8ab7742-5a0b-4bc4-8185-dd0bba5ef98d	5ccaa9ce-850b-4364-9c90-57ec7950afc6	\N	285509	t	2026-03-27 08:57:45.530581	2026-03-27 09:07:45.530581
9f0c2b9e-929d-4bc2-b2c5-dd628c311a66	85f93a22-8de9-416a-8bd8-6e8b62747ee3	\N	582174	t	2026-03-13 13:13:36.229844	2026-03-13 13:23:36.229844
73ec48ed-946d-45f5-bd5e-e854de2a43b7	85f93a22-8de9-416a-8bd8-6e8b62747ee3	\N	209947	t	2026-04-01 09:57:22.471259	2026-04-01 10:07:22.471259
357b17e4-82f5-4be7-9656-37e0703a295c	85f93a22-8de9-416a-8bd8-6e8b62747ee3	\N	882655	f	2026-04-01 09:57:31.08215	2026-04-01 10:07:31.08215
8aac9b67-940f-45a7-b92a-16163d5f9330	46daaa54-0db6-419d-9227-24f7c18eddfa	\N	937215	t	2026-03-20 19:40:23.337755	2026-03-20 19:50:23.337755
7b914673-fb74-4e93-87b8-950d9c2855f1	46daaa54-0db6-419d-9227-24f7c18eddfa	\N	792657	t	2026-04-01 09:58:46.291661	2026-04-01 10:08:46.291661
56179a49-2bbb-4ed1-af94-31a368532f09	46daaa54-0db6-419d-9227-24f7c18eddfa	\N	178128	t	2026-04-01 09:59:15.730587	2026-04-01 10:09:15.730587
6fd63a6a-874b-42f2-91d2-5948c962ad2a	46daaa54-0db6-419d-9227-24f7c18eddfa	\N	101536	f	2026-04-01 09:59:27.713562	2026-04-01 10:09:27.713562
798b331d-a64e-4152-8efb-fd9651779523	84bf3ad2-6a18-4d99-a8f5-174ed3e6a32b	\N	266247	t	2026-03-28 21:28:54.037936	2026-03-28 21:38:54.037936
8db15037-1c9b-4b38-b893-302bd800d757	84bf3ad2-6a18-4d99-a8f5-174ed3e6a32b	\N	416053	f	2026-04-01 10:02:12.99393	2026-04-01 10:12:12.99393
098b927c-f75d-49c3-b4f5-d0387682cddd	34e3760b-9b66-450c-b4f7-f2f5e193b80a	\N	703632	f	2026-04-01 10:42:12.768332	2026-04-01 10:52:12.768332
84dabbe1-cbfc-4b25-90b0-9e617f82d2c9	45c1d931-b9f6-40ac-9647-9c042e32d964	\N	163578	f	2026-04-02 08:16:34.409539	2026-04-02 08:26:34.409539
d65b3975-7dba-4f9a-9cbf-f003016003c6	66c6ee57-59a6-4ab9-9f82-bc7584c8d611	\N	204655	f	2026-04-02 08:25:20.506883	2026-04-02 08:35:20.506883
3c42295c-71f9-4927-b3e2-3dacf143c464	9592c141-2224-4730-9367-c4b0cd915a41	\N	959999	f	2026-04-02 08:27:16.475836	2026-04-02 08:37:16.475836
c9b6397d-2a4d-4082-be46-eef2c367ce07	ebba0a0d-64db-4eaa-86ca-2d999a8ae6c6	\N	862459	f	2026-04-03 17:09:13.075295	2026-04-03 17:19:13.075295
888dd60d-ef94-4084-8353-0e1172a9caf3	fbb56d07-4b6e-4bbf-ad3e-8ab1a047b9db	\N	766015	f	2026-04-05 21:59:34.82221	2026-04-05 22:09:34.82221
3781c844-f3c6-40fd-a6e0-b5fd6ba8387e	23405e45-93b9-4f9e-97f7-7781db7824bc	\N	400023	t	2026-04-05 22:22:12.463927	2026-04-05 22:32:12.463927
6ad01b08-3187-45ca-9f2a-47ad0134d709	3eda7106-4ca1-417a-9f40-52524af1f5db	\N	313167	f	2026-04-13 11:52:42.450533	2026-04-13 12:02:42.450533
97a7305f-d695-4c89-b1fe-d091308f43d0	3b56b109-2370-4e0f-9e83-2b0529106202	\N	130724	f	2026-04-13 12:01:33.404821	2026-04-13 12:11:33.404821
ee650de2-c09a-42cf-bd8f-f25bd693c49e	bc7b578c-8392-4e51-8350-adf848fa16e0	\N	640218	t	2026-04-13 12:04:25.885116	2026-04-13 12:14:25.885116
25b08df7-1e6a-432f-9dd2-90c23d06679b	c06d4be1-77e0-4fc7-a30e-be71a6c4b0c3	\N	197040	f	2026-04-13 12:41:45.51143	2026-04-13 12:51:45.51143
50b04dcf-c5a4-4b4d-812b-49bd1515c7ff	b6b5ee73-13ca-406b-8230-a2cca818e337	\N	738480	t	2026-07-27 20:57:34.07381	2026-07-27 21:07:34.07381
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, job_id, customer_id, worker_id, amount, payment_sent, payment_received, sent_at, received_at) FROM stdin;
7e13102a-ef8c-43bd-b968-a38e468302dc	b7c27a08-03ec-4f22-8b10-010ad77fe7fa	a390fd14-073b-41f4-a5cf-6e4b50f47f99	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	800.00	t	t	2026-03-13 12:24:05.586517	2026-03-13 12:24:38.641818
ddafb239-763e-40a1-aa7c-34acf29276fa	6b4e8b88-390f-4fb9-9c27-1f1c2f0523aa	0c1cd16a-c66f-4585-a998-e291335327a4	0394eaa6-ce6d-4812-b507-a9f843d4df32	500.00	t	t	2026-03-20 20:15:18.657477	2026-03-20 20:15:24.852687
1a2a30d8-5847-4ba5-9c8a-0a52ff8c2bad	57962871-3156-4345-a5bc-8b63c2c5482d	0c1cd16a-c66f-4585-a998-e291335327a4	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	500.00	t	t	2026-03-25 15:50:11.744723	2026-03-25 15:50:21.141889
9be59e81-f081-43e4-8238-8f7ecdf84dc6	72b97a95-fe5b-45aa-9d0a-d456df96cca8	0c1cd16a-c66f-4585-a998-e291335327a4	0394eaa6-ce6d-4812-b507-a9f843d4df32	500.00	t	t	2026-03-29 07:48:11.274068	2026-03-29 07:53:35.148861
839ca66d-a060-4b12-81b5-cb7b99198644	aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	0c1cd16a-c66f-4585-a998-e291335327a4	0394eaa6-ce6d-4812-b507-a9f843d4df32	1500.00	t	t	2026-03-29 08:03:48.683249	2026-03-29 08:04:00.126103
afc81beb-a403-40fc-84c5-cc61296cdf38	9e7d5898-bace-4261-a789-a88e42b19795	a390fd14-073b-41f4-a5cf-6e4b50f47f99	0394eaa6-ce6d-4812-b507-a9f843d4df32	1000.00	t	t	2026-03-29 12:55:57.311132	2026-03-29 12:59:40.242398
e17e8a6b-10b6-464d-a1ff-86b2a85ca6fc	a15a5709-036a-4b13-85f4-b4b1b630fbcd	4544b725-5aa4-4cc6-99b0-a4810f40e187	6965a121-ed6b-41fd-b50c-a88fc1c5c826	2000.00	t	t	2026-03-29 13:23:32.772456	2026-03-29 13:23:43.370785
5f88605b-95ee-45bb-8b2b-fcf42608d058	7312e2ee-b9ca-44a5-a8ff-7ab4e9c02732	9a1232df-5dc0-462b-9cba-c088e1fdf90e	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	498.00	t	t	2026-03-30 12:13:26.835503	2026-03-30 12:14:17.276065
382a1b32-8271-400d-b796-f8fa089d94dd	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	86cf02fe-dc4a-4cfb-b016-4ec420d85291	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	1000.00	t	t	2026-04-01 09:49:01.790904	2026-04-01 10:39:29.862404
7aa534f4-433c-4e70-a57c-c5e47bdd0df9	23405e45-93b9-4f9e-97f7-7781db7824bc	d37e9244-7d69-4893-b85a-7dc96be55a4a	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	500.00	t	t	2026-04-05 22:25:54.163516	2026-04-05 22:26:23.748742
bc474cc3-ca34-4885-883b-fc39bfae4152	bc7b578c-8392-4e51-8350-adf848fa16e0	d37e9244-7d69-4893-b85a-7dc96be55a4a	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	600.00	t	t	2026-04-13 12:08:52.014493	2026-04-13 12:11:46.322948
8a4be9f9-f8eb-4214-859d-5a0ff65f73ad	b6b5ee73-13ca-406b-8230-a2cca818e337	d37e9244-7d69-4893-b85a-7dc96be55a4a	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	100.00	t	t	2026-07-27 21:01:58.721996	2026-07-27 21:06:42.796904
\.


--
-- Data for Name: portfolio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.portfolio (id, worker_id, photo_url, job_title, created_at) FROM stdin;
6ff5023c-1b8f-4cbb-8204-2689dfb0b951	f19f5bae-d7b1-4553-85bd-d750c3f59fab	http://localhost:5000/uploads/completion-aaaeea68-db66-4ebb-b89c-6dcb3297ff11-1773381846075.jpg	Fix Kitchen Sink	2026-03-13 11:34:06.094374
1d63077c-f9d1-4a97-92c0-00a9b9f8a143	6a84565a-4531-4a35-ac44-e956b32e952d	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774017912909.jpg	Shopping	2026-03-20 20:15:12.983767
ece75101-c1dd-41ca-a18f-a6ed1b7a482b	f19f5bae-d7b1-4553-85bd-d750c3f59fab	http://localhost:5000/uploads/completion-aaaeea68-db66-4ebb-b89c-6dcb3297ff11-1774433924399.jpg	Moving	2026-03-25 15:48:44.415313
81e1cd2c-50a8-4f25-9fc5-fa3c0e45f46a	6a84565a-4531-4a35-ac44-e956b32e952d	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774716320440.jpeg	Wiring	2026-03-28 22:15:20.455944
497b3fc3-b6c6-4cb5-bef1-cd8bff167c7a	6a84565a-4531-4a35-ac44-e956b32e952d	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774750680213.jpg	Delivery	2026-03-29 07:48:00.223984
4aa22325-d46e-405f-9dbe-833055bd2b71	6a84565a-4531-4a35-ac44-e956b32e952d	http://localhost:5000/uploads/completion-0394eaa6-ce6d-4812-b507-a9f843d4df32-1774751606697.jpg	Fix a leaking pipe	2026-03-29 08:03:26.763184
d8b4367f-c407-4253-9e97-2cc0ce59272b	ad9237bc-3b7b-4b07-b8c8-4668e42ff16b	http://localhost:5000/uploads/completion-6965a121-ed6b-41fd-b50c-a88fc1c5c826-1774770780783.jpg	Cleaning	2026-03-29 13:23:00.87527
dffd8efd-3551-446b-87b4-9fe06a034a4e	f19f5bae-d7b1-4553-85bd-d750c3f59fab	http://localhost:5000/uploads/completion-aaaeea68-db66-4ebb-b89c-6dcb3297ff11-1774852960865.jpg	Delivery	2026-03-30 12:12:40.8767
903b65e5-4782-47a2-be87-99b2474aa48a	cb9130f9-22c2-4832-99e3-369084723d27	http://localhost:5000/uploads/completion-a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb-1775017041598.jpg	Driving	2026-04-01 09:47:21.728525
20563d44-97ea-4858-8ee2-4f8a2b9a4168	7c3be074-298c-4482-9f79-53cd87b56663	http://localhost:5000/uploads/completion-91729c91-80ab-4b0e-9a7d-40d4a5fba7a8-1775408146651.jpeg	Fix leakage	2026-04-05 22:25:46.761758
b6e9cde4-9ddd-43ea-83b9-d7c6e249a443	7c3be074-298c-4482-9f79-53cd87b56663	http://localhost:5000/uploads/completion-91729c91-80ab-4b0e-9a7d-40d4a5fba7a8-1776062317778.jpeg	Painting	2026-04-13 12:08:37.834341
d751dcd6-6320-4b02-a0b5-d10eb4254881	7c3be074-298c-4482-9f79-53cd87b56663	http://localhost:5000/uploads/completion-91729c91-80ab-4b0e-9a7d-40d4a5fba7a8-1785166309820.jpg	delivery	2026-07-27 21:01:49.912216
\.


--
-- Data for Name: ratings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ratings (id, job_id, customer_id, worker_id, score, review, created_at) FROM stdin;
2ba800a2-78b1-4235-ac53-aad450fd5c44	b7c27a08-03ec-4f22-8b10-010ad77fe7fa	a390fd14-073b-41f4-a5cf-6e4b50f47f99	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	5	good	2026-03-13 12:27:52.880216
af355230-cc05-4eb4-9016-fcfc172c3878	aa11df3f-a3d7-4698-a975-a3b8e8e4a7b4	0c1cd16a-c66f-4585-a998-e291335327a4	0394eaa6-ce6d-4812-b507-a9f843d4df32	4	good	2026-03-29 08:05:43.699695
319024fe-bd29-4ee9-a284-e0d917880796	9e7d5898-bace-4261-a789-a88e42b19795	a390fd14-073b-41f4-a5cf-6e4b50f47f99	0394eaa6-ce6d-4812-b507-a9f843d4df32	4	Good 	2026-03-29 12:59:52.292849
bd41bded-0218-4776-b522-2049f3d7041e	72b97a95-fe5b-45aa-9d0a-d456df96cca8	0c1cd16a-c66f-4585-a998-e291335327a4	0394eaa6-ce6d-4812-b507-a9f843d4df32	5	Excellent service	2026-03-29 13:13:29.324866
57298d21-91b8-4189-bb41-ddcf2e346921	57962871-3156-4345-a5bc-8b63c2c5482d	0c1cd16a-c66f-4585-a998-e291335327a4	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	2	Satisfactionary	2026-03-29 13:14:23.506706
7d815c96-85e5-42d5-8da3-9bc25b152c35	a15a5709-036a-4b13-85f4-b4b1b630fbcd	4544b725-5aa4-4cc6-99b0-a4810f40e187	6965a121-ed6b-41fd-b50c-a88fc1c5c826	3	Good	2026-03-29 13:23:59.918452
8205bfc7-b599-4b66-8e4e-91a2750b6cd0	7312e2ee-b9ca-44a5-a8ff-7ab4e9c02732	9a1232df-5dc0-462b-9cba-c088e1fdf90e	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	4	Good	2026-03-30 12:14:31.132522
580c1f39-1ba4-4b44-a919-a658facdba85	6e86ac33-4bec-4bee-80ef-e7fb38e9dbdf	86cf02fe-dc4a-4cfb-b016-4ec420d85291	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	5	Excellent Job	2026-04-01 10:40:03.568545
b5bb2247-4a65-459c-8b54-bb1c3b207da0	23405e45-93b9-4f9e-97f7-7781db7824bc	d37e9244-7d69-4893-b85a-7dc96be55a4a	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	5	great service	2026-04-05 22:26:45.343664
c064a0fd-22f8-49cf-ac37-f9959fefb71c	bc7b578c-8392-4e51-8350-adf848fa16e0	d37e9244-7d69-4893-b85a-7dc96be55a4a	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	5	Excellent service	2026-04-13 12:12:23.537802
c4d67010-9acb-4568-a74c-4cc2f12c8b1a	b6b5ee73-13ca-406b-8230-a2cca818e337	d37e9244-7d69-4893-b85a-7dc96be55a4a	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	5	\N	2026-07-27 21:08:41.262631
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, full_name, email, phone, password_hash, role, created_at, is_banned, ban_reason, warn_count, is_online, address) FROM stdin;
4544b725-5aa4-4cc6-99b0-a4810f40e187	Rahul Varma	rahul@example.com	9876543220	$2b$10$//BG2r4IyZ5WLSSouz5mo.ysZGF5yzjUy68/pOCewt9gLZ6a9NVTi	customer	2026-03-13 08:40:20.478823	f	\N	0	f	Ernakulam, Kerala
9a1232df-5dc0-462b-9cba-c088e1fdf90e	Anjali Raj	anjali@example.com	9876543221	$2b$10$1/E46NRMVMvl7TGmNhUJUe.C.udJQ2Mp7A..e9YFksPt/1TZi7urC	customer	2026-03-13 08:41:05.772482	f	\N	0	f	Thrissur, Kerala
0c1cd16a-c66f-4585-a998-e291335327a4	Vikram Das	vikram@example.com	9876543222	$2b$10$zvg1zdAJ5ys.Xbs8082snOdlxs.hJmUM4/I.n85gYgOU0ucR5BUfe	customer	2026-03-13 08:41:40.206542	f	\N	0	f	Kochi, Kerala
49bb73ef-c7ca-4966-a27a-a68d29f0b181	Suresh Kumar	suresh@example.com	9876543212	$2b$10$2l.dKgkGLb86hysSkbwawesAPWCH526lKLZUXm.UKaLW8P5qnAD/C	worker	2026-03-13 08:43:25.495153	f	\N	2	t	\N
86cf02fe-dc4a-4cfb-b016-4ec420d85291	Rohit	Rohit@example.com	9655132536	$2b$10$aRZnUN.o1kg62nSQV/j9s.4CPZui9hAVY725MVq4WjbZBDq0c2hSy	customer	2026-04-01 09:12:40.731924	f	\N	0	f	Vikas Bhavan,Thrikkakkara P.O, Ernakulam
a390fd14-073b-41f4-a5cf-6e4b50f47f99	John Customer	john@example.com	9876543210	$2b$10$qhpM7AOx54rRMOyK9lx6zuRKA/Cr.Fv8spiP/0Ufjkr9kRcaPgl12	customer	2026-02-23 00:16:08.764656	f	\N	3	f	Kottayam, Kerala
a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	Ruhi	ruhi@example.com	7123456473	$2b$10$W7QOKCXwu8Kxj2.JRJjGk.NRZbHv4h2.CYCE/JUzhk7aGEXJi4LFO	worker	2026-04-01 09:15:09.075542	f	\N	0	f	Vidya Bhavan,Thrikkakkara P.O, Ernakulam
6965a121-ed6b-41fd-b50c-a88fc1c5c826	Arjun	arjun@example.com	8111111101	$2b$10$wCf8rkGfIs.VnA56Xr2qzeJy8k1qgZf5Q3SzhGzLQJaGy8w1uW16S	worker	2026-03-13 08:44:50.633105	f	\N	2	f	\N
f8d63afd-5e92-47df-8546-93982952a2eb	Admin	admin@worklink.com	0000000000	$2b$10$liUWaKiMI3wz.FYWL2eSCu7YEvlmy/w7ijHO63k.M5x/ZeA.k5bYK	admin	2026-03-13 08:22:14.487523	f	\N	0	f	\N
0394eaa6-ce6d-4812-b507-a9f843d4df32	Priya 	priya@example.com	9876543211	$2b$10$1UKrq/RtVIya9I3D2css1uLLKhaqueXUhD2Vd5E0HIK8zwymakB4i	worker	2026-03-13 08:42:38.126188	f	\N	1	f	\N
aaaeea68-db66-4ebb-b89c-6dcb3297ff11	Ravi Worker	ravi@example.com	9123456780	$2b$10$VJyWOaEK2aFt6ae4aZQlj.z4TYPy.UyTwFdhficWB17S.BNJAGr9a	worker	2026-02-23 00:16:55.33921	f	\N	0	f	\N
d37e9244-7d69-4893-b85a-7dc96be55a4a	Jeon	jeon@gmail.com	1254789562	$2b$10$o09lnYA9ZsXv7SCmEN8nWuWlydHQ7orUEwzzdt8fSBYhOmmA8gAN2	customer	2026-04-05 21:35:17.316845	f	\N	0	f	\N
38b0ad83-a8b9-4c35-8fc0-f489d0473d30	ram	852@g	123	$2b$10$q/nrXdprx0ihX23mStlHH./18c.yU7z1Ep7lr9M.JxJgYesAF0dH6	worker	2026-04-06 10:35:52.517696	f	\N	0	f	huo
91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	Jay	jay@gmail.com	5412368547	$2b$10$u5lGSsNZxr19o8Vpbkwn9Ospqxdl3VEs0VWRhKiCgZjqUtbiMohYe	worker	2026-04-05 21:58:16.107789	f	\N	0	t	\N
\.


--
-- Data for Name: worker_profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.worker_profiles (id, user_id, skills, is_online, rating, total_ratings, latitude, longitude, created_at, bio, hourly_rate) FROM stdin;
fc4d4d51-7fbc-4be1-91f1-17f6f3a28b04	49bb73ef-c7ca-4966-a27a-a68d29f0b181	{carpentry}	f	0.00	0	9.7591550	76.6812740	2026-03-13 08:43:25.50212	\N	\N
f19f5bae-d7b1-4553-85bd-d750c3f59fab	aaaeea68-db66-4ebb-b89c-6dcb3297ff11	{plumbing,electrical}	t	3.67	3	9.7591550	76.6812740	2026-02-23 00:16:55.351465	More than 5 years of experience in plumbing,electrical works	250.00
ad9237bc-3b7b-4b07-b8c8-4668e42ff16b	6965a121-ed6b-41fd-b50c-a88fc1c5c826	{plumbing}	f	3.00	1	9.7268435	76.7261930	2026-03-13 08:44:50.644335		200.00
6a84565a-4531-4a35-ac44-e956b32e952d	0394eaa6-ce6d-4812-b507-a9f843d4df32	{electrical,cleaning,carpentry}	f	4.33	3	\N	\N	2026-03-13 08:42:38.133423	A beginner with less than 1 year experience\n	200.00
cb9130f9-22c2-4832-99e3-369084723d27	a8d6e53d-7463-4e19-8ac8-4661a5c7c4bb	{Driving,Gardening,Housework}	f	5.00	1	9.7270866	76.7262596	2026-04-01 09:15:09.088489	\N	\N
7cc2b57b-f1fd-4d06-aea3-9e3c3bc336fc	38b0ad83-a8b9-4c35-8fc0-f489d0473d30	{driving}	f	0.00	0	\N	\N	2026-04-06 10:35:53.23134	\N	\N
7c3be074-298c-4482-9f79-53cd87b56663	91729c91-80ab-4b0e-9a7d-40d4a5fba7a8	{Driving,Plumbing,driving,plumbing,painting}	f	5.00	3	\N	\N	2026-04-05 21:58:16.129851		\N
\.


--
-- Name: applications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.applications_id_seq', 53, true);


--
-- Name: admin_actions admin_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_actions
    ADD CONSTRAINT admin_actions_pkey PRIMARY KEY (id);


--
-- Name: admin_messages admin_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_messages
    ADD CONSTRAINT admin_messages_pkey PRIMARY KEY (id);


--
-- Name: applications applications_job_id_worker_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_job_id_worker_id_key UNIQUE (job_id, worker_id);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: assigned_workers assigned_workers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assigned_workers
    ADD CONSTRAINT assigned_workers_pkey PRIMARY KEY (id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: commitment_bonds commitment_bonds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commitment_bonds
    ADD CONSTRAINT commitment_bonds_pkey PRIMARY KEY (id);


--
-- Name: dispute_messages dispute_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispute_messages
    ADD CONSTRAINT dispute_messages_pkey PRIMARY KEY (id);


--
-- Name: disputes disputes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_pkey PRIMARY KEY (id);


--
-- Name: emergency_backups emergency_backups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emergency_backups
    ADD CONSTRAINT emergency_backups_pkey PRIMARY KEY (id);


--
-- Name: job_applications job_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: otps otps_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.otps
    ADD CONSTRAINT otps_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: portfolio portfolio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.portfolio
    ADD CONSTRAINT portfolio_pkey PRIMARY KEY (id);


--
-- Name: ratings ratings_job_customer_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_job_customer_unique UNIQUE (job_id, customer_id);


--
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: worker_profiles worker_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.worker_profiles
    ADD CONSTRAINT worker_profiles_pkey PRIMARY KEY (id);


--
-- Name: worker_profiles worker_profiles_user_id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.worker_profiles
    ADD CONSTRAINT worker_profiles_user_id_unique UNIQUE (user_id);


--
-- Name: jobs trg_arrival_deadline; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_arrival_deadline BEFORE INSERT ON public.jobs FOR EACH ROW EXECUTE FUNCTION public.set_arrival_deadline();


--
-- Name: admin_actions admin_actions_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_actions
    ADD CONSTRAINT admin_actions_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id);


--
-- Name: admin_actions admin_actions_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_actions
    ADD CONSTRAINT admin_actions_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id);


--
-- Name: admin_messages admin_messages_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_messages
    ADD CONSTRAINT admin_messages_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id);


--
-- Name: admin_messages admin_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_messages
    ADD CONSTRAINT admin_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: admin_messages admin_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_messages
    ADD CONSTRAINT admin_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: applications applications_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: applications applications_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: assigned_workers assigned_workers_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assigned_workers
    ADD CONSTRAINT assigned_workers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: assigned_workers assigned_workers_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assigned_workers
    ADD CONSTRAINT assigned_workers_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: commitment_bonds commitment_bonds_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commitment_bonds
    ADD CONSTRAINT commitment_bonds_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: commitment_bonds commitment_bonds_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commitment_bonds
    ADD CONSTRAINT commitment_bonds_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: dispute_messages dispute_messages_dispute_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispute_messages
    ADD CONSTRAINT dispute_messages_dispute_id_fkey FOREIGN KEY (dispute_id) REFERENCES public.disputes(id) ON DELETE CASCADE;


--
-- Name: dispute_messages dispute_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispute_messages
    ADD CONSTRAINT dispute_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: disputes disputes_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE SET NULL;


--
-- Name: disputes disputes_reported_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_reported_id_fkey FOREIGN KEY (reported_id) REFERENCES public.users(id);


--
-- Name: disputes disputes_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id);


--
-- Name: disputes disputes_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.users(id);


--
-- Name: emergency_backups emergency_backups_backup_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emergency_backups
    ADD CONSTRAINT emergency_backups_backup_worker_id_fkey FOREIGN KEY (backup_worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: emergency_backups emergency_backups_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emergency_backups
    ADD CONSTRAINT emergency_backups_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: job_applications job_applications_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: job_applications job_applications_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: jobs jobs_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: otps otps_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.otps
    ADD CONSTRAINT otps_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: otps otps_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.otps
    ADD CONSTRAINT otps_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: payments payments_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: portfolio portfolio_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.portfolio
    ADD CONSTRAINT portfolio_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.worker_profiles(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: worker_profiles worker_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.worker_profiles
    ADD CONSTRAINT worker_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict pOkdK8u7rDHREqcgsEYYbq383Q39ibuBE2mHa74OIvAgqqAeeYIwevjHl1nGvXM

