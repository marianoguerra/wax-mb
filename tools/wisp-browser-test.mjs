// Run against a headless Chromium with --remote-debugging-port=9223 and the
// repository served on localhost:8765. No browser dependencies are needed.
const target = await fetch('http://127.0.0.1:9223/json/new?' + encodeURIComponent('http://127.0.0.1:8765/wisp/js/browser-test.html'), {method: 'PUT'}).then(r => r.json());
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
let serial = 0;
const pending = new Map();
socket.onmessage = event => {
  const reply = JSON.parse(event.data);
  if (pending.has(reply.id)) { pending.get(reply.id)(reply); pending.delete(reply.id); }
};
const command = (method, params = {}) => new Promise(resolve => {
  const id = ++serial;
  pending.set(id, resolve);
  socket.send(JSON.stringify({id, method, params}));
});
const timer = setTimeout(() => { console.error('browser test timeout'); socket.close(); process.exitCode = 1; }, 45000);
try {
  const result = await command('Runtime.evaluate', {
    expression: 'new Promise((resolve,reject)=>{const poll=setInterval(()=>{if(globalThis.testDone){clearInterval(poll);globalThis.testDone.then(resolve,reject)}},20)})',
    awaitPromise: true,
    returnByValue: true,
  });
  const dom = await command('Runtime.evaluate', {expression: 'document.querySelector("#result").textContent', returnByValue: true});
  console.log(dom.result.result.value);
  if (result.result?.result?.value !== 'PASS') process.exitCode = 1;
} finally {
  clearTimeout(timer);
  await command('Page.close');
  socket.close();
}
