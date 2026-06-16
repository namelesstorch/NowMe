BEGIN;

CREATE TABLE IF NOT EXISTS ai_inputs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  input_type ai_input_type_enum NOT NULL,
  content TEXT,
  raw_text TEXT,
  image_url TEXT,
  recognized_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id)
);

CREATE TABLE IF NOT EXISTS ai_extractions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  input_id UUID NOT NULL REFERENCES ai_inputs(id) ON DELETE CASCADE,
  entity_type ai_entity_type_enum NOT NULL,
  parsed_data JSONB NOT NULL,
  confidence NUMERIC(5,4),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ai_extractions_confidence_check
    CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'events_source_input_fk') THEN
    ALTER TABLE events
      ADD CONSTRAINT events_source_input_fk
      FOREIGN KEY (source_input_id)
      REFERENCES ai_inputs(id)
      ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'transactions_source_input_fk') THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_source_input_fk
      FOREIGN KEY (source_input_id)
      REFERENCES ai_inputs(id)
      ON DELETE SET NULL;
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  insight_type ai_insight_type_enum NOT NULL,
  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  related_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS context_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_type context_source_type_enum NOT NULL,
  event_id UUID,
  transaction_id UUID,
  input_id UUID,
  occurred_at TIMESTAMPTZ NOT NULL,
  date_local DATE NOT NULL,
  timezone VARCHAR(50) NOT NULL,
  day_of_week SMALLINT NOT NULL,
  is_weekend BOOLEAN NOT NULL,
  time_bucket time_bucket_enum NOT NULL,
  weather_condition weather_condition_enum NOT NULL DEFAULT 'unknown',
  temperature_bucket temperature_bucket_enum NOT NULL DEFAULT 'unknown',
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
  CONSTRAINT context_snapshots_day_of_week_check
    CHECK (day_of_week BETWEEN 1 AND 7)
);

CREATE TABLE IF NOT EXISTS user_habit_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signal_type habit_signal_type_enum NOT NULL,
  subject_type habit_subject_type_enum NOT NULL,
  subject_value VARCHAR(100) NOT NULL,
  context_filter JSONB NOT NULL DEFAULT '{}'::jsonb,
  evidence_count INTEGER NOT NULL DEFAULT 0,
  confidence NUMERIC(5,4) NOT NULL DEFAULT 0,
  first_observed_at TIMESTAMPTZ,
  last_observed_at TIMESTAMPTZ,
  example_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
  status habit_signal_status_enum NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_habit_signals_confidence_check
    CHECK (confidence >= 0 AND confidence <= 1),
  CONSTRAINT user_habit_signals_evidence_count_check
    CHECK (evidence_count >= 0)
);

CREATE TABLE IF NOT EXISTS ai_context_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  input_id UUID REFERENCES ai_inputs(id) ON DELETE SET NULL,
  package_type ai_package_type_enum NOT NULL,
  context_keys JSONB NOT NULL DEFAULT '[]'::jsonb,
  payload_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  token_estimate INTEGER,
  privacy_level privacy_level_enum NOT NULL DEFAULT 'minimal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ai_context_packages_token_estimate_check
    CHECK (token_estimate IS NULL OR token_estimate >= 0)
);

CREATE TABLE IF NOT EXISTS ai_recommendation_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  insight_id UUID NOT NULL REFERENCES ai_insights(id) ON DELETE CASCADE,
  feedback_type feedback_type_enum NOT NULL,
  feedback_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;
