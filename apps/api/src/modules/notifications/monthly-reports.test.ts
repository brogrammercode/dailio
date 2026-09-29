import { beforeEach, describe, expect, it, vi } from 'vitest';

const branchFindMany = vi.hoisted(() => vi.fn());
const sendEmailMock = vi.hoisted(() => vi.fn());

vi.mock('../../lib/prisma', () => ({ prisma: { branch: { findMany: branchFindMany } } }));
vi.mock('../../config/logger', () => ({ logger: { warn: vi.fn() } }));
vi.mock('./email.service', () => ({
  escapeHtml: (value: string) => value,
  isEmailConfigured: () => true,
  sendEmail: sendEmailMock,
}));

import { runMonthlyMemberReports } from './monthly-reports.service';

describe('monthly member reports', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    sendEmailMock.mockResolvedValue({ messageId: 'message-1' });
    branchFindMany.mockResolvedValue([
      {
        id: 'branch-1',
        name: 'Barari',
        timezone: 'Asia/Kolkata',
        organization_id: 'org-1',
        organization: {
          name: 'Fitness Gym',
          logo_url: null,
          currency: 'INR',
          status: 'ACTIVE',
        },
        members: [
          {
            member_number: 'MEM-001',
            user: { name: 'Adarsh', email: 'owner@example.com' },
            role: { system_key: 'OWNER' },
            attendance_sessions: [{ worked_minutes: 75 }],
            subscriptions: [
              {
                status: 'ACTIVE',
                start_date: new Date('2026-08-01T00:00:00.000Z'),
                end_date: new Date('2026-11-01T00:00:00.000Z'),
                agreed_amount_minor: 250000,
                plan: { name: '3 Months' },
              },
            ],
          },
        ],
      },
    ]);
  });

  it('emails one branded PDF attachment to the scoped branch owner', async () => {
    const result = await runMonthlyMemberReports({
      start: new Date('2026-08-01T00:00:00.000Z'),
      end: new Date('2026-09-01T00:00:00.000Z'),
      label: 'August 2026',
    });

    expect(result).toEqual({ branches: 1, sent: 1, skipped: 0 });
    expect(sendEmailMock).toHaveBeenCalledWith(
      expect.objectContaining({
        to: 'owner@example.com',
        subject: expect.stringContaining('August 2026'),
        attachments: [
          expect.objectContaining({
            filename: expect.stringContaining('barari'),
            contentType: 'application/pdf',
          }),
        ],
      }),
    );
    const attachment = sendEmailMock.mock.calls[0][0].attachments[0];
    expect(Buffer.isBuffer(attachment.content)).toBe(true);
    expect(attachment.content.subarray(0, 5).toString()).toBe('%PDF-');
  });
});
