-- ==============================================================================
-- SmartMove Supabase Database Migration
-- Persistent Negotiation Messages & Direct Buyer-Seller Chat Table
-- ==============================================================================

-- 1. Create negotiation_messages table for buyer-seller direct messaging
CREATE TABLE IF NOT EXISTS public.negotiation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_key TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  sender_name TEXT NOT NULL,
  recipient_id TEXT,
  is_trader BOOLEAN NOT NULL DEFAULT false,
  message_text TEXT NOT NULL,
  proposed_price NUMERIC(12, 2),
  commodity_name TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Query performance indexes
CREATE INDEX IF NOT EXISTS idx_negotiation_messages_conv ON public.negotiation_messages(conversation_key);
CREATE INDEX IF NOT EXISTS idx_negotiation_messages_created ON public.negotiation_messages(created_at ASC);
CREATE INDEX IF NOT EXISTS idx_negotiation_messages_sender ON public.negotiation_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_negotiation_messages_recipient ON public.negotiation_messages(recipient_id);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.negotiation_messages ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies: Allow shoppers and verified traders to read and post negotiation messages
CREATE POLICY "Allow public read access to negotiation_messages"
  ON public.negotiation_messages FOR SELECT
  USING (true);

CREATE POLICY "Allow public insert access to negotiation_messages"
  ON public.negotiation_messages FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow participants to update read status"
  ON public.negotiation_messages FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- 5. Enable Supabase Realtime for live instant chat updates
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.negotiation_messages;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

