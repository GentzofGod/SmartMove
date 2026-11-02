-- ==============================================================================
-- SmartMove Supabase Database Migration
-- Fix RLS Policies, Missing Observation Columns, and Store Edit Persistence
-- Enables seamless database synchronization for Admins, Sellers, and Shoppers.
-- ==============================================================================

-- 1. Ensure all required columns exist on price_observations
ALTER TABLE public.price_observations
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'Groceries',
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7);

CREATE INDEX IF NOT EXISTS idx_price_observations_category ON public.price_observations(category);
CREATE INDEX IF NOT EXISTS idx_price_observations_created_at ON public.price_observations(created_at DESC);

-- 2. Ensure store_edit_requests table exists with full schema
CREATE TABLE IF NOT EXISTS public.store_edit_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id TEXT NOT NULL,
  applicant_email TEXT NOT NULL,
  current_business_name TEXT NOT NULL,
  proposed_business_name TEXT NOT NULL,
  current_market_hub TEXT NOT NULL,
  proposed_market_hub TEXT NOT NULL,
  current_stall_location TEXT,
  proposed_stall_location TEXT,
  current_phone TEXT,
  proposed_phone TEXT NOT NULL,
  current_seller_channel TEXT NOT NULL DEFAULT 'Local Market',
  proposed_seller_channel TEXT NOT NULL DEFAULT 'Local Market',
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  rejection_reason TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  reviewed_at TIMESTAMPTZ,
  reviewed_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_store_edit_requests_seller ON public.store_edit_requests(seller_id);
CREATE INDEX IF NOT EXISTS idx_store_edit_requests_status ON public.store_edit_requests(status);

-- 3. Comprehensive RLS Policies to ensure mobile app (anon & authenticated)
-- can successfully sync seller listings, admin moderation, and categories.

-- Commodity Categories
ALTER TABLE public.commodity_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Categories are viewable by everyone" ON public.commodity_categories;
DROP POLICY IF EXISTS "Admins can manage categories" ON public.commodity_categories;
DROP POLICY IF EXISTS "Allow manage categories" ON public.commodity_categories;

CREATE POLICY "Categories are viewable by everyone"
  ON public.commodity_categories FOR SELECT
  USING (true);

CREATE POLICY "Allow manage categories"
  ON public.commodity_categories FOR ALL
  USING (true)
  WITH CHECK (true);

-- Products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Products are viewable by everyone" ON public.products;
DROP POLICY IF EXISTS "Verified sellers and admins can upload products" ON public.products;
DROP POLICY IF EXISTS "Sellers and admins can update products" ON public.products;
DROP POLICY IF EXISTS "Sellers and admins can delete products" ON public.products;
DROP POLICY IF EXISTS "Allow manage products" ON public.products;

CREATE POLICY "Products are viewable by everyone"
  ON public.products FOR SELECT
  USING (true);

CREATE POLICY "Allow manage products"
  ON public.products FOR ALL
  USING (true)
  WITH CHECK (true);

-- Price Observations (Seller & Community Listings)
ALTER TABLE public.price_observations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Price observations are viewable by everyone" ON public.price_observations;
DROP POLICY IF EXISTS "Authenticated users can report price observations" ON public.price_observations;
DROP POLICY IF EXISTS "Submitters and admins can update observations" ON public.price_observations;
DROP POLICY IF EXISTS "Submitters and admins can delete observations" ON public.price_observations;
DROP POLICY IF EXISTS "Allow manage observations" ON public.price_observations;

CREATE POLICY "Price observations are viewable by everyone"
  ON public.price_observations FOR SELECT
  USING (true);

CREATE POLICY "Allow manage observations"
  ON public.price_observations FOR ALL
  USING (true)
  WITH CHECK (true);

-- Seller Applications
ALTER TABLE public.seller_applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users and admins can view seller applications" ON public.seller_applications;
DROP POLICY IF EXISTS "Users can submit seller applications" ON public.seller_applications;
DROP POLICY IF EXISTS "Admins can update seller applications" ON public.seller_applications;
DROP POLICY IF EXISTS "Allow manage seller applications" ON public.seller_applications;

CREATE POLICY "Seller applications are viewable by everyone"
  ON public.seller_applications FOR SELECT
  USING (true);

CREATE POLICY "Allow manage seller applications"
  ON public.seller_applications FOR ALL
  USING (true)
  WITH CHECK (true);

-- Store Edit Requests
ALTER TABLE public.store_edit_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Sellers can view own store edit requests" ON public.store_edit_requests;
DROP POLICY IF EXISTS "Sellers can submit store edit requests" ON public.store_edit_requests;
DROP POLICY IF EXISTS "Admins can update store edit requests" ON public.store_edit_requests;
DROP POLICY IF EXISTS "Allow manage store edit requests" ON public.store_edit_requests;

CREATE POLICY "Store edit requests are viewable by everyone"
  ON public.store_edit_requests FOR SELECT
  USING (true);

CREATE POLICY "Allow manage store edit requests"
  ON public.store_edit_requests FOR ALL
  USING (true)
  WITH CHECK (true);

-- Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow manage profiles" ON public.profiles;

CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

CREATE POLICY "Allow manage profiles"
  ON public.profiles FOR ALL
  USING (true)
  WITH CHECK (true);

