import { describe, expect, it } from 'vitest';

import { birthdayMatchesLocalDate } from './birthday-jobs.service';

describe('birthday local-date matching', () => {
  it('matches by month and day in the branch timezone', () => {
    expect(
      birthdayMatchesLocalDate(
        new Date('1995-09-30T00:30:00.000Z'),
        new Date('2026-09-30T18:00:00.000Z'),
        'Asia/Kolkata',
      ),
    ).toBe(true);
  });

  it('does not match a different local day', () => {
    expect(
      birthdayMatchesLocalDate(
        new Date('1995-09-29T00:30:00.000Z'),
        new Date('2026-09-30T18:00:00.000Z'),
        'Asia/Kolkata',
      ),
    ).toBe(false);
  });
});
