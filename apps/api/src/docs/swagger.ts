import { type Router, Router as ExpressRouter } from 'express';
import swaggerUi from 'swagger-ui-express';

import { generateOpenApiDocument } from '../lib/openapi';

const router: Router = ExpressRouter();

router.get('/openapi.json', (_req, res) => {
  res.json(generateOpenApiDocument());
});

router.use('/', swaggerUi.serve);
router.get('/', swaggerUi.setup(undefined, { swaggerUrl: '/api/docs/openapi.json' }));

export { router as docsRouter };
