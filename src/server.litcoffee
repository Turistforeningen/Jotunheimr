    compression  = require 'compression'
    express      = require 'express'
    morgan       = require 'morgan'
    responseTime = require 'response-time'

    multer       = require 'multer'
    async        = require 'async'
    dms2dec      = require 'dms2dec'

    raven        = require 'raven'
    sentry       = require './sentry'

    app = express()
    app.use morgan 'combined'
    app.use compression()
    app.use responseTime()

    Upload = require 's3-uploader'
    s3 = new Upload process.env.AWS_BUCKET_NAME,
      awsBucketUrl: "https://s3-eu-west-1.amazonaws.com/#{process.env.AWS_BUCKET_NAME}/"
      awsBucketPath: process.env.AWS_BUCKET_PATH
      awsBucketAcl: 'public-read'
      awsHttpTimeout: 60000
      returnExif: true

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
        error = new Error "Bad Origin Header #{req.get('Origin')}"
        error.status 403
        return next error

      res.set 'Access-Control-Allow-Origin', req.get('Origin')
      res.set 'Access-Control-Allow-Methods', 'POST'
      res.set 'Access-Control-Allow-Headers', 'X-Requested-With, Content-Type'
      res.set 'Access-Control-Expose-Headers', 'X-Response-Time'
      res.set 'Access-Control-Allow-Max-Age', 0

      return res.send 200 if req.method is 'OPTIONS'
      return next()

    app.post '/upload', multer(dest: require('os').tmpdir()), (req, res, next) ->
      console.log "Recieved #{Object.keys(req.files).length} files"

      async.mapSeries Object.keys(req.files), (key, cb) ->
        # @TODO check if file is valid image
        s3.upload req.files[key].path, {}, (err, images, meta) ->
          return cb err if err

          if meta.exif['exif:GPSLatitude'] and meta.exif['exif:GPSLongitude']
            meta.geojson =
              type: 'Point'
              coordinates: dms2dec \
                meta.exif['exif:GPSLatitude'], \
                meta.exif['exif:GPSLatitudeRef'], \
                meta.exif['exif:GPSLongitude'], \
                meta.exif['exif:GPSLongitudeRef']
              .reverse()

          return cb null, versions: images.splice(1), meta: meta
      , (err, files) ->
        return next err if err
        sentry.captureHeaderSent req, files if res._headerSent
        return res.status(201).json files

    app.use raven.middleware.express sentry
    app.use (err, req, res, next) ->
      if not err.status or err.status >= 500
        sentry.captureError error

        console.error err.message
        console.error err.stack

        res.status(err.status or 500).json message: 'Internal Server Error'
      else
        sentry.captureMessage err.message, level: 'warning', req: req
        res.status(err.status).json message: err.message

    if not module.parent
      app.listen process.env.PORT_WWW
      console.log "Server listening on port #{process.env.PORT_WWW}"
    else
      module.exports = app

