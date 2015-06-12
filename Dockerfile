FROM starefossen/iojs-imagemagick:1.6-6.9

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/package.json
RUN npm install

COPY . /usr/src/app
RUN ./node_modules/.bin/coffee --bare --compile --output lib/ src/
CMD ./node_modules/.bin/supervisor lib/server.js
