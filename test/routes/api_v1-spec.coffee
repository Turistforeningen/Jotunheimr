assert  = require 'assert'
request = require 'supertest'

resolve = require('path').resolve

req = request require '../../src/server'
base = ''

describe '/', ->
  it 'should not return much', (done) ->
    req.get "#{base}/"
      .expect 204
      .end done

describe '/upload', ->
  url = "#{base}/upload"

  it 'should upload single landscape image to s3', (done) ->
    @timeout 30000
    req.post url
      .attach 'files[]', resolve __dirname, '../assets/IMG_5836.jpg'
      .expect 201
      .expect (res) ->
        assert.deepEqual res.body[0].meta.imageSize, { width: 5184, height: 3456 }
        assert.equal res.body[0].versions.length, 3
      .end done

  it 'should upload single horizontal image to s3', (done) ->
    @timeout 30000
    req.post url
      .attach 'files[]', resolve __dirname, '../assets/IMG_5299.jpg'
      .expect 201
      .expect (res) ->
        assert.deepEqual res.body[0].meta.imageSize, { width: 3264, height: 2448 }
        assert.equal res.body[0].versions.length, 3
      .end done

