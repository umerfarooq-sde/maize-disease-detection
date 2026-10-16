// Phase 24.6 controlled live verification. Only the parent-owned disposable schema
// and generated Cloudinary fixtures may be mutated by this script.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {spawn} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {createApp} from '../backend/src/app.ts';
import {loadEnvironment} from '../backend/src/config/environment.ts';
import {getDatabaseClient} from '../backend/src/database/client.ts';
import {createAuthRepository} from '../backend/src/modules/auth/auth.repository.ts';
import {createAuthService} from '../backend/src/modules/auth/auth.service.ts';
import {createReferenceRepository} from '../backend/src/modules/knowledge/media.repository.ts';
import {createReferenceService} from '../backend/src/modules/knowledge/media.service.ts';
import {createImageStorage} from '../backend/src/modules/scans/scan.storage.ts';
import {createOperationsRepository} from '../backend/src/modules/admin/operations.repository.ts';
import {createProfileMediaRepository} from '../backend/src/modules/profile/profile-media.repository.ts';
import {createProfileMediaService} from '../backend/src/modules/profile/profile-media.service.ts';
import {silentLogger} from '../backend/tests/foundation/helpers.ts';
import {flutterTestEnvironment} from './flutter-test-environment.mjs';

const schema=process.env.PHASE23_SCHEMA;
assert.match(schema??'',/^phase23_[a-f0-9]{32}$/);
assert.equal(process.env.PHASE23_DB_CONTEXT_LOADED,'1');
const environment={...loadEnvironment(),NODE_ENV:'test',RATE_LIMIT_MAX:3000,AUTH_RATE_LIMIT_MAX:100};
assert.equal(new URL(environment.DATABASE_URL).searchParams.get('schema'),schema);
const database=getDatabaseClient(environment.DATABASE_URL);
assert.equal((await database.$queryRaw`SELECT current_schema() AS schema`)[0].schema,schema);
const authRepository=createAuthRepository(database),auth=createAuthService(environment,authRepository);
const storage=createImageStorage(environment,'references'),assets=new Set();
const referenceWarnings=[];
let stage='controlled principals';
const profileStorage=createImageStorage(environment,'profiles');
let profileDeletes=0;
const photos=createProfileMediaService(createProfileMediaRepository(database),{
  ...profileStorage,
  async upload(image,id){assets.add(id);return profileStorage.upload(image,id);},
  async destroy(id){profileDeletes++;await new Promise(resolve=>setTimeout(resolve,16500));return profileStorage.destroy(id);},
});
const telemetryWarnings=[];
const phaseLogger=silentLogger.child({});
phaseLogger.warn=event=>{
 if(event?.event==='ai_telemetry_dropped')telemetryWarnings.push({reason:event.reason,storageCode:event.storageCode??null});
 if(event?.event==='reference_database_failed')referenceWarnings.push({stage,code:event.code});
};
const references=createReferenceService(createReferenceRepository(database,phaseLogger),{...storage,async upload(image,id){assets.add(id);return storage.upload(image,id);}},true);
// Synthetic publication is injected only here after the disposable-schema proof.
// The production composition always rejects synthetic reference publication.
const app=createApp(environment,phaseLogger,{async checkDatabase(){await database.$queryRaw`SELECT 1`;}},authRepository,
  undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined,photos,references);
