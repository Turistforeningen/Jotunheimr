    express = require 'express'
    multer  = require 'multer'
    async   = require 'async'
    dms2dec = require 'dms2dec'

    sentry  = require '../sentry'
    librato = require '../librato'
    s3      = require '../upload'

Make a new Express router object for this part of the application.

    api = express.Router()

## Metrics

Agregate metrics for all requests and wheter they succeded (`finish`) or closed
before the request succeeded (`close`).

    api.use (req, res, next) ->
      librato.logRequest req.method

      res.once 'close', ->
        librato.logResponse 'closed'
        sentry.captureResClose res

      res.once 'finish', ->
        librato.logResponse res.statusCode

      next()

## GET /

    api.get '/', (req, res, next) ->
      res.status(204).end()

## POST /upload

Configure [multer](https://github.com/expressjs/multer) to store files in the
OS's temorary directory `tempdir()`. This way we should not need to clean up the
uploaded files since that should be the job of the OS.

    uuid = require('uuid')
    extname = require('path').extname
    multer = require('multer')
      storage: require('multer').diskStorage
        destination: require('os').tmpdir()
        filename: (req, file, cb) ->
          cb null, uuid.v4() + '.' + extname(file.originalname).substr(1).toLowerCase()

Configure the `/upload` route handler.

    api.post '/upload', multer.single('image'), (req, res, next) ->
      librato.logImageUpload()

      if not /(jpe?g|png|gif)$/i.test req.file.originalname
        error = new Error "Invalid Image #{req.file.originalname}"
        error.statusCode = 422
        return next error

      t1 = new Date().getTime()
      s3.upload req.file.path, {}, (error, images, meta) ->
        return next error if error

        librato.logImageProcessingTime t1, new Date().getTime()

Format image GeoJSON correctly if the image has GPS properties.

        if meta.exif?.GPSLatitude and meta.exif?.GPSLongitude
          meta.geojson =
            type: 'Point'
            coordinates: dms2dec \
              meta.exif.GPSLatitude, \
              meta.exif.GPSLatitudeRef, \
              meta.exif.GPSLongitude, \
              meta.exif.GPSLongitudeRef
            .reverse()

We need to remove the original image (index i - 1) since it is not publicly
accessible. It gets uploaded to AWS as backup of the original image.

        images = images.splice 0, images.length - 1

        for image in images
          image.aspect      = undefined
          image.awsImageAcl = undefined
          image.key         = undefined
          image.maxHeight   = undefined
          image.maxWidth    = undefined
          image.path        = undefined
          image.suffix      = undefined

        sentry.captureHeaderSent req, images if res._headerSent

        res.status 201
        res.json meta: meta, versions: images

    module.exports = api
