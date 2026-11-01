-- ==============================================================================
-- SmartMove Supabase Database Migration
-- Store Edit Verification, Password Reset Tokens & High-Precision GPS Coordinates
-- ==============================================================================

-- 1. Add GPS Coordinate Columns to seller_applications and profiles
ALTER TABLE public.seller_applications
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7),
  ADD COLUMN IF NOT EXISTS has_pending_store_edit BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS pending_store_edit_summary TEXT;

-- 2. Create store_edit_requests table for marketplace credibility governance
CREATE TABLE IF NOT EXISTS public.store_edit_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for query optimization
CREATE INDEX IF NOT EXISTS idx_store_edit_requests_seller ON public.store_edit_requests(seller_id);
CREATE INDEX IF NOT EXISTS idx_store_edit_requests_status ON public.store_edit_requests(status);

-- Trigger to apply approved store profile edits automatically to profiles table
CREATE OR REPLACE FUNCTION public.handle_store_edit_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    UPDATE public.profiles
    SET
      business_name = NEW.proposed_business_name,
      market_hub = NEW.proposed_market_hub,
      stall_location = NEW.proposed_stall_location,
      phone = NEW.proposed_phone,
      seller_channel = NEW.proposed_seller_channel,
      has_pending_store_edit = false,
      pending_store_edit_summary = NULL,
      updated_at = timezone('utc'::text, now())
    WHERE id = NEW.seller_id;
  ELSIF NEW.status = 'rejected' AND OLD.status != 'rejected' THEN
    UPDATE public.profiles
    SET
      has_pending_store_edit = false,
      pending_store_edit_summary = NULL,
      updated_at = timezone('utc'::text, now())
    WHERE id = NEW.seller_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_store_edit_reviewed ON public.store_edit_requests;
CREATE TRIGGER on_store_edit_reviewed
  AFTER UPDATE OF status ON public.store_edit_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_store_edit_approval();

-- 3. Password Reset Tokens Table (6-digit numeric OTP without confirmation links)
CREATE TABLE IF NOT EXISTS public.password_resets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  token TEXT NOT NULL, -- 6-digit numeric token e.g. '849201'
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_password_resets_email_token ON public.password_resets(email, token);

-- 4. Row-Level Security (RLS) Policies
ALTER TABLE public.store_edit_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_resets ENABLE ROW LEVEL SECURITY;

-- Sellers can create and view their own edit requests
CREATE POLICY "Sellers can view own store edit requests"
  ON public.store_edit_requests FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can insert own store edit requests"
  ON public.store_edit_requests FOR INSERT
  WITH CHECK (auth.uid() = seller_id);

-- Admins can view and moderate all store edit requests
CREATE POLICY "Admins can view and moderate all store edit requests"
  ON public.store_edit_requests FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND (profiles.role = 'Admin' OR profiles.role = 'SuperAdmin')
    )
  );
