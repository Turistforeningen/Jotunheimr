/* eslint no-unused-vars: 0, no-console: 0 */
'use strict';

if (process.env.NODE_ENV === 'production') {
  /* eslint-disable no-console */
  console.log('Starting newrelic application monitoring');
  /* eslint-enable */
  require('newrelic'); // eslint-disable-line global-require
}

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

app.use((req, res, next) => {
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

app.all('/CloudHealthCheck', (req, res) => {
  res.status(200);

  if (req.method === 'HEAD') {
    return res.end();
  }

  return res.json({
    message: 'System OK',
  });
});

app.use('/api/v1/', require('./routes/api_v1'));

app.use((req, res, next) => {
  res.status(404).json({
    message: 'Not Found',
  });
});

app.use(raven.middleware.express.requestHandler(sentry));
app.use(raven.middleware.express.errorHandler(sentry));

app.use((err, req, res, next) => {
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

  return res.json({
    message: err.message || 'Unknown error',
  });
});

if (!module.parent) {
  const port = process.env.PORT_WWW || 8080;
  app.listen(port);
  console.log(`Server is listening on port ${port}`);
}
