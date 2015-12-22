FROM starefossen/node-imagemagick:4-6

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/package.json
RUN npm install --production

COPY . /usr/src/app

CMD [ "node", "lib/server.js" ]
