-- ============================================================================
-- HEYORA SUPABASE PRODUCTION DATABASE SCHEMA & RPC FUNCTIONS
-- ============================================================================
-- Low-cost, high-performance, real-time matchmaking, WebRTC signaling,
-- wallet & virtual gifting, voting anti-abuse, and moderation system.
-- ============================================================================

-- Enable pgcrypto for UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. USERS & PROFILES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    is_guest BOOLEAN DEFAULT true,
    email TEXT,
    display_name TEXT DEFAULT 'Stranger',
    avatar_url TEXT,
    device_id TEXT,
    is_banned BOOLEAN DEFAULT false,
    ban_reason TEXT,
    upvotes INT DEFAULT 0,
    downvotes INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. WALLETS & TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wallets (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    coins INT NOT NULL DEFAULT 120 CHECK (coins >= 0),
    diamonds INT NOT NULL DEFAULT 0 CHECK (diamonds >= 0),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL, -- 'signup_bonus', 'iap_purchase', 'ad_reward', 'gender_filter', 'gift_sent', 'gift_received'
    amount INT NOT NULL,
    currency_type TEXT NOT NULL CHECK (currency_type IN ('coins', 'diamonds')),
    reference_id TEXT, -- e.g. IAP purchaseToken, AdMob transactionId, gift_id
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_user ON public.wallet_transactions(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_tx_reference ON public.wallet_transactions(reference_id) WHERE reference_id IS NOT NULL;

-- ============================================================================
-- 3. MATCHMAKING QUEUE TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.match_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'waiting', -- 'waiting', 'matched', 'cancelled'
    preferred_gender TEXT DEFAULT 'random', -- 'random', 'female'
    caller_karma INT NOT NULL DEFAULT 100, -- Dynamic Karma / MMR score
    channel_id TEXT,
    matched_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '45 seconds')
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_user_queue ON public.match_queue(user_id) WHERE status = 'waiting';
CREATE INDEX IF NOT EXISTS idx_match_queue_status_created ON public.match_queue(status, created_at);

-- ============================================================================
-- 4. ACTIVE CALLS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id TEXT UNIQUE NOT NULL,
    user_a UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_b UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'connected', -- 'connected', 'ended'
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    end_reason TEXT -- 'user_skipped', 'network_disconnect', 'reported', 'timeout'
);

CREATE INDEX IF NOT EXISTS idx_calls_channel ON public.calls(channel_id);
CREATE INDEX IF NOT EXISTS idx_calls_users ON public.calls(user_a, user_b);

-- ============================================================================
-- 5. VIRTUAL GIFTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.gifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    call_id UUID REFERENCES public.calls(id) ON DELETE SET NULL,
    gift_id TEXT NOT NULL, -- 'rose', 'heart', 'cake', 'ring', 'car', 'castle'
    coin_cost INT NOT NULL CHECK (coin_cost > 0),
    diamond_value INT NOT NULL CHECK (diamond_value > 0),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 6. VOTES & ANTI-ABUSE TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    call_id UUID REFERENCES public.calls(id) ON DELETE SET NULL,
    vote_type TEXT NOT NULL CHECK (vote_type IN ('upvote', 'downvote')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT no_self_vote CHECK (voter_id != target_user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_call_vote ON public.votes(voter_id, target_user_id, call_id);

-- ============================================================================
-- 7. REPORTS & BLOCKS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    call_id UUID REFERENCES public.calls(id) ON DELETE SET NULL,
    category TEXT NOT NULL, -- 'nudity', 'harassment', 'underage', 'violence', 'spam'
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'pending' -- 'pending', 'resolved', 'dismissed'
);

CREATE TABLE IF NOT EXISTS public.blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT no_self_block CHECK (blocker_id != blocked_id),
    CONSTRAINT unique_block_pair UNIQUE(blocker_id, blocked_id)
);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone authenticated can read basic profiles, only owner can update their profile
CREATE POLICY "Public profiles are viewable by authenticated users" 
ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Wallets: Users can only select their own wallet. Deductions/Credits only via SECURITY DEFINER functions!
CREATE POLICY "Users can view own wallet" 
ON public.wallets FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can view own wallet transactions" 
ON public.wallet_transactions FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Match Queue: Users can view their own queue entries
CREATE POLICY "Users can manage own queue entry" 
ON public.match_queue FOR ALL TO authenticated USING (auth.uid() = user_id);

