/* eslint func-names: 0 */
'use strict';

const assert = require('assert');
const request = require('supertest');
const resolve = require('path').resolve;
const req = request(require('../..'));

const base = '/api/v1';

describe('/', () => {
  it('should not return much', (done) => {
    req.get(`${base}/`).expect(204, done);
  });
});

describe('/upload', () => {
  const url = `${base}/upload`;

  it('returns 400 for invalid form filed', (done) => {
    req.post(url)
      .attach('some_field', resolve(__dirname, '../assets/invalid.image'))
      .expect(400)
      .expect({
        message: 'Unknown form field "some_field"',
      }, done);
  });

  it('returns 422 for invalid image type', (done) => {
    req.post(url)
      .attach('image', resolve(__dirname, '../assets/invalid.image'))
      .expect(422, done);
  });

  it('should upload single horizontal image to s3', function (done) {
    this.timeout(30000);

    req.post(url)
      .attach('image', resolve(__dirname, '../assets/horizontal.jpg'))
      .expect(201)
      .expect((res) => {
        assert.deepEqual(res.body.meta.height, 2623);
        assert.deepEqual(res.body.meta.width, 5184);
        assert.equal(res.body.versions.length, 5);
      })
      .end(done);
  });

  it('should upload single vertical image to s3', function (done) {
    this.timeout(30000);

    req.post(url)
      .attach('image', resolve(__dirname, '../assets/vertical.jpg'))
      .expect(201)
      .expect((res) => {
        assert.deepEqual(res.body.meta.height, 3456);
        assert.deepEqual(res.body.meta.width, 1929);
        assert.equal(res.body.versions.length, 5);
      })
      .end(done);
  });
});
