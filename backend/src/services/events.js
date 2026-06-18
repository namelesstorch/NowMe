const config = require('../config')
const { createHttpError } = require('../http')
const { ensureCategory } = require('./categories')
const {
  recalculateFinancialProfile,
  rebuildSummariesForDates,
  formatDateOnly,
} = require('./summaries')

function pad(value) {
  return String(value).padStart(2, '0')
}

function getDateParts(value, timezone) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone || 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })

  const parts = formatter.formatToParts(new Date(value))
  const map = {}
  for (const part of parts) {
    if (part.type !== 'literal') {
      map[part.type] = part.value
    }
  }

  return {
    date: `${map.year}-${map.month}-${map.day}`,
    hour: Number(map.hour),
    minute: Number(map.minute),
  }
}

function toIsoWithTimezone(dateText, hour, minute, timezone) {
  const safeHour = Number.isInteger(Number(hour)) ? Number(hour) : 0
  const safeMinute = Number.isInteger(Number(minute)) ? Number(minute) : 0
  if (!dateText) {
    throw createHttpError(400, 'date is required for non-all-day events.')
  }
  return `${dateText}T${pad(safeHour)}:${pad(safeMinute)}:00+08:00`
}

function buildLegacyFields(row) {
  const start = row.start_at ? getDateParts(row.start_at, row.timezone) : null
  const end = row.end_at ? getDateParts(row.end_at, row.timezone) : null

  return {
    date: row.all_day ? row.start_date : start ? start.date : null,
    startHour: start ? start.hour : 0,
    startMinute: start ? start.minute : 0,
    endHour: end ? end.hour : 0,
    endMinute: end ? end.minute : 0,
  }
}

function formatEventRow(row) {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    description: row.description,
    allDay: row.all_day,
    startDate: row.start_date,
    endDate: row.end_date,
    startAt: row.start_at,
    endAt: row.end_at,
    timezone: row.timezone,
    location: row.location,
    eventType: row.event_type,
    priority: row.priority,
    status: row.status,
    color: row.color,
    isRecurring: row.is_recurring,
    recurrenceRule: row.recurrence_rule,
    sourceInputId: row.source_input_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    amount: row.linked_amount !== null ? Number(row.linked_amount) : null,
    category: row.linked_category_name || '',
    categoryId: row.linked_category_id || null,
    ...buildLegacyFields(row),
  }
}

function normalizeEventPayload(payload) {
  const allDay = Boolean(payload.allDay || payload.all_day)
  const timezone = payload.timezone || 'Asia/Shanghai'

  const normalized = {
    id: payload.id || null,
    title: String(payload.title || '').trim(),
    description: payload.description ? String(payload.description).trim() : null,
    allDay,
    startDate: payload.startDate || payload.start_date || payload.date || null,
    endDate:
      payload.endDate || payload.end_date || payload.date || payload.startDate || null,
    startAt: payload.startAt || payload.start_at || null,
    endAt: payload.endAt || payload.end_at || null,
    timezone,
    location: payload.location ? String(payload.location).trim() : null,
    eventType: payload.eventType || payload.event_type || 'schedule',
    priority: payload.priority || 'medium',
    status: payload.status || 'active',
    color: payload.color || null,
    isRecurring: Boolean(payload.isRecurring || payload.is_recurring),
    recurrenceRule: payload.recurrenceRule || payload.recurrence_rule || null,
    amount:
      payload.amount === null || payload.amount === undefined || payload.amount === ''
        ? null
        : Number(payload.amount),
    categoryId: payload.categoryId || payload.category_id || null,
    categoryName: payload.category || payload.categoryName || null,
  }

  if (!normalized.title) {
    throw createHttpError(400, 'title is required.')
  }

  if (allDay) {
    if (!normalized.startDate || !normalized.endDate) {
      throw createHttpError(400, 'all-day events require startDate and endDate.')
    }
  } else {
    if (!normalized.startAt) {
      normalized.startAt = toIsoWithTimezone(
        payload.date,
        payload.startHour,
        payload.startMinute,
        timezone
      )
    }
    if (!normalized.endAt) {
      normalized.endAt = toIsoWithTimezone(
        payload.date,
        payload.endHour,
        payload.endMinute,
        timezone
      )
    }

    const startDate = new Date(normalized.startAt)
    const endDate = new Date(normalized.endAt)

    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
      throw createHttpError(400, 'Invalid startAt or endAt.')
    }

    if (endDate <= startDate) {
      throw createHttpError(400, 'endAt must be later than startAt.')
    }

    normalized.startDate = startDate.toISOString().slice(0, 10)
    normalized.endDate = endDate.toISOString().slice(0, 10)
  }

  if (normalized.amount !== null) {
    if (!Number.isFinite(normalized.amount) || normalized.amount < 0) {
      throw createHttpError(400, 'amount must be a non-negative number.')
    }
  }

  return normalized
}

