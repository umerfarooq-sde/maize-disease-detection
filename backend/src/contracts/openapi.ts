import type { RequestHandler, Router } from 'express';
import { z } from 'zod';
import { createHash } from 'node:crypto';
import { requestContracts } from '../validators/request.js';
import { responseContract } from './responses.js';
export const mounts = new WeakMap<Router, string>();
interface Layer {
  route?: { path: string; methods: Record<string, boolean>; stack: { handle: RequestHandler }[] };
  handle: Router;
}
export interface RegisteredOperation {
  method: string;
  path: string;
  request: z.ZodType;
}
export function registeredOperations(router: Router, prefix = ''): RegisteredOperation[] {
  const result: RegisteredOperation[] = [];
  for (const layer of router.stack as unknown as Layer[]) {
    if (layer.route) {
      const route = layer.route;
      for (const [method, enabled] of Object.entries(route.methods)) {
        if (!enabled || method === '_all') continue;
        const path = (prefix + route.path).replace(/\/$/, '');
        const schema = route.stack.map((item) => requestContracts.get(item.handle)).find(Boolean);
        if (!schema)
          throw new Error(`Registered route lacks runtime request schema: ${method} ${path}`);
        result.push({ method, path, request: schema });
      }
    } else if (Array.isArray(layer.handle?.stack))
      result.push(...registeredOperations(layer.handle, prefix + (mounts.get(layer.handle) ?? '')));
  }
  return result;
}
type Schema = Record<string, unknown>;
function toSchema(schema: z.ZodType, definitions: Record<string, unknown>): Schema {
  // Zod refinements continue to run at runtime. Native JSON Schema represents
  // structural checks; transformation input is documented, never output coercion.
  const { $schema: _, ...result } = z.toJSONSchema(schema, {
    target: 'draft-2020-12',
    io: 'input',
    unrepresentable: 'any',
  });
  const prefix = createHash('sha256').update(JSON.stringify(result)).digest('hex').slice(0, 16);
  const rewrite = (value: unknown): unknown => {
    if (Array.isArray(value)) return value.map(rewrite);
    if (value && typeof value === 'object')
      return Object.fromEntries(
        Object.entries(value).map(([key, item]) => [
          key,
          key === '$ref' && typeof item === 'string' && item.startsWith('#/$defs/')
            ? `#/components/schemas/${prefix}_${item.slice(8)}`
            : rewrite(item),
        ]),
      );
    return value;
  };
  const { $defs, ...body } = result;
  if ($defs && typeof $defs === 'object')
    for (const [name, value] of Object.entries($defs))
      definitions[`${prefix}_${name}`] = rewrite(value);
  return rewrite(body) as Schema;
}
function objectProperties(schema: Schema): Record<string, Schema> {
  return schema.properties && typeof schema.properties === 'object'
    ? (schema.properties as Record<string, Schema>)
    : {};
}
export function generateOpenApi(router: Router) {
  const definitions: Record<string, unknown> = {};
  const jsonSchema = (schema: z.ZodType) => toSchema(schema, definitions);
  const paths: Record<string, Record<string, unknown>> = {};
  const operations = registeredOperations(router),
    ids = new Set<string>();
  const error = z.strictObject({
    success: z.literal(false),
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.array(z.object({ path: z.string(), code: z.string() })).optional(),
    }),
    requestId: z.uuid(),
  });
  definitions.ErrorResponse = jsonSchema(error);
  for (const { method, path, request } of operations) {
    const openPath = path.replace(/:([A-Za-z]+)/g, '{$1}'),
      schema = jsonSchema(request),
      props = objectProperties(schema);
    const operationId = `${method}_${path.replace(/[^A-Za-z0-9]+/g, '_')}`;
    if (ids.has(operationId) || paths[openPath]?.[method])
      throw new Error('Duplicate API operation');
    ids.add(operationId);
    const params: Schema[] = [];
    for (const [key, location] of [
      ['params', 'path'],
      ['query', 'query'],
    ] as const) {
      const part = props[key] ?? {},
        required = Array.isArray(part.required) ? part.required : [];
      for (const [name, value] of Object.entries(objectProperties(part)))
        params.push({
          name,
          in: location,
          required: location === 'path' || required.includes(name),
          schema: value,
        });
    }
    if (props.key)
      params.push({
        name: 'Idempotency-Key',
        in: 'header',
        required: ((schema.required ?? []) as string[]).includes('key'),
        schema: props.key,
        description:
          'Original anonymous scan capability. Keep private; scan UUID is not authorization.',
      });
    const admin = path.startsWith('/admin/'),
      profile = path.startsWith('/profile'),
      ownScan = path.startsWith('/scans'),
      farmerOnly =
        profile || path.startsWith('/analytics/') || (path === '/scans' && method === 'get');
    const roles = admin
      ? ['ADMIN']
      : farmerOnly
        ? ['FARMER']
        : path === '/auth/me'
          ? ['FARMER', 'ADMIN']
          : ownScan
            ? ['FARMER', 'GUEST_CAPABILITY']
            : [];
    const cookie = path === '/auth/refresh' || path === '/auth/logout';
    const security = cookie
      ? [{ RefreshCookie: [] }]
      : admin || farmerOnly || path === '/auth/me'
        ? [{ BearerAuth: [] }]
        : ownScan
          ? [{ BearerAuth: [] }, { GuestCapability: [] }]
          : [];
    const intent =
      path === '/profile/avatar' ||
      (method !== 'get' &&
        (path === '/profile' ||
          path === '/scans' ||
          path.startsWith('/auth/') ||
          path.startsWith('/admin/disease-images')));
    if (intent)
      params.push({
        name: 'X-Auth-Request',
        in: 'header',
        required: true,
        schema: { type: 'string', const: '1' },
        description:
          'Native/approved browser mutation intent header; cookie flows also enforce origin policy.',
      });
    const multipart =
      method === 'post' &&
      (path === '/scans' || path === '/profile/avatar' || path === '/admin/disease-images');
    let body = props.body;
    if (multipart)
      body = {
        type: 'object',
        required: [
          'image',
          ...(path === '/profile/avatar'
            ? ['expectedRevision']
            : path === '/admin/disease-images'
              ? ['metadata']
              : []),
        ],
        properties: {
          image: {
            type: 'string',
            format: 'binary',
            description:
              'Still JPEG/PNG/WebP, <=5 MiB, 16 px minimum side, <=16 MP. MIME/extension/container/decode must agree.',
          },
          ...(path === '/profile/avatar'
            ? objectProperties(props.body ?? {})
            : path === '/admin/disease-images'
              ? {
                  metadata: {
                    type: 'string',
                    description: 'JSON-encoded reference metadata validated by the runtime schema.',
                    contentMediaType: 'application/json',
                    contentSchema: props.body,
                  },
                }
              : {}),
        },
        additionalProperties: false,
      };
    const data = responseContract(method, path),
      responses: Record<string, unknown> = {};
    const status =
      method === 'post' &&
      (path === '/admin/fertilizers' ||
        path === '/auth/register' ||
        path === '/scans' ||
        path === '/admin/disease-images' ||
        path === '/admin/knowledge/documents' ||
        path === '/admin/knowledge/diseases' ||
        path.startsWith('/admin/calculators/'))
        ? '201'
        : '200';
    responses[status] = data
      ? {
          description:
            'Validated application success. Version/source/cursor fields retain their server meanings.',
          content: {
            'application/json': {
              schema: jsonSchema(z.object({ success: z.literal(true), data, requestId: z.uuid() })),
            },
          },
        }
      : {
          description:
            'Authorized metadata-free image bytes; private, no-store. No Cloudinary capability is returned.',
          content: Object.fromEntries(
            ['image/jpeg', 'image/png', 'image/webp'].map((type) => [
              type,
              { schema: { type: 'string', format: 'binary' } },
            ]),
          ),
        };
    if (path === '/scans' && method === 'post') responses['200'] = responses[status];
    if (['/auth/login', '/auth/refresh', '/auth/logout'].includes(path))
      (responses[status] as Record<string, unknown>).headers = {
        'Set-Cookie': {
          description:
            'HttpOnly, SameSite=Strict refresh cookie; login/refresh sets or rotates it and logout clears it. Production uses the Secure __Host- prefix. Cookie contents are never returned in JSON.',
          schema: { type: 'string' },
        },
      };
    for (const code of [400, 401, 403, 404, 409, 413, 415, 429, 500, 502, 503, 504])
      responses[String(code)] = {
        description: `Safe centralized error (${code}); no stack or provider secrets.`,
        content: { 'application/json': { schema: { $ref: '#/components/schemas/ErrorResponse' } } },
      };
    paths[openPath] ??= {};
    paths[openPath][method] = {
      operationId,
      tags: [admin ? 'Admin' : path.split('/')[1]],
      security,
      'x-required-roles': roles,
      description: cookie
        ? 'Rotating HttpOnly refresh cookie; replay/revocation invalidates the session. No refresh token in JSON.'
        : ownScan
          ? 'Owner/capability policy applies. ADMIN does not bypass Farmer scan privacy.'
          : 'Runtime Zod refinements remain authoritative in addition to structural documentation.',
      parameters: params,
      ...(body && Object.keys(body).length
        ? {
            requestBody: {
              required: true,
              content: {
                [multipart ? 'multipart/form-data' : 'application/json']: { schema: body },
              },
            },
          }
        : {}),
      responses,
    };
  }
  return {
    openapi: '3.1.0',
    info: { title: 'MAIZEDOCTOR Node API', version: '0.1.0' },
    servers: [{ url: '/api/v1' }],
    paths,
    components: {
      schemas: definitions,
      securitySchemes: {
        BearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
        RefreshCookie: {
          type: 'apiKey',
          in: 'cookie',
          name: 'maizedoctor_refresh',
          description:
            'Development cookie. Production uses __Host-maizedoctor_refresh; Secure, HttpOnly, path /, no Domain.',
        },
        GuestCapability: { type: 'apiKey', in: 'header', name: 'Idempotency-Key' },
      },
    },
  };
}
