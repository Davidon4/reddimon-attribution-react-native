-- Function to automatically set updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';


-- Create publishers table
create table publishers (
  id uuid references auth.users not null primary key,
  full_name text,
  email text,
  bio text,
  total_campaigns integer default 0,
  total_invites_sent integer default 0,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table publishers enable row level security;
create policy "Can view own publisher data." on publishers for select using (auth.uid() = id);
create policy "Can update own publisher data." on publishers for update using (auth.uid() = id);

/**
* This trigger automatically creates a publisher entry when a new user signs up via Supabase Auth.
*/ 
create function public.handle_new_publisher() 
returns trigger as $$
begin
  insert into public.publishers (id, full_name, email)
  values (new.id, new.raw_user_meta_data->>'full_name', new.email);
  return new;
end;
$$ language plpgsql security definer;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_publisher();

-- Create API keys table
CREATE TABLE publisher_api_keys (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  publisher_id UUID REFERENCES publishers(id) NOT NULL,
  name TEXT NOT NULL,                    -- Description/name for the key
  api_key TEXT UNIQUE NOT NULL,          -- The actual API key
  environment TEXT NOT NULL              -- 'development' or 'production'
    CHECK (environment IN ('development', 'production')),
  status TEXT DEFAULT 'active'           -- 'active' or 'revoked'
    CHECK (status IN ('active', 'revoked')),
  last_used_at TIMESTAMPTZ,             -- Track key usage
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  revoked_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE publisher_api_keys ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Publishers can view their own API keys"
  ON publisher_api_keys FOR SELECT
  USING (publisher_id = auth.uid());

-- Function to generate secure API key
CREATE OR REPLACE FUNCTION generate_api_key(prefix TEXT)
RETURNS TEXT AS $$
DECLARE
  key_bytes BYTEA;
  base64_key TEXT;
BEGIN
  -- Generate 32 random bytes
  key_bytes := gen_random_bytes(32);
  -- Convert to base64 and remove padding
  base64_key := replace(encode(key_bytes, 'base64'), '=', '');
  -- Add prefix and return
  RETURN prefix || '_' || base64_key;
END;
$$ LANGUAGE plpgsql;

-- Function to create new API key
CREATE OR REPLACE FUNCTION create_publisher_api_key(
  publisher_id UUID,
  key_name TEXT,
  env TEXT
) RETURNS TEXT AS $$
DECLARE
  new_key TEXT;
BEGIN
  -- Generate key with prefix based on environment
  new_key := CASE env
    WHEN 'production' THEN generate_api_key('pub_live')
    ELSE generate_api_key('pub_test')
  END;
  
  -- Insert new key
  INSERT INTO publisher_api_keys (
    publisher_id,
    name,
    api_key,
    environment
  ) VALUES (
    publisher_id,
    key_name,
    new_key,
    env
  );
  
  RETURN new_key;
END;
$$ LANGUAGE plpgsql;

-- Create campaigns table
CREATE TABLE publisher_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  publisher_id UUID NOT NULL REFERENCES publishers(id),
  name TEXT NOT NULL,
  description TEXT,
  campaign_type TEXT NOT NULL,
  app_name TEXT NOT NULL,
  campaign_identifier TEXT NOT NULL,
  payout_amount DECIMAL NOT NULL,
  app_identifiers JSONB,
  target_audience TEXT,
  key_features TEXT[],
  keywords TEXT[],
  requirements JSONB,
  suggested_captions TEXT[],
  promotional_materials JSONB,
  total_creators INTEGER DEFAULT 0,
  active_creators INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_status CHECK (status IN ('draft', 'active', 'paused', 'completed', 'cancelled')),
  total_subscriptions INTEGER DEFAULT 0,
  total_installations INTEGER DEFAULT 0,
  total_revenue DECIMAL DEFAULT 0,
  total_clicks INTEGER DEFAULT 0,
  total_payout_amount DECIMAL DEFAULT 0
);

-- Enable RLS on publisher_campaigns
ALTER TABLE publisher_campaigns ENABLE ROW LEVEL SECURITY;

-- Create trigger function to update publisher campaign count
CREATE OR REPLACE FUNCTION update_publisher_campaign_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE publishers 
    SET total_campaigns = total_campaigns + 1,
        updated_at = now()
    WHERE id = NEW.publisher_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE publishers 
    SET total_campaigns = total_campaigns - 1,
        updated_at = now()
    WHERE id = OLD.publisher_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for insert and delete operations
DROP TRIGGER IF EXISTS on_campaign_change ON publisher_campaigns;
CREATE TRIGGER on_campaign_change
  AFTER INSERT OR DELETE ON publisher_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_publisher_campaign_count();

-- Publishers can view their own campaigns
CREATE POLICY "Publishers can view own campaigns"
  ON publisher_campaigns
  FOR SELECT
  USING (publisher_id IN (
    SELECT id FROM publishers WHERE id = auth.uid()
  ));

-- Publishers can insert their own campaigns
CREATE POLICY "Publishers can insert own campaigns"
  ON publisher_campaigns
  FOR INSERT
  WITH CHECK (publisher_id IN (
    SELECT id FROM publishers WHERE id = auth.uid()
  ));

  -- Add this policy if not exists
CREATE POLICY "Anyone can read campaigns"
ON publisher_campaigns
FOR SELECT
TO authenticated
USING (true);

-- Publishers can update their own campaigns
CREATE POLICY "Publishers can update own campaigns"
  ON publisher_campaigns
  FOR UPDATE
  USING (publisher_id IN (
    SELECT id FROM publishers WHERE id = auth.uid()
  ));

-- Publishers can delete their own campaigns
CREATE POLICY "Publishers can delete own campaigns"
  ON publisher_campaigns
  FOR DELETE
  USING (publisher_id IN (
    SELECT id FROM publishers WHERE id = auth.uid()
  ));

-- Create table creator_invites
CREATE TABLE creator_invites (
  id uuid primary key default uuid_generate_v4(), 
  publisher_id uuid references publishers(id) not null,
  campaign_id uuid references publisher_campaigns(id) not null,
  invite_token text unique not null,
  social_platform text not null,
  social_handle text not null,
  followers numeric(10,2),
  status text default 'pending', -- pending, accepted, rejected
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Enable RLS on creator_invites
ALTER TABLE creator_invites ENABLE ROW LEVEL SECURITY;

-- Policies for creator_invites

-- Publishers can view their own invites
CREATE POLICY "Publishers can view own invites"
  ON creator_invites
  FOR SELECT
  TO authenticated
  USING (auth.uid() = publisher_id);

-- Publishers can create invites for their campaigns
CREATE POLICY "Publishers can create invites"
  ON creator_invites
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = publisher_id AND
    EXISTS (
      SELECT 1 FROM publisher_campaigns
      WHERE id = campaign_id AND publisher_id = auth.uid()
    )
  );

-- Publishers can update their own invites
CREATE POLICY "Publishers can update own invites"
  ON creator_invites
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = publisher_id)
  WITH CHECK (auth.uid() = publisher_id);

