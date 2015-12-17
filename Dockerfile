FROM starefossen/iojs-imagemagick:2-6

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/package.json
RUN npm install --production

COPY . /usr/src/app
RUN ./node_modules/.bin/coffee --bare --compile --output lib/ src/
CMD ./node_modules/.bin/supervisor lib/server.js
