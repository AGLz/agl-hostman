/**
 * Logger Utility
 * Winston-based logging with file and console transports
 * Falls back to console.log if winston is not installed
 */

const path = require('path');
const fs = require('fs');

// Try to load winston, fall back to console logging if not available
let winston;
try {
  winston = require('winston');
} catch (error) {
  // Winston not available, will use console fallback
  winston = null;
}

// Fallback console logger with winston-compatible interface
const createConsoleLogger = () => {
  const timestamp = () => new Date().toISOString();
  const formatMessage = (level, message, ...meta) => {
    const metaStr = meta.length ? ` ${JSON.stringify(meta)}` : '';
    return `${timestamp()} [${level.toUpperCase()}]: ${message}${metaStr}`;
  };

  return {
    info: (message, ...meta) => console.log(formatMessage('info', message, ...meta)),
    warn: (message, ...meta) => console.warn(formatMessage('warn', message, ...meta)),
    error: (message, ...meta) => console.error(formatMessage('error', message, ...meta)),
    debug: (message, ...meta) => console.log(formatMessage('debug', message, ...meta)),
    verbose: (message, ...meta) => console.log(formatMessage('verbose', message, ...meta)),
  };
};

let logger;

if (winston) {
  // Winston is available, use full-featured logging
  const logsDir = path.join(process.cwd(), 'logs');
  if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
  }

  const devFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
      const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
      return `${timestamp} [${level}]: ${message} ${metaStr}`;
    })
  );

  const prodFormat = winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  );

  const logFormat = process.env.NODE_ENV === 'production' ? prodFormat : devFormat;

  logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: logFormat,
    transports: [
      new winston.transports.Console({
        stderrLevels: ['error'],
      }),
      new winston.transports.File({
        filename: path.join(logsDir, 'app.log'),
        maxsize: 10 * 1024 * 1024,
        maxFiles: 5,
        tailable: true,
      }),
      new winston.transports.File({
        filename: path.join(logsDir, 'error.log'),
        level: 'error',
        maxsize: 10 * 1024 * 1024,
        maxFiles: 5,
        tailable: true,
      }),
    ],
    exceptionHandlers: [
      new winston.transports.File({
        filename: path.join(logsDir, 'exceptions.log'),
      }),
    ],
    rejectionHandlers: [
      new winston.transports.File({
        filename: path.join(logsDir, 'rejections.log'),
      }),
    ],
  });

  if (process.env.NODE_ENV !== 'production') {
    logger.debug('Logger initialized in development mode with winston');
  }
} else {
  // Winston not available, use console fallback
  logger = createConsoleLogger();
  if (process.env.NODE_ENV !== 'production') {
    logger.debug('Logger initialized in development mode with console fallback (winston not installed)');
  }
}

module.exports = logger;
