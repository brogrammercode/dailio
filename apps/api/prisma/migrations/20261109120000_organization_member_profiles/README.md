# Organization member profiles

Additive migration; no existing user, member, attendance or ledger data is changed.
Existing member profiles fall back to global user fields until an organization override is saved.
The composite primary key prevents duplicate overrides and the foreign keys enforce ownership.

Deploy this migration before deploying the API that reads organization profile overrides.
Run `npx prisma generate` with the local API stopped if Windows reports a locked engine DLL.
Then run `npx prisma migrate deploy` through the normal database release process and restart the API.
The mobile update requires that API deployment.

Rollback the API before any database rollback. Retain the new table and its profile edits;
do not drop it during ordinary rollback. No historical attendance session should be closed,
voided or deleted as part of fixing reminder eligibility.
