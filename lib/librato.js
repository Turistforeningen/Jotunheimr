'use strict';

const StatsD = require('node-statsd');

module.exports = new StatsD({
  host: process.env.STATSD_HOST || 'localhost',
  port: process.env.STATSD_PORT || 8125,
  prefix: process.env.STATSD_PREFIX || 'jotunheimr.',
});

module.exports.logRequest = function libratoLogRequest(method) {
  module.exports.increment(`http.request.${method}`);
};

module.exports.logResponse = function libratoLogResponse(status) {
  module.exports.increment(`http.response.${status}`);
};

module.exports.logImageUpload = function libratoLogImageUpload() {
  module.exports.increment('image.upload');
};

module.exports.logImageProcessingTime = function libratoLogImageProcessingTime(t1, t2) {
  module.exports.gauge('image.processing', t2 - t1);
};
