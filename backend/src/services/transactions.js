const { createHttpError } = require('../http')
const { ensureCategory } = require('./categories')
const {
  recalculateFinancialProfile,
  rebuildSummariesForDates,
  formatDateOnly,
} = require('./summaries')

function formatTransactionRow(row) {
  return {
    id: row.id,
    userId: row.user_id,
    eventId: row.event_id,
    categoryId: row.category_id,
    categoryName: row.category_name || '',
    type: row.type,
    amount: Number(row.amount),
    currency: row.currency,
    description: row.description,
    occurredAt: row.occurred_at,
    paymentMethod: row.payment_method,
    location: row.location,
    isManual: row.is_manual,
    sourceInputId: row.source_input_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

function normalizeTransactionPayload(payload) {
  const amount = Number(payload.amount)
  if (!Number.isFinite(amount) || amount <= 0) {
    throw createHttpError(400, 'amount must be a positive number.')
  }

  const type = payload.type || 'expense'
  if (!['income', 'expense'].includes(type)) {
    throw createHttpError(400, 'type must be income or expense.')
  }

  const occurredAt = payload.occurredAt || payload.occurred_at
  if (!occurredAt || Number.isNaN(new Date(occurredAt).getTime())) {
    throw createHttpError(400, 'occurredAt is required and must be valid.')
  }

  return {
    eventId: payload.eventId || payload.event_id || null,
    categoryId: payload.categoryId || payload.category_id || null,
    categoryName: payload.category || payload.categoryName || null,
    type,
    amount,
    currency: payload.currency || 'CNY',
    description: payload.description ? String(payload.description).trim() : null,
    occurredAt,
    paymentMethod: payload.paymentMethod || payload.payment_method || null,
    location: payload.location ? String(payload.location).trim() : null,
    isManual:
      payload.isManual === undefined && payload.is_manual === undefined
        ? true
        : Boolean(payload.isManual || payload.is_manual),
    sourceInputId: payload.sourceInputId || payload.source_input_id || null,
  }
}

async function validateEventOwnership(client, userId, eventId) {
  if (!eventId) {
    return
  }

  const result = await client.query(
    `SELECT id
       FROM events
      WHERE user_id = $1
        AND id = $2
        AND deleted_at IS NULL`,
    [userId, eventId]
  )

  if (result.rows.length === 0) {
    throw createHttpError(404, `Event ${eventId} was not found for this user.`)
  }
}

async function upsertTransactionContextSnapshot(client, userId, transactionRow) {
  const occurredAt = transactionRow.occurred_at
  const dateObj = new Date(occurredAt)
  const hour = dateObj.getUTCHours()
  const dayOfWeek = ((dateObj.getUTCDay() + 6) % 7) + 1

  let timeBucket = 'night'
  if (hour < 6) timeBucket = 'early_morning'
  else if (hour < 11) timeBucket = 'morning'
  else if (hour < 13) timeBucket = 'noon'
  else if (hour < 18) timeBucket = 'afternoon'
  else if (hour < 22) timeBucket = 'evening'

  let locationScene = 'unknown'
  if (transactionRow.location) {
    if (/超市|market/i.test(transactionRow.location)) locationScene = 'supermarket'
    else if (/餐厅|饭店|restaurant/i.test(transactionRow.location)) locationScene = 'restaurant'
    else if (/公司|办公室|office/i.test(transactionRow.location)) locationScene = 'work'
    else if (/家|home/i.test(transactionRow.location)) locationScene = 'home'
    else locationScene = 'outdoor'
  }

  let activityScene = 'shopping'
  if (/吃|餐|饭|meal/i.test(transactionRow.description || '')) activityScene = 'meal'

  const existing = await client.query(
    `SELECT id
       FROM context_snapshots
      WHERE user_id = $1
        AND transaction_id = $2
      LIMIT 1`,
    [userId, transactionRow.id]
  )

  const values = [
    userId,
    transactionRow.id,
    occurredAt,
    formatDateOnly(dateObj),
    'Asia/Shanghai',
    dayOfWeek,
    dayOfWeek >= 6,
    timeBucket,
    transactionRow.location,
    locationScene,
    activityScene,
  ]

  if (existing.rows.length === 0) {
    await client.query(
      `INSERT INTO context_snapshots (
          user_id,
          source_type,
          transaction_id,
          occurred_at,
          date_local,
          timezone,
          day_of_week,
          is_weekend,
          time_bucket,
          location_text,
          location_scene,
          activity_scene
        )
        VALUES ($1, 'transaction', $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      values
    )
  } else {
    await client.query(
      `UPDATE context_snapshots
          SET occurred_at = $3,
              date_local = $4,
              timezone = $5,
              day_of_week = $6,
              is_weekend = $7,
              time_bucket = $8,
              location_text = $9,
              location_scene = $10,
              activity_scene = $11
        WHERE id = $12`,
      [...values, existing.rows[0].id]
    )
  }
}

async function getTransactionById(client, userId, transactionId) {
  const result = await client.query(
    `SELECT t.*, c.name AS category_name
       FROM transactions t
       LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.user_id = $1
        AND t.id = $2
        AND t.deleted_at IS NULL`,
    [userId, transactionId]
  )

  if (result.rows.length === 0) {
    throw createHttpError(404, `Transaction ${transactionId} was not found.`)
  }

  return result.rows[0]
}

async function listTransactions(client, userId, filters = {}) {
  const values = [userId]
  const conditions = ['t.user_id = $1', 't.deleted_at IS NULL']

  if (filters.type) {
    values.push(filters.type)
    conditions.push(`t.type = $${values.length}`)
  }

  if (filters.startDate) {
    values.push(filters.startDate)
    conditions.push(`t.occurred_at >= $${values.length}::date`)
  }

  if (filters.endDate) {
    values.push(filters.endDate)
    conditions.push(`t.occurred_at < ($${values.length}::date + INTERVAL '1 day')`)
  }

  const result = await client.query(
    `SELECT t.*, c.name AS category_name
       FROM transactions t
       LEFT JOIN categories c ON c.id = t.category_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY t.occurred_at DESC, t.created_at DESC`,
    values
  )

  return result.rows.map(formatTransactionRow)
}

async function createTransaction(client, userId, payload) {
  const input = normalizeTransactionPayload(payload)
  await validateEventOwnership(client, userId, input.eventId)

  const category = await ensureCategory(
    client,
    userId,
    input.categoryId || input.categoryName,
    input.type === 'income' ? 'income' : 'expense'
  )

  const inserted = await client.query(
    `INSERT INTO transactions (
        user_id,
        event_id,
        category_id,
        type,
        amount,
        currency,
        description,
        occurred_at,
        payment_method,
        location,
        is_manual,
        source_input_id
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING *`,
    [
      userId,
      input.eventId,
      category ? category.id : null,
      input.type,
      input.amount,
      input.currency,
      input.description,
      input.occurredAt,
      input.paymentMethod,
      input.location,
      input.isManual,
      input.sourceInputId,
    ]
  )

  const transaction = inserted.rows[0]
  await upsertTransactionContextSnapshot(client, userId, transaction)
  await recalculateFinancialProfile(client, userId)
  await rebuildSummariesForDates(client, userId, [transaction.occurred_at])

  const fullRow = await getTransactionById(client, userId, transaction.id)
  return formatTransactionRow(fullRow)
}

async function updateTransaction(client, userId, transactionId, payload) {
  const existing = await getTransactionById(client, userId, transactionId)
  const input = normalizeTransactionPayload({ ...existing, ...payload })
  await validateEventOwnership(client, userId, input.eventId)

  const category = await ensureCategory(
    client,
    userId,
    input.categoryId || input.categoryName,
    input.type === 'income' ? 'income' : 'expense'
  )

  await client.query(
    `UPDATE transactions
        SET event_id = $3,
            category_id = $4,
            type = $5,
            amount = $6,
            currency = $7,
            description = $8,
            occurred_at = $9,
            payment_method = $10,
            location = $11,
            is_manual = $12,
            source_input_id = $13,
            updated_at = now()
      WHERE user_id = $1
        AND id = $2`,
    [
      userId,
      transactionId,
      input.eventId,
      category ? category.id : null,
      input.type,
      input.amount,
      input.currency,
      input.description,
      input.occurredAt,
      input.paymentMethod,
      input.location,
      input.isManual,
      input.sourceInputId,
    ]
  )

  const updated = await getTransactionById(client, userId, transactionId)
  await upsertTransactionContextSnapshot(client, userId, updated)
  await recalculateFinancialProfile(client, userId)
  await rebuildSummariesForDates(client, userId, [
    existing.occurred_at,
    updated.occurred_at,
  ])

  return formatTransactionRow(updated)
}

async function deleteTransaction(client, userId, transactionId) {
  const existing = await getTransactionById(client, userId, transactionId)

  await client.query(
    `UPDATE transactions
        SET deleted_at = now(),
            updated_at = now()
      WHERE user_id = $1
        AND id = $2
        AND deleted_at IS NULL`,
    [userId, transactionId]
  )

  await client.query(
    `DELETE FROM context_snapshots
      WHERE user_id = $1
        AND transaction_id = $2`,
    [userId, transactionId]
  )

  await recalculateFinancialProfile(client, userId)
  await rebuildSummariesForDates(client, userId, [existing.occurred_at])

  return {
    id: transactionId,
    deleted: true,
  }
}

module.exports = {
  listTransactions,
  createTransaction,
  updateTransaction,
  deleteTransaction,
}
