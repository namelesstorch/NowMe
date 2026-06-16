BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_unique
  ON users(phone);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique
  ON users(email)
  WHERE email IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_sessions_token_hash_unique
  ON user_sessions(session_token_hash);

CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_settings_user_channel
  ON notification_settings(user_id, channel);

CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_user_name_type_active
  ON categories(user_id, name, type)
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tags_user_name_active
  ON tags(user_id, name)
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_spending_summaries_user_period
  ON spending_summaries(user_id, period_type, period_start);

CREATE UNIQUE INDEX IF NOT EXISTS idx_habit_signals_unique_active
  ON user_habit_signals(user_id, signal_type, subject_type, subject_value, context_filter);

CREATE INDEX IF NOT EXISTS idx_auth_verification_codes_phone_created_at
  ON auth_verification_codes(phone, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_auth_verification_codes_pending
  ON auth_verification_codes(phone, expires_at)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_active
  ON user_sessions(user_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_events_user_start_at
  ON events(user_id, start_at)
  WHERE deleted_at IS NULL AND all_day = false;

CREATE INDEX IF NOT EXISTS idx_events_user_start_date
  ON events(user_id, start_date)
  WHERE deleted_at IS NULL AND all_day = true;

CREATE INDEX IF NOT EXISTS idx_events_user_status
  ON events(user_id, status)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_event_reminders_due
  ON event_reminders(remind_at)
  WHERE is_sent = false;

CREATE INDEX IF NOT EXISTS idx_transactions_user_occurred_at
  ON transactions(user_id, occurred_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_user_category
  ON transactions(user_id, category_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_user_type
  ON transactions(user_id, type)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_event
  ON transactions(event_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_budgets_user_period
  ON budgets(user_id, period, start_date)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_financial_goals_user_status
  ON financial_goals(user_id, status)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_inputs_user_created_at
  ON ai_inputs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_extractions_input_entity
  ON ai_extractions(input_id, entity_type);

CREATE INDEX IF NOT EXISTS idx_ai_insights_user_created_at
  ON ai_insights(user_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_context_snapshots_user_context
  ON context_snapshots(user_id, weather_condition, time_bucket, is_weekend, date_local);

CREATE INDEX IF NOT EXISTS idx_context_snapshots_user_scene
  ON context_snapshots(user_id, location_scene, activity_scene, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_context_snapshots_features_gin
  ON context_snapshots USING GIN (features);

CREATE INDEX IF NOT EXISTS idx_user_habit_signals_lookup
  ON user_habit_signals(user_id, signal_type, subject_type, subject_value)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_habit_signals_context_gin
  ON user_habit_signals USING GIN (context_filter);

CREATE INDEX IF NOT EXISTS idx_ai_context_packages_user_created_at
  ON ai_context_packages(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_context_packages_payload_gin
  ON ai_context_packages USING GIN (payload_summary);

COMMIT;
