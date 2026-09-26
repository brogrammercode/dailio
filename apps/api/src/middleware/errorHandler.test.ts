import { describe, expect, it } from 'vitest';

import { AppError } from '../lib/errors';

import { safeErrorForLog } from './errorHandler';

describe('safe error logging', () => {
  it('does not serialize unknown exception messages or stacks', () => {
    const error = new Error('database password and SQL details');
    error.stack = 'sensitive stack and query';

    expect(safeErrorForLog(error)).toEqual({ type: 'Error' });
  });

  it('keeps only the safe contract fields for application errors', () => {
    expect(safeErrorForLog(new AppError(500, 'INTERNAL', 'private details'))).toEqual({
      type: 'AppError',
      code: 'INTERNAL',
      status_code: 500,
    });
  });
});