const server=createServer(app);
const proof={passed:false,cloudCleanupComplete:false,normalConfidenceConfiguration:true,steps:[]};
try {
  const credentials=kind=>({email:`phase246-${kind}-${randomUUID()}@example.invalid`,password:`synthetic-${randomUUID()}`});
  const admin=credentials('admin'),farmer=credentials('farmer');
  await auth.createAdmin(admin);await auth.register(farmer);
  const adminToken=(await auth.login(admin)).accessToken,farmerToken=(await auth.login(farmer)).accessToken;
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api/v1`;
  async function request(path,token,method='GET',body,expected=200) {
    const response=await fetch(base+path,{method,headers:{...(token?{Authorization:`Bearer ${token}`} : {}),'X-Auth-Request':'1',...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});
    assert.equal(response.status,expected,`${method} ${path}`);
    const result=await response.json();return result.data;
  }
  stage='operational persistence preflight and idempotency';
  const event={id:randomUUID(),scope:'NODE',operation:'RETRIEVAL',outcome:'SUCCESS',durationMs:12,category:null,occurredAt:new Date('2026-10-01T12:00:00Z')};
  const operationalRepository=createOperationsRepository(database);
  await operationalRepository.record(event);await operationalRepository.record(event);
  assert.equal(await database.aiOperation.count({where:{id:event.id}}),1);
  stage='actual grounded generation';
  const before=await database.aiOperation.count({where:{scope:'NODE',operation:'GENERATION'}});
  const answer=await request('/knowledge/ask',undefined,'POST',{question:'What symptoms identify common rust in maize?'});
  assert.equal(answer.status,'GROUNDED');
  stage='Node event persistence';
  const recordDeadline=Date.now()+45000;
  while(await database.aiOperation.count({where:{scope:'NODE',operation:'GENERATION'}})===before && Date.now()<recordDeadline)await new Promise(resolve=>setTimeout(resolve,100));
  assert.equal(await database.aiOperation.count({where:{scope:'NODE',operation:'GENERATION'}}),before+1);
  stage='provider event persistence';
  const until=Date.now()+15000;
  while(await database.aiOperation.count({where:{scope:'PROVIDER',operation:'GEMINI',outcome:'SUCCESS'}})===0 && Date.now()<until)await new Promise(resolve=>setTimeout(resolve,100));
  assert.ok(await database.aiOperation.count({where:{scope:'PROVIDER',operation:'GEMINI',outcome:'SUCCESS'}})>0);
  stage='Admin operational authorization and aggregation';
  await request('/admin/ai-operations',farmerToken,'GET',undefined,403);
  await request('/admin/ai-operations',undefined,'GET',undefined,401);
  const metrics=await request('/admin/ai-operations',adminToken);
  assert.equal(metrics.status,'COLLECTED');assert.ok(metrics.totals.some(row=>row.scope==='NODE'&&row.operation==='GENERATION'));
  const fields=Object.keys(await database.aiOperation.findFirstOrThrow()).sort();
  assert.deepEqual(fields,['id','scope','operation','outcome','durationMs','category','occurredAt'].sort());
  stage='source-backed optional catalogue metadata and unchanged classifier';
  const source={url:'https://example.invalid/phase246-fixture',title:'Synthetic test source',publisher:'Test fixture generator',authors:[],publishedAt:null,retrievedAt:'2026-10-16',rights:'Synthetic isolated test metadata only; no agricultural claims.'};
  const slug=`synthetic-information-${randomUUID()}`;
  await request('/admin/knowledge/diseases',farmerToken,'POST',{},403);
  await request('/admin/knowledge/diseases',adminToken,'POST',{slug,name:'Synthetic informational test entry',scientificName:null,description:'Synthetic isolated test entry, never a trained class.',status:'ACTIVE',source,reviewNote:'Isolated source intake and informational catalogue review.',approved:true},201);
  let entry=(await request('/admin/knowledge/diseases',adminToken)).items.find(row=>row.slug===slug);
  assert.equal(entry.literalLabel,null);assert.equal(entry.classifierSupported,false);
  await request(`/admin/knowledge/diseases/${slug}`,adminToken,'PATCH',{name:entry.name,scientificName:null,description:entry.description,status:'ACTIVE',expectedRevision:entry.revision,
    catalogueMetadata:{growthStages:['Synthetic stage fixture, not an agronomic claim'],severityDescriptors:['Synthetic severity fixture, not field guidance'],source,reviewNote:'Review synthetic applicability for isolated contract testing only.',approved:true}});
  const detail=await request(`/diseases/${slug}`);
  assert.equal(detail.catalogue.classifierSupported,false);assert.equal(detail.catalogue.applicability.growthStages.length,1);
  assert.deepEqual((await database.modelVersion.findFirstOrThrow()).classLabels,['Common_Rust','Gray_Leaf_Spot','Healthy','Northern_Corn_Leaf_Blight']);
  stage='generated reference image, rights review and protected bytes';
  const sharp=createRequire(new URL('../backend/package.json',import.meta.url))('sharp');
  const bytes=await sharp({create:{width:32,height:48,channels:3,background:'#447766'}}).png().toBuffer();
  const metadata={diseaseSlug:slug,altText:'Synthetic test rectangle, not a disease reference photograph',sortOrder:1,
    provenance:{source,license:'Generated fixture; testing only',contributor:'Phase 24.6 test generator',attribution:'SYNTHETIC TEST FIXTURE — NOT DISEASE EVIDENCE',rightsConfirmed:true,contentKind:'SYNTHETIC_TEST'}};
  async function upload(extra={}) {
    const form=new FormData();form.set('metadata',JSON.stringify({...metadata,...extra}));form.set('image',new Blob([bytes],{type:'image/png'}),'synthetic.png');
    const response=await fetch(base+'/admin/disease-images',{method:'POST',headers:{Authorization:`Bearer ${adminToken}`,'X-Auth-Request':'1'},body:form});
    assert.equal(response.status,201);return (await response.json()).data;
  }
  let media=await upload();
  assert.deepEqual((await request(`/diseases/${slug}/images`)).items,[]);
  assert.equal((await fetch(base+`/disease-images/${media.id}/image`)).status,404);
  media=await request(`/admin/disease-images/${media.id}/status`,adminToken,'PATCH',{status:'ACTIVE',expectedRevision:media.revision,reviewNote:'Explicit isolated synthetic fixture review, never approval of real reference content.'});
  const publicMedia=(await request(`/diseases/${slug}/images`)).items[0];assert.ok(publicMedia);
  assert.equal(publicMedia.provenance.contentKind,'SYNTHETIC_TEST');assert.equal(JSON.stringify(publicMedia).includes('res.cloudinary.com'),false);
  const image=await fetch(base+'/'+publicMedia.imagePath);assert.equal(image.status,200);assert.equal(image.headers.get('cache-control'),'private, no-store');
  assert.equal((await sharp(Buffer.from(await image.arrayBuffer())).metadata()).exif,undefined);
  stage='real profile association and controlled delayed cleanup boundary';
  const oldProfile=(await request('/profile',farmerToken)).profile;
  const preparedProfile=await request('/profile',farmerToken,'PATCH',{expectedRevision:oldProfile?.revision??null,displayName:'Synthetic cleanup fixture'});
  const avatarForm=new FormData();avatarForm.set('expectedRevision',preparedProfile.profile.revision);avatarForm.set('image',new Blob([bytes],{type:'image/png'}),'synthetic-avatar.png');
  const avatarResponse=await fetch(base+'/profile/avatar',{method:'POST',headers:{Authorization:`Bearer ${farmerToken}`,'X-Auth-Request':'1'},body:avatarForm});
  assert.equal(avatarResponse.status,200);assert.ok((await avatarResponse.json()).data.profile.avatarUrl);
  stage='actual Flutter monitoring, metadata and gallery';
  await new Promise((resolve,reject)=>{
    const child=spawn(process.env.PHASE23_DART,[process.env.PHASE23_FLUTTER_TOOLS,'test','--no-pub','--reporter=expanded','test/integration/predeployment_remediation_test.dart',
      '--dart-define=RUN_LIVE_PREDEPLOYMENT=true',`--dart-define=API_BASE_URL=${base}`],
      {cwd:new URL('../mobile/',import.meta.url),windowsHide:true,env:{...flutterTestEnvironment(),PHASE246_ADMIN:JSON.stringify(admin),PHASE246_SLUG:slug,PHASE246_FARMER_TOKEN:farmerToken},stdio:'inherit'});
    child.once('error',reject);child.once('exit',code=>code===0?resolve():reject(new Error('Flutter remediation integration failed')));
  });
  assert.equal(profileDeletes,0,'Committed Flutter removal must not await or detach provider cleanup.');
  const cleanupStarted=Date.now();
  const profileCleanup=await photos.cleanup();
  assert.equal(profileCleanup.failed,0);assert.equal(profileCleanup.removed,1);assert.ok(Date.now()-cleanupStarted>=16500);
  proof.avatarCleanup={flutterCommittedRemoval:true,providerDelayMs:16500,cleanupRemoved:1};
  stage='reference replacement upload';
  const replacement=await upload({replacementFor:media.id});
  stage='reference replacement publication';
  const activeReplacement=await request(`/admin/disease-images/${replacement.id}/status`,adminToken,'PATCH',{status:'ACTIVE',expectedRevision:replacement.revision,reviewNote:'Review isolated generated replacement and preserve prior publication audit.'});
  stage='reference replacement visibility and revision conflict';
  assert.equal((await request(`/diseases/${slug}/images`)).items.length,1);
  await request(`/admin/disease-images/${replacement.id}`,adminToken,'PATCH',{altText:metadata.altText,sortOrder:8,provenance:metadata.provenance,expectedRevision:replacement.revision},409);
  stage='reference replacement retirement';
  await request(`/admin/disease-images/${replacement.id}/status`,adminToken,'PATCH',{status:'DELETED',expectedRevision:activeReplacement.revision,reviewNote:'Retire generated test image, retain metadata/audit and queue cleanup.'});
  assert.deepEqual((await request(`/diseases/${slug}/images`)).items,[]);
  // A provider failure or lost clear acknowledgement is not a lost mutation.
  // Exercise the same bounded durable retry used by the cleanup CLI and verify
  // the final journal, rather than assuming the first external call succeeds.
  stage='reference durable cleanup and recovery';
  const firstCleanup=await references.cleanup();
  proof.referenceCleanupAttempts=[firstCleanup];
  if(firstCleanup.failed){
    const pending=await database.diseaseImage.findMany({where:{disease:{slug},cleanupPending:true}});
    assert.ok(pending.length<=firstCleanup.failed);
    assert.ok(pending.every(row=>row.uploadState==='RETIRED'&&row.status==='INACTIVE'));
    console.log('OBSERVED: initial reference cleanup failure; retired intent preserved or acknowledged clear reconciled. Retrying once through the durable service.');
    const recovered=await references.cleanup();
    proof.referenceCleanupAttempts.push(recovered);
    assert.equal(recovered.failed,0,'Durable cleanup must recover within the bounded retry; persistent failures remain test failures.');
  }
  const retired=await database.diseaseImage.findMany({where:{disease:{slug}}});
  assert.equal(retired.length,2);
  assert.ok(retired.every(row=>row.uploadState==='RETIRED'&&row.status==='INACTIVE'&&!row.cleanupPending&&row.imageUrl===null),'Every owned reference must have an acknowledged cleared journal.');
  stage='reviewed agronomic model intake remains non-executable';
  const specification={modelKey:`synthetic-${randomUUID()}`,kind:'YIELD',expectedVersion:0,title:'Synthetic model review fixture',
    mathematicalDefinition:'Synthetic source intake only, no field prediction formula or coefficients are approved.',applicability:'Isolated contract tests only',assumptions:['No agronomic validity.'],
    inputs:[{key:'area',unit:'HECTARE',description:'Synthetic area contract'}],outputs:['minimum','expected','potential'].map(key=>({key,unit:'KG',description:'Synthetic model output contract only'})),coefficients:[],
    source:{url:source.url,title:source.title,publisher:source.publisher,citation:'Synthetic source-intake contract, not approved agronomy.'},reviewNote:'Review synthetic source intake while keeping all numerical execution disabled.',approved:true};
  await request('/admin/calculators/model-specifications',farmerToken,'POST',specification,403);
  const proposal=await request('/admin/calculators/model-specifications',adminToken,'POST',specification,201);
  assert.equal(proposal.execution,'DISABLED');assert.equal(proposal.validForActivation,false);
  await request('/admin/calculators/model-specifications',adminToken,'POST',specification,409);
  const second=await request('/admin/calculators/model-specifications',adminToken,'POST',{...specification,expectedVersion:1},201);
  assert.equal(second.version,2);
  await request(`/admin/calculators/yield/configurations/${proposal.id}/status`,adminToken,'PATCH',{status:'ACTIVE'},404);
  stage='independent fertilizer product catalogue, versioning and rule snapshot preservation';
  const productSource={url:'https://example.invalid/synthetic-product',title:'Synthetic product source',publisher:'Test generator',citation:'Generated isolated product metadata, never a field recommendation.'};
  const productInput={product:{slug:`synthetic-${randomUUID()}`,name:'Synthetic catalogue fixture',description:'Synthetic isolated product, no agricultural advice.',nitrogenPercent:'0',phosphorusPercent:'0',potassiumPercent:'0',applicationMethod:null,precautions:[],sourceReference:productSource.url},
    information:{type:null,growthStages:[],suitableConditions:[],applicationRateText:null,source:productSource,reviewNote:'Review generated product metadata only, not an agronomic recommendation.',approved:true},status:'DRAFT'};
  await request('/admin/fertilizers',farmerToken,'POST',productInput,403);
  await request('/admin/fertilizers',undefined,'GET',undefined,401);
  const product=await request('/admin/fertilizers',adminToken,'POST',productInput,201);
  const revised=await request(`/admin/fertilizers/${product.id}`,adminToken,'PATCH',{...productInput,product:{...productInput.product,name:'Revised synthetic product fixture'},expectedRevision:product.revision});
  assert.equal(revised.version,2);
  await request(`/admin/fertilizers/${product.id}`,adminToken,'PATCH',{...productInput,expectedRevision:product.revision},409);
  const activated=await request(`/admin/fertilizers/${product.id}/status`,adminToken,'PATCH',{status:'ACTIVE',expectedRevision:revised.revision});
  assert.equal(activated.status,'ACTIVE');
  await request(`/admin/fertilizers/${product.id}/status`,adminToken,'PATCH',{status:'INACTIVE',expectedRevision:activated.revision});
  assert.equal(await database.knowledgeDocument.count({where:{fertilizerId:product.id}}),2);
  assert.equal(await database.knowledgeChunk.count({where:{document:{fertilizerId:product.id}}}),0);
  assert.ok((await request('/admin/fertilizers',adminToken)).items.some(row=>row.id===product.id));
  const ruleModule=await import('../backend/tests/fertilizer/helpers.ts');
  const ruleFixture=ruleModule.draftInput();
  const latestConfig=await database.calculatorConfig.aggregate({where:{kind:'FERTILIZER',configKey:'maize-area-rate'},_max:{version:true}});
  // An independent config version avoids rewriting any earlier immutable fixture.
  const configVersion=Math.max(latestConfig._max.version??0,100)+1;
  await request('/admin/calculators/fertilizer/rules',adminToken,'POST',{...ruleFixture,
    product:{...productInput.product,name:'Revised synthetic product fixture'},
    rule:{...ruleFixture.rule,ruleKey:`synthetic-${randomUUID()}`},config:{...ruleFixture.config,version:configVersion}},201);
  const frozen=(await request('/admin/fertilizers',adminToken)).items.find(row=>row.id===product.id);
  assert.equal(frozen.contentEditable,false);
  await request(`/admin/fertilizers/${product.id}`,adminToken,'PATCH',{...productInput,expectedRevision:frozen.revision},409);
  assert.ok(await database.auditLog.count({where:{entityType:'disease_image'}})>=4);
  proof.steps=['real-generation-operational-record','provider-event','admin-aggregate-rbac','metadata-only-privacy',
    'informational-catalogue','sourced-optional-applicability','unchanged-model-mapping','real-cloudinary-synthetic-upload',
    'isolated-rights-publication','protected-node-delivery','flutter-monitoring-metadata-gallery',
    'replacement-revision-conflict','durable-retirement-cleanup','versioned-non-executable-model-intake','independent-product-catalogue-versioning','flutter-avatar-commit-before-delayed-cleanup'];
  proof.passed=true;
} catch(error) {
  proof.failure={stage,telemetryWarnings,referenceWarnings,type:error?.name??'Unknown',code:/^[A-Z0-9_]+$/.test(error?.code??'')?error.code:null,
    actual:typeof error?.actual==='number'||['GROUNDED','INSUFFICIENT_INFORMATION','OUT_OF_SCOPE','UNAVAILABLE','COLLECTED'].includes(error?.actual)?error.actual:null};
  console.error(`FAIL: Phase 24.6 ${stage}; private details omitted.`);process.exitCode=1;
} finally {
  await new Promise(resolve=>server.close(resolve));
  await app.locals.flushOperationalEvents();
  const cleanup=await Promise.allSettled([...assets].map(id=>createImageStorage(environment,id.split('/')[1]).destroy(id)));
  proof.ownedCloudAssets=[...assets];proof.cloudCleanupComplete=cleanup.every(row=>row.status==='fulfilled');
  if(!proof.cloudCleanupComplete)process.exitCode=1;
  await writeFile(join(process.env.PHASE23_OUTPUT,'phase246-proof.json'),JSON.stringify(proof,null,2)+'\n');
  await database.$disconnect();
}
