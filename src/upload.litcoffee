    Upload = require 's3-uploader'

Configure [s3-uploader](https://github.com/Turistforeningen/node-s3-uploader) to
store three versions of the image `320px`, `780px`, and `1040px`. The original
image is also uploaded but not publicly avaiable.

    module.exports = new Upload process.env.AWS_BUCKET_NAME,
      aws:
        region: process.env.AWS_BUCKET_REGION
        path: process.env.AWS_BUCKET_PATH
        acl: 'public-read'
        httpOptions: timeout: 60000
      returnExif: true

      versions: [
        original: true
        awsImageAcl: 'private'
      ,
        suffix: '-large'
        quality: 80
        maxHeight: 1040
        maxWidth: 1040
      ,
        suffix: '-medium'
        maxHeight: 780
        maxWidth: 780
      ,
        suffix: '-small'
        maxHeight: 320
        maxWidth: 320
      ]

