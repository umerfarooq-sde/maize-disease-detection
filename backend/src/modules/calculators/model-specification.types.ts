import { z } from 'zod';
import { calculatorSourceSchema, calculatorText } from './calculator.contract.js';
const variable = z.strictObject({
  key: z.string().regex(/^[a-z][a-z0-9_]{0,47}$/),
  unit: z.enum([
    'HECTARE',
    'KG',
    'GRAM',
    'TONNE',
    'KG_PER_HECTARE',
    'MG_PER_KG',
    'PERCENT',
    'COUNT',
    'DIMENSIONLESS',
  ]),
  description: calculatorText(600),
});
/** Source-intake protocol only. No formula interpreter, default coefficient or
 * farmer calculation can execute these pending scientific specifications. */
export const modelSpecification = z
  .strictObject({
    modelKey: z
      .string()
      .max(80)
      .regex(/^[a-z0-9][a-z0-9-]*$/),
    kind: z.enum(['FERTILIZER', 'YIELD']),
    expectedVersion: z.number().int().min(0).max(2147483646),
    title: calculatorText(160),
    mathematicalDefinition: calculatorText(6000).min(20),
    applicability: calculatorText(2000),
    assumptions: z.array(calculatorText(400)).min(1).max(12),
    inputs: z.array(variable).min(1).max(16),
    outputs: z.array(variable).min(1).max(16),
    coefficients: z
      .array(
        z.strictObject({
          key: variable.shape.key,
          value: z
            .string()
            .max(64)
            .regex(/^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$/),
          unit: variable.shape.unit,
          sourceSection: calculatorText(600),
        }),
      )
      .max(32),
    source: calculatorSourceSchema,
    reviewNote: calculatorText(2000).min(20),
    approved: z.literal(true),
  })
  .refine((value) =>
    [value.inputs, value.outputs, value.coefficients].every(
      (list) => new Set(list.map((item) => item.key)).size === list.length,
    ),
  )
  .refine((value) =>
    (value.kind === 'YIELD'
      ? ['minimum', 'expected', 'potential']
      : ['nitrogen', 'phosphorus', 'potassium']
    ).every((key) => value.outputs.some((output) => output.key === key)),
  );
export type ModelSpecification = z.infer<typeof modelSpecification>;
