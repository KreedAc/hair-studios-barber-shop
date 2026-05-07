-- ============================================================
-- Hair Studios – Barber Shop · Schema Supabase
-- Incolla tutto nel SQL Editor di Supabase ed esegui
-- ============================================================

-- ── PROFILES ─────────────────────────────────────────────────
-- Estende auth.users con nome, telefono e flag admin
CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID        PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  name       TEXT        NOT NULL DEFAULT '',
  phone      TEXT,
  is_admin   BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger: crea il profilo automaticamente ad ogni signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, name, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.raw_user_meta_data->>'phone'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── STAFF ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.staff (
  id         SERIAL      PRIMARY KEY,
  full_name  TEXT        NOT NULL,
  name       TEXT        NOT NULL,          -- nome breve es. "Marco V."
  role       TEXT        NOT NULL DEFAULT 'Barber',
  phone      TEXT,
  email      TEXT,
  color      TEXT        NOT NULL DEFAULT 'oklch(65% 0.14 240)',
  initials   TEXT        NOT NULL,
  active     BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── SERVICES ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.services (
  id         SERIAL       PRIMARY KEY,
  name       TEXT         NOT NULL,
  duration   INTEGER      NOT NULL CHECK (duration > 0), -- minuti
  price      NUMERIC(8,2),
  active     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ── BOOKINGS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bookings (
  id               SERIAL       PRIMARY KEY,
  user_id          UUID         REFERENCES public.profiles(id) ON DELETE SET NULL,
  staff_id         INTEGER      NOT NULL REFERENCES public.staff(id) ON DELETE RESTRICT,
  service_id       INTEGER      REFERENCES public.services(id) ON DELETE SET NULL,
  service_name     TEXT         NOT NULL,   -- denormalizzato: mantiene storico
  service_duration INTEGER      NOT NULL,
  client_name      TEXT         NOT NULL,
  date             DATE         NOT NULL,
  time             TIME         NOT NULL,
  status           TEXT         NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','confirmed','cancelled')),
  notes            TEXT,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bookings_user_id_idx    ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS bookings_staff_id_idx   ON public.bookings(staff_id);
CREATE INDEX IF NOT EXISTS bookings_date_idx       ON public.bookings(date);
CREATE INDEX IF NOT EXISTS bookings_status_idx     ON public.bookings(status);

-- ── STAFF SCHEDULES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.staff_schedules (
  id         SERIAL       PRIMARY KEY,
  staff_id   INTEGER      NOT NULL UNIQUE REFERENCES public.staff(id) ON DELETE CASCADE,
  start_time TIME         NOT NULL DEFAULT '08:00',
  end_time   TIME         NOT NULL DEFAULT '20:00',
  work_days  BOOLEAN[]    NOT NULL DEFAULT ARRAY[true,true,true,true,true,true,false],
  breaks     JSONB        NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_schedules ENABLE ROW LEVEL SECURITY;

-- Helper: è admin?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    FALSE
  );
$$;

-- PROFILES
CREATE POLICY "profiles: leggi il proprio"    ON public.profiles FOR SELECT USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "profiles: modifica il proprio" ON public.profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
  );
CREATE POLICY "profiles: admin tutto"         ON public.profiles FOR ALL    USING (public.is_admin());

-- STAFF (tutti possono leggere, solo admin scrivono)
CREATE POLICY "staff: lettura pubblica" ON public.staff FOR SELECT USING (TRUE);
CREATE POLICY "staff: admin scrittura"  ON public.staff FOR ALL    USING (public.is_admin());

-- SERVICES (tutti possono leggere, solo admin scrivono)
CREATE POLICY "services: lettura pubblica" ON public.services FOR SELECT USING (TRUE);
CREATE POLICY "services: admin scrittura"  ON public.services FOR ALL    USING (public.is_admin());

-- BOOKINGS
CREATE POLICY "bookings: leggi le proprie o admin" ON public.bookings
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "bookings: inserisci le proprie" ON public.bookings
  FOR INSERT WITH CHECK (auth.uid() = user_id AND status = 'pending');

CREATE POLICY "bookings: cancella le proprie pending" ON public.bookings
  FOR UPDATE USING (auth.uid() = user_id AND status = 'pending')
  WITH CHECK (status = 'cancelled');

CREATE POLICY "bookings: admin tutto" ON public.bookings
  FOR ALL USING (public.is_admin());

-- STAFF SCHEDULES
CREATE POLICY "schedules: lettura pubblica" ON public.staff_schedules FOR SELECT USING (TRUE);
CREATE POLICY "schedules: admin scrittura"  ON public.staff_schedules FOR ALL    USING (public.is_admin());

-- ── DATI INIZIALI ──────────────────────────────────────────────

-- Servizi
INSERT INTO public.services (name, duration, price) VALUES
  ('Taglio',          30,  18.00),
  ('Barba',           20,  12.00),
  ('Taglio + Barba',  50,  28.00),
  ('Shampoo',         15,   8.00),
  ('Colorazione',     90,  55.00)
ON CONFLICT DO NOTHING;

-- Staff (adatta con i tuoi barbieri reali)
INSERT INTO public.staff (full_name, name, role, color, initials) VALUES
  ('Marco Valentini', 'Marco V.', 'Senior Barber', 'oklch(65% 0.14 240)', 'MV'),
  ('Luca Russo',      'Luca R.',  'Barber',        'oklch(65% 0.14 20)',  'LR')
ON CONFLICT DO NOTHING;

-- Orario default per ogni barbiere (Lun-Sab 08:00-20:00)
INSERT INTO public.staff_schedules (staff_id, start_time, end_time, work_days, breaks)
SELECT id, '08:00', '20:00', ARRAY[true,true,true,true,true,true,false], '[]'
FROM public.staff
ON CONFLICT (staff_id) DO NOTHING;

-- ── DOPO IL PRIMO SIGNUP ───────────────────────────────────────
-- Per impostare il tuo account come admin, esegui questa query
-- sostituendo YOUR_EMAIL con la tua email:
--
--   UPDATE public.profiles
--   SET is_admin = TRUE
--   WHERE id = (SELECT id FROM auth.users WHERE email = 'YOUR_EMAIL');
