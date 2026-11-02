-- ==============================================================================
-- SmartMove Supabase Database Migration
-- 1. Consolidate Food Categories (Groceries, Grains, Tubers, Oils -> Food)
-- 2. Explicit Unrestricted Delete RLS Policies for Observations and Products
-- ==============================================================================

-- 1. Ensure Food category exists
INSERT INTO public.commodity_categories (id, name, slug, icon_name, description, display_order)
VALUES ('cat-food', 'Food', 'food', 'restaurant_outlined', 'Groceries, grains, tubers, oils, seasonings, and cooking items', 1)
ON CONFLICT (id) DO UPDATE SET
  name = 'Food',
  slug = 'food',
  icon_name = 'restaurant_outlined',
  description = 'Groceries, grains, tubers, oils, seasonings, and cooking items',
  display_order = 1;

-- 2. Consolidate price_observations categories to 'Food'
UPDATE public.price_observations
SET category = 'Food'
WHERE LOWER(category) IN ('groceries', 'grains & flours', 'tubers & produce', 'oils & seasonings')
   OR LOWER(category) LIKE '%grain%'
   OR LOWER(category) LIKE '%tuber%'
   OR LOWER(category) LIKE '%oil%';

-- 3. Consolidate products categories to 'Food'
UPDATE public.products
SET category = 'Food'
WHERE LOWER(category) IN ('groceries', 'grains & flours', 'tubers & produce', 'oils & seasonings')
   OR LOWER(category) LIKE '%grain%'
   OR LOWER(category) LIKE '%tuber%'
   OR LOWER(category) LIKE '%oil%';

-- 4. Delete obsolete separate food categories from commodity_categories
DELETE FROM public.commodity_categories
WHERE LOWER(name) IN ('groceries', 'grains & flours', 'tubers & produce', 'oils & seasonings')
  AND id <> 'cat-food';

-- 5. Ensure explicit DELETE policies for anon and authenticated users
DROP POLICY IF EXISTS "Allow delete price observations" ON public.price_observations;
CREATE POLICY "Allow delete price observations"
  ON public.price_observations FOR DELETE
  USING (true);

DROP POLICY IF EXISTS "Allow delete products" ON public.products;
CREATE POLICY "Allow delete products"
  ON public.products FOR DELETE
  USING (true);

