/* eslint no-console: 0 */
'use strict';

const Client = require('raven').Client;

Client.prototype.captureHeaderSent = function sentryCaptureHeadersSent(req, files) {
  this.captureMessage('Headers already sent', {
    level: 'error',
    extra: { req, files },
  });
};

Client.prototype.captureResClose = function sentryCaptureResClosed(req) {
  this.captureMessage('Response was closed', {
    level: 'warning',
    extra: { req },
  });
};

module.exports = new Client(process.env.SENTRY_DNS);

if (process.env.SENTRY_DNS) {
  module.exports.patchGlobal((id, err) => {
    console.error('Uncaught Exception');
    console.error(err.message);
    console.error(err.stack);
    process.exit(1);
  });
}
