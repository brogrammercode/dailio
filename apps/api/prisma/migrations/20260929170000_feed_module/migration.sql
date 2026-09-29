CREATE TYPE "FeedReactionType" AS ENUM ('LIKE', 'LOVE', 'CELEBRATE', 'LAUGH', 'SAD', 'ANGRY');
CREATE TYPE "FeedPostStatus" AS ENUM ('ACTIVE', 'HIDDEN');
CREATE TYPE "FeedReportStatus" AS ENUM ('OPEN', 'REVIEWED', 'DISMISSED');

CREATE TABLE "feeds" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "participants_can_post" BOOLEAN NOT NULL DEFAULT false,
  "post_timeout" INTEGER,
  "disbanded" BOOLEAN NOT NULL DEFAULT false,
  "report_threshold" INTEGER NOT NULL DEFAULT 3,
  "created_by_user_id" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "feeds_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "feeds_organization_id_branch_id_name_key" ON "feeds"("organization_id", "branch_id", "name");
CREATE INDEX "feeds_organization_id_branch_id_disbanded_idx" ON "feeds"("organization_id", "branch_id", "disbanded");
ALTER TABLE "feeds"
  ADD CONSTRAINT "feeds_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feeds_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feeds_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "feed_participants" (
  "id" TEXT NOT NULL,
  "feed_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "added_by_user_id" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "removed_at" TIMESTAMP(3),
  CONSTRAINT "feed_participants_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "feed_participants_feed_id_member_id_key" ON "feed_participants"("feed_id", "member_id");
CREATE INDEX "feed_participants_member_id_removed_at_idx" ON "feed_participants"("member_id", "removed_at");
ALTER TABLE "feed_participants"
  ADD CONSTRAINT "feed_participants_feed_id_fkey" FOREIGN KEY ("feed_id") REFERENCES "feeds"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_participants_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_participants_added_by_user_id_fkey" FOREIGN KEY ("added_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "feed_posts" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "feed_id" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "status" "FeedPostStatus" NOT NULL DEFAULT 'ACTIVE',
  "expires_at" TIMESTAMP(3),
  "idempotency_key" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "feed_posts_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "feed_posts_idempotency_key_key" ON "feed_posts"("idempotency_key");
CREATE INDEX "feed_posts_organization_id_branch_id_feed_id_created_at_idx" ON "feed_posts"("organization_id", "branch_id", "feed_id", "created_at");
CREATE INDEX "feed_posts_feed_id_status_expires_at_idx" ON "feed_posts"("feed_id", "status", "expires_at");
ALTER TABLE "feed_posts"
  ADD CONSTRAINT "feed_posts_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_posts_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_posts_feed_id_fkey" FOREIGN KEY ("feed_id") REFERENCES "feeds"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_posts_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "feed_post_reads" (
  "id" TEXT NOT NULL,
  "feed_post_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "read_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "feed_post_reads_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "feed_post_reads_feed_post_id_member_id_key" ON "feed_post_reads"("feed_post_id", "member_id");
ALTER TABLE "feed_post_reads"
  ADD CONSTRAINT "feed_post_reads_feed_post_id_fkey" FOREIGN KEY ("feed_post_id") REFERENCES "feed_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_post_reads_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "feed_reactions" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "feed_post_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "reaction" "FeedReactionType" NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "feed_reactions_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "feed_reactions_feed_post_id_member_id_key" ON "feed_reactions"("feed_post_id", "member_id");
CREATE INDEX "feed_reactions_organization_id_branch_id_feed_post_id_idx" ON "feed_reactions"("organization_id", "branch_id", "feed_post_id");
ALTER TABLE "feed_reactions"
  ADD CONSTRAINT "feed_reactions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_reactions_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_reactions_feed_post_id_fkey" FOREIGN KEY ("feed_post_id") REFERENCES "feed_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_reactions_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "feed_comments" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "feed_post_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "reply_to_id" TEXT,
  "idempotency_key" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  "deleted_at" TIMESTAMP(3),
  CONSTRAINT "feed_comments_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "feed_comments_idempotency_key_key" ON "feed_comments"("idempotency_key");
CREATE INDEX "feed_comments_organization_id_branch_id_feed_post_id_created_at_idx" ON "feed_comments"("organization_id", "branch_id", "feed_post_id", "created_at");
CREATE INDEX "feed_comments_reply_to_id_idx" ON "feed_comments"("reply_to_id");
ALTER TABLE "feed_comments"
  ADD CONSTRAINT "feed_comments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_comments_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_comments_feed_post_id_fkey" FOREIGN KEY ("feed_post_id") REFERENCES "feed_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_comments_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_comments_reply_to_id_fkey" FOREIGN KEY ("reply_to_id") REFERENCES "feed_comments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "feed_reports" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "feed_post_id" TEXT NOT NULL,
  "reporter_member_id" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "status" "FeedReportStatus" NOT NULL DEFAULT 'OPEN',
  "reviewed_by_user_id" TEXT,
  "reviewed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "feed_reports_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "feed_reports_feed_post_id_reporter_member_id_key" ON "feed_reports"("feed_post_id", "reporter_member_id");
CREATE INDEX "feed_reports_organization_id_branch_id_status_idx" ON "feed_reports"("organization_id", "branch_id", "status");
ALTER TABLE "feed_reports"
  ADD CONSTRAINT "feed_reports_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_reports_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_reports_feed_post_id_fkey" FOREIGN KEY ("feed_post_id") REFERENCES "feed_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_reports_reporter_member_id_fkey" FOREIGN KEY ("reporter_member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "feed_reports_reviewed_by_user_id_fkey" FOREIGN KEY ("reviewed_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

UPDATE "roles"
SET "permissions" = ARRAY(
  SELECT DISTINCT permission
  FROM unnest("permissions" || ARRAY['FEED_READ','FEED_CREATE','FEED_UPDATE','FEED_DISBAND','FEED_PARTICIPANT_MANAGE','FEED_POST','FEED_REACT','FEED_COMMENT','FEED_REPORT','FEED_MODERATE']::text[]) AS permission
)
WHERE "system_key" = 'OWNER';

UPDATE "roles"
SET "permissions" = ARRAY(
  SELECT DISTINCT permission
  FROM unnest("permissions" || ARRAY['FEED_READ','FEED_CREATE','FEED_UPDATE','FEED_DISBAND','FEED_PARTICIPANT_MANAGE','FEED_POST','FEED_REACT','FEED_COMMENT','FEED_REPORT','FEED_MODERATE']::text[]) AS permission
)
WHERE "system_key" = 'ADMIN';

UPDATE "roles"
SET "permissions" = ARRAY(
  SELECT DISTINCT permission
  FROM unnest("permissions" || ARRAY['FEED_READ','FEED_POST','FEED_REACT','FEED_COMMENT','FEED_REPORT']::text[]) AS permission
)
WHERE "system_key" = 'MEMBER';