-- Publishers can delete their own invites
CREATE POLICY "Publishers can delete own invites"
  ON creator_invites
  FOR DELETE
  TO authenticated
  USING (auth.uid() = publisher_id);

  CREATE POLICY "Public invite token access"
  ON creator_invites
  FOR SELECT
  TO public  -- Allowing public access
  USING (status = 'pending');

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION update_creator_invites_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_creator_invites_timestamp
  BEFORE UPDATE ON creator_invites
  FOR EACH ROW
  EXECUTE FUNCTION update_creator_invites_timestamp();

-- Trigger to increment/decrement active creators count
CREATE OR REPLACE FUNCTION update_campaign_creator_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status != NEW.status THEN
      IF NEW.status = 'accepted' THEN
        -- Increment active_creators when invite is accepted
        UPDATE publisher_campaigns
        SET active_creators = active_creators + 1,
            total_creators = total_creators + 1
        WHERE id = NEW.campaign_id;
      ELSIF OLD.status = 'accepted' AND NEW.status != 'accepted' THEN
        -- Decrement active_creators when invite is no longer accepted
        UPDATE publisher_campaigns
        SET active_creators = active_creators - 1
        WHERE id = NEW.campaign_id;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_campaign_creator_count
  AFTER UPDATE ON creator_invites
  FOR EACH ROW
  EXECUTE FUNCTION update_campaign_creator_count();

