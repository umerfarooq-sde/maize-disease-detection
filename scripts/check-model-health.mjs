import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {createServer} from 'node:http';
import {spawn} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
import {pino} from '../backend/node_modules/pino/pino.js';
import {createApp} from '../backend/src/app.ts';
import {loadEnvironment} from '../backend/src/config/environment.ts';
import {getDatabaseClient} from '../backend/src/database/client.ts';
import {createAuthService} from '../backend/src/modules/auth/auth.service.ts';
import {memoryRepository} from '../backend/tests/auth/helpers.ts';
import {modelHealthSchema} from '../backend/src/modules/admin/model-health.types.ts';

const environment={...loadEnvironment(),NODE_ENV:'test',LOG_LEVEL:'silent',
  JWT_SECRET:randomBytes(48).toString('base64url'),JWT_REFRESH_SECRET:randomBytes(48).toString('base64url')};
assert.equal(new URL(environment.DATABASE_URL).searchParams.get('options'),'-c default_transaction_read_only=on');
const database=getDatabaseClient(environment.DATABASE_URL);
const memory=memoryRepository();
const auth=createAuthService(environment,memory.repository);
const credentials={email:`health-${randomUUID()}@example.invalid`,password:randomBytes(32).toString('base64url')};
const app=createApp(environment,pino({level:'silent'}),{async checkDatabase(){}},memory.repository);
const server=createServer(app);
let stage='registry read-only';
try {
  assert.equal((await database.$queryRaw`SHOW transaction_read_only`)[0].transaction_read_only,'on');
  const before=await database.modelVersion.count();
  await auth.createAdmin(credentials);
  const grant=await auth.login(credentials);
  await server.listen(0,'127.0.0.1');
  await new Promise(resolve=>server.listening?resolve():server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api/v1`;
  const headers={Authorization:`Bearer ${grant.accessToken}`};
  const read=async()=>{
    const response=await fetch(`${base}/admin/model-health`,{headers});
    assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');
    return (await response.json()).data;
  };
  stage='pinned model, saved evidence and runtime accounting';
  const internal=await fetch(`${environment.AI_SERVICE_URL}/api/v1/model-dashboard`,{headers:{Authorization:`Bearer ${environment.AI_SERVICE_TOKEN}`}});
  assert.equal(internal.status,200);
  const contract=modelHealthSchema.safeParse((await internal.json()).data);
  if(!contract.success) console.error('Internal schema issues: '+JSON.stringify(contract.error.issues.map(issue=>({path:issue.path,code:issue.code}))));
  assert.ok(contract.success);
  const first=await read();
  console.log(`Phase 22 probe status: ${first.service.status}`);
  assert.equal(first.service.status,'READY');
  assert.equal(first.service.data.modelVersion,environment.AI_MODEL_VERSION);
  assert.equal(first.service.data.runtime.requests,0);
  assert.equal(first.service.data.development.evaluation.sample_count,624);
  assert.equal(first.service.data.development.evaluation.accuracy,0.9583333333333334);
  stage='synthetic valid/unsupported image outcomes';
  for(const [image,type,expected] of [[Buffer.from(process.env.MODEL_HEALTH_IMAGE,'base64'),'image/png',200],[Buffer.from('bad'),'image/png',422]]) {
    const response=await fetch(`${environment.AI_SERVICE_URL}/api/v1/predict`,{
      method:'POST',headers:{Authorization:`Bearer ${environment.AI_SERVICE_TOKEN}`,'Content-Type':type},body:image});
    assert.ok(expected===200 ? response.status===200 : [415,422].includes(response.status));
  }
  const second=await read();
  assert.deepEqual(second.service.data.development,first.service.data.development);
  assert.equal(second.service.data.runtime.requests,2);
  assert.equal(second.service.data.runtime.successes,1);assert.equal(second.service.data.runtime.failures,1);
  assert.equal(second.registry.status,first.registry.status);
  stage='Flutter authenticated repository/ViewModel contract';
  await new Promise((resolve,reject)=>{
    const child=spawn(process.env.MODEL_HEALTH_DART,[
      process.env.MODEL_HEALTH_FLUTTER_TOOLS,'test','test/integration/model_health_test.dart',
      '--dart-define=RUN_LIVE_MODEL_HEALTH_CHECK=true',`--dart-define=API_BASE_URL=${base}`,
      '--reporter=expanded'],{cwd:new URL('../mobile/',import.meta.url),env:{...process.env,
        MODEL_HEALTH_ADMIN_EMAIL:credentials.email,MODEL_HEALTH_ADMIN_PASSWORD:credentials.password},stdio:'inherit'});
    child.once('error',reject);child.once('exit',code=>code===0?resolve():reject(new Error('Flutter contract failed')));
  });
  assert.equal(await database.modelVersion.count(),before);
  await mkdir(new URL('../.cache/phase22/',import.meta.url),{recursive:true});
  await writeFile(new URL('../.cache/phase22/integration-proof.json',import.meta.url),JSON.stringify({passed:true,
    realPinnedModel:true,registryReadOnly:true,flutterContract:true,modelVersion:environment.AI_MODEL_VERSION,
    testSampleCount:624,registryStatus:second.registry.status,runtime:second.service.data.runtime,productionMutations:false}));
  console.log('PASS: read-only registry, pinned model, runtime counters and Flutter contract. No model promotion or final-test rerun.');
} catch {
  console.error(`Phase 22 live check failed during ${stage}; private details omitted.`);process.exitCode=1;
} finally {
  await new Promise(resolve=>server.close(resolve));await database.$disconnect();
}
