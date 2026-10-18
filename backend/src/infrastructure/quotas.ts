import { createHmac, randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';
import { ipKeyGenerator } from 'express-rate-limit';
import type { Logger } from 'pino';
import { createClient } from 'redis';
import type { Environment } from '../config/environment.js';
import { AppError } from '../errors/app-error.js';

// Redis time avoids replica clock skew. All keys share a namespace hash slot.
export const admissionScript = `
local t=redis.call('TIME'); local now=t[1]*1000+math.floor(t[2]/1000)
local limit=tonumber(ARGV[1]); local window=tonumber(ARGV[2]); local cap=tonumber(ARGV[3])
for i=1,2 do
  if tonumber(redis.call('GET',KEYS[i]) or '0')>=limit then
    return {0,math.max(1,redis.call('PTTL',KEYS[i]))}
  end
end
if cap>0 then
  redis.call('ZREMRANGEBYSCORE',KEYS[3],'-inf',now)
  if redis.call('ZCARD',KEYS[3])>=cap then return {0,1000} end
end
for i=1,2 do
  if i==1 or KEYS[1]~=KEYS[2] then
    if redis.call('INCR',KEYS[i])==1 then redis.call('PEXPIRE',KEYS[i],window) end
  end
end
if cap>0 then
  redis.call('ZADD',KEYS[3],now+tonumber(ARGV[4]),ARGV[5])
  redis.call('PEXPIRE',KEYS[3],ARGV[4])
end
return {1,0}`;

export interface QuotaStore {
  start(): Promise<void>;
  ready(): boolean;
  evaluate(keys: string[], args: string[]): Promise<unknown>;
  release(key: string, identity: string): Promise<void>;
  close(): Promise<void>;
}

export function redisQuotaStore(url: string, logger: Pick<Logger, 'warn'>): QuotaStore {
  const client = createClient({
    url,
    disableOfflineQueue: true,
    commandsQueueMaxLength: 128,
    socket: { connectTimeout: 1000, reconnectStrategy: false },
  });
  client.on('error', () => logger.warn({ event: 'redis_connection_failed' }));
  let connecting: Promise<void> | undefined;
  let stopping = false;
  async function start() {
    if (stopping) throw new Error('Redis is closing');
    connecting ??= client
      .connect()
      .then(() => undefined)
      .finally(() => {
        connecting = undefined;
      });
    await connecting;
  }
  const recovery = setInterval(() => {
    if (!stopping && !client.isReady && !connecting)
      void start().catch(() => logger.warn({ event: 'redis_reconnect_failed' }));
  }, 10000);
  recovery.unref();
  async function bounded<T>(action: () => Promise<T>): Promise<T> {
    let timer: NodeJS.Timeout | undefined;
    try {
      if (!client.isReady) throw new Error('Redis is not ready');
      return await Promise.race([
        action(),
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => {
            if (client.isOpen) client.destroy(); // Reject pending commands; never grow a timed-out backlog.
            reject(new Error('Redis operation deadline exceeded'));
          }, 750);
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
  }
  return {
    start,
    ready: () => client.isReady,
    evaluate: (keys, args) =>
      bounded(() => client.eval(admissionScript, { keys, arguments: args })),
    async release(key, identity) {
      await bounded(() => client.zRem(key, identity));
    },
    async close() {
      stopping = true;
      clearInterval(recovery);
      if (client.isOpen) client.destroy();
      await connecting?.catch(() => undefined);
    },
  };
}

export function createDistributedQuota(
  environment: Environment,
  store: QuotaStore,
  logger: Pick<Logger, 'warn'>,
) {
  const pending = new Set<Promise<void>>();
  let closing = false;
  const hash = (value: string) =>
    createHmac('sha256', environment.JWT_SECRET).update(value).digest('hex');
  function category(path: string) {
    if (/auth.*(register|login)/.test(path)) return { scope: 'authentication', cap: 2 };
    if (/assistant|explanation|knowledge\/ask/.test(path)) return { scope: 'generation', cap: 2 };
    if (/scans/.test(path) && path.endsWith(':POST') && !/image|history/.test(path))
      return { scope: 'inference', cap: 4 };
    if (/search/.test(path)) return { scope: 'retrieval', cap: 4 };
    if (/index/.test(path)) return { scope: 'indexing', cap: 1 };
    if (/avatar|image/.test(path)) return { scope: 'media', cap: 4 };
    return { scope: 'ordinary', cap: 0 };
  }
  return {
    async start() {
      await store.start();
    },
    ready: () => store.ready(),
    async admit(request: Request, response: Response, limit: number, windowMs: number) {
      if (closing) throw new AppError('SERVICE_UNAVAILABLE');
      // No URL/query/account/IP values appear in Redis keys or operational labels.
      const path = request.route
        ? `${request.baseUrl}:${String(request.route.path)}:${request.method}`
        : /^\/api\/v1\/(profile\/avatar|admin\/(knowledge|disease-images))$/.test(request.baseUrl)
          ? `${request.baseUrl}:middleware:${request.method}`
          : 'global';
      const identity = hash(
        `ip:${ipKeyGenerator(request.ip ?? request.socket.remoteAddress ?? 'unknown')}`,
      );
      const account = response.locals.principal?.userId;
      const prefix = `{${environment.REDIS_NAMESPACE}}:quota:`;
      const rate = `${prefix}${hash(`${path}:${limit}:${windowMs}`)}:`;
      const policy = category(path);
      const leaseKey = `${prefix}active:${policy.scope}`;
      const lease = randomUUID();
      let result: unknown;
      try {
        result = await store.evaluate(
          [rate + identity, rate + (account ? hash(`account:${account}`) : identity), leaseKey],
          [String(limit), String(windowMs), String(policy.cap), '180000', lease],
        );
      } catch {
        logger.warn({ event: 'redis_admission_unavailable' });
        throw new AppError('SERVICE_UNAVAILABLE');
      }
      if (
        !Array.isArray(result) ||
        result.length !== 2 ||
        ![0, 1].includes(Number(result[0])) ||
        !Number.isFinite(Number(result[1])) ||
        Number(result[1]) < 0
      ) {
        throw new AppError('SERVICE_UNAVAILABLE');
      }
      if (Number(result[0]) === 0) {
        response.setHeader('Retry-After', Math.max(1, Math.ceil(Number(result[1]) / 1000)));
        throw new AppError('RATE_LIMITED');
      }
      if (policy.cap) {
        let released = false;
        const release = () => {
          if (released) return;
          released = true;
          const task = store
            .release(leaseKey, lease)
            .catch(() => logger.warn({ event: 'redis_lease_release_failed' }))
            .finally(() => pending.delete(task));
          pending.add(task);
        };
        response.once('finish', release);
        response.once('close', () => {
          // A complete upload can continue decoding/provider work after a client
          // disconnect. Keep its bounded lease until completion or TTL expiry;
          // do not let disconnects bypass shared concurrency admission.
          if (!request.complete) release();
        });
      }
    },
    async close() {
      closing = true;
      await Promise.allSettled([...pending]);
      await store.close();
    },
  };
}
export type DistributedQuota = ReturnType<typeof createDistributedQuota>;