-- Create table creator_campaign_memberships with proper foreign keys
CREATE TABLE creator_campaign_memberships (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  creator_id uuid REFERENCES creators(id) NOT NULL,
  campaign_id uuid REFERENCES publisher_campaigns(id) NOT NULL,
  publisher_id uuid REFERENCES publishers(id) NOT NULL,
  status text DEFAULT 'pending' 
    CHECK (status IN ('pending', 'invited', 'accepted', 'rejected', 'active', 'inactive')),
  invited_at timestamptz DEFAULT now(),
  joined_at timestamptz,
  left_at timestamptz,
  performance_metrics jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(creator_id, campaign_id)
);

-- Enable RLS
ALTER TABLE creator_campaign_memberships ENABLE ROW LEVEL SECURITY;

-- Add policies
CREATE POLICY "Creators can view own memberships"
ON creator_campaign_memberships
FOR SELECT
TO authenticated
USING (creator_id = auth.uid());

CREATE POLICY "Publishers can view campaign memberships"
ON creator_campaign_memberships
FOR SELECT
TO authenticated
USING (publisher_id = auth.uid());

-- Add INSERT policy for creator_campaign_memberships
CREATE POLICY "Allow creator membership creation"
ON creator_campaign_memberships
FOR INSERT
TO authenticated
WITH CHECK (
  -- Allow insert if the user is the creator
  auth.uid() = creator_id
  OR
  -- OR if the user is the publisher of the campaign
  EXISTS (
    SELECT 1 FROM publisher_campaigns
    WHERE publisher_campaigns.id = campaign_id
    AND publisher_campaigns.publisher_id = auth.uid()
  )
);

-- Add UPDATE policy
CREATE POLICY "Allow membership updates"
ON creator_campaign_memberships
FOR UPDATE
TO authenticated
USING (
  creator_id = auth.uid()
  OR
  publisher_id = auth.uid()
)
WITH CHECK (
  creator_id = auth.uid()
  OR
  publisher_id = auth.uid()
);

-- Add DELETE policy
CREATE POLICY "Allow membership deletion"
ON creator_campaign_memberships
FOR DELETE
TO authenticated
USING (
  creator_id = auth.uid()
  OR
  publisher_id = auth.uid()
);

-- Add indexes for better performance
CREATE INDEX idx_memberships_creator ON creator_campaign_memberships(creator_id);
CREATE INDEX idx_memberships_campaign ON creator_campaign_memberships(campaign_id);
CREATE INDEX idx_memberships_publisher ON creator_campaign_memberships(publisher_id);

