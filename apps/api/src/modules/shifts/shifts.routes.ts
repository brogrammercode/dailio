import { Router } from 'express';

import { authenticate } from '../../middleware/auth';

import { listShifts, createShift, updateShift, deleteShift } from './shifts.controller';

const router: Router = Router();

router.get('/:organization_id/shifts', authenticate, listShifts);
router.post('/:organization_id/shifts', authenticate, createShift);
router.patch('/:organization_id/shifts/:shift_id', authenticate, updateShift);
router.delete('/:organization_id/shifts/:shift_id', authenticate, deleteShift);

export default router;
