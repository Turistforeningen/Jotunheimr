'use strict';

const Client = require('librato');

module.exports = new Client(process.env.LIBRATO_USER, process.env.LIBRATO_TOKEN, {
  prefix: process.env.LIBRATO_PREFIX,
  source: process.env.DOTCLOUD_SERVICE_ID || 'test',
});

module.exports.logRequest = function libratoLogRequest(method) {
  module.exports.measure('http.request', 1, {
    source: method,
  });
};

module.exports.logResponse = function libratoLogResponse(status) {
  module.exports.measure('http.response', 1, {
    source: '' + status,
  });
};

module.exports.logImageUpload = function libratoLogImageUpload() {
  module.exports.measure('image.upload', 1, {});
};

module.exports.logImageProcessingTime = function libratoLogProcessingTime(t1, t2) {
  module.exports.measure('image.processing', t2 - t1, {});
};
