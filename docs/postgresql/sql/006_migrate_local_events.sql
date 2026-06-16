BEGIN;

-- 说明：
-- 1. 先执行 001-005，确保目标结构与演示用户已存在。
-- 2. 本脚本假设旧版本地 events 已经导入到 staging_local_events 临时表。
-- 3. 这是参考迁移模板，适合一次性从旧原型迁移到新数据库。

CREATE TEMP TABLE IF NOT EXISTS staging_local_events (
  legacy_event_id TEXT PRIMARY KEY,
  event_date DATE NOT NULL,
  start_hour SMALLINT NOT NULL,
  start_minute SMALLINT NOT NULL DEFAULT 0,
  end_hour SMALLINT NOT NULL,
  end_minute SMALLINT NOT NULL DEFAULT 0,
  title TEXT NOT NULL,
  location TEXT,
  amount NUMERIC(14,2),
  category_name TEXT,
  color TEXT,
  record_type TEXT
);

-- 可选示例：
-- INSERT INTO staging_local_events
--   (legacy_event_id, event_date, start_hour, start_minute, end_hour, end_minute, title, location, amount, category_name, color, record_type)
-- VALUES
--   ('1710000000000', '2026-05-27', 8, 0, 9, 0, '开会', '办公室', NULL, NULL, '#2196F3', NULL),
--   ('1710000000001', '2026-05-27', 18, 30, 19, 30, '食堂晚饭', '学生食堂', 15.00, '餐饮', '#FF7043', 'expense');

CREATE TEMP TABLE IF NOT EXISTS tmp_event_mapping (
  legacy_event_id TEXT PRIMARY KEY,
  new_event_id UUID NOT NULL
);

WITH target_user AS (
  SELECT id
  FROM users
  WHERE phone = '13900000000'
),
inserted_events AS (
  INSERT INTO events (
    id,
    user_id,
    title,
    all_day,
    start_at,
    end_at,
    timezone,
    location,
    event_type,
    priority,
    status,
    color
  )
  SELECT
    (
      substr(md5('event:' || s.legacy_event_id), 1, 8) || '-' ||
      substr(md5('event:' || s.legacy_event_id), 9, 4) || '-' ||
      substr(md5('event:' || s.legacy_event_id), 13, 4) || '-' ||
      substr(md5('event:' || s.legacy_event_id), 17, 4) || '-' ||
      substr(md5('event:' || s.legacy_event_id), 21, 12)
    )::uuid,
    target_user.id,
    s.title,
    false,
    make_timestamptz(
      EXTRACT(YEAR FROM s.event_date)::int,
      EXTRACT(MONTH FROM s.event_date)::int,
      EXTRACT(DAY FROM s.event_date)::int,
      s.start_hour::int,
      s.start_minute::int,
      0,
      'Asia/Shanghai'
    ),
    make_timestamptz(
      EXTRACT(YEAR FROM s.event_date)::int,
      EXTRACT(MONTH FROM s.event_date)::int,
      EXTRACT(DAY FROM s.event_date)::int,
      s.end_hour::int,
      s.end_minute::int,
      0,
      'Asia/Shanghai'
    ),
    'Asia/Shanghai',
    NULLIF(s.location, ''),
    'schedule',
    'medium',
    'active',
    NULLIF(s.color, '')
  FROM staging_local_events s
  CROSS JOIN target_user
  ON CONFLICT (id) DO NOTHING
  RETURNING id
)
INSERT INTO tmp_event_mapping (legacy_event_id, new_event_id)
SELECT
  s.legacy_event_id,
  (
    substr(md5('event:' || s.legacy_event_id), 1, 8) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 9, 4) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 13, 4) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 17, 4) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 21, 12)
  )::uuid
FROM staging_local_events s
LEFT JOIN inserted_events e
  ON e.id = (
    substr(md5('event:' || s.legacy_event_id), 1, 8) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 9, 4) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 13, 4) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 17, 4) || '-' ||
    substr(md5('event:' || s.legacy_event_id), 21, 12)
  )::uuid
ON CONFLICT (legacy_event_id) DO NOTHING;

WITH target_user AS (
  SELECT id
  FROM users
  WHERE phone = '13900000000'
),
upsert_categories AS (
  INSERT INTO categories (user_id, name, type, icon, color)
  SELECT DISTINCT
    target_user.id,
    s.category_name,
    CASE WHEN lower(coalesce(s.record_type, 'expense')) = 'income' THEN 'income'::category_type_enum ELSE 'expense'::category_type_enum END,
    NULL,
    NULL
  FROM staging_local_events s
  CROSS JOIN target_user
  WHERE s.amount IS NOT NULL
    AND s.amount > 0
    AND NULLIF(s.category_name, '') IS NOT NULL
  ON CONFLICT DO NOTHING
  RETURNING id
)
SELECT 1 FROM upsert_categories LIMIT 1;

WITH target_user AS (
  SELECT id
  FROM users
  WHERE phone = '13900000000'
),
prepared_records AS (
  SELECT
    s.legacy_event_id,
    m.new_event_id,
    s.amount,
    NULLIF(s.category_name, '') AS category_name,
    CASE WHEN lower(coalesce(s.record_type, 'expense')) = 'income' THEN 'income'::transaction_type_enum ELSE 'expense'::transaction_type_enum END AS txn_type,
    make_timestamptz(
      EXTRACT(YEAR FROM s.event_date)::int,
      EXTRACT(MONTH FROM s.event_date)::int,
      EXTRACT(DAY FROM s.event_date)::int,
      s.start_hour::int,
      s.start_minute::int,
      0,
      'Asia/Shanghai'
    ) AS occurred_at,
    s.title,
    s.location
  FROM staging_local_events s
  JOIN tmp_event_mapping m
    ON m.legacy_event_id = s.legacy_event_id
  WHERE s.amount IS NOT NULL
    AND s.amount > 0
)
INSERT INTO transactions (
  id,
  user_id,
  event_id,
  category_id,
  type,
  amount,
  currency,
  description,
  occurred_at,
  location,
  is_manual
)
SELECT
  (
    substr(md5('txn:' || prepared_records.legacy_event_id), 1, 8) || '-' ||
    substr(md5('txn:' || prepared_records.legacy_event_id), 9, 4) || '-' ||
    substr(md5('txn:' || prepared_records.legacy_event_id), 13, 4) || '-' ||
    substr(md5('txn:' || prepared_records.legacy_event_id), 17, 4) || '-' ||
    substr(md5('txn:' || prepared_records.legacy_event_id), 21, 12)
  )::uuid,
  target_user.id,
  prepared_records.new_event_id,
  c.id,
  prepared_records.txn_type,
  prepared_records.amount,
  'CNY',
  prepared_records.title,
  prepared_records.occurred_at,
  NULLIF(prepared_records.location, ''),
  true
FROM prepared_records
CROSS JOIN target_user
LEFT JOIN categories c
  ON c.user_id = target_user.id
 AND c.name = prepared_records.category_name
 AND c.deleted_at IS NULL
ON CONFLICT (id) DO NOTHING;

WITH target_user AS (
  SELECT id
  FROM users
  WHERE phone = '13900000000'
),
totals AS (
  SELECT
    COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS total_income,
    COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense
  FROM transactions
  WHERE user_id = (SELECT id FROM target_user)
    AND deleted_at IS NULL
)
UPDATE user_financial_profiles
SET current_balance = initial_balance + totals.total_income - totals.total_expense,
    updated_at = now()
FROM target_user, totals
WHERE user_financial_profiles.user_id = target_user.id;

COMMIT;
