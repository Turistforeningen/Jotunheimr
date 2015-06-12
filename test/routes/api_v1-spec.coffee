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
        assert.deepEqual res.body[0].meta.height, 3456
        assert.deepEqual res.body[0].meta.width, 5184
        assert.equal res.body[0].versions.length, 6
      .end done

  it 'should upload single horizontal image to s3', (done) ->
    @timeout 30000
    req.post url
      .attach 'files[]', resolve __dirname, '../assets/IMG_5299.jpg'
      .expect 201
      .expect (res) ->
        assert.deepEqual res.body[0].meta.height, 2448
        assert.deepEqual res.body[0].meta.width, 3264
        assert.equal res.body[0].versions.length, 6
      .end done