-- Create table creators
CREATE TABLE creators (
  id uuid references auth.users not null primary key,
  full_name text not null,
  email text,
  social_handle text not null,
  social_platform text not null,
  followers numeric(10,2),
  status text default 'active',
  
  -- Performance Metrics
  total_campaigns INTEGER DEFAULT 0,      -- Number of campaigns joined
  total_clicks INTEGER DEFAULT 0,         -- Total clicks across all campaigns
  total_installs INTEGER DEFAULT 0,       -- Total app installs
  total_subscriptions INTEGER DEFAULT 0,  -- Total subscriptions generated
  total_revenue DECIMAL DEFAULT 0,        -- Total revenue generated
  total_payout_amount DECIMAL DEFAULT 0,  -- Total earnings
  
  -- Payout Info
  payout_details JSONB,                   -- Store payment account details
  
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Function to update creator totals
CREATE OR REPLACE FUNCTION update_creator_metrics()
RETURNS TRIGGER AS $$
BEGIN
  -- Update creator's overall metrics
  UPDATE creators
  SET total_clicks = (
    SELECT COALESCE(SUM(clicks), 0)
    FROM creator_attribution_links
    WHERE creator_id = NEW.creator_id
  ),
  total_installs = (
    SELECT COALESCE(SUM(total_installs), 0)
    FROM creator_attribution_links
    WHERE creator_id = NEW.creator_id
  ),
  total_subscriptions = (
    SELECT COALESCE(SUM(total_subscriptions), 0)
    FROM creator_attribution_links
    WHERE creator_id = NEW.creator_id
  ),
  total_revenue = (
    SELECT COALESCE(SUM(total_revenue), 0)
    FROM creator_attribution_links
    WHERE creator_id = NEW.creator_id
  ),
  total_payout_amount = (
    SELECT COALESCE(SUM(total_payout_amount), 0)
    FROM creator_attribution_links
    WHERE creator_id = NEW.creator_id
  ),
  updated_at = NOW()
  WHERE id = NEW.creator_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for creator_attribution_links
CREATE TRIGGER update_creator_metrics
  AFTER UPDATE OF clicks, total_installs, total_subscriptions, total_revenue, total_payout_amount
  ON creator_attribution_links
  FOR EACH ROW
  EXECUTE FUNCTION update_creator_metrics();

-- Create trigger for campaign memberships
CREATE TRIGGER update_creator_campaign_count
  AFTER INSERT OR DELETE ON creator_campaign_memberships
  FOR EACH ROW
  EXECUTE FUNCTION update_creator_campaign_count();

-- Function to update campaign count
CREATE OR REPLACE FUNCTION update_creator_campaign_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE creators 
    SET total_campaigns = total_campaigns + 1,
        updated_at = NOW()
    WHERE id = NEW.creator_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE creators 
    SET total_campaigns = total_campaigns - 1,
        updated_at = NOW()
    WHERE id = OLD.creator_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create clicks tracking table
CREATE TABLE campaign_clicks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  campaign_id UUID REFERENCES publisher_campaigns(id),
  device_type TEXT,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ip_address TEXT
);

-- Add RLS policy
CREATE POLICY "Enable insert for authenticated users only"
ON public.campaign_clicks
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Add RLS policy for viewing clicks
CREATE POLICY "Enable select for campaign owners"
ON public.campaign_clicks
FOR SELECT
USING (
  EXISTS (
    SELECT 1 
    FROM publisher_campaigns pc
    WHERE pc.id = campaign_clicks.campaign_id
    AND pc.publisher_id = auth.uid()
  )
);

-- Create a table for creator attribution links
CREATE TABLE creator_attribution_links (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  creator_id UUID REFERENCES auth.users(id),
  campaign_id UUID REFERENCES publisher_campaigns(id),
  short_code TEXT UNIQUE,
  clicks INTEGER DEFAULT 0,
  total_installs INTEGER DEFAULT 0,
  total_subscriptions INTEGER DEFAULT 0,
  total_revenue DECIMAL DEFAULT 0,
  total_payout_amount DECIMAL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(creator_id, campaign_id)
);

-- Add RLS policy
CREATE POLICY "Enable select for authenticated users"
ON public.creator_attribution_links
FOR SELECT
TO authenticated
USING (true);

-- Add insert policy
CREATE POLICY "Enable insert for authenticated users"
ON public.creator_attribution_links
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = creator_id);

-- Add update policy for click counting
CREATE POLICY "Enable update for click counting"
ON public.creator_attribution_links
FOR UPDATE
USING (true);

