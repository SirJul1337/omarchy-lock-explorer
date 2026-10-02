const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const source = fs.readFileSync(require('node:path').join(__dirname, '../Service.qml'), 'utf8');
function bodyAfter(marker, start=0) {
  const at = source.indexOf(marker, start);
  assert(at >= 0);
  const open = source.indexOf('{', at);
  let depth = 1, end = open + 1;
  for (; depth; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(open+1,end-1);
}
function context(extra={}) {
  const c = {fido2Authenticating:true, fido2NeedsPin:false, enteredPassword:'',
    fido2RoundStarted:Date.now()-100, lockRequested:true, screenBlanked:false,
    fido2PinSubmitted:false, fido2Cue:'', fido2DeviceChanged:false,
    fido2TokenPresent:true, fido2FailurePending:false, fido2ProbeForFailure:false, fido2FailureElapsed:0, fido2TouchMisses:0, failedAttempts:0,
    fido2PinAttempts:0, fido2NoTouchMs:20000, fido2TouchRetryLimit:3,
    authMode:'fido2', fido2Configured:true, authenticatingPassword:false,
    failureTimes:[], failureMessage:'', fido2Status:'', retries:0, probes:0, unlocked:false,
    Qt:{callLater(fn){fn()}}, PamResult:{Success:0,Failed:1,Error:2}, sessionLock:{secure:true},
    fido2Pam:{active:false,start(){throw Error('unexpected PAM start')}},
    setAuthMode(mode){c.authMode=mode;c.failureMessage='';c.fido2FailurePending=false}, settleAuthMode(){},
    finishUnlock(){c.unlocked=true}, logEvent(){}, runWake(){},
    refreshFido2Status(){c.probes++}, ...extra};
  Object.defineProperty(c,'fido2Active',{get:()=>c.authMode==='fido2'});
  Object.defineProperty(c,'fido2Exhausted',{get:()=>c.fido2PinAttempts>=3});
  c.fido2RetryTimer={restart(){c.retries++}};
  c.fido2FailureSettle={running:false,restart(){this.running=true},stop(){this.running=false}}; c.root=c;
  vm.createContext(c);
  vm.runInContext('function t(text) { return text; }; String.prototype.arg = function(value) { return this.replace("%1", value); };',c);
  for (const name of ['handleFido2Finished','finishFido2Failure','startFido2','retryFido2'])
    vm.runInContext(`function ${name}(${name==='handleFido2Finished'?'result':name==='finishFido2Failure'?'elapsed':''}) {${bodyAfter('function '+name+'(')}}`,c);
  return c;
}
test('three immediate no-device errors do not consume fingerprint retries',()=>{
 const c=context(); for(let i=0;i<3;i++){c.authMode='fido2';c.fido2Authenticating=true;fail(c)}
 assert.equal(c.failedAttempts,0);assert.equal(c.fido2TouchMisses,0);
 assert.equal(c.retries,0);assert.equal(c.fido2TokenPresent,false);
});
test('USB change during assertion schedules a probe without a failed try',()=>{
 const c=context({fido2Cue:'Touch your security key',fido2DeviceChanged:true});
 fail(c);assert.equal(c.failedAttempts,0);assert.equal(c.retries,1);
});
test('real touch failures retain the three-attempt limit',()=>{
 const c=context({fido2Cue:'Touch your security key'});
 for(let i=0;i<3;i++){c.fido2Authenticating=true;fail(c)}
 assert.equal(c.failedAttempts,3);assert.equal(c.authMode,'password');assert.equal(c.failureMessage,'Too many tries');
});
test('submitted PIN still consumes its budget even after USB loss',()=>{
 const c=context({fido2PinSubmitted:true,fido2PinAttempts:2,fido2DeviceChanged:true});
 fail(c);assert.equal(c.fido2PinAttempts,3);assert.equal(c.authMode,'password');
});
test('wake rechecks presence instead of trusting the pre-suspend flag',()=>{
 const c=context();c.retryFido2();assert.equal(c.probes,1);
});
const probe = bodyAfter('onExited:',source.indexOf('id: fido2CheckProc'));
for(const [name,extra,expected] of [
 ['empty password prompt',{},'fido2'],
 ['partially typed password',{enteredPassword:'example'},'password'],
 ['password check in flight',{authenticatingPassword:true},'password'],
 ['PIN limit reached',{fido2PinAttempts:3},'password']]) {
 test('insertion handles '+name,()=>{
  const c=context({authMode:'password',fido2TokenPresent:false,...extra});
  c.fido2CheckStdout={text:'yes present'};
  vm.runInContext('(function(){'+probe+'})()',c);
  assert.equal(c.authMode,expected);
 });
}
test('PAM success remains required to unlock, including during unplug',()=>{
 const c=context({fido2DeviceChanged:true});fail(c);assert.equal(c.unlocked,false);
 c.fido2Authenticating=true;c.handleFido2Finished(0);assert.equal(c.unlocked,true);
});

function resolveFailure(c, present=true) {
 c.fido2FailureSettle.running=false; c.fido2ProbeForFailure=true;
 c.fido2CheckStdout={text:'yes '+(present?'present':'absent')};
 vm.runInContext('(function(){'+probe+'})()',c);
}
function fail(c) {
 c.handleFido2Finished(1);
 if(c.fido2FailurePending) resolveFailure(c);
}
test('PAM failure before USB remove waits and does not charge an unplug',()=>{
 const c=context({fido2Cue:'Touch your security key'});
 c.handleFido2Finished(1);
 assert.equal(c.failedAttempts,0);assert.equal(c.fido2FailurePending,true);
 // No udev event is needed: a fresh probe independently confirms removal.
 resolveFailure(c,false);
 assert.equal(c.failedAttempts,0);assert.equal(c.fido2TouchMisses,0);
 assert.equal(c.failureMessage,'');assert.equal(c.fido2Status,'');assert.equal(c.authMode,'password');
});
test('an old probe cannot resolve a pending failure before the settle timer',()=>{
 const c=context({fido2Cue:'Touch your security key'});
 c.handleFido2Finished(1);c.fido2CheckStdout={text:'yes present'};
 vm.runInContext('(function(){'+probe+'})()',c);
 assert.equal(c.fido2FailurePending,true);assert.equal(c.failedAttempts,0);
 resolveFailure(c,false);assert.equal(c.failedAttempts,0);
});
test('a new assertion cannot start while removal classification is pending',()=>{
 const c=context({fido2Authenticating:false,fido2FailurePending:true});c.startFido2();
 assert.equal(c.fido2Authenticating,false);
});

test('a slow pre-failure probe cannot classify removal after the timer expires',()=>{
 const c=context({fido2Cue:'Touch your security key'});
 c.handleFido2Finished(1);c.fido2FailureSettle.running=false;
 c.fido2CheckStdout={text:'yes present'};
 vm.runInContext('(function(){'+probe+'})()',c);
 assert.equal(c.fido2FailurePending,true);assert.equal(c.failedAttempts,0);
 assert.equal(c.probes,1);
 resolveFailure(c,false);assert.equal(c.failedAttempts,0);
});
