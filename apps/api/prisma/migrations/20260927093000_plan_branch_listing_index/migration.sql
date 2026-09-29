-- Keep organization/branch plan selection index-backed for member purchase flows.
CREATE INDEX "plans_organization_id_branch_id_created_at_idx"
  ON "plans"("organization_id", "branch_id", "created_at");
