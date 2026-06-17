CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID,
  category_id UUID,
  type VARCHAR(20) NOT NULL,
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
  CONSTRAINT transactions_source_input_fk
    FOREIGN KEY (source_input_id)
    REFERENCES ai_inputs(id)
    ON DELETE SET NULL,
  CONSTRAINT transactions_type_check
    CHECK (type IN ('income', 'expense')),
  CONSTRAINT transactions_amount_check
    CHECK (amount > 0)
);

CREATE TABLE transaction_tags (
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

CREATE TABLE budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID,
  period VARCHAR(10) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  limit_amount NUMERIC(14,2) NOT NULL,
  alert_threshold NUMERIC(5,2) NOT NULL DEFAULT 0.80,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT budgets_category_fk
    FOREIGN KEY (category_id)
    REFERENCES categories(id)
    ON DELETE SET NULL,
  CONSTRAINT budgets_period_check
    CHECK (period IN ('day', 'week', 'month', 'year')),
  CONSTRAINT budgets_amount_check
    CHECK (limit_amount > 0 AND alert_threshold > 0 AND alert_threshold <= 1),
  CONSTRAINT budgets_date_check
    CHECK (end_date >= start_date)
);

CREATE TABLE spending_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  period_type VARCHAR(10) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_income NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_expense NUMERIC(14,2) NOT NULL DEFAULT 0,
  balance NUMERIC(14,2) NOT NULL DEFAULT 0,
  category_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT spending_summaries_period_type_check
    CHECK (period_type IN ('day', 'month', 'year')),
  CONSTRAINT spending_summaries_date_check
    CHECK (period_end >= period_start),
  UNIQUE (user_id, period_type, period_start)
);
