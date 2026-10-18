import { z } from 'zod';
import { privacyResponse } from '../modules/privacy/privacy.types.js';
import { modelSpecification } from '../modules/calculators/model-specification.types.js';
import { productInformation } from '../modules/fertilizer/catalogue.types.js';
import { fertilizerProductInputSchema } from '../modules/fertilizer/fertilizer.validators.js';
import { generationDataSchema } from '../modules/generation/generation.types.js';
import {
  retrievalResultSchema,
  knowledgeSourceSchema,
  knowledgeTypes,
} from '../modules/knowledge/knowledge.types.js';
import { predictionSchema, diseaseLabels } from '../modules/inference/inference.types.js';
import {
  analyticsAggregateSchema,
  activityItemSchema,
} from '../modules/analytics/analytics.types.js';
import { dashboardStoredSchema } from '../modules/admin/dashboard.types.js';
import {
  indexReceiptSchema,
  sourceSchema,
  curationSchema,
} from '../modules/admin/management.types.js';
import { referenceProvenance } from '../modules/knowledge/media.types.js';
import {
  calculatorInputSchema,
  fertilizerSourceSchema,
} from '../modules/fertilizer/fertilizer.types.js';
import { yieldInputSchema } from '../modules/yield/yield.types.js';
import { modelHealthSchema, registryModelSchema } from '../modules/admin/model-health.types.js';

const count = z.number().int().nonnegative().safe(),
  text = z.string(),
  date = z.iso.datetime({ offset: true }),
  id = z.uuid();
const jsonObject = z.record(z.string(), z.json());
const cursor = id.nullable();
const page = (item: z.ZodType) => z.object({ items: z.array(item), nextCursor: cursor });
const range = z.object({
  from: z.iso.date(),
  to: z.iso.date(),
  timeZone: z.literal('UTC'),
  days: count,
});
const user = z.strictObject({
  email: z.email(),
  role: z.enum(['FARMER', 'ADMIN']),
  createdAt: date,
});
const { topProbabilities: _, ...predictionFields } = predictionSchema.shape;
const savedPrediction = z.object({
  ...predictionFields,
  probabilities: z.record(z.enum(diseaseLabels), z.number().min(0).max(1)),
  inferredAt: date.nullable(),
});
const scan = z.object({
  id,
  status: z.enum(['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED']),
  createdAt: date,
  finishedAt: date.nullable(),
  prediction: savedPrediction.nullable(),
  analysisError: z.object({ code: text, message: text }).nullable(),
  image: z.object({
    url: text,
    mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp']),
    bytes: count,
    uploadedAt: date,
  }),
});
const disease = z.object({
  slug: text,
  name: text,
  scientificName: text.nullable(),
  description: text,
});
const managedDisease = disease.extend({
  id,
  status: z.enum(['DRAFT', 'ACTIVE', 'INACTIVE']),
  revision: text,
  literalLabel: text.nullable(),
  classifierSupported: z.boolean(),
  catalogueMetadata: jsonObject.nullable(),
  createdAt: date,
  updatedAt: date,
});
const documents = z.object({
  id,
  documentKey: text,
  version: count,
  title: text,
  status: z.enum(['DRAFT', 'ACTIVE', 'ARCHIVED']),
  diseaseSlug: text,
  knowledgeType: z.enum(knowledgeTypes),
  createdAt: date,
  updatedAt: date,
  indexed: z.boolean(),
});
const profile = z.object({
  profile: z
    .strictObject({
      displayName: text,
      region: text.nullable(),
      countryCode: text.nullable(),
      fieldAreaHectares: text.nullable(),
      avatarUrl: text.nullable(),
      updatedAt: date,
      revision: text,
    })
    .nullable(),
});
const media = z.object({
  id,
  diseaseSlug: text,
  altText: text,
  sortOrder: count,
  status: z.enum(['DRAFT', 'ACTIVE', 'INACTIVE']),
  revision: text,
  provenance: referenceProvenance.nullable(),
  imagePath: text.nullable(),
  updatedAt: date,
  uploadState: z.enum(['UPLOADING', 'READY', 'RETIRED']).optional(),
  cleanupPending: z.boolean().optional(),
});
const rounding = z.object({ mode: z.literal('HALF_UP'), decimalPlaces: count });
const assumptions = z.array(text);
const quantity = z.object({
  value: text,
  unit: z.enum(['KG', 'G', 'TONNE']),
  unroundedValue: text,
});
const fertilizerRule = z.object({
  id,
  ruleKey: text,
  version: count,
  title: text,
  crop: z.literal('MAIZE'),
  fertilizer: z.object({ slug: text, name: text }),
  rateKgPerHectare: text,
  applicability: text,
  assumptions,
  source: fertilizerSourceSchema,
  config: z.object({
    key: text,
    version: count,
    engineVersion: text,
    quantityDecimalPlaces: count,
    roundingMode: z.literal('HALF_UP'),
  }),
});
const yieldConfig = z.object({
  id,
  configKey: text,
  version: count,
  title: text,
  crop: z.literal('MAIZE'),
  expectedYieldKgPerHectare: text,
  applicability: text,
  assumptions,
  source: fertilizerSourceSchema,
  engineVersion: text,
  formulaVersion: text,
  rounding,
});
const resultBase = {
  normalizedArea: z.object({ value: text, unit: z.literal('HECTARE') }),
  rounding,
  engineVersion: text,
  explanation: text,
  assumptions,
  unitReference: z.object({ title: text, url: z.url() }),
};
const calculatorDraft = z.object({
  id,
  version: count,
  status: z.enum(['DRAFT', 'ACTIVE', 'INACTIVE']),
  validForActivation: z.boolean(),
  title: text.optional(),
  ruleKey: text.optional(),
  configKey: text.optional(),
  draftInput: jsonObject.nullable().optional(),
  createdAt: date.optional(),
  updatedAt: date.optional(),
});
const farmer = z.object({
  id,
  email: z.email(),
  status: z.enum(['ACTIVE', 'SUSPENDED', 'DEACTIVATED']),
  displayName: text.nullable(),
  createdAt: date,
  revision: text,
});
const operation = z.object({
  scope: z.enum(['NODE', 'AI_SERVICE', 'PROVIDER']),
  operation: z.enum(['INFERENCE', 'RETRIEVAL', 'GENERATION', 'EXPLANATION', 'GEMINI', 'EMBEDDING']),
  requests: count,
  successes: count,
  failures: count,
  abstained: count,
  averageMs: z.number().nonnegative(),
  p50Ms: z.number().nonnegative(),
  p95Ms: z.number().nonnegative(),
});

