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

    multer = require('multer')
      putSingleFilesInArray: true
      dest: require('os').tmpdir()

Configure the `/upload` route handler.

    api.post '/upload', multer, (req, res, next) ->
      librato.logImagesUploaded Object.keys req.files

      files = []
      for key, f of req.files
        files.push file for file in f

      async.mapSeries files, (file, cb) ->
        if file.extension.toLowerCase() not in ['jpg', 'jpeg', 'png', 'gif']
          error = new Error "Invalid Image #{file.extension}"
          error.status = 422
          return cb error

        t1 = new Date().getTime()
        s3.upload file.path, {}, (err, images, meta) ->
          return cb err if err

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

Loop over all the generated images and apply `width` and `height` properties
since that is currently not set correctly. We also remove some image information
such as AWS key and local path which are not in use.

          for image in images
            # Since we
            if not image.width
              image.height = image.maxHeight
              image.width = image.maxWidth

              if image.aspect
                image.height = Math.floor image.maxHeight * 2 / 3
              else
                if meta.height > meta.width
                  image.width = Math.floor image.height * meta.width / meta.height
                else
                  image.height = Math.floor image.width * meta.height / meta.width

            image.key       = undefined
            image.maxHeight = undefined
            image.maxWidth  = undefined
            image.path      = undefined
            image.suffix    = undefined

          return cb null, versions: images, meta: meta
      , (err, files) ->
        return next err if err
        sentry.captureHeaderSent req, files if res._headerSent
        return res.status(201).json files

    module.exports = api
