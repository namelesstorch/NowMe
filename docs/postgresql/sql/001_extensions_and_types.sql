BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'default_view_enum') THEN
    CREATE TYPE default_view_enum AS ENUM ('week', 'month', 'agenda');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_channel_enum') THEN
    CREATE TYPE notification_channel_enum AS ENUM ('push', 'email', 'sms', 'voice');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_channel_enum') THEN
    CREATE TYPE verification_channel_enum AS ENUM ('sms', 'voice');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_purpose_enum') THEN
    CREATE TYPE verification_purpose_enum AS ENUM ('login', 'register', 'reset_phone');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_code_status_enum') THEN
    CREATE TYPE verification_code_status_enum AS ENUM ('pending', 'verified', 'expired', 'cancelled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'category_type_enum') THEN
    CREATE TYPE category_type_enum AS ENUM ('income', 'expense', 'both');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_type_enum') THEN
    CREATE TYPE event_type_enum AS ENUM ('schedule', 'todo');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_priority_enum') THEN
    CREATE TYPE event_priority_enum AS ENUM ('low', 'medium', 'high');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status_enum') THEN
    CREATE TYPE event_status_enum AS ENUM ('active', 'completed', 'cancelled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type_enum') THEN
    CREATE TYPE transaction_type_enum AS ENUM ('income', 'expense');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'budget_period_enum') THEN
    CREATE TYPE budget_period_enum AS ENUM ('day', 'week', 'month', 'year');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'goal_status_enum') THEN
    CREATE TYPE goal_status_enum AS ENUM ('active', 'paused', 'achieved');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'spending_period_enum') THEN
    CREATE TYPE spending_period_enum AS ENUM ('day', 'month', 'year');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_input_type_enum') THEN
    CREATE TYPE ai_input_type_enum AS ENUM ('text', 'voice', 'image');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_entity_type_enum') THEN
    CREATE TYPE ai_entity_type_enum AS ENUM ('event', 'transaction', 'task');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_insight_type_enum') THEN
    CREATE TYPE ai_insight_type_enum AS ENUM ('analysis', 'budget', 'advice', 'reminder');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'context_source_type_enum') THEN
    CREATE TYPE context_source_type_enum AS ENUM ('event', 'transaction', 'ai_input', 'manual');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'time_bucket_enum') THEN
    CREATE TYPE time_bucket_enum AS ENUM ('early_morning', 'morning', 'noon', 'afternoon', 'evening', 'night');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'weather_condition_enum') THEN
    CREATE TYPE weather_condition_enum AS ENUM ('sunny', 'cloudy', 'rainy', 'snowy', 'foggy', 'windy', 'unknown');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'temperature_bucket_enum') THEN
    CREATE TYPE temperature_bucket_enum AS ENUM ('cold', 'cool', 'mild', 'warm', 'hot', 'unknown');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'habit_signal_type_enum') THEN
    CREATE TYPE habit_signal_type_enum AS ENUM ('food_preference', 'spending_pattern', 'schedule_pattern', 'location_pattern', 'time_pattern');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'habit_subject_type_enum') THEN
    CREATE TYPE habit_subject_type_enum AS ENUM ('category', 'tag', 'item', 'location_scene', 'activity_scene', 'text_label');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'habit_signal_status_enum') THEN
    CREATE TYPE habit_signal_status_enum AS ENUM ('active', 'stale', 'rejected');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_package_type_enum') THEN
    CREATE TYPE ai_package_type_enum AS ENUM ('parse', 'recommendation', 'budget', 'schedule_summary', 'monthly_summary');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'privacy_level_enum') THEN
    CREATE TYPE privacy_level_enum AS ENUM ('minimal', 'standard', 'sensitive');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'feedback_type_enum') THEN
    CREATE TYPE feedback_type_enum AS ENUM ('accepted', 'dismissed', 'modified', 'negative');
  END IF;
END
$$;

COMMIT;
