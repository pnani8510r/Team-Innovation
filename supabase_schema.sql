-- ============================================================
-- LINGUAQUEST — SUPABASE SCHEMA
-- Run this entire file in your Supabase SQL Editor
-- Dashboard → SQL Editor → New Query → Paste → Run
-- ============================================================


-- ============================================================
-- 1. USERS TABLE
-- Extends Supabase auth.users with profile data
-- ============================================================
create table public.users (
  id           uuid references auth.users(id) on delete cascade primary key,
  username     text unique not null,
  avatar_emoji text default '👤',
  languages    text default 'English',         -- e.g. "Hindi · English"
  role         text default 'student',          -- 'student' | 'teacher'
  coins        integer default 0,
  streak       integer default 0,
  problems_solved integer default 0,
  created_at   timestamptz default now()
);

-- Anyone can read profiles (for leaderboard)
alter table public.users enable row level security;

create policy "Public profiles are viewable by everyone"
  on public.users for select using (true);

create policy "Users can update their own profile"
  on public.users for update using (auth.uid() = id);


-- ============================================================
-- 2. SEED DATA — the 6 users already in your frontend
-- Run AFTER signing those users up through your app, OR
-- use these as mock rows for testing without real auth.
-- For testing: temporarily disable RLS on users table,
-- insert rows, then re-enable.
-- ============================================================

-- To insert test data without auth, run in SQL editor:
/*
insert into public.users (id, username, avatar_emoji, languages, coins, streak, problems_solved)
values
  (gen_random_uuid(), 'priya_codes',    '🧑', 'Hindi · English',  1240, 14, 142),
  (gen_random_uuid(), 'sofia_learns',   '👩', 'Spanish · English',  980,  9,  98),
  (gen_random_uuid(), 'rahul_dev',      '👦', 'Hindi',              820,  5,  87),
  (gen_random_uuid(), 'arjun_s',        '🚀', 'Hindi · English',    340,  7,  61),
  (gen_random_uuid(), 'dev_khan',       '🧑‍💻', 'English',           290,  3,  54),
  (gen_random_uuid(), 'learnwithkiti',  '🌈', 'German · English',   260,  2,  41);
*/


-- ============================================================
-- 3. LEADERBOARD VIEW
-- Pre-sorted, used directly by your frontend fetch
-- ============================================================
create or replace view public.leaderboard as
  select
    row_number() over (order by coins desc) as rank,
    username,
    avatar_emoji,
    languages,
    coins,
    streak,
    problems_solved,
    role
  from public.users
  order by coins desc;

-- Make view publicly readable
create policy "Leaderboard is public"
  on public.users for select using (true);


-- ============================================================
-- 4. FOLLOWS TABLE
-- username-based so it works without full auth during testing
-- ============================================================
create table public.follows (
  id          bigserial primary key,
  follower_id uuid references public.users(id) on delete cascade,
  following_id uuid references public.users(id) on delete cascade,
  created_at  timestamptz default now(),
  unique(follower_id, following_id)
);

alter table public.follows enable row level security;

create policy "Anyone can read follows"
  on public.follows for select using (true);

create policy "Users can manage their own follows"
  on public.follows for all using (auth.uid() = follower_id);


-- ============================================================
-- 5. PROBLEMS TABLE
-- Your question bank lives here instead of a JS object
-- ============================================================
create table public.problems (
  id          text primary key,           -- e.g. 'e1', 'm1', 'h1'
  title       text not null,
  difficulty  text not null,              -- 'easy' | 'medium' | 'hard'
  language    text default 'English',
  coins       integer not null,
  description text,
  constraints text,
  created_at  timestamptz default now()
);

alter table public.problems enable row level security;
create policy "Problems are public" on public.problems for select using (true);

-- Seed problems
insert into public.problems (id, title, difficulty, language, coins) values
  ('e1', 'Two Sum',                      'easy',   'English', 10),
  ('e2', 'Valid Palindrome',             'easy',   'Hindi',   15),
  ('e3', 'Reverse String',              'easy',   'English', 10),
  ('e4', 'Fibonacci Number',            'easy',   'Spanish', 12),
  ('e5', 'Maximum Subarray',            'easy',   'English', 15),
  ('m1', 'Binary Search',               'medium', 'English', 20),
  ('m2', 'Inorder Tree Traversal',      'medium', 'Spanish', 25),
  ('m3', 'Binary Search — Hindi',       'medium', 'Hindi',   22),
  ('m4', 'Product of Array Except Self','medium', 'English', 25),
  ('h1', 'Longest Common Subsequence',  'hard',   'Hindi',   40),
  ('h2', 'Trapping Rain Water',         'hard',   'English', 45),
  ('h3', 'Word Break',                  'hard',   'Spanish', 40);