-- Function to increment link clicks
CREATE OR REPLACE FUNCTION increment_link_clicks(p_link_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE creator_links
    SET total_clicks = total_clicks + 1,
        updated_at = now()
    WHERE id = p_link_id;
END;
$$ LANGUAGE plpgsql;

-- Function to record install
CREATE OR REPLACE FUNCTION record_link_install(p_link_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE creator_links
    SET total_installs = total_installs + 1,
        updated_at = now()
    WHERE id = p_link_id;
END;
$$ LANGUAGE plpgsql;

-- Function to record activation
CREATE OR REPLACE FUNCTION record_link_activation(p_link_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE creator_links
    SET total_activations = total_activations + 1,
        updated_at = now()
    WHERE id = p_link_id;
END;
$$ LANGUAGE plpgsql;

-- Function to record subscription
CREATE OR REPLACE FUNCTION record_link_subscription(p_link_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE creator_links
    SET total_subscriptions = total_subscriptions + 1,
        updated_at = now()
    WHERE id = p_link_id;
END;
$$ LANGUAGE plpgsql;

-- Create subscriptions table
CREATE TABLE campaign_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES publisher_campaigns(id) NOT NULL,
  creator_id UUID REFERENCES creators(id) NOT NULL,
  publisher_id UUID REFERENCES publishers(id) NOT NULL,
  subscription_id TEXT NOT NULL,
  plan_type TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  currency TEXT NOT NULL,
  payout_amount DECIMAL NOT NULL,  -- From campaign's payout_amount
  status TEXT DEFAULT 'active' 
    CHECK (status IN ('active', 'cancelled', 'expired')),
  subscription_date TIMESTAMPTZ DEFAULT NOW(),
  interval TEXT NOT NULL,          -- monthly/yearly
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE campaign_subscriptions ENABLE ROW LEVEL SECURITY;

-- Add policies
CREATE POLICY "Publishers can view campaign subscriptions"
ON campaign_subscriptions
FOR SELECT
TO authenticated
USING (publisher_id = auth.uid());

CREATE POLICY "Creators can view own attributed subscriptions"
ON campaign_subscriptions
FOR SELECT
TO authenticated
USING (creator_id = auth.uid());

-- Add tracking function
CREATE OR REPLACE FUNCTION handle_subscription_event()
RETURNS TRIGGER AS $$
BEGIN
  -- Update creator metrics
  UPDATE creator_attribution_links
  SET total_subscriptions = total_subscriptions + 1,
      total_revenue = total_revenue + NEW.amount,
      total_payout_amount = total_payout_amount + NEW.payout_amount,
      updated_at = NOW()
  WHERE campaign_id = NEW.campaign_id 
  AND creator_id = NEW.creator_id;

  -- Update publisher campaign metrics
  UPDATE publisher_campaigns
  SET total_subscriptions = total_subscriptions + 1,
      total_revenue = total_revenue + NEW.amount,
      total_payout_amount = total_payout_amount + NEW.payout_amount,
      updated_at = NOW()
  WHERE id = NEW.campaign_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for subscription events
CREATE TRIGGER on_subscription_event
  AFTER INSERT ON campaign_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION handle_subscription_event();

-- Create installations table
CREATE TABLE campaign_installations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES publisher_campaigns(id) NOT NULL,
  creator_id UUID REFERENCES creators(id) NOT NULL,
  publisher_id UUID REFERENCES publishers(id) NOT NULL,
  
  -- Device Info
  platform TEXT NOT NULL,          -- ios/android
  
  -- Location Data (if available)
  country TEXT,
  region TEXT,
  city TEXT,
  
  -- Attribution Data
  attribution_url TEXT,            -- Original deep link URL
  install_source TEXT,             -- App Store, Play Store
  
  -- Timestamps
  install_date TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create function to handle installation events
CREATE OR REPLACE FUNCTION handle_installation_event()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. Update creator metrics
  UPDATE creator_attribution_links
  SET total_installs = total_installs + 1,
      updated_at = NOW()
  WHERE campaign_id = NEW.campaign_id 
  AND creator_id = NEW.creator_id;

  -- 2. Update publisher campaign metrics
  UPDATE publisher_campaigns
  SET total_installs = total_installs + 1,
      updated_at = NOW()
  WHERE id = NEW.campaign_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for installation events
CREATE TRIGGER on_installation_event
  AFTER INSERT ON campaign_installations
  FOR EACH ROW
  EXECUTE FUNCTION handle_installation_event();

-- Add RLS policies
ALTER TABLE campaign_installations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Publishers can view campaign installations"
ON campaign_installations
FOR SELECT
TO authenticated
USING (publisher_id = auth.uid());

CREATE POLICY "Creators can view own attributed installations"
ON campaign_installations
FOR SELECT
TO authenticated
USING (creator_id = auth.uid());

-- Update function to handle installation events and update all metrics
CREATE OR REPLACE FUNCTION handle_installation_event()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. Update creator attribution link metrics
  UPDATE creator_attribution_links
  SET total_installs = total_installs + 1,
      updated_at = NOW()
  WHERE campaign_id = NEW.campaign_id 
  AND creator_id = NEW.creator_id;

  -- 2. Update publisher campaign metrics
  UPDATE publisher_campaigns
  SET total_installations = total_installations + 1,  -- Note: using total_installations to match table column
      updated_at = NOW()
  WHERE id = NEW.campaign_id;

  -- 3. Update creator's total metrics
  UPDATE creators
  SET total_installs = total_installs + 1,
      updated_at = NOW()
  WHERE id = NEW.creator_id;

  -- 4. Update publisher's metrics if needed
  UPDATE publishers
  SET updated_at = NOW()
  WHERE id = NEW.publisher_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create revenue table for financial tracking
CREATE TABLE campaign_revenue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id UUID REFERENCES campaign_subscriptions(id),
  campaign_id UUID REFERENCES publisher_campaigns(id),
  creator_id UUID REFERENCES creators(id),
  publisher_id UUID REFERENCES publishers(id),
  
  -- Financial Data
  amount DECIMAL NOT NULL,
  payout_amount DECIMAL NOT NULL,
  currency TEXT NOT NULL,
  
  -- Revenue Type   
  interval TEXT NOT NULL,           -- 'monthly', 'yearly'
  
  -- Status
  status TEXT DEFAULT 'pending'     -- 'pending', 'paid', 'failed'
    CHECK (status IN ('pending', 'paid', 'failed')),
  
  -- Dates
  subscription_date TIMESTAMPTZ DEFAULT NOW(),
  payout_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE campaign_revenue ENABLE ROW LEVEL SECURITY;

-- Add policies
CREATE POLICY "Publishers can view campaign revenue"
ON campaign_revenue
FOR SELECT
TO authenticated
USING (publisher_id = auth.uid());

CREATE POLICY "Creators can view own revenue"
ON campaign_revenue
FOR SELECT
TO authenticated
USING (creator_id = auth.uid());

-- Update campaign_revenue table to handle multiple revenue types
ALTER TABLE campaign_revenue 
  ADD COLUMN revenue_type TEXT NOT NULL DEFAULT 'subscription'
    CHECK (revenue_type IN ('subscription', 'install', 'click')),
  ADD COLUMN installation_id UUID REFERENCES campaign_installations(id),
  ADD COLUMN click_id UUID REFERENCES campaign_clicks(id);

-- Create trigger to update campaign metrics
CREATE OR REPLACE FUNCTION update_campaign_revenue()
RETURNS TRIGGER AS $$
BEGIN
  -- Update publisher campaign totals
  UPDATE publisher_campaigns
  SET total_revenue = total_revenue + NEW.amount
  WHERE id = NEW.campaign_id;
  
  -- Update creator metrics
  UPDATE creator_attribution_links
  SET total_revenue = total_revenue + NEW.payout_amount
  WHERE campaign_id = NEW.campaign_id 
  AND creator_id = NEW.creator_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update trigger function to handle all revenue types
CREATE OR REPLACE FUNCTION update_campaign_revenue()
RETURNS TRIGGER AS $$
BEGIN
  -- Update publisher campaign totals
  UPDATE publisher_campaigns
  SET total_revenue = total_revenue + NEW.amount,
      total_payout_amount = total_payout_amount + NEW.payout_amount
  WHERE id = NEW.campaign_id;
  
  -- Update creator attribution metrics
  UPDATE creator_attribution_links
  SET total_revenue = total_revenue + NEW.payout_amount
  WHERE campaign_id = NEW.campaign_id 
  AND creator_id = NEW.creator_id;

  -- Update specific metrics based on revenue type
  CASE NEW.revenue_type
    WHEN 'subscription' THEN
      -- Existing subscription logic
      NULL;
    WHEN 'install' THEN
      UPDATE creator_attribution_links
      SET total_installs = total_installs + 1
      WHERE campaign_id = NEW.campaign_id 
      AND creator_id = NEW.creator_id;
    WHEN 'click' THEN
      UPDATE creator_attribution_links
      SET clicks = clicks + 1
            WHERE campaign_id = NEW.campaign_id 
      AND creator_id = NEW.creator_id;
  END CASE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER on_revenue_created
  AFTER INSERT ON campaign_revenue
  FOR EACH ROW
  EXECUTE FUNCTION update_campaign_revenue();

-- Drop existing views and functions
DROP VIEW IF EXISTS creator_revenue_metrics CASCADE;
DROP VIEW IF EXISTS creator_attribution_metrics CASCADE;
DROP FUNCTION IF EXISTS get_creator_revenue_metrics(UUID);
DROP FUNCTION IF EXISTS get_creator_attribution_metrics(UUID);

-- Create views with proper RLS
CREATE VIEW creator_revenue_metrics AS
SELECT 
  cr.creator_id,
  pc.name as campaign_name,
  COUNT(DISTINCT cs.id)::BIGINT as total_subscribers,
  SUM(cr.amount) as total_revenue,
  SUM(cr.payout_amount) as total_earnings,
  cr.currency,
  cr.status as payment_status
FROM campaign_revenue cr
JOIN campaign_subscriptions cs ON cr.subscription_id = cs.id
JOIN publisher_campaigns pc ON cr.campaign_id = pc.id
GROUP BY 
  cr.creator_id,
  pc.name,
  cr.currency,
  cr.status;

CREATE VIEW creator_attribution_metrics AS
SELECT 
  cal.creator_id,
  pc.name as campaign_name,
  cal.short_code as attribution_link,
  COUNT(DISTINCT ci.id)::BIGINT as total_installations,
  COUNT(DISTINCT cs.id)::BIGINT as total_subscriptions,
  cal.clicks as total_clicks,
  ci.country,
  ci.platform
FROM creator_attribution_links cal
LEFT JOIN campaign_installations ci ON cal.campaign_id = ci.campaign_id 
  AND cal.creator_id = ci.creator_id
LEFT JOIN campaign_subscriptions cs ON cal.campaign_id = cs.campaign_id 
  AND cal.creator_id = cs.creator_id
JOIN publisher_campaigns pc ON cal.campaign_id = pc.id
GROUP BY 
  cal.creator_id,
  pc.name,
  cal.short_code,
  cal.clicks,
  ci.country,
  ci.platform;

-- Enable RLS
ALTER VIEW creator_revenue_metrics SET (security_invoker = true);
ALTER VIEW creator_attribution_metrics SET (security_invoker = true);

-- Create RLS policies for the underlying tables if not exists
CREATE POLICY IF NOT EXISTS "Users can view their own revenue data"
ON campaign_revenue
FOR SELECT
USING (
  creator_id = auth.uid() OR 
  publisher_id = auth.uid()
);

CREATE POLICY IF NOT EXISTS "Users can view their own attribution data"
ON creator_attribution_links
FOR SELECT
USING (
  creator_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM publisher_campaigns pc
    WHERE pc.id = campaign_id
    AND pc.publisher_id = auth.uid()
  )
);

-- Grant access
GRANT SELECT ON creator_revenue_metrics TO authenticated;
GRANT SELECT ON creator_attribution_metrics TO authenticated;

  -- Store Stripe accounts for creators
create table creator_payment_accounts (
  id uuid REFERENCES creators(id) PRIMARY KEY,
  stripe_account_id text NOT NULL,
  onboarded boolean DEFAULT false,        -- Track if they've completed Stripe onboarding
  requirements_due text[],               -- Any pending Stripe requirements
  payouts_enabled boolean DEFAULT false,  -- If their account can receive payouts
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Store payment transactions
create table payment_transactions (
  id uuid primary key default uuid_generate_v4(),
  publisher_id uuid references publishers(id) not null,
  creator_id uuid references creators(id) not null,
  campaign_id uuid references publisher_campaigns(id) not null,
  amount decimal not null,
  currency text default 'usd',
  status text default 'pending',
  stripe_payment_intent_id text,
  stripe_transfer_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table creator_payment_accounts enable row level security;
alter table payment_transactions enable row level security;

-- RLS policies
create policy "Creators can view their own payment account"
  on creator_payment_accounts for select
  using (auth.uid() = id);

create policy "Creators can update their own payment account"
  on creator_payment_accounts for update
  using (auth.uid() = id);

create policy "Publishers can view payments they made"
  on payment_transactions for select
  using (auth.uid() = publisher_id);

create policy "Creators can view payments they received"
  on payment_transactions for select
  using (auth.uid() = creator_id);

-- Trigger to update updated_at
create trigger set_updated_at
  before update on payment_transactions
  for each row
  execute function update_updated_at_column();