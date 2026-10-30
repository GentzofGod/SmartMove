-- ==============================================================================
-- SmartMove Supabase Database Migration
-- Seller Application & Role Governance Schema Update
-- All new accounts start as Customer; applying for seller status requires admin review.
-- ==============================================================================

-- 1. Upgrade user_role enum to include Admin if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t 
    JOIN pg_enum e ON t.oid = e.enumtypid 
    WHERE t.typname = 'user_role' AND e.enumlabel = 'Admin'
  ) THEN
    ALTER TYPE public.user_role ADD VALUE 'Admin';
  END IF;
END $$;

-- 2. Create seller_application_status enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'seller_application_status') THEN
    CREATE TYPE public.seller_application_status AS ENUM (
      'none',
      'pending',
      'approved',
      'rejected'
    );
  END IF;
END $$;

-- 3. Update profiles table with seller credentials & verification status
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS business_name TEXT,
  ADD COLUMN IF NOT EXISTS market_hub TEXT,
  ADD COLUMN IF NOT EXISTS seller_channel TEXT,
  ADD COLUMN IF NOT EXISTS stall_location TEXT,
  ADD COLUMN IF NOT EXISTS seller_application_status public.seller_application_status NOT NULL DEFAULT 'none';

-- 4. Create seller_applications table
CREATE TABLE IF NOT EXISTS public.seller_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  applicant_name TEXT NOT NULL,
  applicant_email TEXT NOT NULL,
  business_name TEXT NOT NULL,
  market_hub TEXT NOT NULL,
  seller_channel TEXT NOT NULL DEFAULT 'Local Market',
  stall_location TEXT,
  phone TEXT NOT NULL,
  status public.seller_application_status NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for fast query performance
CREATE INDEX IF NOT EXISTS idx_seller_applications_user ON public.seller_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_seller_applications_status ON public.seller_applications(status);

-- 5. Trigger to automatically promote profile when application is approved
CREATE OR REPLACE FUNCTION public.handle_seller_application_review()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD IS NULL OR OLD.status != 'approved') THEN
    UPDATE public.profiles
    SET role = 'Trader',
        business_name = NEW.business_name,
        market_hub = NEW.market_hub,
        seller_channel = NEW.seller_channel,
        stall_location = NEW.stall_location,
        phone = COALESCE(NEW.phone, public.profiles.phone),
        seller_application_status = 'approved',
        updated_at = timezone('utc'::text, now())
    WHERE id = NEW.user_id;
  ELSIF NEW.status = 'rejected' AND (OLD IS NULL OR OLD.status != 'rejected') THEN
    UPDATE public.profiles
    SET seller_application_status = 'rejected',
        updated_at = timezone('utc'::text, now())
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_seller_application_status_changed ON public.seller_applications;
CREATE TRIGGER on_seller_application_status_changed
  AFTER INSERT OR UPDATE OF status ON public.seller_applications
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_seller_application_review();

-- 6. Row Level Security (RLS) Policies
ALTER TABLE public.seller_applications ENABLE ROW LEVEL SECURITY;

-- Customers can submit applications for their own user_id
DROP POLICY IF EXISTS "Users can submit their own seller application" ON public.seller_applications;
CREATE POLICY "Users can submit their own seller application"
  ON public.seller_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Customers can view their own application, Admins can view all applications
DROP POLICY IF EXISTS "Users and admins can view seller applications" ON public.seller_applications;
CREATE POLICY "Users and admins can view seller applications"
  ON public.seller_applications FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'Admin'
    )
  );

-- Admins can update applications (Approve / Reject)
DROP POLICY IF EXISTS "Admins can update seller applications" ON public.seller_applications;
CREATE POLICY "Admins can update seller applications"
  ON public.seller_applications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'Admin'
    )
  );
