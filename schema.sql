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
  payment_method TEXT NOT NULL,
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
  CONSTRAINT valid_status CHECK (status IN ('draft', 'active', 'paused', 'completed', 'cancelled'))
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
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

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
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
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

-- Create attribution events table
CREATE TABLE attribution_events (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  link_id UUID REFERENCES creator_attribution_links(id),
  creator_id UUID REFERENCES creators(id),
  campaign_id UUID REFERENCES publisher_campaigns(id),
  event_type TEXT NOT NULL CHECK (event_type IN ('installation', 'subscription', 'activation')),
  device_info JSONB,
  metadata JSONB,
  session_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  amount DECIMAL,
  currency TEXT,
  subscription_id TEXT,
  plan_type TEXT
);

-- Add columns to creator_attribution_links for tracking stats
ALTER TABLE creator_attribution_links ADD COLUMN IF NOT EXISTS total_installs INTEGER DEFAULT 0;
ALTER TABLE creator_attribution_links ADD COLUMN IF NOT EXISTS total_subscriptions INTEGER DEFAULT 0;
ALTER TABLE creator_attribution_links ADD COLUMN IF NOT EXISTS total_activations INTEGER DEFAULT 0;
ALTER TABLE creator_attribution_links ADD COLUMN IF NOT EXISTS total_revenue DECIMAL DEFAULT 0;
ALTER TABLE creator_attribution_links ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create trigger function to update attribution stats
CREATE OR REPLACE FUNCTION update_attribution_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update stats based on event type
  IF NEW.event_type = 'installation' THEN
    UPDATE creator_attribution_links
    SET total_installs = total_installs + 1,
        updated_at = NOW()
    WHERE id = NEW.link_id;
  
  ELSIF NEW.event_type = 'subscription' THEN
    UPDATE creator_attribution_links
    SET total_subscriptions = total_subscriptions + 1,
        total_revenue = total_revenue + COALESCE(NEW.amount, 0),
        updated_at = NOW()
    WHERE id = NEW.link_id;
  
  ELSIF NEW.event_type = 'activation' THEN
    UPDATE creator_attribution_links
    SET total_activations = total_activations + 1,
        updated_at = NOW()
    WHERE id = NEW.link_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on attribution_events
CREATE TRIGGER on_attribution_event
  AFTER INSERT ON attribution_events
  FOR EACH ROW
  EXECUTE FUNCTION update_attribution_stats();

-- Add RLS policies for attribution_events
ALTER TABLE attribution_events ENABLE ROW LEVEL SECURITY;

-- Allow insert for authenticated users
CREATE POLICY "Enable insert for authenticated users"
ON attribution_events
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow select for campaign owners and creators
CREATE POLICY "Enable select for campaign owners and creators"
ON attribution_events
FOR SELECT
TO authenticated
USING (
  auth.uid() = creator_id 
  OR 
  EXISTS (
    SELECT 1 FROM publisher_campaigns pc
    WHERE pc.id = campaign_id
    AND pc.publisher_id = auth.uid()
  )
);
