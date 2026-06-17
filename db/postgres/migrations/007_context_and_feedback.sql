CREATE TABLE context_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_type VARCHAR(20) NOT NULL,
  event_id UUID,
  transaction_id UUID,
  input_id UUID,
  occurred_at TIMESTAMPTZ NOT NULL,
  date_local DATE NOT NULL,
  timezone VARCHAR(50) NOT NULL,
  day_of_week SMALLINT NOT NULL,
  is_weekend BOOLEAN NOT NULL,
  time_bucket VARCHAR(20) NOT NULL,
  weather_condition VARCHAR(30) NOT NULL DEFAULT 'unknown',
  temperature_bucket VARCHAR(20) NOT NULL DEFAULT 'unknown',
  location_text VARCHAR(255),
  location_scene VARCHAR(50),
  activity_scene VARCHAR(50),
  mood VARCHAR(30),
  features JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT context_snapshots_event_fk
    FOREIGN KEY (event_id)
    REFERENCES events(id)
    ON DELETE CASCADE,
  CONSTRAINT context_snapshots_transaction_fk
    FOREIGN KEY (transaction_id)
    REFERENCES transactions(id)
    ON DELETE CASCADE,
  CONSTRAINT context_snapshots_input_fk
    FOREIGN KEY (input_id)
    REFERENCES ai_inputs(id)
    ON DELETE SET NULL,
  CONSTRAINT context_snapshots_source_type_check
    CHECK (source_type IN ('event', 'transaction', 'ai_input', 'manual')),
  CONSTRAINT context_snapshots_day_of_week_check
    CHECK (day_of_week BETWEEN 1 AND 7),
  CONSTRAINT context_snapshots_time_bucket_check
    CHECK (time_bucket IN ('early_morning', 'morning', 'noon', 'afternoon', 'evening', 'night')),
  CONSTRAINT context_snapshots_weather_check
    CHECK (weather_condition IN ('sunny', 'cloudy', 'rainy', 'snowy', 'foggy', 'windy', 'unknown')),
  CONSTRAINT context_snapshots_temperature_check
    CHECK (temperature_bucket IN ('cold', 'cool', 'mild', 'warm', 'hot', 'unknown'))
);

CREATE TABLE user_habit_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signal_type VARCHAR(30) NOT NULL,
  subject_type VARCHAR(30) NOT NULL,
  subject_value VARCHAR(100) NOT NULL,
  context_filter JSONB NOT NULL DEFAULT '{}'::jsonb,
  evidence_count INTEGER NOT NULL DEFAULT 0,
  confidence NUMERIC(5,4) NOT NULL DEFAULT 0,
  first_observed_at TIMESTAMPTZ,
  last_observed_at TIMESTAMPTZ,
  example_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_habit_signals_signal_type_check
    CHECK (signal_type IN ('food_preference', 'spending_pattern', 'schedule_pattern', 'location_pattern', 'time_pattern')),
  CONSTRAINT user_habit_signals_subject_type_check
    CHECK (subject_type IN ('category', 'tag', 'item', 'location_scene', 'activity_scene', 'text_label')),
  CONSTRAINT user_habit_signals_confidence_check
    CHECK (confidence >= 0 AND confidence <= 1),
  CONSTRAINT user_habit_signals_evidence_count_check
    CHECK (evidence_count >= 0),
  CONSTRAINT user_habit_signals_status_check
    CHECK (status IN ('active', 'stale', 'rejected')),
  UNIQUE (user_id, signal_type, subject_type, subject_value, context_filter)
);

CREATE TABLE ai_context_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  input_id UUID REFERENCES ai_inputs(id) ON DELETE SET NULL,
  package_type VARCHAR(30) NOT NULL,
  context_keys JSONB NOT NULL DEFAULT '[]'::jsonb,
  payload_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  token_estimate INTEGER,
  privacy_level VARCHAR(20) NOT NULL DEFAULT 'minimal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ai_context_packages_type_check
    CHECK (package_type IN ('parse', 'recommendation', 'budget', 'schedule_summary', 'monthly_summary')),
  CONSTRAINT ai_context_packages_privacy_level_check
    CHECK (privacy_level IN ('minimal', 'standard', 'sensitive')),
  CONSTRAINT ai_context_packages_token_estimate_check
    CHECK (token_estimate IS NULL OR token_estimate >= 0)
);

CREATE TABLE ai_recommendation_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  insight_id UUID NOT NULL REFERENCES ai_insights(id) ON DELETE CASCADE,
  feedback_type VARCHAR(20) NOT NULL,
  feedback_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ai_recommendation_feedback_type_check
    CHECK (feedback_type IN ('accepted', 'dismissed', 'modified', 'negative'))
);
