-- Indexes for the hot cache-first/mobile paths.
-- Keep the existing indexes for compatibility with other query shapes.
CREATE INDEX "members_user_id_status_idx"
  ON "members" ("user_id", "status");

CREATE INDEX "feed_posts_org_branch_feed_status_created_idx"
  ON "feed_posts" ("organization_id", "branch_id", "feed_id", "status", "created_at");

CREATE INDEX "notifications_user_id_read_at_created_at_idx"
  ON "notifications" ("user_id", "read_at", "created_at");

CREATE INDEX "announcements_org_branch_status_created_idx"
  ON "announcements" ("organization_id", "branch_id", "status", "created_at");
