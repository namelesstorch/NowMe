const fs = require('fs')
const path = require('path')
const config = require('../src/config')
const { pool } = require('../src/db')

async function ensureMigrationsTable(client) {
  await client.query(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
      filename VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`
  )
}

async function getAppliedMigrations(client) {
  const result = await client.query(
    `SELECT filename
       FROM schema_migrations`
  )
  return new Set(result.rows.map((row) => row.filename))
}

async function run() {
  const client = await pool.connect()

  try {
    await ensureMigrationsTable(client)
    const applied = await getAppliedMigrations(client)

    const filenames = fs
      .readdirSync(config.migrationsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort()

    for (const filename of filenames) {
      if (applied.has(filename)) {
        console.log(`Skipping ${filename}`)
        continue
      }

      const filePath = path.join(config.migrationsDir, filename)
      const sql = fs.readFileSync(filePath, 'utf8')
      console.log(`Applying ${filename}`)

      await client.query('BEGIN')
      await client.query(sql)
      await client.query(
        `INSERT INTO schema_migrations (filename)
         VALUES ($1)`,
        [filename]
      )
      await client.query('COMMIT')
    }

    console.log('Migration complete.')
  } catch (error) {
    await client.query('ROLLBACK')
    console.error(error)
    process.exitCode = 1
  } finally {
    client.release()
    await pool.end()
  }
}

run()
