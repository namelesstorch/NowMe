const path = require('path')
const { loadEnv } = require('./env')

loadEnv()

const config = {
  port: Number(process.env.PORT || 3000),
  host: process.env.HOST || '0.0.0.0',
  databaseUrl: process.env.DATABASE_URL || '',
  defaultUserId:
    process.env.DEFAULT_USER_ID || '00000000-0000-4000-8000-000000000001',
  defaultUsername: process.env.DEFAULT_USERNAME || 'nowme_demo_user',
  defaultTimezone: process.env.DEFAULT_USER_TIMEZONE || 'Asia/Shanghai',
  defaultCurrency: process.env.DEFAULT_CURRENCY || 'CNY',
  allowedOrigin: process.env.ALLOWED_ORIGIN || '*',
  rootDir: path.resolve(__dirname, '..', '..'),
  migrationsDir: path.resolve(
    __dirname,
    '..',
    '..',
    'db',
    'postgres',
    'migrations'
  ),
  eventSyncPaymentMethod: 'event_sync',
}

if (!config.databaseUrl) {
  throw new Error('DATABASE_URL is required. Please configure backend/.env.')
}

module.exports = config
