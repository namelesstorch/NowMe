const { createHttpError } = require('../http')
const { isUuid } = require('../context')

async function ensureCategory(client, userId, categoryInput, type = 'expense') {
  if (!categoryInput) {
    return null
  }

  if (typeof categoryInput === 'object' && categoryInput.id) {
    const category = await getCategoryById(client, userId, categoryInput.id)
    return category
  }

  if (isUuid(categoryInput)) {
    const category = await getCategoryById(client, userId, categoryInput)
    return category
  }

  const name = String(categoryInput).trim()
  if (!name) {
    return null
  }

  const normalizedType = ['income', 'expense', 'both'].includes(type)
    ? type
    : 'expense'

  const inserted = await client.query(
    `INSERT INTO categories (user_id, name, type)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, name, type)
     DO UPDATE SET name = EXCLUDED.name
     RETURNING *`,
    [userId, name, normalizedType]
  )

  return inserted.rows[0]
}

async function getCategoryById(client, userId, categoryId) {
  const result = await client.query(
    `SELECT *
       FROM categories
      WHERE user_id = $1
        AND id = $2`,
    [userId, categoryId]
  )

  if (result.rows.length === 0) {
    throw createHttpError(404, `Category ${categoryId} was not found.`)
  }

  return result.rows[0]
}

async function listCategories(client, userId, filters = {}) {
  const values = [userId]
  const conditions = ['user_id = $1']

  if (filters.type) {
    values.push(filters.type)
    conditions.push(`type = $${values.length}`)
  }

  const result = await client.query(
    `SELECT *
       FROM categories
      WHERE ${conditions.join(' AND ')}
      ORDER BY name ASC, created_at ASC`,
    values
  )

  return result.rows
}

module.exports = {
  ensureCategory,
  getCategoryById,
  listCategories,
}
