/* eslint-disable @typescript-eslint/no-explicit-any */
import { OpenApiGeneratorV3, OpenAPIRegistry } from '@asteasolutions/zod-to-openapi';

export const registry = new OpenAPIRegistry();

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function generateOpenApiDocument(): Record<string, any> {
  const generator = new OpenApiGeneratorV3(registry.definitions);
  return generator.generateDocument({
    openapi: '3.0.0',
    info: {
      title: 'Organization Management Platform API',
      version: '1.0.0',
      description: 'Multi-tenant organization management REST API',
    },
    servers: [{ url: '/api/v1' }],
  }) as any;
}

// Register common security scheme
registry.registerComponent('securitySchemes', 'BearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
});

