-- Supporting indexes for the scoped member/fee queries.
-- These are additive and do not change data or lifecycle semantics.
CREATE INDEX "members_org_branch_status_created_idx"
  ON "members" ("organization_id", "branch_id", "status", "created_at");

CREATE INDEX "subscriptions_org_branch_member_status_end_idx"
  ON "subscriptions" ("organization_id", "branch_id", "member_id", "status", "end_date");

CREATE INDEX "ledger_entries_org_branch_member_subscription_idx"
  ON "ledger_entries" ("organization_id", "branch_id", "member_id", "subscription_id");

CREATE INDEX "payment_requests_org_branch_member_status_created_idx"
  ON "payment_requests" ("organization_id", "branch_id", "member_id", "status", "created_at");
