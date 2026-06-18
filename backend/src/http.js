const { AppError } = require('./errors')

function asyncHandler(handler) {
  return async (req, res, next) => {
    try {
      await handler(req, res, next)
    } catch (error) {
      next(error)
    }
  }
}

function sendJson(res, data, status = 200) {
  res.status(status).json({
    success: true,
    value: data,
  })
}

function createHttpError(status, message, details) {
  return new AppError(status, message, details)
}

module.exports = {
  asyncHandler,
  sendJson,
  createHttpError,
}
