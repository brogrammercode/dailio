-- QR invites are permanent until explicitly revoked.
ALTER TABLE "invite_tokens"
  ALTER COLUMN "expires_at" DROP NOT NULL;

UPDATE "invite_tokens"
SET "expires_at" = NULL
WHERE "expires_at" IS NOT NULL;
