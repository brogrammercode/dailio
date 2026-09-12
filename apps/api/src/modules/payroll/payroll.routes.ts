import { Router } from 'express';

import { authenticate } from '../../middleware/auth';

import { listStructures, createStructure, updateStructure, deleteStructure } from './payroll.controller';

const router: Router = Router();

router.get('/:organization_id/salary-structures', authenticate, listStructures);
router.post('/:organization_id/salary-structures', authenticate, createStructure);
router.patch('/:organization_id/salary-structures/:id', authenticate, updateStructure);
router.delete('/:organization_id/salary-structures/:id', authenticate, deleteStructure);

export default router;