function deriveOccurredAtFromEvent(eventInput) {
  if (eventInput.startAt) {
    return eventInput.startAt
  }
  return `${eventInput.startDate}T09:00:00+08:00`
}

async function upsertEventContextSnapshot(client, userId, eventRow) {
  const occurredAt = eventRow.start_at || `${eventRow.start_date}T09:00:00+08:00`
  const dateObj = new Date(occurredAt)
  const hour = dateObj.getUTCHours()
  const dayOfWeek = ((dateObj.getUTCDay() + 6) % 7) + 1

  let timeBucket = 'night'
  if (hour < 6) timeBucket = 'early_morning'
  else if (hour < 11) timeBucket = 'morning'
  else if (hour < 13) timeBucket = 'noon'
  else if (hour < 18) timeBucket = 'afternoon'
  else if (hour < 22) timeBucket = 'evening'

  const locationText = eventRow.location || null
  let locationScene = 'unknown'
  if (locationText) {
    if (/家|home/i.test(locationText)) locationScene = 'home'
    else if (/公司|办公室|office|work/i.test(locationText)) locationScene = 'work'
    else if (/学校|school/i.test(locationText)) locationScene = 'school'
    else if (/超市|market/i.test(locationText)) locationScene = 'supermarket'
    else if (/餐厅|饭店|restaurant/i.test(locationText)) locationScene = 'restaurant'
    else locationScene = 'outdoor'
  }

  let activityScene = 'work'
  if (/吃|餐|饭|meal/i.test(eventRow.title)) activityScene = 'meal'
  else if (/买|购|超市|shopping/i.test(eventRow.title)) activityScene = 'shopping'
  else if (/学|课|study/i.test(eventRow.title)) activityScene = 'study'
  else if (/通勤|地铁|公交|commute/i.test(eventRow.title)) activityScene = 'commute'
  else if (/健身|运动|fitness/i.test(eventRow.title)) activityScene = 'fitness'
  else if (/聚|见面|social/i.test(eventRow.title)) activityScene = 'social'
  else if (/办事|errand/i.test(eventRow.title)) activityScene = 'errand'

  const existing = await client.query(
    `SELECT id
       FROM context_snapshots
      WHERE user_id = $1
        AND event_id = $2
      LIMIT 1`,
    [userId, eventRow.id]
  )

  const values = [
    userId,
    eventRow.id,
    occurredAt,
    formatDateOnly(dateObj),
    eventRow.timezone,
    dayOfWeek,
    dayOfWeek >= 6,
    timeBucket,
    locationText,
    locationScene,
    activityScene,
  ]

  if (existing.rows.length === 0) {
    await client.query(
      `INSERT INTO context_snapshots (
          user_id,
          source_type,
          event_id,
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
        VALUES ($1, 'event', $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
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

async function syncEventTransaction(client, userId, eventId, eventInput) {
  const existingRows = await client.query(
    `SELECT id, occurred_at
       FROM transactions
      WHERE user_id = $1
        AND event_id = $2
        AND payment_method = $3
        AND deleted_at IS NULL
      ORDER BY created_at ASC`,
    [userId, eventId, config.eventSyncPaymentMethod]
  )

  if (!eventInput.amount || eventInput.amount <= 0) {
    if (existingRows.rows.length > 0) {
      await client.query(
        `UPDATE transactions
            SET deleted_at = now(),
                updated_at = now()
          WHERE user_id = $1
            AND event_id = $2
            AND payment_method = $3
            AND deleted_at IS NULL`,
        [userId, eventId, config.eventSyncPaymentMethod]
      )
      await client.query(
        `DELETE FROM context_snapshots
          WHERE user_id = $1
            AND transaction_id IN (
              SELECT id
                FROM transactions
               WHERE user_id = $1
                 AND event_id = $2
                 AND payment_method = $3
            )`,
        [userId, eventId, config.eventSyncPaymentMethod]
      )
    }
    return existingRows.rows.map((row) => row.occurred_at)
  }

  const category = await ensureCategory(
    client,
    userId,
    eventInput.categoryId || eventInput.categoryName || '未分类',
    'expense'
  )

  const occurredAt = deriveOccurredAtFromEvent(eventInput)

  if (existingRows.rows.length === 0) {
    await client.query(
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
          is_manual
        )
        VALUES ($1, $2, $3, 'expense', $4, $5, $6, $7, $8, $9, true)`,
      [
        userId,
        eventId,
        category ? category.id : null,
        eventInput.amount,
        'CNY',
        eventInput.title,
        occurredAt,
        config.eventSyncPaymentMethod,
        eventInput.location,
      ]
    )
  } else {
    const primary = existingRows.rows[0]

    await client.query(
      `UPDATE transactions
          SET category_id = $3,
              amount = $4,
              description = $5,
              occurred_at = $6,
              location = $7,
              updated_at = now()
        WHERE id = $1
          AND user_id = $2`,
      [
        primary.id,
        userId,
        category ? category.id : null,
        eventInput.amount,
        eventInput.title,
        occurredAt,
        eventInput.location,
      ]
    )

    if (existingRows.rows.length > 1) {
      const extraIds = existingRows.rows.slice(1).map((row) => row.id)
      await client.query(
        `UPDATE transactions
            SET deleted_at = now(),
                updated_at = now()
          WHERE user_id = $1
            AND id = ANY($2::uuid[])`,
        [userId, extraIds]
      )
    }
  }

  return [occurredAt, ...existingRows.rows.map((row) => row.occurred_at)]
}

