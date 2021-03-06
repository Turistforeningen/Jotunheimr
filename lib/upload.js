'use strict';

const Upload = require('s3-uploader');

module.exports = new Upload(process.env.AWS_BUCKET_NAME, {
  aws: {
    region: process.env.AWS_BUCKET_REGION,
    path: process.env.AWS_BUCKET_PATH,
    acl: 'public-read',
    httpOptions: {
      timeout: 60000,
    },
  },
  returnExif: true,
  cleanup: {
    original: true,
    versions: true,
  },
  original: {
    awsImageAcl: 'private',
  },
  versions: [
    {
      suffix: '-full',
      quality: 80,
      maxHeight: 1200,
      maxWidth: 1200,
    }, {
      suffix: '-800',
      maxHeight: 800,
      maxWidth: 800,
      aspect: '3:2!h',
    }, {
      suffix: '-500',
      maxHeight: 500,
      maxWidth: 500,
      aspect: '3:2!h',
    }, {
      suffix: '-260',
      maxHeight: 260,
      maxWidth: 260,
      aspect: '3:2!h',
    }, {
      suffix: '-150',
      maxHeight: 150,
      maxWidth: 150,
      aspect: '3:2!h',
    },
  ],
});
