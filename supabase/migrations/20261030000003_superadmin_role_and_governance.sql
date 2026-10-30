-- ==============================================================================
-- SmartMove Supabase Database Migration
-- SuperAdmin Role & Governance Schema Update
-- Adds 'SuperAdmin' value to user_role and updates RLS policies for moderation.
-- ==============================================================================

-- 1. Upgrade user_role enum to include SuperAdmin if not present
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'SuperAdmin';

-- 2. Update Seller Applications RLS: Admins & SuperAdmins can view and update all applications
DROP POLICY IF EXISTS "Users and admins can view seller applications" ON public.seller_applications;
CREATE POLICY "Users and admins can view seller applications"
  ON public.seller_applications FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND (p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
    )
  );

DROP POLICY IF EXISTS "Admins can update seller applications" ON public.seller_applications;
CREATE POLICY "Admins can update seller applications"
  ON public.seller_applications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND (p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
    )
  );

-- 3. Update Commodity Categories RLS: Admins & SuperAdmins can manage categories
DROP POLICY IF EXISTS "Admins can manage categories" ON public.commodity_categories;
CREATE POLICY "Admins can manage categories"
  ON public.commodity_categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND (p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
    )
  );

-- 4. Update Products RLS: Verified Traders, Admins, and SuperAdmins
DROP POLICY IF EXISTS "Verified sellers and admins can upload products" ON public.products;
CREATE POLICY "Verified sellers and admins can upload products"
  ON public.products FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND (p.role::text = 'Trader' OR p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
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
      AND (p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
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
      AND (p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
    )
  );

-- 5. Update Price Observations RLS: Submitters, Admins, and SuperAdmins can update/delete
DROP POLICY IF EXISTS "Submitters and admins can update observations" ON public.price_observations;
CREATE POLICY "Submitters and admins can update observations"
  ON public.price_observations FOR UPDATE
  USING (
    auth.uid() = submitter_id OR
    EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
      AND (p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
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
      AND (p.role::text = 'Admin' OR p.role::text = 'SuperAdmin')
    )
  );

