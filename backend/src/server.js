const config = require('./config')
const { closePool } = require('./db')
const { createApp } = require('./app')

const app = createApp()

const server = app.listen(config.port, config.host, () => {
  console.log(
    `NowMe backend listening on http://${config.host}:${config.port}`
  )
})

async function shutdown(signal) {
  console.log(`Received ${signal}, shutting down gracefully...`)
  server.close(async () => {
    await closePool()
    process.exit(0)
  })
}

process.on('SIGINT', () => shutdown('SIGINT'))
process.on('SIGTERM', () => shutdown('SIGTERM'))
