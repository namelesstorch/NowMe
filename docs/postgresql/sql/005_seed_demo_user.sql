BEGIN;

WITH upsert_user AS (
  INSERT INTO users (username, phone, email, avatar_url, last_login_at)
  VALUES (
    '演示用户',
    '13900000000',
    'demo@wozai.local',
    'https://example.com/assets/demo-avatar.png',
    now()
  )
  ON CONFLICT (phone) DO UPDATE
    SET username = EXCLUDED.username,
        email = EXCLUDED.email,
        avatar_url = EXCLUDED.avatar_url,
        last_login_at = EXCLUDED.last_login_at,
        updated_at = now()
  RETURNING id
)
INSERT INTO user_preferences (user_id, currency, timezone, default_view, reminder_setting)
SELECT id, 'CNY', 'Asia/Shanghai', 'week', '{"default_minutes_before":[10,30]}'::jsonb
FROM upsert_user
ON CONFLICT (user_id) DO UPDATE
  SET currency = EXCLUDED.currency,
      timezone = EXCLUDED.timezone,
      default_view = EXCLUDED.default_view,
      reminder_setting = EXCLUDED.reminder_setting,
      updated_at = now();

WITH demo_user AS (
  SELECT id
  FROM users
  WHERE phone = '13900000000'
)
INSERT INTO user_financial_profiles (user_id, currency, initial_balance, current_balance)
SELECT id, 'CNY', 3000.00, 3000.00
FROM demo_user
ON CONFLICT (user_id) DO UPDATE
  SET currency = EXCLUDED.currency,
      initial_balance = EXCLUDED.initial_balance,
      current_balance = EXCLUDED.current_balance,
      updated_at = now();

WITH demo_user AS (
  SELECT id
  FROM users
  WHERE phone = '13900000000'
)
INSERT INTO notification_settings (user_id, channel, quiet_start, quiet_end, enabled)
SELECT id, channel, '23:00', '07:00', true
FROM demo_user
CROSS JOIN (VALUES ('push'::notification_channel_enum), ('sms'::notification_channel_enum)) AS t(channel)
ON CONFLICT (user_id, channel) DO UPDATE
  SET quiet_start = EXCLUDED.quiet_start,
      quiet_end = EXCLUDED.quiet_end,
      enabled = EXCLUDED.enabled,
      updated_at = now();

WITH demo_user AS (
  SELECT id
  FROM users
  WHERE phone = '13900000000'
)
INSERT INTO categories (user_id, name, type, icon, color)
SELECT demo_user.id, seed.name, seed.type, seed.icon, seed.color
FROM demo_user
CROSS JOIN (
  VALUES
    ('餐饮', 'expense'::category_type_enum, 'food', '#FF7043'),
    ('交通', 'expense'::category_type_enum, 'commute', '#42A5F5'),
    ('购物', 'expense'::category_type_enum, 'shopping', '#AB47BC'),
    ('学习', 'expense'::category_type_enum, 'study', '#26A69A'),
    ('工资', 'income'::category_type_enum, 'salary', '#66BB6A'),
    ('兼职', 'income'::category_type_enum, 'parttime', '#9CCC65')
) AS seed(name, type, icon, color)
ON CONFLICT DO NOTHING;

COMMIT;
