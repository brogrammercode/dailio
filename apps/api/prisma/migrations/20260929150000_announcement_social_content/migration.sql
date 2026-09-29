ALTER TABLE "announcements"
  ADD COLUMN "content" JSONB NOT NULL DEFAULT '[]';

CREATE TYPE "AnnouncementReactionType" AS ENUM ('LIKE', 'LOVE', 'CELEBRATE', 'LAUGH', 'SAD', 'ANGRY');

CREATE TABLE "announcement_reactions" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT,
  "announcement_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "reaction" "AnnouncementReactionType" NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "announcement_reactions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "announcement_reactions_announcement_id_user_id_key"
  ON "announcement_reactions"("announcement_id", "user_id");
CREATE INDEX "announcement_reactions_organization_id_branch_id_announcement_id_idx"
  ON "announcement_reactions"("organization_id", "branch_id", "announcement_id");

ALTER TABLE "announcement_reactions"
  ADD CONSTRAINT "announcement_reactions_organization_id_fkey"
    FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "announcement_reactions_branch_id_fkey"
    FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "announcement_reactions_announcement_id_fkey"
    FOREIGN KEY ("announcement_id") REFERENCES "announcements"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "announcement_reactions_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "announcement_comments" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT,
  "announcement_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "reply_to_id" TEXT,
  "idempotency_key" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  "deleted_at" TIMESTAMP(3),
  CONSTRAINT "announcement_comments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "announcement_comments_idempotency_key_key"
  ON "announcement_comments"("idempotency_key");
CREATE INDEX "announcement_comments_organization_id_branch_id_announcement_id_created_at_idx"
  ON "announcement_comments"("organization_id", "branch_id", "announcement_id", "created_at");
CREATE INDEX "announcement_comments_reply_to_id_idx" ON "announcement_comments"("reply_to_id");

ALTER TABLE "announcement_comments"
  ADD CONSTRAINT "announcement_comments_organization_id_fkey"
    FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "announcement_comments_branch_id_fkey"
    FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "announcement_comments_announcement_id_fkey"
    FOREIGN KEY ("announcement_id") REFERENCES "announcements"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "announcement_comments_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "announcement_comments_reply_to_id_fkey"
    FOREIGN KEY ("reply_to_id") REFERENCES "announcement_comments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
