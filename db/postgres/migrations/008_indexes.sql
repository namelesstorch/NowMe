CREATE INDEX idx_events_user_start_at
  ON events(user_id, start_at)
  WHERE deleted_at IS NULL AND all_day = false;

CREATE INDEX idx_events_user_start_date
  ON events(user_id, start_date)
  WHERE deleted_at IS NULL AND all_day = true;

CREATE INDEX idx_events_user_status
  ON events(user_id, status)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_event_reminders_due
  ON event_reminders(remind_at)
  WHERE is_sent = false;

CREATE INDEX idx_transactions_user_occurred_at
  ON transactions(user_id, occurred_at)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_transactions_user_category
  ON transactions(user_id, category_id)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_transactions_user_type
  ON transactions(user_id, type)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_spending_summaries_user_period
  ON spending_summaries(user_id, period_type, period_start);

CREATE INDEX idx_ai_inputs_user_created_at
  ON ai_inputs(user_id, created_at);

CREATE INDEX idx_context_snapshots_user_context
  ON context_snapshots(user_id, weather_condition, time_bucket, is_weekend, date_local);

CREATE INDEX idx_context_snapshots_user_scene
  ON context_snapshots(user_id, location_scene, activity_scene, occurred_at);

CREATE INDEX idx_context_snapshots_features_gin
  ON context_snapshots USING GIN (features);

CREATE INDEX idx_user_habit_signals_lookup
  ON user_habit_signals(user_id, signal_type, subject_type, subject_value)
  WHERE status = 'active';

CREATE INDEX idx_user_habit_signals_context_gin
  ON user_habit_signals USING GIN (context_filter);

CREATE INDEX idx_ai_context_packages_user_created_at
  ON ai_context_packages(user_id, created_at);
