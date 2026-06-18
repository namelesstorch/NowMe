const { createHttpError } = require('../http')

function toDateObject(value) {
  const date = value instanceof Date ? value : new Date(value)
  if (Number.isNaN(date.getTime())) {
    throw createHttpError(400, `Invalid date value: ${value}`)
  }
  return date
}

function startOfPeriod(date, periodType) {
  const d = toDateObject(date)
  const year = d.getUTCFullYear()
  const month = d.getUTCMonth()
  const day = d.getUTCDate()

  if (periodType === 'day') {
    return new Date(Date.UTC(year, month, day))
  }

  if (periodType === 'month') {
    return new Date(Date.UTC(year, month, 1))
  }

  if (periodType === 'year') {
    return new Date(Date.UTC(year, 0, 1))
  }

  throw createHttpError(400, `Unsupported period type: ${periodType}`)
}

function endOfPeriod(date, periodType) {
  const start = startOfPeriod(date, periodType)
  if (periodType === 'day') {
    return new Date(Date.UTC(
      start.getUTCFullYear(),
      start.getUTCMonth(),
      start.getUTCDate()
    ))
  }
  if (periodType === 'month') {
    return new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 0))
  }
  return new Date(Date.UTC(start.getUTCFullYear(), 11, 31))
}

function formatDateOnly(date) {
  return toDateObject(date).toISOString().slice(0, 10)
}

async function recalculateFinancialProfile(client, userId) {
  const profileResult = await client.query(
    `SELECT user_id, currency, initial_balance
       FROM user_financial_profiles
      WHERE user_id = $1`,
    [userId]
  )

  if (profileResult.rows.length === 0) {
    throw createHttpError(404, 'Financial profile was not found.')
  }

  const profile = profileResult.rows[0]
  const aggregate = await client.query(
    `SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense
       FROM transactions
      WHERE user_id = $1
        AND deleted_at IS NULL`,
    [userId]
  )

  const totalIncome = Number(aggregate.rows[0].total_income || 0)
  const totalExpense = Number(aggregate.rows[0].total_expense || 0)
  const initialBalance = Number(profile.initial_balance || 0)
  const currentBalance = initialBalance + totalIncome - totalExpense

  const updated = await client.query(
    `UPDATE user_financial_profiles
        SET current_balance = $2,
            updated_at = now()
      WHERE user_id = $1
      RETURNING *`,
    [userId, currentBalance]
  )

  return updated.rows[0]
}

async function rebuildSummary(client, userId, periodType, date) {
  const periodStart = startOfPeriod(date, periodType)
  const periodEnd = endOfPeriod(date, periodType)
  const periodStartText = formatDateOnly(periodStart)
  const periodEndText = formatDateOnly(periodEnd)

  const totals = await client.query(
    `SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense
       FROM transactions
      WHERE user_id = $1
        AND deleted_at IS NULL
        AND occurred_at >= $2::date
        AND occurred_at < ($3::date + INTERVAL '1 day')`,
    [userId, periodStartText, periodEndText]
  )

  const breakdownRows = await client.query(
    `SELECT
        COALESCE(c.name, '未分类') AS category_name,
        COALESCE(SUM(t.amount), 0) AS total_amount
       FROM transactions t
       LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.user_id = $1
        AND t.deleted_at IS NULL
        AND t.type = 'expense'
        AND t.occurred_at >= $2::date
        AND t.occurred_at < ($3::date + INTERVAL '1 day')
      GROUP BY COALESCE(c.name, '未分类')
      ORDER BY total_amount DESC, category_name ASC`,
    [userId, periodStartText, periodEndText]
  )

  const categoryBreakdown = {}
  for (const row of breakdownRows.rows) {
    categoryBreakdown[row.category_name] = Number(row.total_amount || 0)
  }

  const totalIncome = Number(totals.rows[0].total_income || 0)
  const totalExpense = Number(totals.rows[0].total_expense || 0)
  const balance = totalIncome - totalExpense

  const upserted = await client.query(
    `INSERT INTO spending_summaries (
        user_id,
        period_type,
        period_start,
        period_end,
        total_income,
        total_expense,
        balance,
        category_breakdown
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
      ON CONFLICT (user_id, period_type, period_start)
      DO UPDATE SET
        period_end = EXCLUDED.period_end,
        total_income = EXCLUDED.total_income,
        total_expense = EXCLUDED.total_expense,
        balance = EXCLUDED.balance,
        category_breakdown = EXCLUDED.category_breakdown,
        updated_at = now()
      RETURNING *`,
    [
      userId,
      periodType,
      periodStartText,
      periodEndText,
      totalIncome,
      totalExpense,
      balance,
      JSON.stringify(categoryBreakdown),
    ]
  )

  return upserted.rows[0]
}

async function rebuildSummariesForDates(client, userId, dates) {
  const normalizedDates = [...new Set(dates.filter(Boolean).map(String))]
  const summaries = []

  for (const date of normalizedDates) {
    summaries.push(await rebuildSummary(client, userId, 'day', date))
    summaries.push(await rebuildSummary(client, userId, 'month', date))
    summaries.push(await rebuildSummary(client, userId, 'year', date))
  }

  return summaries
}

module.exports = {
  rebuildSummary,
  rebuildSummariesForDates,
  recalculateFinancialProfile,
  formatDateOnly,
}
