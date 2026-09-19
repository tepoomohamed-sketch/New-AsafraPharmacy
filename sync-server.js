/*
  سيرفر مزامنة محلي لأداة إدارة النواقص والطلبية - صيدلية أسافرة
  ------------------------------------------------------------
  - Node.js فقط (بدون أي مكتبات خارجية) — لا يحتاج npm install.
  - يعمل على شبكة الواي فاي المحلية فقط. لا يتصل بالإنترنت ولا يرسل أي بيانات لأي سيرفر خارجي.
  - طريقة التشغيل: افتح Command Prompt في هذا المجلد واكتب:
        node sync-server.js
    ثم افتح الرابط اللي هيظهر لك (مثلاً http://192.168.1.5:8420) على كل الأجهزة المتصلة بنفس الواي فاي.
*/

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = 8420;
const DATA_FILE = path.join(__dirname, 'pharmacy_sync_data.json');
const HTML_FILE = path.join(__dirname, 'أداة_إدارة_النواقص_والطلبية_الموحدة.html');

let idCounter = 1;
function nextId(){ return 'srv-' + Date.now() + '-' + (idCounter++); }

function defaultState(){
  return {
    masterItems: [],
    movementByCode: [],
    movementByName: [],
    movementMonths: 6,
    movementLoaded: false,
    customerLog: [],
    customerBackup: []
  };
}

let state = defaultState();

function loadState(){
  try{
    if(fs.existsSync(DATA_FILE)){
      const raw = fs.readFileSync(DATA_FILE, 'utf8');
      const parsed = JSON.parse(raw);
      state = Object.assign(defaultState(), parsed);
      // resume id counter above any existing srv- ids so we never collide
      const allIds = [].concat(
        (state.customerLog||[]).map(e=>e.id),
        (state.customerBackup||[]).map(e=>e.id)
      ).filter(Boolean);
      allIds.forEach(id=>{
        const m = /^srv-\d+-(\d+)$/.exec(id);
        if(m){ const n = parseInt(m[1]); if(n>=idCounter) idCounter = n+1; }
      });
    }
  }catch(e){
    console.error('تعذرت قراءة ملف البيانات، هيتم البدء ببيانات فارغة.', e.message);
    state = defaultState();
  }
}

let saveTimer = null;
function saveState(){
  clearTimeout(saveTimer);
  saveTimer = setTimeout(()=>{
    try{ fs.writeFileSync(DATA_FILE, JSON.stringify(state, null, 2), 'utf8'); }
    catch(e){ console.error('تعذر حفظ ملف البيانات:', e.message); }
  }, 50);
}

loadState();

function send(res, code, obj){
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*'
  });
  res.end(body);
}

function readBody(req){
  return new Promise((resolve, reject)=>{
    let data = '';
    req.on('data', chunk=>{ data += chunk; if(data.length > 50*1024*1024) req.destroy(); });
    req.on('end', ()=>{
      if(!data) return resolve({});
      try{ resolve(JSON.parse(data)); }catch(e){ reject(e); }
    });
    req.on('error', reject);
  });
}

const routes = {
  'POST /api/register-customer': async (body)=>{
    const name = String(body.name||'').trim();
    const qty = parseInt(body.qty) || 1;
    const phone = String(body.phone||'').trim();
    if(!name) throw new Error('اسم الصنف مطلوب');
    const now = new Date();
    const entry = {
      id: nextId(),
      date: now.toISOString().slice(0,10),
      time: now.toLocaleTimeString('ar-EG', {hour:'2-digit', minute:'2-digit'}),
      name, qty, phone, delivered: false
    };
    state.customerLog.push(entry);
    state.customerBackup.push(Object.assign({}, entry));
  },
  'POST /api/delete-customer-log': async (body)=>{
    const id = String(body.id);
    state.customerLog = state.customerLog.filter(e=> String(e.id) !== id);
  },
  'POST /api/clear-customer-log': async ()=>{
    state.customerLog = [];
  },
  'POST /api/mark-delivered': async (body)=>{
    const id = String(body.id);
    const delivered = !!body.delivered;
    const entry = state.customerBackup.find(e=> String(e.id) === id);
    if(entry) entry.delivered = delivered;
  },
  'POST /api/clear-archive': async ()=>{
    state.customerBackup = [];
  },
  'POST /api/import-backup': async (body)=>{
    const rows = Array.isArray(body.backup) ? body.backup : [];
    rows.forEach(r=>{
      state.customerBackup.push(Object.assign({}, r, { id: r.id || nextId() }));
    });
  },
  'POST /api/set-master-items': async (body)=>{
    state.masterItems = Array.isArray(body.items) ? body.items : [];
  },
  'POST /api/clear-master': async ()=>{
    state.masterItems = [];
  },
  'POST /api/set-movement-data': async (body)=>{
    state.movementByCode = Array.isArray(body.byCode) ? body.byCode : [];
    state.movementByName = Array.isArray(body.byName) ? body.byName : [];
    state.movementMonths = parseInt(body.months) || 6;
    state.movementLoaded = true;
  },
  'POST /api/clear-movement': async ()=>{
    state.movementByCode = [];
    state.movementByName = [];
    state.movementLoaded = false;
  }
};

const server = http.createServer(async (req, res)=>{
  const url = new URL(req.url, 'http://localhost');
  const key = req.method + ' ' + url.pathname;

  if(req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')){
    fs.readFile(HTML_FILE, (err, data)=>{
      if(err){ res.writeHead(500); res.end('تعذر تحميل ملف الأداة: ' + err.message); return; }
      res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
      res.end(data);
    });
    return;
  }

  if(req.method === 'GET' && url.pathname === '/api/state'){
    send(res, 200, state);
    return;
  }

  if(routes[key]){
    try{
      const body = await readBody(req);
      await routes[key](body);
      saveState();
      send(res, 200, state);
    }catch(e){
      send(res, 400, {error: e.message});
    }
    return;
  }

  res.writeHead(404, {'Content-Type': 'text/plain; charset=utf-8'});
  res.end('غير موجود');
});

function getLanIps(){
  const ifaces = os.networkInterfaces();
  const ips = [];
  Object.values(ifaces).forEach(list=>{
    (list||[]).forEach(iface=>{
      if(iface.family==='IPv4' && !iface.internal) ips.push(iface.address);
    });
  });
  return ips;
}

server.listen(PORT, ()=>{
  console.log('====================================================');
  console.log(' سيرفر المزامنة المحلي لصيدلية أسافرة يعمل الآن ✅');
  console.log('====================================================');
  console.log('افتح الرابط التالي على هذا الجهاز:');
  console.log('  http://localhost:' + PORT);
  const ips = getLanIps();
  if(ips.length){
    console.log('\nوافتح أحد الروابط التالية على باقي الأجهزة على نفس شبكة الواي فاي:');
    ips.forEach(ip=> console.log('  http://' + ip + ':' + PORT));
  } else {
    console.log('\nتعذر تحديد عنوان الشبكة المحلي تلقائيًا. تأكد إن الجهاز متصل بشبكة واي فاي.');
  }
  console.log('\nلإيقاف السيرفر: اضغط Ctrl+C');
  console.log('====================================================');
});
