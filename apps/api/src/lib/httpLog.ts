import type { NextFunction, Request, Response } from 'express';

import { env } from '../config/env';
import { logger } from '../config/logger';

import { redactSensitiveRequestUrl } from './requestLog';

const requestColour = '\x1B[38;5;45m';
const successColour = '\x1B[38;5;82m';
const redirectColour = '\x1B[38;5;75m';
const clientErrorColour = '\x1B[38;5;214m';
const serverErrorColour = '\x1B[38;5;196m';
const networkErrorColour = '\x1B[38;5;201m';
const resetColour = '\x1B[0m';

type HttpLogContext = {
  startedAt: bigint;
  requestLogged: boolean;
};

const contextKey = Symbol('dailioHttpLogContext');

type LoggedResponse = Response & {
  [contextKey]?: HttpLogContext;
};

export function istTime(date = new Date()) {
  const now = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
  const two = (value: number) => value.toString().padStart(2, '0');
  const three = (value: number) => value.toString().padStart(3, '0');
  return `${two(now.getUTCHours())}:${two(now.getUTCMinutes())}:${two(
    now.getUTCSeconds(),
  )}.${three(now.getUTCMilliseconds())} IST`;
}

export function safeHttpPath(value: string) {
  const redacted = redactSensitiveRequestUrl(value);
  if (redacted === '*') return redacted;

  try {
    const parsed = new URL(redacted, 'http://dailio.local');
    return `${parsed.pathname || '/'}${parsed.search}`;
  } catch {
    return redacted;
  }
}

export function safeHttpPayload(value: unknown) {
  if (value === undefined || value === null || value === '') return '-';

  let sanitized: unknown;
  try {
    sanitized = sanitize(value);
    const encoded = typeof sanitized === 'string' ? sanitized : JSON.stringify(sanitized);
    if (!encoded) return '-';
    return encoded.length <= 4000 ? encoded : `${encoded.slice(0, 4000)}…`;
  } catch {
    return `<unserializable ${typeof value}>`;
  }
}

export function formatHttpResponseLog(input: {
  time: string;
  speed: string;
  method: string;
  status: number;
  path: string;
}) {
  return (
    `${colourForStatus(input.status)}${emojiForStatus(input.status)} : ` +
    `[${input.time}] : [${input.speed}] : [${input.method}] : ` +
    `[${input.status}] : [${input.path}]${resetColour}`
  );
}

export function httpLogMiddleware(req: Request, res: Response, next: NextFunction) {
  if (env.NODE_ENV === 'test') {
    next();
    return;
  }

  const loggedResponse = res as LoggedResponse;
  const context: HttpLogContext = {
    startedAt: process.hrtime.bigint(),
    requestLogged: false,
  };
  loggedResponse[contextKey] = context;

  res.on('finish', () => writeResponseLog(req, res, context));
  res.on('close', () => {
    if (!res.writableFinished) writeResponseLog(req, res, context);
  });

  next();
}

/** Logs after body parsing, while the start middleware retains timing. */
export function httpRequestBodyLogMiddleware(req: Request, res: Response, next: NextFunction) {
  if (env.NODE_ENV !== 'test') {
    const context = (res as LoggedResponse)[contextKey];
    if (context && !context.requestLogged) {
      context.requestLogged = true;
      writeRequestLog(req);
    }
  }
  next();
}

function writeRequestLog(req: Request) {
  write(
    `${requestColour}[${istTime()}] : [${req.method}] : ` +
      `[${safeHttpPath(req.originalUrl ?? req.url ?? '-')}] : ` +
      `[${safeHttpPayload(req.body)}]${resetColour}`,
  );
}

function writeResponseLog(req: Request, res: Response, context: HttpLogContext) {
  if (!context.requestLogged) {
    context.requestLogged = true;
    writeRequestLog(req);
  }

  const status = res.statusCode;
  const elapsedMs = Number(process.hrtime.bigint() - context.startedAt) / 1_000_000;
  const speed = `${Math.round(elapsedMs)}ms`;
  write(
    formatHttpResponseLog({
      time: istTime(),
      speed,
      method: req.method,
      status,
      path: safeHttpPath(req.originalUrl ?? req.url ?? '-'),
    }),
  );
}

function write(message: string) {
  const output = env.NODE_ENV === 'production' ? stripColours(message) : message;
  logger.info(`[Dailio.HTTP] ${output}`);
}

function stripColours(message: string) {
  return [
    requestColour,
    successColour,
    redirectColour,
    clientErrorColour,
    serverErrorColour,
    networkErrorColour,
    resetColour,
  ].reduce((result, code) => result.split(code).join(''), message);
}

function emojiForStatus(status: number) {
  if (status >= 200 && status < 300) return '✅';
  if (status >= 300 && status < 400) return '↪️';
  if (status >= 400 && status < 500) return '⚠️';
  if (status >= 500) return '❌';
  return '❔';
}

function colourForStatus(status: number) {
  if (status >= 200 && status < 300) return successColour;
  if (status >= 300 && status < 400) return redirectColour;
  if (status >= 400 && status < 500) return clientErrorColour;
  if (status >= 500) return serverErrorColour;
  return networkErrorColour;
}

function sanitize(value: unknown, key?: string, seen = new WeakSet<object>()): unknown {
  if (key && isSensitiveKey(key)) return '[REDACTED]';
  if (
    value === null ||
    value === undefined ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }
  if (typeof value === 'string') return value.length <= 1000 ? value : `${value.slice(0, 1000)}…`;
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    return `<binary ${value.byteLength} bytes>`;
  }
  if (typeof value !== 'object') return String(value);
  if (seen.has(value)) return '[CIRCULAR]';
  seen.add(value);

  if (Array.isArray(value)) return value.map((item) => sanitize(item, undefined, seen));

  const result: Record<string, unknown> = {};
  for (const [entryKey, entryValue] of Object.entries(value)) {
    result[entryKey] = sanitize(entryValue, entryKey, seen);
  }
  return result;
}

function isSensitiveKey(key: string) {
  const normalized = key.toLowerCase().replace(/[^a-z0-9]/g, '');
  const fragments = [
    'authorization',
    'password',
    'secret',
    'token',
    'apikey',
    'signature',
    'selfie',
    'latitude',
    'longitude',
    'preciselocation',
    'deviceinfo',
    'signedurl',
    'presigned',
    'rawqr',
    'fcm',
    'googleid',
    'email',
    'phone',
    'dateofbirth',
    'emergency',
    'avatarurl',
    'storagekey',
    'membernumber',
    'name',
  ];
  return fragments.some((fragment) => normalized.includes(fragment));
}
