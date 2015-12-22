/* eslint no-unused-vars: 0, no-console: 0 */
'use strict';

const express = require('express');
const compression = require('compression');
const responseTime = require('response-time');

const raven = require('raven');
const sentry = require('./lib/sentry');
const HttpError = require('@starefossen/node-http-error');

const app = module.exports = express();

app.set('json spaces', 2);
app.set('x-powered-by', false);
app.set('etag', false);

app.use(compression());
app.use(responseTime());

const origins = new Set((process.env.ALLOW_ORIGINS || '').split(','));
const url = require('url');

app.use(function appUseCoors(req, res, next) {
  if (req.get('Origin')) {
    const origin = url.parse(req.get('Origin'));

    if (!origins.has(origin.hostname)) {
      return next(new HttpError(`Bad Origin ${req.get('Origin')}`, 403));
    }

    res.set('Access-Control-Allow-Origin', req.get('Origin'));
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type');
    res.set('Access-Control-Expose-Headers', 'X-Response-Time');
    res.set('Access-Control-Allow-Max-Age', 0);
  }

  if (req.method === 'OPTIONS' && req.path !== '/CloudHealthCheck') {
    return res.status(200).end();
  }

  return next();
});

app.all('/CloudHealthCheck', function appGetCloudCheck(req, res) {
  res.status(200);

  if (req.method === 'HEAD') {
    return res.end();
  }

  res.json({
    message: 'System OK',
  });
});

app.use('/api/v1/', require('./routes/api_v1'));

app.use(function appUseNotFound(req, res, next) {
  res.status(404).json({
    message: 'Not Found',
  });
});

app.use(raven.middleware.express.requestHandler(sentry));
app.use(raven.middleware.express.errorHandler(sentry));

app.use(function appUseErrorHandler(err, req, res, next) {
  if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    err.message = `Unknown form field "${err.field}"`;
    err.code = 400;
  }

  err.code = err.code || 500;
  res.status(err.code);

  if (err.code >= 500) {
    console.error(err);
    console.error(err.message);
    console.error(err.stack);
  }

  if (req.method === 'HEAD') {
    return res.end();
  }

  res.json({
    message: err.message || 'Unknown error',
  });
});

if (!module.parent) {
  app.listen(8080);
  console.log(`Server is listening on port 8080`);
}
