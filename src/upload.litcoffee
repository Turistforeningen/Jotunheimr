    Upload = require 's3-uploader'

Configure [s3-uploader](https://github.com/Turistforeningen/node-s3-uploader) to
store the following versions:

| Suffix    | Max Height | Max Width | Aspect Ratio |
|-----------|------------|-----------|--------------|
| `-full`   | `1200`     | `1200`    |              |
| `-thumb`  | `250`      | `250`     | `1:1`        |
| `-800`    | `800`      | `800`     | `3:2`        |
| `-500`    | `500`      | `500`     | `3:2`        |
| `-260`    | `260`      | `260`     | `3:2`        |
| `-150`    | `150`      | `150`     | `3:2`        |

    module.exports = new Upload process.env.AWS_BUCKET_NAME,
      aws:
        region: process.env.AWS_BUCKET_REGION
        path: process.env.AWS_BUCKET_PATH
        acl: 'public-read'
        httpOptions: timeout: 60000

      returnExif: true

      cleanup:
        original: true
        versions: true

      original:
        awsImageAcl: 'private'

      versions: [
        suffix: '-full'
        quality: 80
        maxHeight: 1200
        maxWidth: 1200
      ,
        suffix: '-thumb'
        maxHeight: 250
        maxWidth: 250
        aspect: '1:1'
      ,
        suffix: '-800'
        maxHeight: 800
        maxWidth: 800
        aspect: '3:2'
      ,
        suffix: '-500'
        maxHeight: 500
        maxWidth: 500
        aspect: '3:2'
      ,
        suffix: '-260'
        maxHeight: 260
        maxWidth: 260
        aspect: '3:2'
      ,
        suffix: '-150'
        maxHeight: 150
        maxWidth: 150
        aspect: '3:2'
      ]
