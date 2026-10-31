import type { Logger } from 'pino';
import { AppError } from '../../errors/app-error.js';
import type { AiInferenceClient } from '../inference/inference.types.js';
import type { ScanRepository } from './scan.repository.js';
import {
  inferenceFailureCodes,
  type ScanRecord,
  scanLimits,
  scanResponse,
  type ValidatedImage,
} from './scan.types.js';

/** Isolated attempt/lease/inference/persistence boundary; transport remains synchronous. */
export function createScanProcessor(
  repository: ScanRepository,
  logger: Logger,
  inference?: AiInferenceClient,
  expectedModelVersion?: string,
) {
  async function analyze(scan: ScanRecord, image: ValidatedImage) {
    if (scan.status === 'COMPLETED') return scanResponse(scan);
    if (scan.status === 'FAILED' && scan.errorCode === 'INVALID_IMAGE') return scanResponse(scan);
    let attemptId: string | null;
    try {
      await repository.failInference(
        scan.id,
        'INFERENCE_INTERRUPTED',
        new Date(Date.now() - scanLimits.inferenceLeaseMs),
      );
      attemptId = await repository.startInference(scan.id);
      if (!attemptId) {
        const current = await repository.findScan(scan.id);
        if (!current) throw new Error('Saved scan is unavailable');
        return scanResponse(current);
      }
    } catch {
      throw new AppError('SCAN_PROCESSING_UNAVAILABLE');
    }
    let persisting = false;
    try {
      if (!inference?.enabled) throw new AppError('INFERENCE_UNAVAILABLE');
      if (expectedModelVersion && !(await repository.canServeVersion(expectedModelVersion))) {
        throw new AppError('INFERENCE_UNAVAILABLE');
      }
      const result = await inference.predict(image);
      persisting = true;
      return scanResponse(await repository.completeInference(scan.id, attemptId, result));
    } catch (error) {
      const code = persisting
        ? 'INFERENCE_PERSISTENCE_FAILED'
        : error instanceof AppError && inferenceFailureCodes.some((item) => item === error.code)
          ? error.code
          : 'INFERENCE_FAILED';
      try {
        // A lost persistence acknowledgement must not replace a committed outcome.
        const current = await repository.findScan(scan.id);
        if (current?.status === 'COMPLETED') return scanResponse(current);
        await repository.failInference(scan.id, code, undefined, attemptId);
        const failed = await repository.findScan(scan.id);
        if (!failed) throw new Error('Saved scan is unavailable');
        return scanResponse(failed);
      } catch {
        logger.error({ code: 'SCAN_RECOVERY_PENDING' }, 'Saved scan requires inference recovery');
        throw new AppError('SCAN_PROCESSING_UNAVAILABLE');
      }
    }
  }
  return { analyze };
}
