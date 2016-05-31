'use strict';

const express = require('express');
const dms2dec = require('dms2dec');

const sentry = require('../lib/sentry');
const librato = require('../lib/librato');
const s3 = require('../lib/upload');

const HttpError = require('@starefossen/node-http-error');

const router = express.Router;
const api = router();

api.use((req, res, next) => {
  librato.logRequest(req.method);

  res.once('close', () => {
    librato.logResponse('closed');
    return sentry.captureResClose(res);
  });

  res.once('finish', () => librato.logResponse(res.statusCode));

  return next();
});

api.get('/', (req, res) => res.status(204).end());

const uuid = require('uuid');
const extname = require('path').extname;
const diskStorage = require('multer').diskStorage;
const tmpdir = require('os').tmpdir;
const multer = require('multer')({
  storage: diskStorage({
    destination: tmpdir(),
    filename: function multerFilenameCb(req, file, cb) {
      const ext = extname(file.originalname).substr(1).toLowerCase() || 'jpg';
      return cb(null, `${uuid.v4()}.${ext}`);
    },
  }),
});

api.post('/upload', multer.single('image'), (req, res, next) => {
  librato.logImageUpload();

  if (!/(jpe?g|png|gif)$/i.test(req.file.originalname)) {
    return next(new HttpError(`Invalid Image "${req.file.originalname}"`, 422));
  }

  const t1 = new Date().getTime();

  return s3.upload(req.file.path, {}, (error, versions, meta) => {
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
      image.awsImageAcl = undefined;
      image.key = undefined;
      image.maxHeight = undefined;
      image.maxWidth = undefined;
      image.path = undefined;
      image.suffix = undefined;
    }

    if (res._headerSent) { // eslint-disable-line no-underscore-dangle
      sentry.captureHeaderSent(req, images);
    }

    return res.status(201).json({ meta, versions: images });
  });
});

module.exports = api;
