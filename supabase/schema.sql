-- ==============================================================================
-- SmartMove Supabase Database Schema
-- Local Market Intelligence, Errand Planning, and Decision Simulation
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DROP ALL PRE-EXISTING OBJECTS (CLEAN SLATE)
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

DROP TABLE IF EXISTS public.saved_items CASCADE;
DROP TABLE IF EXISTS public.saved_locations CASCADE;
DROP TABLE IF EXISTS public.itinerary_stops CASCADE;
DROP TABLE IF EXISTS public.user_plans CASCADE;
DROP TABLE IF EXISTS public.shopping_items CASCADE;
DROP TABLE IF EXISTS public.errands CASCADE;
DROP TABLE IF EXISTS public.price_observations CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.markets CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

DROP TYPE IF EXISTS public.observation_source CASCADE;
DROP TYPE IF EXISTS public.errand_priority CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;

-- ------------------------------------------------------------------------------
-- 2. EXTENSIONS & CUSTOM TYPES
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE public.user_role AS ENUM (
  'Customer',
  'Trader'
);

CREATE TYPE public.observation_source AS ENUM (
  'simulated_demo',
  'community_reported',
  'trader_provided',
  'trader_confirmed'
);

CREATE TYPE public.errand_priority AS ENUM (
  'high',
  'medium',
  'low'
);

-- ------------------------------------------------------------------------------
-- 3. PROFILES TABLE (Mirrors auth.users)
-- ------------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL,
  role public.user_role NOT NULL DEFAULT 'Customer',
  avatar_url TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Trigger to auto-create user profile when auth.users signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'User'),
    COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'Customer'::public.user_role)
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------------------------
-- 4. MARKETS & COMMERCIAL HUBS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE public.markets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  city TEXT NOT NULL DEFAULT 'Lagos',
  state TEXT NOT NULL DEFAULT 'Lagos',
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  description TEXT,
  opening_time TIME,
  closing_time TIME,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 5. PRODUCTS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL, -- 'Groceries', 'Electronics', 'Pharmacy', 'Others'
  standard_unit TEXT NOT NULL DEFAULT '1kg',
  lowest_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  best_seller_id UUID REFERENCES public.markets(id) ON DELETE SET NULL,
  best_seller_name TEXT,
  percentage_change NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
  is_cheapest BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 6. PRICE OBSERVATIONS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE public.price_observations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  market_id UUID REFERENCES public.markets(id) ON DELETE SET NULL,
  seller_name TEXT NOT NULL,
  market_location TEXT NOT NULL,
  price NUMERIC(12, 2) NOT NULL,
  unit TEXT NOT NULL DEFAULT '1kg',
  source_type public.observation_source NOT NULL DEFAULT 'community_reported',
  submitter_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  submitter_name TEXT NOT NULL,
  submitter_role public.user_role NOT NULL DEFAULT 'Customer',
  is_verified BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 7. ERRANDS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE public.errands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  location_name TEXT NOT NULL,
  market_id UUID REFERENCES public.markets(id) ON DELETE SET NULL,
  scheduled_time TEXT,
  deadline TEXT,
  priority public.errand_priority NOT NULL DEFAULT 'medium',
  category TEXT NOT NULL DEFAULT 'general',
  is_completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 8. SHOPPING ITEMS TABLE (Belongs to Errand)
-- ------------------------------------------------------------------------------
CREATE TABLE public.shopping_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  errand_id UUID NOT NULL REFERENCES public.errands(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  quantity NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
  unit TEXT NOT NULL DEFAULT '1kg',
  estimated_unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  is_checked BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 9. USER PLANS (Accepted Decision Lab Itineraries)
-- ------------------------------------------------------------------------------
CREATE TABLE public.user_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_name TEXT NOT NULL,
  total_cost NUMERIC(12, 2) NOT NULL,
  total_time_hours NUMERIC(4, 2) NOT NULL,
  trade_off_explanation TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 10. ITINERARY STOPS TABLE (Belongs to User Plan)
-- ------------------------------------------------------------------------------
CREATE TABLE public.itinerary_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES public.user_plans(id) ON DELETE CASCADE,
  stop_number INT NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT,
  location TEXT NOT NULL,
  distance_km NUMERIC(6, 2) NOT NULL DEFAULT 0.0,
  duration_minutes INT NOT NULL DEFAULT 0,
  time_window TEXT,
  badge_text TEXT,
  estimated_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
  task_items JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 11. SAVED LOCATIONS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE public.saved_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  city TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 12. SAVED ITEMS (Bookmarks)
-- ------------------------------------------------------------------------------
CREATE TABLE public.saved_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(user_id, product_id)
);