async function getEventById(client, userId, eventId) {
  const result = await client.query(
    `SELECT
        e.*,
        t.amount AS linked_amount,
        c.id AS linked_category_id,
        c.name AS linked_category_name
       FROM events e
       LEFT JOIN LATERAL (
         SELECT *
           FROM transactions tx
          WHERE tx.event_id = e.id
            AND tx.user_id = e.user_id
            AND tx.payment_method = $3
            AND tx.deleted_at IS NULL
          ORDER BY tx.created_at ASC
          LIMIT 1
       ) t ON true
       LEFT JOIN categories c ON c.id = t.category_id
      WHERE e.user_id = $1
        AND e.id = $2
        AND e.deleted_at IS NULL`,
    [userId, eventId, config.eventSyncPaymentMethod]
  )

  if (result.rows.length === 0) {
    throw createHttpError(404, `Event ${eventId} was not found.`)
  }

  return result.rows[0]
}

async function listEvents(client, userId, filters = {}) {
  const values = [userId, config.eventSyncPaymentMethod]
  const conditions = ['e.user_id = $1', 'e.deleted_at IS NULL']

  if (filters.startDate) {
    values.push(filters.startDate)
    conditions.push(
      `(COALESCE(e.start_date, DATE(e.start_at)) >= $${values.length}::date)`
    )
  }

  if (filters.endDate) {
    values.push(filters.endDate)
    conditions.push(
      `(COALESCE(e.end_date, DATE(e.end_at)) <= $${values.length}::date)`
    )
  }

  const result = await client.query(
    `SELECT
        e.*,
        t.amount AS linked_amount,
        c.id AS linked_category_id,
        c.name AS linked_category_name
       FROM events e
       LEFT JOIN LATERAL (
         SELECT *
           FROM transactions tx
          WHERE tx.event_id = e.id
            AND tx.user_id = e.user_id
            AND tx.payment_method = $2
            AND tx.deleted_at IS NULL
          ORDER BY tx.created_at ASC
          LIMIT 1
       ) t ON true
       LEFT JOIN categories c ON c.id = t.category_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY COALESCE(e.start_at, (e.start_date::text || 'T00:00:00+08:00')::timestamptz) ASC`,
    values
  )

  return result.rows.map(formatEventRow)
}

