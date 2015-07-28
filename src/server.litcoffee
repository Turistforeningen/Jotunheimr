    express       = require 'express'
    logger        = require 'morgan'
    url           = require 'url'

    compression   = require 'compression'
    responseTime  = require 'response-time'

    raven         = require 'raven'
    sentry        = require './sentry'

    #process.env.LIBRATO_INTERVAL ?= 1
    #librato =
    #  middleware: require('./librato').middleware.use
    #  count     : require('./librato').middleware.routeCount

## Configuration

    process.env.PORT_WWW ?= 8080

    app = module.exports = express()

    app.set 'json spaces', 2
    app.set 'x-powered-by', false

    app.use compression()
    app.use responseTime()

    if app.get('env').toLowerCase() isnt 'test'
      app.use logger 'dev'
      #app.use librato.middleware
      #app.use librato.count name: 'request', period: 1

## CORS

Cross-site HTTP requests are HTTP requests for resources from a different domain
than the domain of the resource making the request. [Read
More](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS).

    origins = process.env.ALLOW_ORIGINS?.split(',') or []

    app.use (req, res, next) ->
      if req.get 'Origin'
        origin = url.parse req.get('Origin') or ''

Check if the request Origin is on in the `ALLOW_ORIGINS` list. If not return a
403 to prevent this Origin from misusing the service.

        if origin.hostname not in origins
          error = new Error "Bad Origin Header #{req.get('Origin')}"
          error.status = 403
          return next error

Set the correct CORS headers.

        res.set 'Access-Control-Allow-Origin', req.get('Origin')
        res.set 'Access-Control-Allow-Methods', 'GET, POST'
        res.set 'Access-Control-Allow-Headers', 'X-Requested-With, Content-Type'
        res.set 'Access-Control-Expose-Headers', 'X-Response-Time'
        res.set 'Access-Control-Allow-Max-Age', 0

Browsers check for CORS support by doing a "preflight". This means sending a
HTTP `OPTIONS` request to the server and checking the returned CORS-headers. No
body is required for this request so we can safely end this request now.

      if req.method is 'OPTIONS' and req.path isnt '/CloudHealthCheck'
        return res.status(200).end()

      return next()

## Routes

    app.all '/CloudHealthCheck', (req, res, next) ->
      res.status 200
      return res.end() if req.method is 'HEAD'
      return res.json message: 'System OK'

    app.use '/', require './routes/api_v1'
    app.use '/api/v1/', require './routes/api_v1'

    app.get '/', (req, res, next) ->
      res.redirect '/api/v1'

## Not Found

    app.use (req, res, next) ->
      res.status(404).json message: 'Not Found'

### Error Handling

Before handling the error ours self make sure that it is propperly logged in
Sentry by using the express/connect middleware.

    app.use raven.middleware.express sentry

All errors passed to `next` or exceptions ends up here. We set the status code
to `500` if it is not already defined in the `Error` object. We then print the
error mesage and stack trace to the console for debug purposes.

Before returning a response to the user the request method is check. HEAD
requests shall not contain any body – this applies for errors as well.

    app.use (err, req, res, next) ->
      if err.code is 'LIMIT_UNEXPECTED_FILE'
        err.message = "Unknown form field \"#{err.field}\""
        err.statusCode = 400

      if not err.statusCode or err.statusCode >= 500
        console.error err
        console.error err.message
        console.error err.stack

      res.status err.statusCode or 500

      return res.end() if req.method is 'HEAD'
      return res.json message: err.message or 'Unknown error'

### Start Server

    if not module.parent
      app.listen process.env.PORT_WWW
      console.log "Server is listening on port #{process.env.PORT_WWW}"