-- ------------------------------------------------------------------------------
-- 13. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------

-- Enable RLS across all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.markets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.errands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopping_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itinerary_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_items ENABLE ROW LEVEL SECURITY;

-- Profiles: Public can view, owner can update
CREATE POLICY "Public profiles are viewable by everyone" 
  ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Markets: Everyone can view active markets
CREATE POLICY "Markets are viewable by everyone" 
  ON public.markets FOR SELECT USING (is_active = true);

-- Products: Everyone can browse products
CREATE POLICY "Products are viewable by everyone" 
  ON public.products FOR SELECT USING (true);

-- Price Observations: Everyone can view, authenticated users or guests can insert
CREATE POLICY "Price observations are viewable by everyone" 
  ON public.price_observations FOR SELECT USING (true);

CREATE POLICY "Authenticated users can report price observations" 
  ON public.price_observations FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'anon');

-- Errands & Shopping Items: Scoped to owner
CREATE POLICY "Users can manage their own errands" 
  ON public.errands FOR ALL 
  USING (auth.uid() = user_id OR user_id IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can manage shopping items of their errands" 
  ON public.shopping_items FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.errands e 
      WHERE e.id = shopping_items.errand_id 
      AND (e.user_id = auth.uid() OR e.user_id IS NULL)
    )
  );

-- User Plans & Stops: Scoped to owner
CREATE POLICY "Users can manage their own plans" 
  ON public.user_plans FOR ALL 
  USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can manage their plan itinerary stops" 
  ON public.itinerary_stops FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.user_plans p 
      WHERE p.id = itinerary_stops.plan_id 
      AND (p.user_id = auth.uid() OR p.user_id IS NULL)
    )
  );

-- Saved Locations & Items: Scoped to owner
CREATE POLICY "Users can manage their saved locations" 
  ON public.saved_locations FOR ALL 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their saved items" 
  ON public.saved_items FOR ALL 
  USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 14. INITIAL SEED DATA (Nigerian Markets & Baseline Prices)
-- ------------------------------------------------------------------------------
INSERT INTO public.markets (id, name, city, state, latitude, longitude, description) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Market A (Oyingbo Market)', 'Lagos', 'Lagos', 6.4950, 3.3780, 'Major wholesale and retail agricultural market on Lagos Mainland.'),
  ('a0000000-0000-0000-0000-000000000002', 'Market B (Tejuosho Market)', 'Lagos', 'Lagos', 6.5150, 3.3640, 'Popular ultra-modern shopping complex with fresh food and general merchandise in Surulere.'),
  ('a0000000-0000-0000-0000-000000000003', 'Market C (Mile 12 Market)', 'Lagos', 'Lagos', 6.6020, 3.3900, 'Largest fresh foodstuffs, grain, and perishables depot in Lagos State.'),
  ('a0000000-0000-0000-0000-000000000004', 'MedPlus Pharmacy Surulere', 'Lagos', 'Lagos', 6.5200, 3.3750, 'Retail healthcare and pharmaceutical store.'),
  ('a0000000-0000-0000-0000-000000000005', 'GIG Logistics Hub Yaba', 'Lagos', 'Lagos', 6.5100, 3.3700, 'Parcel pickup and package handling terminal.'),
  ('a0000000-0000-0000-0000-000000000006', 'Bodija Market Area', 'Ibadan', 'Oyo', 7.4343, 3.9056, 'Premier agricultural food produce hub in Oyo State.'),
  ('a0000000-0000-0000-0000-000000000007', 'Dugbe Business District', 'Ibadan', 'Oyo', 7.3876, 3.8767, 'Central commercial and goods distribution area in Ibadan.'),
  ('a0000000-0000-0000-0000-000000000008', 'Wuse 2 Market Zone', 'Abuja', 'FCT', 9.0765, 7.3986, 'Central retail market hub in Abuja.');

