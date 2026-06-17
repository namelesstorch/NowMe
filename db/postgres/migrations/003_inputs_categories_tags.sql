CREATE TABLE ai_inputs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  input_type VARCHAR(20) NOT NULL,
  content TEXT,
  raw_text TEXT,
  image_url TEXT,
  recognized_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  CONSTRAINT ai_inputs_input_type_check
    CHECK (input_type IN ('text', 'voice', 'image'))
);

CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  type VARCHAR(20) NOT NULL,
  parent_id UUID,
  icon VARCHAR(50),
  color VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  UNIQUE (user_id, name, type),
  CONSTRAINT categories_type_check
    CHECK (type IN ('income', 'expense', 'both')),
  CONSTRAINT categories_parent_fk
    FOREIGN KEY (parent_id)
    REFERENCES categories(id)
    ON DELETE SET NULL
);

CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  color VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, id),
  UNIQUE (user_id, name)
);
