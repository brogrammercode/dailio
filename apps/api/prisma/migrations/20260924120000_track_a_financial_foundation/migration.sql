DO $$
BEGIN
  ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'PAUSE';
  ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'RESUME';
  ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'RENEW';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "PaymentRequestStatus" AS ENUM (
    'REQUESTED',
    'NEEDS_INFORMATION',
    'APPROVED',
    'REJECTED',
    'CANCELLED'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "payment_attempts"
  ADD COLUMN IF NOT EXISTS "member_id" TEXT;

CREATE TABLE IF NOT EXISTS "payment_requests" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "subscription_id" TEXT,
  "amount_minor_unit" INTEGER NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'INR',
  "method" TEXT NOT NULL,
  "reference" TEXT,
  "note" TEXT,
  "status" "PaymentRequestStatus" NOT NULL DEFAULT 'REQUESTED',
  "rejection_reason" TEXT,
  "reviewer_id" TEXT,
  "reviewed_at" TIMESTAMP(3),
  "payment_attempt_id" TEXT,
  "idempotency_key" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "payment_requests_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "payment_evidence" (
  "id" TEXT NOT NULL,
  "payment_request_id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "uploaded_by" TEXT NOT NULL,
  "storage_key" TEXT NOT NULL,
  "content_type" TEXT NOT NULL,
  "size_bytes" INTEGER,
  "reference" TEXT,
  "note" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "payment_evidence_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "payment_requests_payment_attempt_id_key"
  ON "payment_requests"("payment_attempt_id");
CREATE UNIQUE INDEX IF NOT EXISTS "payment_requests_idempotency_key_key"
  ON "payment_requests"("idempotency_key");
CREATE INDEX IF NOT EXISTS "payment_requests_organization_id_branch_id_status_idx"
  ON "payment_requests"("organization_id", "branch_id", "status");
CREATE INDEX IF NOT EXISTS "payment_requests_member_id_status_idx"
  ON "payment_requests"("member_id", "status");
CREATE INDEX IF NOT EXISTS "payment_requests_subscription_id_idx"
  ON "payment_requests"("subscription_id");
CREATE INDEX IF NOT EXISTS "payment_evidence_organization_id_branch_id_idx"
  ON "payment_evidence"("organization_id", "branch_id");
CREATE INDEX IF NOT EXISTS "payment_evidence_payment_request_id_idx"
  ON "payment_evidence"("payment_request_id");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_attempts_member_id_fkey') THEN
    ALTER TABLE "payment_attempts"
      ADD CONSTRAINT "payment_attempts_member_id_fkey"
      FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_requests_organization_id_fkey') THEN
    ALTER TABLE "payment_requests"
      ADD CONSTRAINT "payment_requests_organization_id_fkey"
      FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_requests_branch_id_fkey') THEN
    ALTER TABLE "payment_requests"
      ADD CONSTRAINT "payment_requests_branch_id_fkey"
      FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_requests_member_id_fkey') THEN
    ALTER TABLE "payment_requests"
      ADD CONSTRAINT "payment_requests_member_id_fkey"
      FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_requests_subscription_id_fkey') THEN
    ALTER TABLE "payment_requests"
      ADD CONSTRAINT "payment_requests_subscription_id_fkey"
      FOREIGN KEY ("subscription_id") REFERENCES "subscriptions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_requests_payment_attempt_id_fkey') THEN
    ALTER TABLE "payment_requests"
      ADD CONSTRAINT "payment_requests_payment_attempt_id_fkey"
      FOREIGN KEY ("payment_attempt_id") REFERENCES "payment_attempts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_evidence_payment_request_id_fkey') THEN
    ALTER TABLE "payment_evidence"
      ADD CONSTRAINT "payment_evidence_payment_request_id_fkey"
      FOREIGN KEY ("payment_request_id") REFERENCES "payment_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