INSERT INTO public.products (id, name, category, standard_unit, lowest_price, best_seller_id, best_seller_name, percentage_change, is_cheapest) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'Rice (1kg)', 'Groceries', '1kg', 1650.00, 'a0000000-0000-0000-0000-000000000002', 'Market B', 8.0, true),
  ('b0000000-0000-0000-0000-000000000002', 'Eggs (crate)', 'Groceries', 'crate of 30', 5200.00, 'a0000000-0000-0000-0000-000000000001', 'Market A', -5.0, true),
  ('b0000000-0000-0000-0000-000000000003', 'Tomatoes (1kg)', 'Groceries', '1kg', 1100.00, 'a0000000-0000-0000-0000-000000000003', 'Market C', 12.0, true),
  ('b0000000-0000-0000-0000-000000000004', 'Cooking Oil (1L)', 'Groceries', '1L', 2850.00, 'a0000000-0000-0000-0000-000000000002', 'Market B', 0.0, true),
  ('b0000000-0000-0000-0000-000000000005', 'Paracetamol (Pack of 20)', 'Pharmacy', 'pack', 600.00, 'a0000000-0000-0000-0000-000000000004', 'MedPlus Pharmacy', 0.0, true),
  ('b0000000-0000-0000-0000-000000000006', 'Onions (Small Basket)', 'Groceries', 'basket', 1800.00, 'a0000000-0000-0000-0000-000000000003', 'Market C', -3.0, true),
  ('b0000000-0000-0000-0000-000000000007', 'USB-C Cable (Fast Charging)', 'Electronics', 'piece', 1500.00, 'a0000000-0000-0000-0000-000000000002', 'Market B', 0.0, true);

INSERT INTO public.price_observations (product_id, product_name, market_id, seller_name, market_location, price, unit, source_type, submitter_name, submitter_role, is_verified, notes) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'Rice (1kg)', 'a0000000-0000-0000-0000-000000000002', 'Mama Ngozi Grains', 'Market B (Tejuosho)', 1650.00, '1kg', 'trader_confirmed', 'Mama Ngozi', 'Trader', true, 'Premium quality short grain rice. Bag price also available.'),
  ('b0000000-0000-0000-0000-000000000001', 'Rice (1kg)', 'a0000000-0000-0000-0000-000000000001', 'Alhaji Danladi Store', 'Market A (Oyingbo)', 1750.00, '1kg', 'community_reported', 'Chinedu O.', 'Customer', true, 'Clean local rice.'),
  ('b0000000-0000-0000-0000-000000000002', 'Eggs (crate)', 'a0000000-0000-0000-0000-000000000001', 'Folake Poultry Depot', 'Market A (Oyingbo)', 5200.00, 'crate of 30', 'trader_confirmed', 'Folake A.', 'Trader', true, 'Fresh medium-large farm eggs, received this morning.'),
  ('b0000000-0000-0000-0000-000000000003', 'Tomatoes (1kg)', 'a0000000-0000-0000-0000-000000000003', 'Iya Basira Produce', 'Market C (Mile 12)', 1100.00, '1kg', 'trader_confirmed', 'Basira T.', 'Trader', true, 'Firm plum tomatoes, wholesale price per basket is ₦18,000.'),
  ('b0000000-0000-0000-0000-000000000004', 'Cooking Oil (1L)', 'a0000000-0000-0000-0000-000000000002', 'Kenechukwu Provisions', 'Market B (Tejuosho)', 2850.00, '1L', 'community_reported', 'Bimbo S.', 'Customer', true, 'Refined vegetable oil bottle.'),
  ('b0000000-0000-0000-0000-000000000005', 'Paracetamol (Pack of 20)', 'a0000000-0000-0000-0000-000000000004', 'MedPlus Pharmacy', 'MedPlus Pharmacy Surulere', 600.00, 'pack', 'trader_confirmed', 'Pharm. Emeka', 'Trader', true, 'Standard OTC blister pack.');
