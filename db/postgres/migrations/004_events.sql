CREATE TABLE events (
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
  event_type VARCHAR(20) NOT NULL DEFAULT 'schedule',
  priority VARCHAR(10) NOT NULL DEFAULT 'medium',
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  color VARCHAR(20),
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  recurrence_rule JSONB,
  source_input_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, id),
  CONSTRAINT events_source_input_fk
    FOREIGN KEY (source_input_id)
    REFERENCES ai_inputs(id)
    ON DELETE SET NULL,
  CONSTRAINT events_type_check
    CHECK (event_type IN ('schedule', 'todo')),
  CONSTRAINT events_priority_check
    CHECK (priority IN ('low', 'medium', 'high')),
  CONSTRAINT events_status_check
    CHECK (status IN ('active', 'completed', 'cancelled')),
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

CREATE TABLE event_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL,
  remind_at TIMESTAMPTZ NOT NULL,
  method VARCHAR(20) NOT NULL DEFAULT 'push',
  is_sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT event_reminders_event_fk
    FOREIGN KEY (user_id, event_id)
    REFERENCES events(user_id, id)
    ON DELETE CASCADE,
  CONSTRAINT event_reminders_method_check
    CHECK (method IN ('push', 'email', 'sms', 'voice'))
);

CREATE TABLE event_tags (
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
