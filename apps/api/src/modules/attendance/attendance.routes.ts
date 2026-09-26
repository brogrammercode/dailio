import { Router } from 'express';

import { authenticate } from '../../middleware/auth';
import { resolveTenantContext } from '../../middleware/tenant';
import { requireAnyPermission, requirePermission } from '../../middleware/permission';

import {
  clockInHandler,
  createManualSessionHandler,
  createEvidenceUploadSignatureHandler,
  clockOutHandler,
  activeSessionHandler,
  listSessionsHandler,
  exportSessionsHandler,
  getSessionDetailHandler,
  getEvidenceDownloadUrlHandler,
  getPolicyHandler,
  listPoliciesHandler,
  updatePolicyHandler,
  correctSessionHandler,
} from './attendance.controller';

const router: Router = Router();

router.get(
  '/branches/:branch_id/attendance/policy',
  authenticate,
  resolveTenantContext,
  requireAnyPermission(
    'ATTENDANCE_READ_SELF',
    'ATTENDANCE_READ_TEAM',
    'ATTENDANCE_READ_BRANCH',
    'ATTENDANCE_READ_ALL',
    'ATTENDANCE_POLICY_READ',
    'ATTENDANCE_POLICY_ASSIGN',
  ),
  getPolicyHandler,
);
router.get(
  '/branches/:branch_id/attendance/policies',
  authenticate,
  resolveTenantContext,
  requireAnyPermission('ATTENDANCE_POLICY_READ', 'ATTENDANCE_POLICY_MANAGE', 'ATTENDANCE_READ_ALL'),
  listPoliciesHandler,
);
router.patch(
  '/branches/:branch_id/attendance/policy',
  authenticate,
  resolveTenantContext,
  requireAnyPermission(
    'BRANCH_SETTINGS_UPDATE',
    'ATTENDANCE_POLICY_MANAGE',
    'ATTENDANCE_POLICY_ASSIGN',
  ),
  updatePolicyHandler,
);

router.post(
  '/branches/:branch_id/attendance/clock-in',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_CREATE_SELF'),
  clockInHandler,
);
router.post(
  '/branches/:branch_id/attendance/evidence/upload-signature',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_CREATE_SELF'),
  createEvidenceUploadSignatureHandler,
);
router.post(
  '/branches/:branch_id/attendance/clock-out',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_CREATE_SELF'),
  clockOutHandler,
);
router.post(
  '/branches/:branch_id/attendance/manual',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_CREATE_ALL'),
  createManualSessionHandler,
);
router.get(
  '/branches/:branch_id/attendance/active-session',
  authenticate,
  resolveTenantContext,
  activeSessionHandler,
);
router.get(
  '/branches/:branch_id/attendance',
  authenticate,
  resolveTenantContext,
  requireAnyPermission(
    'ATTENDANCE_READ_SELF',
    'ATTENDANCE_READ_TEAM',
    'ATTENDANCE_READ_BRANCH',
    'ATTENDANCE_READ_ALL',
  ),
  listSessionsHandler,
);
router.get(
  '/branches/:branch_id/attendance/export',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_EXPORT'),
  exportSessionsHandler,
);
router.get(
  '/branches/:branch_id/attendance/:session_id',
  authenticate,
  resolveTenantContext,
  requireAnyPermission(
    'ATTENDANCE_READ_SELF',
    'ATTENDANCE_READ_TEAM',
    'ATTENDANCE_READ_BRANCH',
    'ATTENDANCE_READ_ALL',
  ),
  getSessionDetailHandler,
);
router.get(
  '/branches/:branch_id/attendance/:session_id/evidence/:evidence_id/download',
  authenticate,
  resolveTenantContext,
  requireAnyPermission(
    'ATTENDANCE_EVIDENCE_READ_SELF',
    'ATTENDANCE_EVIDENCE_READ_ALL',
    'ATTENDANCE_READ_SELF',
  ),
  getEvidenceDownloadUrlHandler,
);

router.patch(
  '/branches/:branch_id/attendance/:session_id/correct',
  authenticate,
  resolveTenantContext,
  requirePermission('ATTENDANCE_UPDATE'),
  correctSessionHandler,
);

export default router;
