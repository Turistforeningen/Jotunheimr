Client = require 'librato'

module.exports = new Client \
  process.env.LIBRATO_USER, \
  process.env.LIBRATO_TOKEN, \
  prefix: process.env.LIBRATO_PREFIX, source: process.env.DOTCLOUD_SERVICE_ID or 'test'

module.exports.logRequest = (method) ->
  module.exports.measure 'http.request', 1, source: method

module.exports.logResponse = (status) ->
  module.exports.measure 'http.response', 1, source: '' + status

module.exports.logImagesUploaded = (images) ->
  module.exports.measure 'image.upload', images.length, {}

module.exports.logImageProcessingTime = (t1, t2) ->
  module.exports.measure 'image.processing', (t2 - t1), {}

