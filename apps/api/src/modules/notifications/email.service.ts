import nodemailer, { type SendMailOptions, type Transporter } from 'nodemailer';

import { env } from '../../config/env';
import { logger } from '../../config/logger';

let transporter: Transporter | null = null;

function getTransporter(): Transporter | null {
  if (!env.MAIL_USER || !env.GOOGLE_APP_PASSWORD) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      host: 'smtp.gmail.com',
      port: 587,
      secure: false,
      auth: {
        user: env.MAIL_USER,
        pass: env.GOOGLE_APP_PASSWORD.replace(/\s+/g, ''),
      },
    });
  }
  return transporter;
}

export function isEmailConfigured() {
  return Boolean(env.MAIL_USER && env.GOOGLE_APP_PASSWORD);
}

export function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

export async function sendEmail(input: {
  to: string;
  subject: string;
  text: string;
  html: string;
}): Promise<{ messageId: string } | null> {
  const mailer = getTransporter();
  if (!mailer || !env.MAIL_USER) return null;

  const options: SendMailOptions = {
    from: `${env.MAIL_FROM_NAME} <${env.MAIL_USER}>`,
    to: input.to,
    subject: input.subject,
    text: input.text,
    html: input.html,
  };
  const result = await mailer.sendMail(options);
  logger.debug('Notification email sent', { message_id: result.messageId });
  return { messageId: result.messageId };
}
