DO $$
BEGIN
  CREATE TYPE "InvitePurpose" AS ENUM ('BRANCH_JOIN', 'PLAN_PURCHASE');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "invite_tokens" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "plan_id" TEXT,
  "purpose" "InvitePurpose" NOT NULL,
  "token_hash" TEXT NOT NULL,
  "expires_at" TIMESTAMP(3) NOT NULL,
  "revoked_at" TIMESTAMP(3),
  "created_by" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "invite_tokens_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "invite_tokens_token_hash_key"
  ON "invite_tokens"("token_hash");
CREATE INDEX IF NOT EXISTS "invite_tokens_organization_id_branch_id_purpose_idx"
  ON "invite_tokens"("organization_id", "branch_id", "purpose");
CREATE INDEX IF NOT EXISTS "invite_tokens_plan_id_purpose_idx"
  ON "invite_tokens"("plan_id", "purpose");
CREATE INDEX IF NOT EXISTS "invite_tokens_expires_at_idx"
  ON "invite_tokens"("expires_at");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invite_tokens_organization_id_fkey') THEN
    ALTER TABLE "invite_tokens" ADD CONSTRAINT "invite_tokens_organization_id_fkey"
      FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invite_tokens_branch_id_fkey') THEN
    ALTER TABLE "invite_tokens" ADD CONSTRAINT "invite_tokens_branch_id_fkey"
      FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invite_tokens_plan_id_fkey') THEN
    ALTER TABLE "invite_tokens" ADD CONSTRAINT "invite_tokens_plan_id_fkey"
      FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
