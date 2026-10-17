import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { createApp } from '../backend/dist/app.js';
import { loadEnvironment } from '../backend/dist/config/environment.js';
import { createLogger } from '../backend/dist/config/logger.js';
import { createDatabaseClient, getDatabaseClient } from '../backend/dist/database/client.js';
import { createHealthRepository } from '../backend/dist/modules/health/health.repository.js';
import { createAuthRepository } from '../backend/dist/modules/auth/auth.repository.js';
import { createAuthService } from '../backend/dist/modules/auth/auth.service.js';

const schema=process.env.PHASE21_SCHEMA;
assert.match(schema??'',/^phase21_[a-f0-9]{32}$/);
const environment={...loadEnvironment(),NODE_ENV:'test',KNOWLEDGE_RATE_LIMIT_MAX:1000,GENERATION_RATE_LIMIT_MAX:60,CALCULATOR_RATE_LIMIT_MAX:1000};
assert.equal(new URL(environment.DATABASE_URL).searchParams.get('schema'),schema);
const database=createDatabaseClient(environment.DATABASE_URL,30000);
const sourceCorpus=JSON.parse(readFileSync(new URL('../backend/knowledge/maize-extension-20261012-v1.json',import.meta.url),'utf8'));
const sourceDocument=sourceCorpus.documents.find(item=>item.diseaseLabel==='Common_Rust' && item.knowledgeType==='OVERVIEW');
const credentials={};let server;let app;let stage='accounts';
function mark(value){stage=value;console.log('Phase 21 live: '+stage);}
try {
  const auth=createAuthService(environment,createAuthRepository(database));
  for(const role of ['ADMIN','FARMER']){
    const account={email:`phase21-${randomUUID()}@example.invalid`,password:`synthetic-${randomUUID()}`};
    if(role==='ADMIN')await auth.createAdmin(account);else await auth.register(account);credentials[role]=account;
  }
  app=createApp(environment,createLogger({LOG_LEVEL:'error'}),createHealthRepository(database));
  server=createServer(app);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api/v1`;
  async function request(path,{method='GET',body,token,status=200}={}){
    const response=await fetch(base+path,{method,redirect:'error',signal:AbortSignal.timeout(150000),headers:{'X-Auth-Request':'1',...(body===undefined?{}:{'Content-Type':'application/json'}),...(token?{Authorization:`Bearer ${token}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
    const result=await response.json();assert.equal(response.status,status,`${method} ${path}: ${result.error?.code??'status'}`);return status<400?result.data:result.error;
  }
  const admin=(await request('/auth/login',{method:'POST',body:credentials.ADMIN})).accessToken;
  const farmer=(await request('/auth/login',{method:'POST',body:credentials.FARMER})).accessToken;
  const prefix='/admin/knowledge';
  mark('RBAC for every knowledge management endpoint');
  for(const [method,path] of [['GET','/diseases'],['PATCH','/diseases/common-rust'],['GET','/documents'],['POST','/documents'],['GET',`/documents/${randomUUID()}`],['POST',`/documents/${randomUUID()}/index`],['PATCH',`/documents/${randomUUID()}/status`]]){
    await request(prefix+path,{method,token:farmer,status:403});await request(prefix+path,{method,status:401});
  }
  const draft={documentKey:'phase21-reviewed-overview',expectedVersion:0,diseaseSlug:'common-rust',knowledgeType:'OVERVIEW',title:sourceDocument.title,content:sourceDocument.content,source:sourceDocument.source,region:sourceDocument.metadata.region,sourceSection:sourceDocument.metadata.sourceSection,
    reviewNote:'Isolated integration fixture copied from the reviewed project corpus; no new agricultural recommendation.',approved:true};
  mark('draft and unindexed activation denial');
  const first=await request(prefix+'/documents',{method:'POST',token:admin,body:draft,status:201});
  assert.equal(first.status,'DRAFT');assert.equal(first.version,1);assert.equal((await request('/diseases/common-rust')).sections.length,0);
  await request(prefix+`/documents/${first.id}/status`,{method:'PATCH',token:admin,body:{status:'ACTIVE',expectedStatus:'DRAFT'},status:409});
  mark('real Google indexing and publication');
  await request(prefix+`/documents/${first.id}/index`,{method:'POST',token:admin,body:{}});
  const count=await database.knowledgeChunk.count({where:{documentId:first.id}});assert.ok(count>0);
  await request(prefix+`/documents/${first.id}/index`,{method:'POST',token:admin,body:{}});
  assert.equal(await database.knowledgeChunk.count({where:{documentId:first.id}}),count);
  await request(prefix+`/documents/${first.id}/status`,{method:'PATCH',token:admin,body:{status:'ACTIVE',expectedStatus:'DRAFT'}});
  assert.equal((await request('/diseases/common-rust')).sections[0].documentVersion,1);
  const search={query:'Common rust maize overview',diseaseLabel:'Common_Rust',knowledgeType:'OVERVIEW',topK:3};
  assert.equal((await request('/knowledge/search',{method:'POST',body:search})).chunks[0].documentVersion,1);
  mark('immutable new version and retired embeddings');
  const old=await database.knowledgeDocument.findUniqueOrThrow({where:{id:first.id}});
  const second=await request(prefix+'/documents',{method:'POST',token:admin,body:{...draft,expectedVersion:1,title:sourceDocument.title+' (reviewed revision)'},status:201});
  assert.equal((await request('/diseases/common-rust')).sections[0].documentVersion,1);
  await request(prefix+`/documents/${second.id}/index`,{method:'POST',token:admin,body:{}});
  await request(prefix+`/documents/${second.id}/status`,{method:'PATCH',token:admin,body:{status:'ACTIVE',expectedStatus:'DRAFT'}});
  const results=await request('/knowledge/search',{method:'POST',body:search});assert.ok(results.chunks.every(item=>item.documentVersion===2));
  const archived=await database.knowledgeDocument.findUniqueOrThrow({where:{id:first.id}});assert.equal(archived.status,'ARCHIVED');assert.equal(archived.content,old.content);assert.deepEqual(archived.metadata,old.metadata);
  assert.equal(await database.knowledgeChunk.count({where:{documentId:first.id,embeddingStatus:'READY'}}),count);
  await request(prefix+'/documents',{method:'POST',token:admin,body:draft,status:409});
  await request(prefix+'/documents',{method:'POST',token:admin,body:{...draft,classLabels:['renamed']},status:400});
  mark('Gemini admits reviewed Admin version through exact chunk/source checks');
  let generated;
  for(let attempt=0;attempt<3;attempt++){
    try{generated=await request('/knowledge/ask',{method:'POST',body:{question:'Describe common rust overview',diseaseLabel:'Common_Rust',knowledgeType:'OVERVIEW'}});break;}
    catch(error){if(attempt===2)throw error;}
  }
  assert.equal(generated.status,'GROUNDED');assert.ok(generated.sources.every(item=>item.documentVersion===2));
  mark('disease display metadata and visibility, optimistic conflict');
  const disease=(await request(prefix+'/diseases',{token:admin})).items.find(item=>item.slug==='common-rust');
  const edit={name:disease.name+' reviewed',description:disease.description,scientificName:disease.scientificName,status:'INACTIVE',expectedRevision:disease.revision};
  await request(prefix+'/diseases/common-rust',{method:'PATCH',token:admin,body:edit});
  await request('/diseases/common-rust',{status:404});assert.equal((await request('/knowledge/search',{method:'POST',body:search})).chunks.length,0);
  await request(prefix+'/diseases/common-rust',{method:'PATCH',token:admin,body:edit,status:409});
  const hidden=(await request(prefix+'/diseases',{token:admin})).items.find(item=>item.slug==='common-rust');
  await request(prefix+'/diseases/common-rust',{method:'PATCH',token:admin,body:{...edit,status:'ACTIVE',expectedRevision:hidden.revision}});
  assert.equal(hidden.literalLabel,'Common_Rust');
  mark('archive excludes retired vectors and preserves audited source/version lineage');
  await request(prefix+`/documents/${second.id}/status`,{method:'PATCH',token:admin,body:{status:'ARCHIVED',expectedStatus:'ACTIVE'}});
  assert.equal((await request('/knowledge/search',{method:'POST',body:search})).chunks.length,0);
  const audit=await database.auditLog.findMany({where:{entityType:{in:['knowledge_document','disease_source','disease']}},select:{action:true,entityType:true,entityId:true,requestId:true}});
  for(const action of ['CREATE','UPDATE','ACTIVATE','DEACTIVATE'])assert.ok(audit.some(item=>item.action===action));
  assert.ok(audit.every(item=>item.requestId));
  mark('existing calculator version/source/audit management with synthetic arithmetic fixtures');
  const calculatorSource={title:'SYNTHETIC test fixture',publisher:'Isolated protocol test',url:'https://example.invalid/synthetic',citation:'Synthetic arithmetic values only; no agronomic recommendation or approval.'};
  const yieldBody={version:1,title:'SYNTHETIC yield scenario',expectedYieldKgPerHectare:'10',applicability:'No real field applicability; test only.',assumptions:['Synthetic arithmetic fixture only.'],source:calculatorSource,quantityDecimalPlaces:3,reviewNote:'Synthetic isolated contract attestation; not a real agronomic approval.'};
  const fertilizerBody={product:{slug:'synthetic-phase21-product',name:'SYNTHETIC product',description:'Synthetic contract fixture only.',nitrogenPercent:'0',phosphorusPercent:'0',potassiumPercent:'0',applicationMethod:null,precautions:[],sourceReference:calculatorSource.url},rule:{ruleKey:'synthetic-phase21-rule',version:1,title:'SYNTHETIC product rule',rateKgPerHectare:'10',applicability:yieldBody.applicability,assumptions:yieldBody.assumptions,source:calculatorSource,reviewNote:yieldBody.reviewNote},config:{version:1,quantityDecimalPlaces:3}};
  for(const [path,body,kind] of [['/admin/calculators/yield/configurations',yieldBody,'yield'],['/admin/calculators/fertilizer/rules',fertilizerBody,'fertilizer']]){
    for(const [method,route,payload] of [['GET',path,undefined],['POST',path,body],['PATCH',path+'/'+randomUUID()+'/status',{status:'ACTIVE'}]])await request(route,{method,body:payload,token:farmer,status:403});
    const initial=await request(path,{method:'POST',body,token:admin,status:201});
    await request(path+'/'+initial.id+'/status',{method:'PATCH',token:admin,body:{status:'ACTIVE'}});
    const replacementBody=kind==='yield'?{...body,version:2,expectedYieldKgPerHectare:'20'}:{...body,rule:{...body.rule,version:2,rateKgPerHectare:'20'}};
    const replacement=await request(path,{method:'POST',body:replacementBody,token:admin,status:201});
    await request(path+'/'+replacement.id+'/status',{method:'PATCH',token:admin,body:{status:'ACTIVE'}});
    const versions=(await request(path,{token:admin})).items;
    assert.equal(versions.find(item=>item.id===initial.id).status,'INACTIVE');
    assert.ok(versions.find(item=>item.id===replacement.id).draftInput);
    const event=await database.auditLog.findFirst({where:{entityId:replacement.id,action:'ACTIVATE'},orderBy:{createdAt:'desc'}});
    const retired=kind==='yield'?event.changes.retiredVersions:event.changes.retiredRules;
    assert.ok(retired.some(item=>item.id===initial.id));
  }
  mark('real Flutter Admin management repository contract');
  const allowed=new Set(['PATH','PATHEXT','SYSTEMROOT','WINDIR','COMSPEC','USERPROFILE','APPDATA','LOCALAPPDATA','TEMP','TMP','HOME','PUB_CACHE','FLUTTER_ROOT','ANDROID_HOME','ANDROID_SDK_ROOT','JAVA_HOME','CI','TERM','NO_COLOR','FLUTTER_SUPPRESS_ANALYTICS','DART_SUPPRESS_ANALYTICS']);
  const childEnvironment=Object.fromEntries(Object.entries(process.env).filter(([key])=>allowed.has(key.toUpperCase())));
  childEnvironment.MANAGEMENT_ADMIN_EMAIL=credentials.ADMIN.email;childEnvironment.MANAGEMENT_ADMIN_PASSWORD=credentials.ADMIN.password;
  childEnvironment.MANAGEMENT_DRAFT=JSON.stringify({...draft,documentKey:'phase21-flutter-overview'});
  const args=['test','--no-pub','--reporter','expanded','test/integration/admin_management_test.dart','--dart-define=RUN_LIVE_MANAGEMENT_CHECK=true',`--dart-define=API_BASE_URL=${base}`];
  const child=spawn(process.platform==='win32'?'cmd.exe':'flutter',process.platform==='win32'?['/d','/s','/c',`flutter.bat ${args.join(' ')}`]:args,{cwd:fileURLToPath(new URL('../mobile',import.meta.url)),windowsHide:true,env:childEnvironment,stdio:['ignore','pipe','pipe']});
  child.stdout.on('data',data=>process.stdout.write(data));child.stderr.on('data',data=>process.stderr.write(data));
  const timer=setTimeout(()=>child.kill(),300000);try{const [code]=await once(child,'exit');assert.equal(code,0,'Flutter management contract');}finally{clearTimeout(timer);}
  mkdirSync(new URL('../.cache/phase21/',import.meta.url),{recursive:true});
  writeFileSync(new URL('../.cache/phase21/integration-proof.json',import.meta.url),JSON.stringify({passed:true,isolatedSchema:true,realGoogleEmbedding:true,realGemini:true,flutterContract:true,knowledgeVersions:2,knowledgeAuditRecords:audit.length,productionMutations:false})+'\n');
  console.log('PASS: ADMIN RBAC, reviewed versions, Google re-indexing, activation/archive, dynamic Gemini grounding, metadata CAS, audit lineage and Flutter management contract.');
} catch(error){console.error(`Phase 21 contract failed at ${stage}; private configuration is not logged.`);if(error instanceof assert.AssertionError)console.error(error.message);process.exitCode=1;}
finally{
  if(server)await new Promise(resolve=>{server.closeAllConnections();server.close(resolve);});
  try{await app?.locals.flushOperationalEvents();}
  finally{
    await getDatabaseClient(environment.DATABASE_URL).$disconnect();
    await database.$disconnect();
  }
}