-- ============================================================
-- 6. SUBMISSIONS TABLE
-- Every solve attempt recorded here
-- ============================================================
create table public.submissions (
  id          bigserial primary key,
  user_id     uuid references public.users(id) on delete cascade,
  problem_id  text references public.problems(id),
  status      text not null,              -- 'accepted' | 'wrong_answer' | 'tle'
  language    text,
  coins_earned integer default 0,
  submitted_at timestamptz default now()
);

alter table public.submissions enable row level security;

create policy "Users can read their own submissions"
  on public.submissions for select using (auth.uid() = user_id);

create policy "Users can insert their own submissions"
  on public.submissions for insert with check (auth.uid() = user_id);


-- ============================================================
-- 7. COIN TRANSACTIONS TABLE
-- Full audit trail of every coin movement
-- ============================================================
create table public.coin_transactions (
  id          bigserial primary key,
  user_id     uuid references public.users(id) on delete cascade,
  amount      integer not null,           -- positive = earned, negative = spent
  reason      text,                       -- 'solved_problem' | 'streak_bonus' | 'sent_to_peer' | 'contest_prize'
  related_user uuid references public.users(id), -- who sent/received
  created_at  timestamptz default now()
);

alter table public.coin_transactions enable row level security;

create policy "Users can read their own transactions"
  on public.coin_transactions for select using (auth.uid() = user_id);

create policy "Users can insert their own transactions"
  on public.coin_transactions for insert with check (auth.uid() = user_id);


-- ============================================================
-- 8. DOUBTS TABLE
-- ============================================================
create table public.doubts (
  id          bigserial primary key,
  user_id     uuid references public.users(id) on delete cascade,
  title       text not null,
  body        text,
  language    text default 'English',
  topic       text,
  ask_type    text default 'peer',        -- 'peer' | 'teacher'
  status      text default 'open',       -- 'open' | 'answered'
  created_at  timestamptz default now()
);

alter table public.doubts enable row level security;
create policy "Doubts are public" on public.doubts for select using (true);
create policy "Users can post doubts" on public.doubts for insert with check (auth.uid() = user_id);


-- ============================================================
-- 9. CONTEST ROOMS TABLE
-- ============================================================
create table public.contest_rooms (
  id            text primary key,          -- e.g. 'LQ-5782'
  name          text not null,
  creator_id    uuid references public.users(id),
  entry_type    text default 'free',       -- 'free' | 'coins'
  entry_fee     integer default 0,
  time_minutes  integer default 30,
  question_ids  text[],                    -- array of problem ids
  max_players   integer default 4,
  status        text default 'waiting',   -- 'waiting' | 'live' | 'ended'
  starts_at     timestamptz,
  created_at    timestamptz default now()
);

alter table public.contest_rooms enable row level security;
create policy "Rooms are public" on public.contest_rooms for select using (true);
create policy "Users can create rooms" on public.contest_rooms for insert with check (auth.uid() = creator_id);


-- ============================================================
-- 10. USEFUL FUNCTION: award coins to a user
-- Call this from your backend/edge function after a solve
-- ============================================================
create or replace function award_coins(
  p_user_id uuid,
  p_amount integer,
  p_reason text,
  p_related_user uuid default null
)
returns void language plpgsql security definer as $$
begin
  -- Update balance
  update public.users
  set coins = coins + p_amount
  where id = p_user_id;

  -- Log transaction
  insert into public.coin_transactions (user_id, amount, reason, related_user)
  values (p_user_id, p_amount, p_reason, p_related_user);
end;
$$;


-- ============================================================
-- DONE ✅
-- Next step: copy your Supabase URL and anon key from
-- Dashboard → Settings → API
-- Paste them into the HTML file where marked SUPABASE_URL
-- and SUPABASE_ANON_KEY
-- ============================================================
