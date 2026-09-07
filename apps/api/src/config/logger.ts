import winston from 'winston';

import { env } from './env';

const { combine, timestamp, json, colorize, simple, errors } = winston.format;

const devFormat = combine(colorize(), timestamp(), errors({ stack: true }), simple());
const prodFormat = combine(timestamp(), errors({ stack: true }), json());

export const logger = winston.createLogger({
  level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: env.NODE_ENV === 'production' ? prodFormat : devFormat,
  transports: [new winston.transports.Console()],
  silent: env.NODE_ENV === 'test',
});
