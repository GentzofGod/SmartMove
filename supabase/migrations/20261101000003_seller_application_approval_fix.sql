-- ==============================================================================
-- SmartMove Supabase Database Migration
-- Seller Application Approval Fix: Dynamic Role Promotion, GPS Sync & Moderation
-- ==============================================================================

-- 1. Make user_id nullable in seller_applications to allow applications prior to auth session linking
ALTER TABLE public.seller_applications
  ALTER COLUMN user_id DROP NOT NULL;

-- 2. Upgrade handle_seller_application_review trigger function
-- Syncs role promotion/demotion, business metadata, and verified GPS coordinates to public.profiles
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
        latitude = COALESCE(NEW.latitude, public.profiles.latitude),
        longitude = COALESCE(NEW.longitude, public.profiles.longitude),
        phone = COALESCE(NEW.phone, public.profiles.phone),
        seller_application_status = 'approved',
        updated_at = timezone('utc'::text, now())
    WHERE (NEW.user_id IS NOT NULL AND id = NEW.user_id)
       OR (NEW.applicant_email IS NOT NULL AND LOWER(email) = LOWER(NEW.applicant_email));
  ELSIF NEW.status = 'rejected' AND (OLD IS NULL OR OLD.status != 'rejected') THEN
    UPDATE public.profiles
    SET role = 'Customer',
        seller_application_status = 'rejected',
        updated_at = timezone('utc'::text, now())
    WHERE (NEW.user_id IS NOT NULL AND id = NEW.user_id)
       OR (NEW.applicant_email IS NOT NULL AND LOWER(email) = LOWER(NEW.applicant_email));
  ELSIF NEW.status = 'pending' THEN
    UPDATE public.profiles
    SET seller_application_status = 'pending',
        updated_at = timezone('utc'::text, now())
    WHERE (NEW.user_id IS NOT NULL AND id = NEW.user_id)
       OR (NEW.applicant_email IS NOT NULL AND LOWER(email) = LOWER(NEW.applicant_email));
  END IF;
  RETURN NEW;
END;
$$;

-- 3. Re-attach trigger
DROP TRIGGER IF EXISTS on_seller_application_status_changed ON public.seller_applications;
CREATE TRIGGER on_seller_application_status_changed
  AFTER INSERT OR UPDATE OF status ON public.seller_applications
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_seller_application_review();

