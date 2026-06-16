BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(50) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email CITEXT,
  avatar_url TEXT,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS auth_verification_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  phone VARCHAR(20) NOT NULL,
  purpose verification_purpose_enum NOT NULL DEFAULT 'login',
  channel verification_channel_enum NOT NULL DEFAULT 'sms',
  code_hash TEXT NOT NULL,
  request_ip INET,
  device_id VARCHAR(100),
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  attempt_count SMALLINT NOT NULL DEFAULT 0,
  status verification_code_status_enum NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT auth_verification_codes_attempt_count_check
    CHECK (attempt_count >= 0)
);

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_token_hash TEXT NOT NULL,
  device_id VARCHAR(100),
  device_name VARCHAR(100),
  client_platform VARCHAR(30),
  app_version VARCHAR(30),
  login_ip INET,
  last_seen_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_sessions_expiry_check
    CHECK (expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
  timezone VARCHAR(50) NOT NULL DEFAULT 'Asia/Shanghai',
  default_view default_view_enum NOT NULL DEFAULT 'week',
  reminder_setting JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_financial_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
  initial_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  current_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel notification_channel_enum NOT NULL,
  quiet_start TIME,
  quiet_end TIME,
  enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  type category_type_enum NOT NULL,
  parent_id UUID,
  icon VARCHAR(50),
  color VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, id),
  CONSTRAINT categories_parent_fk
    FOREIGN KEY (parent_id)
    REFERENCES categories(id)
    ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  color VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, id)
);

CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  all_day BOOLEAN NOT NULL DEFAULT false,
  start_date DATE,
  end_date DATE,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  timezone VARCHAR(50) NOT NULL DEFAULT 'Asia/Shanghai',
  location VARCHAR(255),
  event_type event_type_enum NOT NULL DEFAULT 'schedule',
  priority event_priority_enum NOT NULL DEFAULT 'medium',
  status event_status_enum NOT NULL DEFAULT 'active',
  color VARCHAR(20),
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  recurrence_rule JSONB,
  source_input_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, id),
  CONSTRAINT events_time_check
    CHECK (
      (
        all_day = true
        AND start_date IS NOT NULL
        AND end_date IS NOT NULL
        AND end_date >= start_date
        AND start_at IS NULL
        AND end_at IS NULL
      )
      OR
      (
        all_day = false
        AND start_at IS NOT NULL
        AND end_at IS NOT NULL
        AND end_at > start_at
      )
    )
);

CREATE TABLE IF NOT EXISTS event_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL,
  remind_at TIMESTAMPTZ NOT NULL,
  method notification_channel_enum NOT NULL DEFAULT 'push',
  is_sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_reminders_event_fk
    FOREIGN KEY (user_id, event_id)
    REFERENCES events(user_id, id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS event_tags (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL,
  tag_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, tag_id),
  CONSTRAINT event_tags_event_fk
    FOREIGN KEY (user_id, event_id)
    REFERENCES events(user_id, id)
    ON DELETE CASCADE,
  CONSTRAINT event_tags_tag_fk
    FOREIGN KEY (user_id, tag_id)
    REFERENCES tags(user_id, id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID,
  category_id UUID,
  type transaction_type_enum NOT NULL,
  amount NUMERIC(14,2) NOT NULL,
  currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
  description TEXT,
  occurred_at TIMESTAMPTZ NOT NULL,
  payment_method VARCHAR(30),
  location VARCHAR(255),
  is_manual BOOLEAN NOT NULL DEFAULT false,
  source_input_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, id),
  CONSTRAINT transactions_event_fk
    FOREIGN KEY (event_id)
    REFERENCES events(id)
    ON DELETE SET NULL,
  CONSTRAINT transactions_category_fk
    FOREIGN KEY (category_id)
    REFERENCES categories(id)
    ON DELETE SET NULL,
  CONSTRAINT transactions_amount_check
    CHECK (amount > 0)
);

CREATE TABLE IF NOT EXISTS transaction_tags (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_id UUID NOT NULL,
  tag_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (transaction_id, tag_id),
  CONSTRAINT transaction_tags_transaction_fk
    FOREIGN KEY (user_id, transaction_id)
    REFERENCES transactions(user_id, id)
    ON DELETE CASCADE,
  CONSTRAINT transaction_tags_tag_fk
    FOREIGN KEY (user_id, tag_id)
    REFERENCES tags(user_id, id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID,
  period budget_period_enum NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  limit_amount NUMERIC(14,2) NOT NULL,
  alert_threshold NUMERIC(5,2) NOT NULL DEFAULT 0.80,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT budgets_category_fk
    FOREIGN KEY (category_id)
    REFERENCES categories(id)
    ON DELETE SET NULL,
  CONSTRAINT budgets_amount_check
    CHECK (limit_amount > 0 AND alert_threshold > 0 AND alert_threshold <= 1),
  CONSTRAINT budgets_date_check
    CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS financial_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  target_amount NUMERIC(14,2) NOT NULL,
  current_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  start_date DATE,
  end_date DATE,
  status goal_status_enum NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT financial_goals_amount_check
    CHECK (target_amount > 0 AND current_amount >= 0),
  CONSTRAINT financial_goals_date_check
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS spending_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  period_type spending_period_enum NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_income NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_expense NUMERIC(14,2) NOT NULL DEFAULT 0,
  balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  category_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT spending_summaries_date_check
    CHECK (period_end >= period_start)
);

COMMIT;
