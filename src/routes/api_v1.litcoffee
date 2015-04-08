    express = require 'express'
    Upload  = require 's3-uploader'
    multer  = require 'multer'
    async   = require 'async'
    dms2dec = require 'dms2dec'

    sentry  = require '../sentry'
    librato = require '../librato'

    s3 = new Upload process.env.AWS_BUCKET_NAME,
      awsBucketRegion: process.env.AWS_BUCKET_REGION
      awsBucketPath: process.env.AWS_BUCKET_PATH
      awsBucketAcl: 'public-read'
      awsHttpTimeout: 60000
      returnExif: true

      versions: [
        original: true
        awsImageAcl: 'private'
      ,
        suffix: '-large'
        quality: 80
        maxHeight: 1040
        maxWidth: 1040
      ,
        suffix: '-medium'
        maxHeight: 780
        maxWidth: 780
      ,
        suffix: '-small'
        maxHeight: 320
        maxWidth: 320
      ]

    api = express.Router()

    api.use (req, res, next) ->
      librato.logRequest req.method

      res.once 'close', ->
        librato.logResponse 'closed'
        sentry.captureResClose res

      res.once 'finish', ->
        librato.logResponse res.statusCode

      next()

    api.get '/', (req, res, next) ->
      res.status(204).end()

    api.post '/upload', multer(dest: require('os').tmpdir()), (req, res, next) ->
      librato.logImagesUploaded Object.keys req.files

      async.mapSeries Object.keys(req.files), (key, cb) ->
        if req.files[key].extension.toLowerCase() not in ['jpg', 'jpeg', 'png', 'gif']
          error = new Error "Invalid Image #{req.files[key].extension}"
          error.status = 422
          return cb error

        console.log req.files[key]

        t1 = new Date().getTime()
        s3.upload req.files[key].path, {}, (err, images, meta) ->
          return cb err if err

          librato.logImageProcessingTime t1, new Date().getTime()

          if meta.exif['exif:GPSLatitude'] and meta.exif['exif:GPSLongitude']
            meta.geojson =
              type: 'Point'
              coordinates: dms2dec \
                meta.exif['exif:GPSLatitude'], \
                meta.exif['exif:GPSLatitudeRef'], \
                meta.exif['exif:GPSLongitude'], \
                meta.exif['exif:GPSLongitudeRef']
              .reverse()

          if meta.imageSize.height > meta.imageSize.width
            ratio = meta.imageSize.height / meta.imageSize.width
            edge = 'width'
          else
            ratio = meta.imageSize.width / meta.imageSize.height
            edge = 'height'

          for image in images
            image[edge] = Math.floor(image[edge] / ratio)

            image.path = undefined
            image.src = undefined

          return cb null, versions: images.splice(1), meta: meta
      , (err, files) ->
        return next err if err
        sentry.captureHeaderSent req, files if res._headerSent
        return res.status(201).json files

    module.exports = api

