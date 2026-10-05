-- Additive food-service and audited settlement support. Existing subscription and ledger rows are unchanged.
ALTER TYPE "OrganizationType" ADD VALUE IF NOT EXISTS 'FOOD_SERVICE';
ALTER TYPE "LedgerEntryCategory" ADD VALUE IF NOT EXISTS 'SETTLEMENT_WAIVER';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'SETTLEMENT_WAIVER';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'SERVE';
CREATE TYPE "MealServingStatus" AS ENUM ('CONFIRMED', 'VOID');

CREATE TABLE "meal_slots" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "starts_at_local" TEXT NOT NULL,
  "ends_at_local" TEXT NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "meal_slots_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "meal_slots_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "meal_slots_time_check" CHECK ("starts_at_local" ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' AND "ends_at_local" ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
);
CREATE UNIQUE INDEX "meal_slots_organization_id_branch_id_code_key" ON "meal_slots"("organization_id", "branch_id", "code");
CREATE INDEX "meal_slots_organization_id_branch_id_is_active_idx" ON "meal_slots"("organization_id", "branch_id", "is_active");

CREATE TABLE "plan_meal_entitlements" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "plan_id" TEXT NOT NULL,
  "meal_slot_id" TEXT NOT NULL,
  "max_servings_per_day" INTEGER NOT NULL DEFAULT 1,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "plan_meal_entitlements_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "plan_meal_entitlements_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "plan_meal_entitlements_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "plan_meal_entitlements_meal_slot_id_fkey" FOREIGN KEY ("meal_slot_id") REFERENCES "meal_slots"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "plan_meal_entitlements_limit_check" CHECK ("max_servings_per_day" BETWEEN 1 AND 10)
);
CREATE UNIQUE INDEX "plan_meal_entitlements_organization_id_branch_id_plan_id_meal_slot_id_key" ON "plan_meal_entitlements"("organization_id", "branch_id", "plan_id", "meal_slot_id");
CREATE INDEX "plan_meal_entitlements_organization_id_branch_id_meal_slot_id_idx" ON "plan_meal_entitlements"("organization_id", "branch_id", "meal_slot_id");

CREATE TABLE "meal_servings" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "subscription_id" TEXT NOT NULL,
  "meal_slot_id" TEXT NOT NULL,
  "local_date" DATE NOT NULL,
  "serving_number" INTEGER NOT NULL,
  "status" "MealServingStatus" NOT NULL DEFAULT 'CONFIRMED',
  "served_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "served_by" TEXT NOT NULL,
  "voided_at" TIMESTAMP(3),
  "voided_by" TEXT,
  "void_reason" TEXT,
  "idempotency_key" TEXT NOT NULL,
  CONSTRAINT "meal_servings_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "meal_servings_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "meal_servings_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "meal_servings_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "subscriptions"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "meal_servings_meal_slot_id_fkey" FOREIGN KEY ("meal_slot_id") REFERENCES "meal_slots"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "meal_servings_number_check" CHECK ("serving_number" BETWEEN 1 AND 10)
);
CREATE UNIQUE INDEX "meal_servings_idempotency_key_key" ON "meal_servings"("idempotency_key");
CREATE UNIQUE INDEX "meal_servings_active_number_key" ON "meal_servings"("organization_id", "branch_id", "member_id", "meal_slot_id", "local_date", "serving_number") WHERE "status" = 'CONFIRMED';
CREATE INDEX "meal_servings_organization_id_branch_id_member_id_local_date_idx" ON "meal_servings"("organization_id", "branch_id", "member_id", "local_date");
CREATE INDEX "meal_servings_organization_id_branch_id_meal_slot_id_local_date_status_idx" ON "meal_servings"("organization_id", "branch_id", "meal_slot_id", "local_date", "status");

CREATE TABLE "financial_adjustments" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "subscription_id" TEXT NOT NULL,
  "ledger_entry_id" TEXT NOT NULL,
  "amount_minor_unit" INTEGER NOT NULL,
  "currency" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "approved_by" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "idempotency_key" TEXT NOT NULL,
  CONSTRAINT "financial_adjustments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "financial_adjustments_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "financial_adjustments_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "subscriptions"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "financial_adjustments_ledger_entry_id_fkey" FOREIGN KEY ("ledger_entry_id") REFERENCES "ledger_entries"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "financial_adjustments_positive_amount_check" CHECK ("amount_minor_unit" > 0),
  CONSTRAINT "financial_adjustments_reason_check" CHECK (length(trim("reason")) > 0)
);
CREATE UNIQUE INDEX "financial_adjustments_ledger_entry_id_key" ON "financial_adjustments"("ledger_entry_id");
CREATE UNIQUE INDEX "financial_adjustments_idempotency_key_key" ON "financial_adjustments"("idempotency_key");
CREATE INDEX "financial_adjustments_organization_id_branch_id_member_id_subscription_id_idx" ON "financial_adjustments"("organization_id", "branch_id", "member_id", "subscription_id");

-- Existing protected/member roles retain their self-service meal history access.
UPDATE "roles" SET "permissions" = array_append("permissions", 'MEAL_READ_SELF')
WHERE "system_key" IN ('MEMBER', 'ADMIN') AND NOT ('MEAL_READ_SELF' = ANY("permissions"));
