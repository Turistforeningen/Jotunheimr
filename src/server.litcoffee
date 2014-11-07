    express      = require 'express'
    errorHandler = require 'errorhandler'
    morgan       = require 'morgan'

    multer       = require 'multer'
    async        = require 'async'

    raven        = require 'raven'
    sentry       = require './sentry'

    app = express()
    app.use morgan 'combined'

    Upload = require 's3-uploader'
    s3 = new Upload process.env.AWS_BUCKET_NAME,
      awsBucketUrl: "https://s3-eu-west-1.amazonaws.com/#{process.env.AWS_BUCKET_NAME}/"
      awsBucketPath: process.env.AWS_BUCKET_PATH
      awsBucketAcl: 'public-read'
      awsHttpTimeout: 60000

      versions: [{
        original: true
        awsImageAcl: 'private'
      },{
        suffix: '-large'
        quality: 80
        maxHeight: 1040
        maxWidth: 1040
      },{
        suffix: '-medium'
        maxHeight: 780
        maxWidth: 780
      },{
        suffix: '-small'
        maxHeight: 320
        maxWidth: 320
      }]

    origins = process.env.ALLOW_ORIGINS?.split(',') or []

    app.all '/upload', (req, res, next) ->
      res.once 'close', -> sentry.captureResClose res

      if not req.get('Origin') or not (req.get('Origin') in origins)
        return res.status(403).json message: 'Bad Origin Header'

      res.set 'Access-Control-Allow-Origin', req.get('Origin')
      res.set 'Access-Control-Allow-Methods', 'POST'
      res.set 'Access-Control-Allow-Headers', 'X-Requested-With, Content-Type'
      res.set 'Access-Control-Allow-Max-Age', 0

      return res.send 200 if req.method is 'OPTIONS'
      return next()

    app.post '/upload', multer(dest: require('os').tmpdir()), (req, res, next) ->
      console.log "Recieved #{Object.keys(req.files).length} files"

      async.mapSeries Object.keys(req.files), (key, cb) ->
        # @TODO check if file is valid image
        s3.upload req.files[key].path, {}, (err, images, meta) ->
          return cb err if err
          return cb null, images.splice(1)
      , (err, files) ->
        return next err if err
        sentry.captureHeaderSent req, files if res._headerSent
        return res.status(201).json files

    app.use raven.middleware.express sentry
    app.use errorHandler dumpExceptions: true, showStack: true

    if not module.parent
      app.listen process.env.PORT_WWW
      console.log "Server listening on port #{process.env.PORT_WWW}"
    else
      module.exports = app

