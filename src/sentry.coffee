Client = require('raven').Client

Client.prototype.captureHeaderSent = (req, files) ->
  @captureMessage "Headers already sent",
    level: 'error'
    extra: req: req, files: files

Client.prototype.captureResClose = (req) ->
  @captureMessage "Response was closed",
    level: 'warning'
    extra: req: req

module.exports = new Client process.env.SENTRY_DNS

if process.env.SENTRY_DNS
  module.exports.patchGlobal (id, err) ->
    console.error 'Uncaught Exception'
    console.error err.message
    console.error err.stack
    process.exit 1
