const config = require('./config')
const { createHttpError } = require('./http')

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function isUuid(value) {
  return UUID_PATTERN.test(String(value || ''))
}

async function ensureDefaultUser(client, userId) {
  if (!isUuid(userId)) {
    throw createHttpError(400, 'userId must be a valid UUID.')
  }

  const existing = await client.query(
    `SELECT id, username, created_at, updated_at
       FROM users
      WHERE id = $1`,
    [userId]
  )

  if (existing.rows.length === 0) {
    const username =
      userId === config.defaultUserId
        ? config.defaultUsername
        : `user_${userId.slice(0, 8)}`

    await client.query(
      `INSERT INTO users (id, username)
       VALUES ($1, $2)`,
      [userId, username]
    )
  }

  await client.query(
    `INSERT INTO user_preferences (user_id, currency, timezone)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId, config.defaultCurrency, config.defaultTimezone]
  )

  await client.query(
    `INSERT INTO user_financial_profiles (user_id, currency)
     VALUES ($1, $2)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId, config.defaultCurrency]
  )
}

function extractUserId(req) {
  return (
    req.headers['x-user-id'] ||
    req.query.userId ||
    (req.body && req.body.userId) ||
    config.defaultUserId
  )
}

module.exports = {
  ensureDefaultUser,
  extractUserId,
  isUuid,
}
