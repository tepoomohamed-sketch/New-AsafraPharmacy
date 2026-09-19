/**
 * ==========================================================
 * سيرفر إرسال واتساب تلقائي - صيدلية أصفرا
 * ==========================================================
 * ده سيرفر Node.js بيشغّل جلسة واتساب ويب حقيقية عن طريق
 * مكتبة whatsapp-web.js (مكتبة غير رسمية - مش من ميتا).
 *
 * ⚠️ تحذير مهم قبل ما تشغّله:
 * - المكتبة دي مش معتمدة رسمياً من واتساب، واستخدامها بيخالف
 *   شروط الاستخدام بتاعة واتساب، وممكن يتحظر رقم الصيدلية،
 *   خصوصاً إن إحنا بنبعت رسايل "بنبدأ إحنا فيها" (مش رد على
 *   العميل). قللنا الخطورة قد ما نقدر (نفس رقم واحد، رسائل
 *   قليلة، مفيش إرسال جماعي) لكن الاحتمال موجود.
 * - لازم الجهاز اللي شغال عليه السيرفر يفضل شغال طول وقت
 *   الدوام عشان الإرسال يشتغل. لو قفلت الجهاز أو السيرفر
 *   وقف، اللوحة هترجع تلقائي للطريقة اليدوية (فتح واتساب).
 *
 * طريقة التشغيل (أول مرة):
 *   1) نزّل Node.js من nodejs.org لو مش متثبت.
 *   2) افتح Terminal / CMD في الفولدر ده واكتب: npm install
 *   3) بعدين اكتب: npm start
 *   4) افتح المتصفح على: http://localhost:3000/qr
 *   5) امسح الكود من موبايل الصيدلية:
 *      واتساب > الإعدادات > الأجهزة المرتبطة > ربط جهاز
 *   6) لما تشوف "متصل" في الترمينال، اللوحة (ملف الـ HTML)
 *      هتبدأ تبعت تلقائي من غير كليك.
 *
 * المرات الجايه: تشغيل npm start بس كافي (مش هيطلب مسح تاني
 * إلا لو فصلت الجهاز من واتساب بنفسك).
 * ==========================================================
 */

const express = require('express');
const cors = require('cors');
const qrcode = require('qrcode');
const { Client, LocalAuth } = require('whatsapp-web.js');

const PORT = 3000;
const app = express();
app.use(cors());
app.use(express.json());

let isReady = false;
let lastQrDataUrl = null;

const client = new Client({
  authStrategy: new LocalAuth({ clientId: 'asafra-pharmacy' }),
  puppeteer: {
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  }
});

client.on('qr', async (qr) => {
  isReady = false;
  lastQrDataUrl = await qrcode.toDataURL(qr);
  console.log('📷 كود QR جاهز - افتح http://localhost:' + PORT + '/qr وامسحه من موبايل الصيدلية');
});

client.on('ready', () => {
  isReady = true;
  console.log('✅ واتساب متصل ومستعد للإرسال التلقائي');
});

client.on('authenticated', () => {
  console.log('🔐 تم تسجيل الدخول بنجاح');
});

client.on('disconnected', (reason) => {
  isReady = false;
  console.log('⚠️ انقطع الاتصال بواتساب:', reason);
});

client.initialize();

// صفحة عرض كود QR للمسح من المتصفح
app.get('/qr', (req, res) => {
  if (isReady) {
    res.send(`
      <html dir="rtl"><body style="font-family:sans-serif;text-align:center;margin-top:60px;">
        <h2>✅ واتساب متصل بالفعل</h2>
        <p>مفيش حاجة، السيرفر جاهز يبعت رسائل تلقائي.</p>
      </body></html>
    `);
  } else if (lastQrDataUrl) {
    res.send(`
      <html dir="rtl"><body style="font-family:sans-serif;text-align:center;margin-top:30px;">
        <h2>امسح الكود ده من واتساب موبايل الصيدلية</h2>
        <p>واتساب &gt; الإعدادات &gt; الأجهزة المرتبطة &gt; ربط جهاز</p>
        <img src="${lastQrDataUrl}" style="width:280px;height:280px;">
        <p style="color:#888;font-size:13px;">الصفحة بتتحدث لوحدها، سيبها مفتوحة لحد ما تشوف "متصل"</p>
        <script>setTimeout(()=>location.reload(), 5000);</script>
      </body></html>
    `);
  } else {
    res.send('<p style="font-family:sans-serif;text-align:center;margin-top:60px;">جاري تجهيز كود الربط، حدّث الصفحة بعد كام ثانية...</p>');
  }
});

// حالة الاتصال - بتستخدمها لوحة الموظف عشان تعرف تبعت تلقائي ولا لأ
app.get('/status', (req, res) => {
  res.json({ ready: isReady });
});

// إرسال رسالة فعلية للعميل
app.post('/send-whatsapp', async (req, res) => {
  try {
    const { phone, message } = req.body;
    if (!phone || !message) {
      return res.status(400).json({ ok: false, error: 'رقم الموبايل أو الرسالة ناقصة' });
    }
    if (!isReady) {
      return res.status(503).json({ ok: false, error: 'واتساب لسه مش متصل - امسح الكود من /qr' });
    }
    const chatId = `${phone}@c.us`;
    await client.sendMessage(chatId, message);
    console.log(`📤 اتبعتت رسالة لـ ${phone}`);
    res.json({ ok: true });
  } catch (err) {
    console.error('❌ فشل الإرسال:', err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 السيرفر شغال على http://localhost:${PORT}`);
  console.log(`📷 افتح http://localhost:${PORT}/qr عشان تربط واتساب الصيدلية`);
});
