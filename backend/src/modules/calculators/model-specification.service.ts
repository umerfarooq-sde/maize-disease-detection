import { modelSpecification, type ModelSpecification } from './model-specification.types.js';
import type { SpecificationRepository } from './model-specification.repository.js';
import type { CalculatorConfig } from '../../generated/prisma/client.js';
import { AppError } from '../../errors/app-error.js';
function project(row: CalculatorConfig) {
  const parameters = row.parameters;
  if (
    !parameters ||
    typeof parameters !== 'object' ||
    Array.isArray(parameters) ||
    parameters.purpose !== 'MODEL_SPECIFICATION_ONLY' ||
    parameters.execution !== 'DISABLED' ||
    parameters.domainApproval !== 'PENDING_DOMAIN_APPROVAL'
  )
    throw new AppError('VALIDATION_ERROR');
  const input = modelSpecification.parse(parameters.input);
  return {
    id: row.id,
    title: input.title,
    version: row.version,
    status: 'DRAFT' as const,
    validForActivation: false,
    execution: 'DISABLED' as const,
    domainApproval: 'PENDING_DOMAIN_APPROVAL' as const,
    draftInput: input,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}
export function createSpecificationService(repository: SpecificationRepository) {
  return {
    async list() {
      return { items: (await repository.list()).map(project), limit: 100 };
    },
    async create(input: ModelSpecification, actor: string, requestId: string) {
      return project(await repository.create(input, actor, requestId));
    },
  };
}
export type SpecificationService = ReturnType<typeof createSpecificationService>;