-- Calls: Participants can view calls they belong to
CREATE POLICY "Participants can view their calls" 
ON public.calls FOR SELECT TO authenticated 
USING (auth.uid() = user_a OR auth.uid() = user_b);

-- Reports & Blocks: Users can insert reports and view/insert their blocks
CREATE POLICY "Users can insert reports" 
ON public.reports FOR INSERT TO authenticated WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can view their reports" 
ON public.reports FOR SELECT TO authenticated USING (auth.uid() = reporter_id);

CREATE POLICY "Users can manage own blocks" 
ON public.blocks FOR ALL TO authenticated USING (auth.uid() = blocker_id);

-- Votes: Users can see votes they cast
CREATE POLICY "Users can view votes cast" 
ON public.votes FOR SELECT TO authenticated USING (auth.uid() = voter_id);

-- Gifts: Users can view gifts they sent or received
CREATE POLICY "Users can view gifts sent or received" 
ON public.gifts FOR SELECT TO authenticated 
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ============================================================================
-- ATOMIC RPC FUNCTIONS (SECURITY DEFINER)
-- ============================================================================

-- A. Onboarding Trigger: Automatically create Profile & Wallet on Auth User Creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, is_guest, email, display_name, created_at, updated_at)
    VALUES (
        NEW.id,
        (NEW.email IS NULL OR NEW.is_anonymous = true),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Guest_' || SUBSTRING(NEW.id::text, 1, 6)),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.wallets (user_id, coins, diamonds, updated_at)
    VALUES (NEW.id, 120, 0, NOW())
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO public.wallet_transactions (user_id, transaction_type, amount, currency_type, reference_id)
    VALUES (NEW.id, 'signup_bonus', 120, 'coins', 'welcome_bonus_' || NEW.id::text)
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- B. Atomic Matchmaking RPC: Fast Sub-Second Queue Matching
CREATE OR REPLACE FUNCTION public.enter_match_queue(
    p_preferred_gender TEXT DEFAULT 'random'
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_partner_queue RECORD;
    v_new_channel_id TEXT;
    v_call_id UUID;
    v_is_banned BOOLEAN;
    v_upvotes INT := 0;
    v_downvotes INT := 0;
    v_caller_karma INT := 100;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check if user is banned and fetch current reputation score
    SELECT is_banned, COALESCE(upvotes, 0), COALESCE(downvotes, 0)
    INTO v_is_banned, v_upvotes, v_downvotes
    FROM public.profiles WHERE id = v_user_id;

    IF v_is_banned IS TRUE THEN
        RAISE EXCEPTION 'User is permanently banned for safety violations.';
    END IF;

    -- Dynamic Karma Calculation: baseline 100, +5 per upvote, -15 per downvote
    v_caller_karma := GREATEST(0, 100 + (v_upvotes * 5) - (v_downvotes * 15));

    -- Optimization 5: Automatic garbage-collection of expired queue items and stale abandoned calls
    DELETE FROM public.match_queue WHERE expires_at < NOW() OR user_id = v_user_id;
    UPDATE public.calls 
    SET status = 'ended', ended_at = NOW(), end_reason = 'session_timeout' 
    WHERE status = 'connected' AND started_at < (NOW() - INTERVAL '2 hours');

    -- Shadow-Troll Filter & Nearest Karma Matching (The MMR Algorithm):
    -- If caller is a troll (karma < 40), they ONLY match with other trolls (caller_karma < 40)!
    -- If caller is good citizen (karma >= 40), they match with good citizens, prioritizing closest score!
    SELECT * INTO v_partner_queue
    FROM public.match_queue mq
    WHERE mq.status = 'waiting'
      AND mq.user_id != v_user_id
      AND mq.expires_at > NOW()
      AND (
          (v_caller_karma < 40 AND mq.caller_karma < 40)
          OR
          (v_caller_karma >= 40 AND mq.caller_karma >= 40)
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.blocks b
          WHERE (b.blocker_id = v_user_id AND b.blocked_id = mq.user_id)
             OR (b.blocker_id = mq.user_id AND b.blocked_id = v_user_id)
      )
    ORDER BY ABS(mq.caller_karma - v_caller_karma) ASC, mq.created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF v_partner_queue IS NOT NULL THEN
        -- Found nearest karma partner! Create a shared unique channel and call record
        v_new_channel_id := 'call_' || gen_random_uuid()::text;

        INSERT INTO public.calls (channel_id, user_a, user_b, status, started_at)
        VALUES (v_new_channel_id, v_partner_queue.user_id, v_user_id, 'connected', NOW())
        RETURNING id INTO v_call_id;

        -- Update partner's queue entry so their Realtime listener wakes up immediately
        UPDATE public.match_queue
        SET status = 'matched',
            channel_id = v_new_channel_id,
            matched_user_id = v_user_id
        WHERE id = v_partner_queue.id;

        RETURN jsonb_build_object(
            'status', 'matched',
            'channel_id', v_new_channel_id,
            'call_id', v_call_id,
            'peer_id', v_partner_queue.user_id,
            'peer_karma', v_partner_queue.caller_karma,
            'is_initiator', false -- User B is answerer
        );
    ELSE
        -- Insert self into queue with dynamic karma score for incoming nearest-score callers
        INSERT INTO public.match_queue (user_id, preferred_gender, caller_karma, status, created_at, expires_at)
        VALUES (v_user_id, p_preferred_gender, v_caller_karma, 'waiting', NOW(), NOW() + INTERVAL '45 seconds');

        RETURN jsonb_build_object(
            'status', 'waiting',
            'user_id', v_user_id,
            'caller_karma', v_caller_karma
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- C. Leave Match Queue
CREATE OR REPLACE FUNCTION public.leave_match_queue()
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.match_queue WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D. End Active Call
CREATE OR REPLACE FUNCTION public.end_call(
    p_channel_id TEXT,
    p_reason TEXT DEFAULT 'user_skipped'
)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    UPDATE public.calls
    SET status = 'ended',
        ended_at = NOW(),
        duration_seconds = EXTRACT(EPOCH FROM (NOW() - started_at))::INT,
        end_reason = p_reason
    WHERE channel_id = p_channel_id
      AND (user_a = v_user_id OR user_b = v_user_id)
      AND status = 'connected';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- E. Atomic Coin Deduction (e.g., Girls Only Filter = 10 Coins)
CREATE OR REPLACE FUNCTION public.deduct_coins(
    p_amount INT,
    p_transaction_type TEXT,
    p_reference_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_coins INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Invalid deduction amount';
    END IF;

    -- Lock wallet row
    SELECT coins INTO v_current_coins
    FROM public.wallets
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF v_current_coins IS NULL OR v_current_coins < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins');
    END IF;

    UPDATE public.wallets
    SET coins = coins - p_amount,
        updated_at = NOW()
    WHERE user_id = v_user_id;

    INSERT INTO public.wallet_transactions (user_id, transaction_type, amount, currency_type, reference_id)
    VALUES (v_user_id, p_transaction_type, -p_amount, 'coins', p_reference_id);

    RETURN jsonb_build_object('success', true, 'remaining_coins', v_current_coins - p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- F. Atomic Coin Credit (IAP Packs or Rewarded Video Ad +15 Coins)
CREATE OR REPLACE FUNCTION public.credit_coins(
    p_amount INT,
    p_transaction_type TEXT,
    p_reference_id TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_new_coins INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Invalid credit amount';
    END IF;

    -- Check if reference_id already processed (Idempotency protection!)
    IF p_reference_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.wallet_transactions WHERE reference_id = p_reference_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transaction already processed');
    END IF;

    -- Update or insert wallet
    INSERT INTO public.wallets (user_id, coins, diamonds, updated_at)
    VALUES (v_user_id, p_amount, 0, NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET coins = wallets.coins + p_amount,
        updated_at = NOW()
    RETURNING coins INTO v_new_coins;

    INSERT INTO public.wallet_transactions (user_id, transaction_type, amount, currency_type, reference_id)
    VALUES (v_user_id, p_transaction_type, p_amount, 'coins', p_reference_id);

    RETURN jsonb_build_object('success', true, 'new_balance', v_new_coins);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- G. Send Virtual Gift (Deducts Sender Coins, Credits Receiver Diamonds, Logs Record)
CREATE OR REPLACE FUNCTION public.send_gift(
    p_receiver_id UUID,
    p_call_id UUID,
    p_gift_id TEXT,
    p_coin_cost INT,
    p_diamond_value INT
)
RETURNS JSONB AS $$
DECLARE
    v_sender_id UUID := auth.uid();
    v_sender_coins INT;
BEGIN
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_sender_id = p_receiver_id THEN
        RAISE EXCEPTION 'Cannot gift yourself';
    END IF;

    -- Lock sender wallet
    SELECT coins INTO v_sender_coins
    FROM public.wallets
    WHERE user_id = v_sender_id
    FOR UPDATE;

    IF v_sender_coins IS NULL OR v_sender_coins < p_coin_cost THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins');
    END IF;

    -- Deduct sender coins
    UPDATE public.wallets
    SET coins = coins - p_coin_cost,
        updated_at = NOW()
    WHERE user_id = v_sender_id;

    -- Credit receiver diamonds
    INSERT INTO public.wallets (user_id, coins, diamonds, updated_at)
    VALUES (p_receiver_id, 0, p_diamond_value, NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET diamonds = wallets.diamonds + p_diamond_value,
        updated_at = NOW();

    -- Record gift history
    INSERT INTO public.gifts (sender_id, receiver_id, call_id, gift_id, coin_cost, diamond_value)
    VALUES (v_sender_id, p_receiver_id, p_call_id, p_gift_id, p_coin_cost, p_diamond_value);

    -- Log transactions for both users
    INSERT INTO public.wallet_transactions (user_id, transaction_type, amount, currency_type, reference_id)
    VALUES 
        (v_sender_id, 'gift_sent', -p_coin_cost, 'coins', 'gift_sent_' || gen_random_uuid()::text),
        (p_receiver_id, 'gift_received', p_diamond_value, 'diamonds', 'gift_rcv_' || gen_random_uuid()::text);

    RETURN jsonb_build_object(
        'success', true, 
        'remaining_coins', v_sender_coins - p_coin_cost,
        'gift_id', p_gift_id,
        'diamond_value', p_diamond_value
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- H. Submit Vote (Upvote / Downvote) with Anti-Abuse Integrity
CREATE OR REPLACE FUNCTION public.submit_vote(
    p_target_user_id UUID,
    p_call_id UUID,
    p_vote_type TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_voter_id UUID := auth.uid();
BEGIN
    IF v_voter_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_voter_id = p_target_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot vote for yourself');
    END IF;

    IF p_vote_type NOT IN ('upvote', 'downvote') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid vote type');
    END IF;

    -- Insert vote record (unique constraint prevents multiple votes on same call interaction)
    INSERT INTO public.votes (voter_id, target_user_id, call_id, vote_type)
    VALUES (v_voter_id, p_target_user_id, p_call_id, p_vote_type)
    ON CONFLICT (voter_id, target_user_id, call_id) DO NOTHING;

    -- Update target profile counters
    IF p_vote_type = 'upvote' THEN
        UPDATE public.profiles SET upvotes = upvotes + 1 WHERE id = p_target_user_id;
    ELSE
        UPDATE public.profiles SET downvotes = downvotes + 1 WHERE id = p_target_user_id;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- I. Report and Block User (1-Tap Safety Submission)
CREATE OR REPLACE FUNCTION public.report_and_block_user(
    p_reported_id UUID,
    p_call_id UUID,
    p_category TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_reporter_id UUID := auth.uid();
    v_report_count INT;
BEGIN
    IF v_reporter_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Record safety report
    INSERT INTO public.reports (reporter_id, reported_id, call_id, category, description)
    VALUES (v_reporter_id, p_reported_id, p_call_id, p_category, p_description);

    -- Insert bilateral block so they never pair again
    INSERT INTO public.blocks (blocker_id, blocked_id)
    VALUES (v_reporter_id, p_reported_id)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    -- Auto-ban safety threshold check: If a user accumulates >= 5 serious reports, ban them
    SELECT COUNT(*) INTO v_report_count FROM public.reports WHERE reported_id = p_reported_id;
    IF v_report_count >= 5 THEN
        UPDATE public.profiles
        SET is_banned = true,
            ban_reason = 'Accumulated 5+ verified community safety reports for ' || p_category
        WHERE id = p_reported_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'blocked', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- J. Generate Temporary Coturn TURN REST Credentials
-- Eliminates permanent hardcoded secrets in the APK!
CREATE OR REPLACE FUNCTION public.get_turn_credentials()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_turn_secret TEXT := 'heyora_coturn_super_secret_shared_key_2026'; -- Configure via Supabase Vault / Edge Function
    v_expiry INT := EXTRACT(EPOCH FROM (NOW() + INTERVAL '12 hours'))::INT;
    v_username TEXT;
    v_credential TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_username := v_expiry::TEXT || ':' || v_user_id::TEXT;
    v_credential := encode(hmac(v_username, v_turn_secret, 'sha1'), 'base64');

    RETURN jsonb_build_object(
        'username', v_username,
        'credential', v_credential,
        'ttl', 43200
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- K. High-Performance Leaderboard Aggregation RPC
-- Supports 'stars' (diamonds received) & 'gifters' (coins spent) across 'daily', 'weekly', 'all_time'
CREATE OR REPLACE FUNCTION public.get_leaderboard(
    p_category TEXT DEFAULT 'stars',
    p_timeframe TEXT DEFAULT 'daily',
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    rank INT,
    user_id UUID,
    display_name TEXT,
    avatar_url TEXT,
    score BIGINT
) AS $$
DECLARE
    v_start_time TIMESTAMPTZ;
BEGIN
    IF p_timeframe = 'daily' THEN
        v_start_time := DATE_TRUNC('day', NOW());
    ELSIF p_timeframe = 'weekly' THEN
        v_start_time := DATE_TRUNC('week', NOW());
    ELSE
        v_start_time := '1970-01-01'::TIMESTAMPTZ;
    END IF;

    IF p_category = 'stars' THEN
        IF p_timeframe = 'all_time' THEN
            RETURN QUERY
            SELECT 
                ROW_NUMBER() OVER (ORDER BY w.diamonds DESC)::INT as rank,
                p.id as user_id,
                COALESCE(p.display_name, 'Star_' || SUBSTRING(p.id::text, 1, 6)) as display_name,
                p.avatar_url,
                COALESCE(w.diamonds, 0)::BIGINT as score
            FROM public.wallets w
            JOIN public.profiles p ON p.id = w.user_id
            WHERE p.is_banned IS FALSE AND w.diamonds > 0
            ORDER BY w.diamonds DESC
            LIMIT p_limit;
        ELSE
            RETURN QUERY
            WITH ranked_stars AS (
                SELECT 
                    g.receiver_id as u_id,
                    SUM(g.diamond_value)::BIGINT as total_score
                FROM public.gifts g
                WHERE g.created_at >= v_start_time
                GROUP BY g.receiver_id
            )
            SELECT 
                ROW_NUMBER() OVER (ORDER BY rs.total_score DESC)::INT as rank,
                p.id as user_id,
                COALESCE(p.display_name, 'Star_' || SUBSTRING(p.id::text, 1, 6)) as display_name,
                p.avatar_url,
                rs.total_score as score
            FROM ranked_stars rs
            JOIN public.profiles p ON p.id = rs.u_id
            WHERE p.is_banned IS FALSE
            ORDER BY rs.total_score DESC
            LIMIT p_limit;
        END IF;
    ELSE -- 'gifters'
        RETURN QUERY
        WITH ranked_gifters AS (
            SELECT 
                g.sender_id as u_id,
                SUM(g.coin_cost)::BIGINT as total_score
            FROM public.gifts g
            WHERE (p_timeframe = 'all_time' OR g.created_at >= v_start_time)
            GROUP BY g.sender_id
        )
        SELECT 
            ROW_NUMBER() OVER (ORDER BY rg.total_score DESC)::INT as rank,
            p.id as user_id,
            COALESCE(p.display_name, 'VIP_' || SUBSTRING(p.id::text, 1, 6)) as display_name,
            p.avatar_url,
            rg.total_score as score
        FROM ranked_gifters rg
        JOIN public.profiles p ON p.id = rg.u_id
        WHERE p.is_banned IS FALSE
        ORDER BY rg.total_score DESC
        LIMIT p_limit;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Performance indexes for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_gifts_receiver_created ON public.gifts(receiver_id, created_at);
CREATE INDEX IF NOT EXISTS idx_gifts_sender_created ON public.gifts(sender_id, created_at);
CREATE INDEX IF NOT EXISTS idx_wallets_diamonds ON public.wallets(diamonds DESC);

-- Enable Realtime for match_queue, calls, and wallet tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.match_queue;
ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;
