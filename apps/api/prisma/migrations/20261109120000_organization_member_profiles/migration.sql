CREATE TABLE "organization_member_profiles" (
  "organization_id" TEXT NOT NULL REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  "user_id" TEXT NOT NULL REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  "name" TEXT,
  "phone" TEXT,
  "avatar_url" TEXT,
  "updated_at" TIMESTAMP(3) NOT NULL,
  PRIMARY KEY ("organization_id", "user_id")
);
