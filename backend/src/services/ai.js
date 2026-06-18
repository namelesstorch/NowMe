async function createAiInput(client, userId, payload) {
  const inputType = payload.inputType || payload.input_type || 'text'
  const inserted = await client.query(
    `INSERT INTO ai_inputs (
        user_id,
        input_type,
        content,
        raw_text,
        image_url,
        recognized_json
      )
      VALUES ($1, $2, $3, $4, $5, $6::jsonb)
      RETURNING *`,
    [
      userId,
      inputType,
      payload.content || null,
      payload.rawText || payload.raw_text || null,
      payload.imageUrl || payload.image_url || null,
      JSON.stringify(payload.recognizedJson || payload.recognized_json || {}),
    ]
  )

  return inserted.rows[0]
}

async function listAiInsights(client, userId, filters = {}) {
  const values = [userId]
  const conditions = ['user_id = $1']

  if (filters.isRead !== undefined) {
    values.push(filters.isRead === 'true')
    conditions.push(`is_read = $${values.length}`)
  }

  const result = await client.query(
    `SELECT *
       FROM ai_insights
      WHERE ${conditions.join(' AND ')}
      ORDER BY created_at DESC`,
    values
  )

  return result.rows
}

async function createAiContextPackage(client, userId, payload) {
  const inserted = await client.query(
    `INSERT INTO ai_context_packages (
        user_id,
        input_id,
        package_type,
        context_keys,
        payload_summary,
        token_estimate,
        privacy_level
      )
      VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6, $7)
      RETURNING *`,
    [
      userId,
      payload.inputId || payload.input_id || null,
      payload.packageType || payload.package_type || 'parse',
      JSON.stringify(payload.contextKeys || payload.context_keys || []),
      JSON.stringify(payload.payloadSummary || payload.payload_summary || {}),
      payload.tokenEstimate || payload.token_estimate || null,
      payload.privacyLevel || payload.privacy_level || 'minimal',
    ]
  )

  return inserted.rows[0]
}

async function listHabitSignals(client, userId) {
  const result = await client.query(
    `SELECT *
       FROM user_habit_signals
      WHERE user_id = $1
      ORDER BY confidence DESC, evidence_count DESC, updated_at DESC`,
    [userId]
  )

  return result.rows
}

async function createRecommendationFeedback(client, userId, payload) {
  const inserted = await client.query(
    `INSERT INTO ai_recommendation_feedback (
        user_id,
        insight_id,
        feedback_type,
        feedback_text
      )
      VALUES ($1, $2, $3, $4)
      RETURNING *`,
    [
      userId,
      payload.insightId || payload.insight_id,
      payload.feedbackType || payload.feedback_type,
      payload.feedbackText || payload.feedback_text || null,
    ]
  )

  return inserted.rows[0]
}

module.exports = {
  createAiInput,
  listAiInsights,
  createAiContextPackage,
  listHabitSignals,
  createRecommendationFeedback,
}