async function createEvent(client, userId, payload) {
  const input = normalizeEventPayload(payload)

  const inserted = await client.query(
    `INSERT INTO events (
        user_id,
        title,
        description,
        all_day,
        start_date,
        end_date,
        start_at,
        end_at,
        timezone,
        location,
        event_type,
        priority,
        status,
        color,
        is_recurring,
        recurrence_rule,
        source_input_id
      )
      VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8,
        $9, $10, $11, $12, $13, $14, $15, $16, $17
      )
      RETURNING *`,
    [
      userId,
      input.title,
      input.description,
      input.allDay,
      input.allDay ? input.startDate : null,
      input.allDay ? input.endDate : null,
      input.allDay ? null : input.startAt,
      input.allDay ? null : input.endAt,
      input.timezone,
      input.location,
      input.eventType,
      input.priority,
      input.status,
      input.color,
      input.isRecurring,
      input.recurrenceRule ? JSON.stringify(input.recurrenceRule) : null,
      payload.sourceInputId || payload.source_input_id || null,
    ]
  )

  const eventRow = inserted.rows[0]
  const affectedDates = [eventRow.start_at || eventRow.start_date]

  const transactionDates = await syncEventTransaction(client, userId, eventRow.id, input)
  await upsertEventContextSnapshot(client, userId, eventRow)
  await recalculateFinancialProfile(client, userId)
  await rebuildSummariesForDates(client, userId, [...affectedDates, ...transactionDates])

  const fullRow = await getEventById(client, userId, eventRow.id)
  return formatEventRow(fullRow)
}

async function updateEvent(client, userId, eventId, payload) {
  const existing = await getEventById(client, userId, eventId)
  const input = normalizeEventPayload({ ...existing, ...payload, id: eventId })

  await client.query(
    `UPDATE events
        SET title = $3,
            description = $4,
            all_day = $5,
            start_date = $6,
            end_date = $7,
            start_at = $8,
            end_at = $9,
            timezone = $10,
            location = $11,
            event_type = $12,
            priority = $13,
            status = $14,
            color = $15,
            is_recurring = $16,
            recurrence_rule = $17,
            updated_at = now()
      WHERE user_id = $1
        AND id = $2`,
    [
      userId,
      eventId,
      input.title,
      input.description,
      input.allDay,
      input.allDay ? input.startDate : null,
      input.allDay ? input.endDate : null,
      input.allDay ? null : input.startAt,
      input.allDay ? null : input.endAt,
      input.timezone,
      input.location,
      input.eventType,
      input.priority,
      input.status,
      input.color,
      input.isRecurring,
      input.recurrenceRule ? JSON.stringify(input.recurrenceRule) : null,
    ]
  )

  const updatedRow = await getEventById(client, userId, eventId)
  const transactionDates = await syncEventTransaction(client, userId, eventId, input)
  await upsertEventContextSnapshot(client, userId, updatedRow)
  await recalculateFinancialProfile(client, userId)
  await rebuildSummariesForDates(client, userId, [
    existing.start_at || existing.start_date,
    updatedRow.start_at || updatedRow.start_date,
    ...transactionDates,
  ])

  const fullRow = await getEventById(client, userId, eventId)
  return formatEventRow(fullRow)
}

async function deleteEvent(client, userId, eventId) {
  const existing = await getEventById(client, userId, eventId)

  const linkedTransactions = await client.query(
    `SELECT occurred_at
       FROM transactions
      WHERE user_id = $1
        AND event_id = $2
        AND payment_method = $3
        AND deleted_at IS NULL`,
    [userId, eventId, config.eventSyncPaymentMethod]
  )

  await client.query(
    `UPDATE events
        SET deleted_at = now(),
            updated_at = now()
      WHERE user_id = $1
        AND id = $2
        AND deleted_at IS NULL`,
    [userId, eventId]
  )

  await client.query(
    `UPDATE transactions
        SET deleted_at = now(),
            updated_at = now()
      WHERE user_id = $1
        AND event_id = $2
        AND payment_method = $3
        AND deleted_at IS NULL`,
    [userId, eventId, config.eventSyncPaymentMethod]
  )

  await client.query(
    `DELETE FROM context_snapshots
      WHERE user_id = $1
        AND (event_id = $2 OR transaction_id IN (
          SELECT id
            FROM transactions
           WHERE user_id = $1
             AND event_id = $2
             AND payment_method = $3
        ))`,
    [userId, eventId, config.eventSyncPaymentMethod]
  )

  await recalculateFinancialProfile(client, userId)
  await rebuildSummariesForDates(client, userId, [
    existing.start_at || existing.start_date,
    ...linkedTransactions.rows.map((row) => row.occurred_at),
  ])

  return {
    id: eventId,
    deleted: true,
  }
}

module.exports = {
  listEvents,
  createEvent,
  updateEvent,
  deleteEvent,
}
