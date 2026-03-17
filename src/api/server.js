'use strict';

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const { build } = require('./app');

const PORT = parseInt(process.env.HOSTMAN_PORT || '3030', 10);

async function start() {
  const app = await build();
  try {
    await app.listen({ port: PORT, host: '0.0.0.0' });
    app.log.info(`agl-hostman API listening on port ${PORT}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

start();
