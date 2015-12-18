'use strict';

const express = require('express');
const dms2dec = require('dms2dec');

const sentry = require('../lib/sentry');
const librato = require('../lib/librato');
const s3 = require('../lib/upload');

const HttpError = require('@starefossen/node-http-error');

const router = express.Router;
const api = router();

api.use(function apiUseLibrato(req, res, next) {
  librato.logRequest(req.method);

  res.once('close', function resOnceClosedCb() {
    librato.logResponse('closed');
    return sentry.captureResClose(res);
  });

  res.once('finish', function resOnceFinishedCb() {
    return librato.logResponse(res.statusCode);
  });

  return next();
});

api.get('/', function apiGetIndex(req, res) {
  return res.status(204).end();
});

const uuid = require('uuid');
const extname = require('path').extname;
const multer = require('multer')({
  storage: require('multer').diskStorage({
    destination: require('os').tmpdir(),
    filename: function multerFilenameCb(req, file, cb) {
      const ext = extname(file.originalname).substr(1).toLowerCase() || 'jpg';
      return cb(null, `${uuid.v4()}.${ext}`);
    },
  }),
});

api.post('/upload', multer.single('image'), function apiGetUpload(req, res, next) {
  librato.logImageUpload();

  if (!/(jpe?g|png|gif)$/i.test(req.file.originalname)) {
    return next(new HttpError(`Invalid Image "${req.file.originalname}"`, 422));
  }

  const t1 = new Date().getTime();

  s3.upload(req.file.path, {}, function s3UploadCb(error, versions, meta) {
    if (error) { return next(error); }

    librato.logImageProcessingTime(t1, new Date().getTime());

    if (meta.exif && meta.exif.GPSLongitude && meta.exif.GPSLatitude) {
      meta.geojson = {
        type: 'Point',
        coordinates: dms2dec(
          meta.exif.GPSLatitude,
          meta.exif.GPSLatitudeRef,
          meta.exif.GPSLongitude,
          meta.exif.GPSLongitudeRef
        ).reverse(),
      };
    }

    const images = versions.splice(0, versions.length - 1);

    for (const image of images) {
      image.aspect = undefined;
      image.awsImageAcl = undefined;
      image.key = undefined;
      image.maxHeight = undefined;
      image.maxWidth = undefined;
      image.path = undefined;
      image.suffix = undefined;
    }

    if (res._headerSent) {
      sentry.captureHeaderSent(req, images);
    }

    res.status(201);

    res.json({ meta, versions: images });
  });
});

module.exports = api;