/** These shared schemas validate actual response data and generate the spec.
 * Existing complex historical JSON snapshots remain typed JSON objects; dedicated
 * module validators retain deeper invariants. No undocumented response guess is used.
 */
export function responseContract(method: string, path: string): z.ZodType | null {
  if (method === 'head') method = 'get';
  path = path.replace(/\/$/, '');
  if (path.endsWith('/image') || (path === '/profile/avatar' && method === 'get')) return null;
  if (path === '/health')
    return z.object({
      status: z.enum(['ok', 'degraded']),
      service: z.literal('maizedoctor-backend'),
      timestamp: date,
      uptimeSeconds: count,
      checks: z.object({ database: z.enum(['up', 'down']) }),
    });
  if (path.startsWith('/auth/')) {
    if (path.endsWith('/logout')) return z.object({ loggedOut: z.literal(true) });
    if (path.endsWith('/login') || path.endsWith('/refresh'))
      return z.object({
        accessToken: text,
        tokenType: z.literal('Bearer'),
        expiresIn: count,
        user,
      });
    return z.object({ user });
  }
  if (path === '/profile' || path === '/profile/avatar') return profile;
  if (path === '/knowledge/ask' || path.endsWith('/explanation')) return generationDataSchema;
  if (path === '/knowledge/search') return retrievalResultSchema;
  if (path === '/scans' && method === 'get') return page(scan);
  if (path === '/scans' || /^\/scans\/:scanId$/.test(path)) return scan;
  if (path === '/diseases') return z.object({ items: z.array(disease) });
  if (path.endsWith('/images') || path.endsWith('/items'))
    return z.object({ items: z.array(media) });
  if (path.startsWith('/admin/disease-images')) return media;
  if (path === '/diseases/:slug')
    return disease.extend({
      sections: z.array(
        z.object({
          documentId: id,
          documentKey: text,
          documentVersion: count,
          knowledgeType: z.enum(knowledgeTypes),
          title: text,
          content: text,
          source: knowledgeSourceSchema,
        }),
      ),
      catalogue: z
        .object({
          classifierSupported: z.boolean(),
          literalLabel: text.nullable(),
          applicability: z
            .object({
              growthStages: z.array(text),
              severityDescriptors: z.array(text),
              source: sourceSchema.nullable(),
            })
            .nullable(),
        })
        .optional(),
    });
  if (path === '/admin/ai-operations')
    return z.object({
      status: z.enum(['COLLECTED', 'UNAVAILABLE']),
      from: z.iso.date(),
      to: z.iso.date(),
      totals: z.array(operation).nullable(),
      daily: z
        .array(z.object({ date: z.iso.date(), scope: text, requests: count, failures: count }))
        .nullable(),
      collection: z.object({
        scope: text,
        delivery: text,
        localDropped: count,
        localPending: count,
        historicalCoverage: text,
        retention: text,
      }),
    });
  if (path.startsWith('/admin/knowledge/diseases'))
    return z.object({ items: z.array(managedDisease), classMappingEditable: z.literal(false) });
  if (path === '/admin/knowledge/documents' && method === 'get') return page(documents);
  if (path.endsWith('/index')) return indexReceiptSchema;
  if (path.startsWith('/admin/knowledge/documents'))
    return method === 'get'
      ? documents.extend({
          content: text,
          source: sourceSchema.nullable(),
          curation: curationSchema.nullable(),
        })
      : documents;
  if (path === '/admin/calculators/model-specifications') {
    const specification = z.object({
      id,
      title: text,
      version: count,
      status: z.literal('DRAFT'),
      validForActivation: z.literal(false),
      execution: z.literal('DISABLED'),
      domainApproval: z.literal('PENDING_DOMAIN_APPROVAL'),
      draftInput: modelSpecification,
      createdAt: date,
      updatedAt: date,
    });
    return method === 'get'
      ? z.object({ items: z.array(specification), limit: count })
      : specification;
  }
  if (path.startsWith('/admin/fertilizers')) {
    const product = z.object({
      id,
      title: text,
      version: count,
      status: z.enum(['DRAFT', 'ACTIVE', 'INACTIVE']),
      revision: text,
      rulesCount: count,
      contentEditable: z.boolean(),
      validForActivation: z.boolean(),
      draftInput: z.object({
        product: fertilizerProductInputSchema,
        information: productInformation.nullable(),
      }),
      createdAt: date,
      updatedAt: date,
    });
    return method === 'get'
      ? z.object({ items: z.array(product), limit: count, nextCursor: id.nullable() })
      : product;
  }
  if (path.startsWith('/admin/calculators/'))
    return method === 'get'
      ? z.object({ items: z.array(calculatorDraft), limit: count.optional() })
      : calculatorDraft;
  if (path === '/calculators/fertilizer/rules')
    return z.object({
      status: z.enum(['READY', 'PENDING_RULES']),
      message: text,
      engineVersion: text,
      items: z.array(fertilizerRule),
    });
  if (path === '/calculators/fertilizer/calculate')
    return z.object({
      ...resultBase,
      input: calculatorInputSchema,
      quantity,
      rule: fertilizerRule,
    });
  if (path === '/calculators/yield/configurations')
    return z.object({
      status: z.enum(['READY', 'PENDING_CONFIGURATION']),
      message: text,
      engineVersion: text,
      items: z.array(yieldConfig),
    });
  if (path === '/calculators/yield/calculate')
    return z.object({
      ...resultBase,
      input: yieldInputSchema,
      expectedYield: quantity,
      configuration: yieldConfig,
      formulaVersion: text,
    });
  if (path === '/analytics/scans')
    return analyticsAggregateSchema.safeExtend({ range, asOf: date });
  if (path === '/analytics/scans/activity') return page(activityItemSchema).extend({ range });
  if (path === '/admin/dashboard')
    return z.object({
      range,
      asOf: date,
      scans: analyticsAggregateSchema,
      farmers: dashboardStoredSchema.shape.farmers,
      ownership: dashboardStoredSchema.shape.ownership,
      recent: dashboardStoredSchema.shape.recent,
      model: z.object({
        registry: z.enum(['NOT_PROMOTED', 'SINGLE_PRODUCTION', 'MULTIPLE_PRODUCTION']),
        productionVersion: text.nullable(),
        configuredVersion: text.nullable(),
        inferenceConfigured: z.boolean(),
        readiness: z.literal('NOT_CHECKED'),
      }),
      aiRequestStatistics: z.literal('AVAILABLE_SEPARATELY'),
    });
  if (path === '/admin/farmers') return page(farmer);
  if (path === '/admin/farmers/:id/status') return z.object({ farmer });
  if (path === '/admin/audit-logs')
    return page(
      z
        .object({ id, action: text, entityType: text, entityId: text.nullable(), createdAt: date })
        .passthrough(),
    );
  if (path === '/admin/model-health')
    return z.object({
      asOf: date,
      registry: z.object({
        models: z.array(registryModelSchema),
        productionVersion: text.nullable(),
        status: z.enum(['NOT_PROMOTED', 'SINGLE_PRODUCTION', 'MULTIPLE_PRODUCTION']),
      }),
      service: z.object({
        status: z.enum(['READY', 'NOT_LOADED', 'UNAVAILABLE', 'INCOMPATIBLE']),
        configuredVersion: text.nullable(),
        registered: z.boolean(),
        matchesProduction: z.boolean(),
        data: modelHealthSchema.nullable(),
      }),
      drift: z.literal('NOT_AVAILABLE_NO_GROUND_TRUTH'),
    });
  if (path === '/profile/data-deletion') return privacyResponse;
  throw new Error(`Missing response contract: ${method} ${path}`);
}
