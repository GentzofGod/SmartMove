-- ==============================================================================
-- SmartMove Supabase Database Migration
-- Commodity Categories, Product Catalog, & Seller Upload Schema Update
-- Allows verified sellers (Traders) and Admins to create and manage commodity listings
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. COMMODITY CATEGORIES TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.commodity_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  icon_name TEXT,
  description TEXT,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_commodity_categories_slug ON public.commodity_categories(slug);

-- ------------------------------------------------------------------------------
-- 2. PRODUCTS TABLE ENHANCEMENTS FOR SELLER CONTRIBUTIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES public.commodity_categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS seller_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS brand_or_grade TEXT,
  ADD COLUMN IF NOT EXISTS base_unit TEXT NOT NULL DEFAULT 'kg',
  ADD COLUMN IF NOT EXISTS standardized_unit_price NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS channel TEXT NOT NULL DEFAULT 'Local Market',
  ADD COLUMN IF NOT EXISTS in_stock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS observation_count INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS source_type public.observation_source NOT NULL DEFAULT 'trader_provided';

CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_created_by ON public.products(created_by);
CREATE INDEX IF NOT EXISTS idx_products_channel ON public.products(channel);

-- ------------------------------------------------------------------------------
-- 3. PRICE OBSERVATIONS TABLE ENHANCEMENTS
-- ------------------------------------------------------------------------------
ALTER TABLE public.price_observations
  ADD COLUMN IF NOT EXISTS channel TEXT NOT NULL DEFAULT 'Local Market',
  ADD COLUMN IF NOT EXISTS brand_or_grade TEXT,
  ADD COLUMN IF NOT EXISTS in_stock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS standardized_unit_price NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS base_unit TEXT NOT NULL DEFAULT 'kg',
  ADD COLUMN IF NOT EXISTS is_flagged_anomaly BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS anomaly_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_price_observations_product ON public.price_observations(product_id);
CREATE INDEX IF NOT EXISTS idx_price_observations_submitter ON public.price_observations(submitter_id);
CREATE INDEX IF NOT EXISTS idx_price_observations_channel ON public.price_observations(channel);

-- ------------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) FOR SELLER UPLOADS & MANAGEMENT
-- ------------------------------------------------------------------------------

-- Enable RLS
ALTER TABLE public.commodity_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_observations ENABLE ROW LEVEL SECURITY;

-- Categories RLS
DROP POLICY IF EXISTS "Categories are viewable by everyone" ON public.commodity_categories;
CREATE POLICY "Categories are viewable by everyone"
  ON public.commodity_categories FOR SELECT
  USING (is_active = true OR true);

DROP POLICY IF EXISTS "Admins can manage categories" ON public.commodity_categories;
CREATE POLICY "Admins can manage categories"
  ON public.commodity_categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'Admin'
    )
  );

-- Products RLS: Allow Verified Traders and Admins to upload products
DROP POLICY IF EXISTS "Products are viewable by everyone" ON public.products;
CREATE POLICY "Products are viewable by everyone"
  ON public.products FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Verified sellers and admins can upload products" ON public.products;
CREATE POLICY "Verified sellers and admins can upload products"
  ON public.products FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND (p.role = 'Trader' OR p.role = 'Admin')
    )
  );

DROP POLICY IF EXISTS "Sellers and admins can update products" ON public.products;
CREATE POLICY "Sellers and admins can update products"
  ON public.products FOR UPDATE
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND p.role = 'Admin'
    )
  );

DROP POLICY IF EXISTS "Sellers and admins can delete products" ON public.products;
CREATE POLICY "Sellers and admins can delete products"
  ON public.products FOR DELETE
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND p.role = 'Admin'
    )
  );

-- Price Observations RLS: Allow Submitters and Admins to update / delete
DROP POLICY IF EXISTS "Submitters and admins can update observations" ON public.price_observations;
CREATE POLICY "Submitters and admins can update observations"
  ON public.price_observations FOR UPDATE
  USING (
    auth.uid() = submitter_id OR
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND p.role = 'Admin'
    )
  );

DROP POLICY IF EXISTS "Submitters and admins can delete observations" ON public.price_observations;
CREATE POLICY "Submitters and admins can delete observations"
  ON public.price_observations FOR DELETE
  USING (
    auth.uid() = submitter_id OR
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND p.role = 'Admin'
    )
  );

-- ------------------------------------------------------------------------------
-- 5. AUTOMATIC PRODUCT BEST PRICE & METRICS TRIGGER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_observation_inserted_metrics()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.product_id IS NOT NULL THEN
    -- Update lowest price and best seller if cheaper, increment observation count
    UPDATE public.products
    SET lowest_price = LEAST(public.products.lowest_price, NEW.price),
        best_seller_name = CASE 
          WHEN NEW.price <= public.products.lowest_price THEN NEW.seller_name 
          ELSE public.products.best_seller_name 
        END,
        observation_count = public.products.observation_count + 1,
        updated_at = timezone('utc'::text, now())
    WHERE id = NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_observation_inserted ON public.price_observations;
CREATE TRIGGER on_observation_inserted
  AFTER INSERT ON public.price_observations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_observation_inserted_metrics();

-- ------------------------------------------------------------------------------
-- 6. INITIAL SEED FOR COMMODITY CATEGORIES
-- ------------------------------------------------------------------------------
INSERT INTO public.commodity_categories (id, name, slug, icon_name, description, display_order) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Groceries', 'groceries', 'local_grocery_store_outlined', 'Fresh food produce, pantry goods, and everyday cooking items.', 1),
  ('c0000000-0000-0000-0000-000000000002', 'Grains & Flours', 'grains-flours', 'grain_outlined', 'Rice, beans, garri, semovita, wheat, and bulk staple flours.', 2),
  ('c0000000-0000-0000-0000-000000000003', 'Tubers & Produce', 'tubers-produce', 'eco_outlined', 'Yam, sweet potatoes, plantain, onions, and fresh vegetables.', 3),
  ('c0000000-0000-0000-0000-000000000004', 'Oils & Seasonings', 'oils-seasonings', 'soup_kitchen_outlined', 'Vegetable cooking oil, pure red palm oil, spices, and cubes.', 4),
  ('c0000000-0000-0000-0000-000000000005', 'Pharmacy & Health', 'pharmacy', 'local_pharmacy_outlined', 'Over-the-counter medicine, first aid, and personal healthcare.', 5),
  ('c0000000-0000-0000-0000-000000000006', 'Electronics & Gadgets', 'electronics', 'devices_outlined', 'Mobile cables, power banks, adapters, and home electronics.', 6),
  ('c0000000-0000-0000-0000-000000000007', 'Household & Provisions', 'household', 'home_work_outlined', 'Toiletries, laundry detergents, canned provisions, and cleaning items.', 7),
  ('c0000000-0000-0000-0000-000000000008', 'Others', 'others', 'more_horiz_rounded', 'General market merchandise and specialty products.', 8)
ON CONFLICT (name) DO NOTHING;

