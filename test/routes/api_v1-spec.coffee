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

  it 'should upload single horizontal image to s3', (done) ->
    @timeout 30000
    req.post url
      .attach 'image', resolve __dirname, '../assets/horizontal.jpg'
      .expect 201
      .expect (res) ->
        assert.deepEqual res.body.meta.height, 2623
        assert.deepEqual res.body.meta.width, 5184
        assert.equal res.body.versions.length, 5
      .end done

  it 'should upload single vertical image to s3', (done) ->
    @timeout 30000
    req.post url
      .attach 'image', resolve __dirname, '../assets/vertical.jpg'
      .expect 201
      .expect (res) ->
        assert.deepEqual res.body.meta.height, 3456
        assert.deepEqual res.body.meta.width, 1929
        assert.equal res.body.versions.length, 5
      .end done
