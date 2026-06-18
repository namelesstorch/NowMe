const express = require('express')
const config = require('./config')
const { pool, query, withTransaction } = require('./db')
const { AppError } = require('./errors')
const { asyncHandler, sendJson, createHttpError } = require('./http')
const { ensureDefaultUser, extractUserId } = require('./context')
const { listCategories, ensureCategory } = require('./services/categories')
const {
  rebuildSummary,
} = require('./services/summaries')
const {
  listEvents,
  createEvent,
  updateEvent,
  deleteEvent,
} = require('./services/events')
const {
  listTransactions,
  createTransaction,
  updateTransaction,
  deleteTransaction,
} = require('./services/transactions')
const {
  createAiInput,
  listAiInsights,
  createAiContextPackage,
  listHabitSignals,
  createRecommendationFeedback,
} = require('./services/ai')

function applyCors(req, res, next) {
  res.setHeader('Access-Control-Allow-Origin', config.allowedOrigin)
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, X-User-Id'
  )
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS')

  if (req.method === 'OPTIONS') {
    res.status(204).end()
    return
  }

  next()
}

function createApp() {
  const app = express()

  app.use(applyCors)
  app.use(express.json({ limit: '1mb' }))

  app.use(
    '/api',
    asyncHandler(async (req, res, next) => {
      const userId = extractUserId(req)
      await withTransaction(async (client) => {
        await ensureDefaultUser(client, userId)
      })
      req.userId = userId
      next()
    })
  )

  app.get(
    '/health',
    asyncHandler(async (req, res) => {
      const result = await query('SELECT now() AS now')
      sendJson(res, {
        status: 'ok',
        databaseTime: result.rows[0].now,
      })
    })
  )

  app.get(
    '/api/events',
    asyncHandler(async (req, res) => {
      const events = await withTransaction((client) =>
        listEvents(client, req.userId, {
          startDate: req.query.startDate,
          endDate: req.query.endDate,
        })
      )
      sendJson(res, events)
    })
  )

  app.post(
    '/api/events',
    asyncHandler(async (req, res) => {
      const event = await withTransaction((client) =>
        createEvent(client, req.userId, req.body || {})
      )
      sendJson(res, event, 201)
    })
  )

  app.put(
    '/api/events/:id',
    asyncHandler(async (req, res) => {
      const event = await withTransaction((client) =>
        updateEvent(client, req.userId, req.params.id, req.body || {})
      )
      sendJson(res, event)
    })
  )

  app.delete(
    '/api/events/:id',
    asyncHandler(async (req, res) => {
      const result = await withTransaction((client) =>
        deleteEvent(client, req.userId, req.params.id)
      )
      sendJson(res, result)
    })
  )

  app.get(
    '/api/transactions',
    asyncHandler(async (req, res) => {
      const transactions = await withTransaction((client) =>
        listTransactions(client, req.userId, {
          type: req.query.type,
          startDate: req.query.startDate,
          endDate: req.query.endDate,
        })
      )
      sendJson(res, transactions)
    })
  )

  app.post(
    '/api/transactions',
    asyncHandler(async (req, res) => {
      const transaction = await withTransaction((client) =>
        createTransaction(client, req.userId, req.body || {})
      )
      sendJson(res, transaction, 201)
    })
  )

  app.put(
    '/api/transactions/:id',
    asyncHandler(async (req, res) => {
      const transaction = await withTransaction((client) =>
        updateTransaction(client, req.userId, req.params.id, req.body || {})
      )
      sendJson(res, transaction)
    })
  )

  app.delete(
    '/api/transactions/:id',
    asyncHandler(async (req, res) => {
      const result = await withTransaction((client) =>
        deleteTransaction(client, req.userId, req.params.id)
      )
      sendJson(res, result)
    })
  )

  app.get(
    '/api/categories',
    asyncHandler(async (req, res) => {
      const categories = await withTransaction((client) =>
        listCategories(client, req.userId, {
          type: req.query.type,
        })
      )
      sendJson(res, categories)
    })
  )

  app.post(
    '/api/categories',
    asyncHandler(async (req, res) => {
      const category = await withTransaction((client) =>
        ensureCategory(
          client,
          req.userId,
          req.body.name,
          req.body.type || 'expense'
        )
      )
      sendJson(res, category, 201)
    })
  )

  app.get(
    '/api/user/financial-profile',
    asyncHandler(async (req, res) => {
      const profile = await withTransaction(async (client) => {
        const result = await client.query(
          `SELECT *
             FROM user_financial_profiles
            WHERE user_id = $1`,
          [req.userId]
        )
        return result.rows[0]
      })
      sendJson(res, profile)
    })
  )

  app.put(
    '/api/user/financial-profile',
    asyncHandler(async (req, res) => {
      const profile = await withTransaction(async (client) => {
        if (req.body.currency) {
          await client.query(
            `UPDATE user_financial_profiles
                SET currency = $2,
                    updated_at = now()
              WHERE user_id = $1`,
            [req.userId, req.body.currency]
          )
        }

        if (req.body.initialBalance !== undefined || req.body.initial_balance !== undefined) {
          const initialBalance = Number(
            req.body.initialBalance !== undefined
              ? req.body.initialBalance
              : req.body.initial_balance
          )
          if (!Number.isFinite(initialBalance)) {
            throw createHttpError(400, 'initialBalance must be a number.')
          }

          await client.query(
            `UPDATE user_financial_profiles
                SET initial_balance = $2,
                    updated_at = now()
              WHERE user_id = $1`,
            [req.userId, initialBalance]
          )
        }

        const recalculated = await require('./services/summaries').recalculateFinancialProfile(
          client,
          req.userId
        )
        return recalculated
      })
      sendJson(res, profile)
    })
  )

  app.get(
    '/api/spending-summaries',
    asyncHandler(async (req, res) => {
      const periodType = req.query.periodType || req.query.period_type
      const date = req.query.date || req.query.periodStart || req.query.period_start

      const summaries = await withTransaction(async (client) => {
        if (periodType && date) {
          return rebuildSummary(client, req.userId, periodType, date)
        }

        const result = await client.query(
          `SELECT *
             FROM spending_summaries
            WHERE user_id = $1
            ORDER BY period_start DESC, period_type ASC
            LIMIT 100`,
          [req.userId]
        )
        return result.rows
      })

      sendJson(res, summaries)
    })
  )

  app.post(
    '/api/ai/inputs',
    asyncHandler(async (req, res) => {
      const aiInput = await withTransaction((client) =>
        createAiInput(client, req.userId, req.body || {})
      )
      sendJson(res, aiInput, 201)
    })
  )

  app.get(
    '/api/ai/insights',
    asyncHandler(async (req, res) => {
      const insights = await withTransaction((client) =>
        listAiInsights(client, req.userId, {
          isRead: req.query.isRead,
        })
      )
      sendJson(res, insights)
    })
  )

  app.post(
    '/api/ai/context-packages',
    asyncHandler(async (req, res) => {
      const contextPackage = await withTransaction((client) =>
        createAiContextPackage(client, req.userId, req.body || {})
      )
      sendJson(res, contextPackage, 201)
    })
  )

  app.get(
    '/api/ai/habit-signals',
    asyncHandler(async (req, res) => {
      const signals = await withTransaction((client) =>
        listHabitSignals(client, req.userId)
      )
      sendJson(res, signals)
    })
  )

  app.post(
    '/api/ai/recommendation-feedback',
    asyncHandler(async (req, res) => {
      const insightId = req.body.insightId || req.body.insight_id
      const feedbackType = req.body.feedbackType || req.body.feedback_type
      if (!insightId || !feedbackType) {
        throw createHttpError(400, 'insightId and feedbackType are required.')
      }

      const feedback = await withTransaction((client) =>
        createRecommendationFeedback(client, req.userId, req.body || {})
      )
      sendJson(res, feedback, 201)
    })
  )

  app.use((req, res) => {
    res.status(404).json({
      success: false,
      message: `Route not found: ${req.method} ${req.originalUrl}`,
    })
  })

  app.use((error, req, res, next) => {
    const status = error instanceof AppError ? error.status : 500
    const message =
      status >= 500 ? 'Internal server error.' : error.message || 'Request failed.'

    if (status >= 500) {
      console.error(error)
    }

    res.status(status).json({
      success: false,
      message,
      details: error.details || null,
    })
  })

  return app
}

module.exports = {
  createApp,
}
