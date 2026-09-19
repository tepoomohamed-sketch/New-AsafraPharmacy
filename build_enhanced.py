#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build enhanced dark-theme pharmacy HTML from the original file."""
import os, sys

src  = r'c:\Users\HP\Documents\Claude\Projects\asafra pharmacy\سجل الصيدلية - متعدد المستخدمين.html'
dest = r'c:\Users\HP\Documents\Claude\Projects\asafra pharmacy\صيدلية عصفرة - نسخة محسّنة.html'

with open(src, 'r', encoding='utf-8') as f:
    original = f.read()

# ── Extract JS block and modals ──────────────────────────────────────────────
js_block = original[47563:145657]   # <script>...</script>
modals   = original[145659:]        # <!-- modals --> ... </html>

# ── Dark CSS ─────────────────────────────────────────────────────────────────
dark_css = """<style>
  *{margin:0;padding:0;box-sizing:border-box;}
  :root{
    --bg:#0f1117;--bg2:#161b27;--bg3:#1e2535;
    --card:#1e2535;--card2:#252d3d;--card3:#2d3748;
    --border:rgba(255,255,255,.08);--border2:rgba(255,255,255,.13);
    --green:#40916c;--green2:#2d6a4f;--green3:#1b4332;
    --green-glow:rgba(64,145,108,.35);
    --red:#e53e3e;--blue:#3182ce;--gold:#d69e2e;--purple:#805ad5;
    --text:#e2e8f0;--text2:#a0aec0;--text3:#718096;
    --grad-main:linear-gradient(135deg,#1b4332 0%,#2d6a4f 50%,#40916c 100%);
    --shadow-sm:0 2px 8px rgba(0,0,0,.4);
    --shadow-md:0 4px 20px rgba(0,0,0,.5);
    --shadow-lg:0 8px 40px rgba(0,0,0,.6);
    --r:14px;
  }
  body{font-family:'Tajawal',sans-serif;background:var(--bg);color:var(--text);direction:rtl;min-height:100vh;line-height:1.5;}
  .scr{display:none;min-height:100vh;}
  .scr.on{display:block;}
  #scLoad.on{display:flex;flex-direction:column;align-items:center;justify-content:center;background:var(--grad-main);color:white;gap:18px;}
  .spin{width:52px;height:52px;border:4px solid rgba(255,255,255,.25);border-top-color:white;border-radius:50%;animation:spin .8s linear infinite;}
  @keyframes spin{to{transform:rotate(360deg)}}
  .g-wrap{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px;background:var(--bg) radial-gradient(ellipse at top right,rgba(64,145,108,.18) 0%,transparent 60%);}
  .g-card{background:var(--card);border:1px solid var(--border2);border-radius:22px;padding:36px;width:100%;max-width:460px;box-shadow:var(--shadow-lg);animation:fadeUp .4s ease;}
  .g-card.wide{max-width:640px;}
  @keyframes fadeUp{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:none}}
  .g-logo{font-size:3rem;text-align:center;margin-bottom:10px;}
  .g-title{font-size:1.5rem;font-weight:900;color:var(--text);text-align:center;margin-bottom:4px;}
  .g-sub{font-size:.85rem;color:var(--text3);text-align:center;margin-bottom:26px;}
  .a-tabs{display:flex;background:var(--bg3);border-radius:12px;padding:5px;margin-bottom:22px;}
  .a-tab{flex:1;text-align:center;padding:10px;border-radius:9px;cursor:pointer;font-weight:700;font-size:.9rem;color:var(--text3);transition:all .2s;}
  .a-tab.on{background:var(--green2);color:white;box-shadow:0 2px 10px var(--green-glow);}
  .a-form{display:none;}
  .a-form.on{display:block;}
  .fg{display:flex;flex-direction:column;gap:5px;margin-bottom:14px;}
  .fg label{font-weight:700;font-size:.83rem;color:var(--text2);}
  .fg input,.fg select,.fg textarea{padding:11px 13px;border:1.5px solid var(--border2);border-radius:10px;font-size:.94rem;font-family:'Tajawal',sans-serif;color:var(--text);background:var(--bg3);transition:all .2s;}
  .fg input:focus,.fg select:focus,.fg textarea:focus{outline:none;border-color:var(--green);box-shadow:0 0 0 3px rgba(64,145,108,.2);}
  .fg select option{background:var(--bg2);color:var(--text);}
  .fg-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px;}
  .fg-full{grid-column:1/-1;}
  .btn{padding:11px 18px;border:none;border-radius:10px;cursor:pointer;font-weight:800;font-size:.9rem;font-family:'Tajawal',sans-serif;transition:all .18s;display:inline-flex;align-items:center;gap:7px;}
  .btn-primary{background:var(--grad-main);color:white;width:100%;justify-content:center;margin-top:6px;box-shadow:0 4px 15px var(--green-glow);}
  .btn-primary:hover{transform:translateY(-2px);box-shadow:0 6px 20px var(--green-glow);}
  .btn-primary:active{transform:none;}
  .btn-primary:disabled{opacity:.5;cursor:default;transform:none;box-shadow:none;}
  .btn-sm{padding:7px 14px;font-size:.81rem;border-radius:8px;}
  .btn-green{background:var(--green2);color:white;}
  .btn-red{background:var(--red);color:white;}
  .btn-blue{background:var(--blue);color:white;}
  .btn-gray{background:var(--card3);color:var(--text);}
  .btn-ghost{background:var(--bg3);color:var(--text2);border:1.5px solid var(--border2);}
  .err{color:#fc8181;font-size:.82rem;margin-top:5px;display:none;padding:8px 11px;background:rgba(229,62,62,.12);border-radius:8px;border:1px solid rgba(229,62,62,.3);}
  .err.on{display:block;}
  .steps{background:var(--bg3);border-radius:10px;padding:14px 16px;margin-bottom:16px;font-size:.84rem;color:var(--text2);border:1px solid var(--border);}
  .steps ol{padding-right:18px;}
  .steps li{margin-bottom:5px;line-height:1.6;}
  .steps a{color:var(--green);font-weight:700;}
  .steps code{background:var(--bg2);padding:2px 6px;border-radius:5px;font-size:.81rem;color:#68d391;}
  .cfg-ta{width:100%;height:155px;border:1.5px solid var(--border2);border-radius:10px;padding:11px;font-family:'Courier New',monospace;font-size:.8rem;resize:vertical;direction:ltr;background:var(--bg3);color:#68d391;}
  .cfg-ta:focus{outline:none;border-color:var(--green);}
  .hdr{background:linear-gradient(135deg,var(--green3) 0%,var(--green2) 60%,var(--green) 100%);color:white;padding:14px 24px;box-shadow:0 4px 20px rgba(0,0,0,.4);position:sticky;top:0;z-index:100;border-bottom:1px solid rgba(255,255,255,.1);}
  .hdr-in{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;}
  .ph-name{font-size:1.35rem;font-weight:900;letter-spacing:-.3px;}
  .u-badge{background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.2);border-radius:22px;padding:5px 13px;font-size:.8rem;display:flex;align-items:center;gap:8px;}
  .r-chip{padding:2px 9px;border-radius:10px;font-size:.7rem;font-weight:800;}
  .rc-admin{background:#f6e05e;color:#744210;}
  .rc-emp{background:#bee3f8;color:#2a4a6a;}
  .bal-box{background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.2);border-radius:14px;padding:8px 18px;text-align:center;}
  .bal-lbl{font-size:.7rem;opacity:.8;}
  .bal-amt{font-size:1.6rem;font-weight:900;transition:color .3s;}
  .btn-logout{background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.25);border-radius:9px;padding:7px 15px;color:white;cursor:pointer;font-size:.83rem;font-weight:700;font-family:'Tajawal',sans-serif;transition:all .2s;}
  .btn-logout:hover{background:rgba(255,255,255,.22);}
  .t-bar{background:var(--bg2);padding:10px 24px;display:flex;gap:24px;flex-wrap:wrap;border-bottom:1px solid var(--border);font-size:.83rem;}
  .ti{display:flex;align-items:center;gap:6px;}
  .ti-l{color:var(--text3);}
  .ti-v{font-weight:800;font-size:.93rem;}
  .c-g{color:#68d391;}.c-r{color:#fc8181;}.c-b{color:#63b3ed;}.c-o{color:#f6ad55;}
  .tabs{display:flex;background:var(--bg2);border-bottom:1px solid var(--border);padding:0 20px;overflow-x:auto;scrollbar-width:none;}
  .tabs::-webkit-scrollbar{display:none;}
  .tab{padding:14px 20px;cursor:pointer;font-weight:700;color:var(--text3);border-bottom:2.5px solid transparent;margin-bottom:-1px;transition:all .2s;white-space:nowrap;font-size:.9rem;}
  .tab.on{color:var(--green);border-bottom-color:var(--green);}
  .tab:hover:not(.on){color:var(--text);}
  .content{padding:20px 24px;max-width:1320px;margin:0 auto;}
  .pane{display:none;}
  .pane.on{display:block;animation:fadeIn .25s ease;}
  @keyframes fadeIn{from{opacity:0}to{opacity:1}}
  .card{background:var(--card);border:1px solid var(--border);border-radius:var(--r);padding:22px;box-shadow:var(--shadow-sm);margin-bottom:16px;}
  .card-t{font-size:.97rem;font-weight:800;color:var(--text);margin-bottom:16px;}
  .type-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:18px;}
  .type-btn{padding:13px 8px;text-align:center;border-radius:12px;cursor:pointer;border:1.5px solid;font-weight:800;font-size:.93rem;transition:all .2s;user-select:none;}
  .tb-r{background:rgba(64,145,108,.1);color:#68d391;border-color:rgba(64,145,108,.3);}
  .tb-r.on{background:var(--green2);color:white;border-color:var(--green2);box-shadow:0 4px 15px var(--green-glow);}
  .tb-e{background:rgba(229,62,62,.1);color:#fc8181;border-color:rgba(229,62,62,.3);}
  .tb-e.on{background:var(--red);color:white;border-color:var(--red);box-shadow:0 4px 15px rgba(229,62,62,.35);}
  .tb-o{background:rgba(49,130,206,.1);color:#63b3ed;border-color:rgba(49,130,206,.3);}
  .tb-o.on{background:var(--blue);color:white;border-color:var(--blue);box-shadow:0 4px 15px rgba(49,130,206,.35);}
  .tb-p{background:rgba(214,158,46,.1);color:#f6ad55;border-color:rgba(214,158,46,.3);}
  .tb-p.on{background:#975a16;color:white;border-color:#975a16;}
  .tbl-w{overflow-x:auto;}
  table{width:100%;border-collapse:collapse;min-width:600px;}
  thead th{background:var(--bg3);padding:11px 12px;text-align:right;font-weight:800;color:var(--text2);font-size:.79rem;border-bottom:1px solid var(--border2);white-space:nowrap;}
  tbody td{padding:10px 12px;border-bottom:1px solid var(--border);font-size:.84rem;color:var(--text);}
  tbody tr{transition:background .15s;}
  tbody tr:hover td{background:var(--card2);}
  .badge{padding:3px 10px;border-radius:20px;font-size:.74rem;font-weight:800;display:inline-block;}
  .br{background:rgba(104,211,145,.15);color:#68d391;}
  .be{background:rgba(252,129,129,.15);color:#fc8181;}
  .bo{background:rgba(99,179,237,.15);color:#63b3ed;}
  .bp{background:rgba(246,173,85,.15);color:#f6ad55;}
  .bal-p{color:#68d391;font-weight:700;}.bal-n{color:#fc8181;font-weight:700;}
  .emp-tag{font-size:.75rem;background:var(--bg3);padding:2px 8px;border-radius:8px;color:var(--text3);}
  .btn-del{background:none;border:none;color:rgba(252,129,129,.7);cursor:pointer;font-size:.9rem;padding:4px 8px;border-radius:7px;transition:all .15s;}
  .btn-del:hover{background:rgba(229,62,62,.12);color:#fc8181;}
  .btn-edit{background:none;border:none;color:rgba(99,179,237,.7);cursor:pointer;font-size:.9rem;padding:4px 8px;border-radius:7px;transition:all .15s;}
  .btn-edit:hover{background:rgba(49,130,206,.12);color:#63b3ed;}
  .modal-overlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:2000;align-items:center;justify-content:center;padding:16px;backdrop-filter:blur(4px);}
  .modal-overlay.on{display:flex;}
  .modal-box{background:var(--card);border:1px solid var(--border2);border-radius:20px;padding:30px;width:100%;max-width:480px;direction:rtl;max-height:90vh;overflow-y:auto;box-shadow:0 25px 60px rgba(0,0,0,.6);animation:modalIn .25s ease;}
  @keyframes modalIn{from{opacity:0;transform:scale(.95)}to{opacity:1;transform:none}}
  .frow{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px;}
  .fel{padding:9px 12px;border:1.5px solid var(--border2);border-radius:9px;font-size:.84rem;font-family:'Tajawal',sans-serif;background:var(--bg3);color:var(--text);transition:all .2s;}
  .fel:focus{outline:none;border-color:var(--green);}
  .fel-s{flex:1;min-width:150px;}
  .pgr{display:flex;justify-content:space-between;align-items:center;margin-top:12px;font-size:.82rem;color:var(--text3);}
  .pgr-btns{display:flex;gap:7px;}
  .pb{padding:6px 13px;border:1.5px solid var(--border2);border-radius:8px;background:var(--card2);cursor:pointer;font-size:.79rem;color:var(--text2);font-weight:600;transition:all .15s;}
  .pb:hover:not(:disabled){border-color:var(--green);color:var(--green);}
  .pb:disabled{opacity:.3;cursor:default;}
  .s-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:13px;margin-bottom:16px;}
  .sc{background:var(--card);border:1px solid var(--border);border-radius:13px;padding:16px 18px;box-shadow:var(--shadow-sm);border-right:3px solid;}
  .sc-g{border-right-color:var(--green);}.sc-r{border-right-color:var(--red);}.sc-b{border-right-color:var(--blue);}.sc-o{border-right-color:var(--gold);}.sc-p{border-right-color:var(--purple);}
  .sl{font-size:.75rem;color:var(--text3);margin-bottom:5px;}.sv{font-size:1.45rem;font-weight:900;color:var(--text);}.su{font-size:.7rem;color:var(--text3);}
  .ch-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:14px;margin-bottom:16px;}
  .ch-card{background:var(--card);border:1px solid var(--border);border-radius:var(--r);padding:18px;box-shadow:var(--shadow-sm);}
  .ch-t{font-weight:800;color:var(--text);margin-bottom:12px;font-size:.9rem;}
  .bd-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:14px;}
  .bkt{width:100%;border-collapse:collapse;}
  .bkt th{background:var(--bg3);padding:8px 10px;text-align:right;font-size:.77rem;color:var(--text2);border-bottom:1px solid var(--border);font-weight:700;}
  .bkt td{padding:8px 10px;border-bottom:1px solid var(--border);font-size:.82rem;color:var(--text);}
  .bkt tr:last-child td{border-bottom:none;}
  .mo-tabs{display:flex;gap:7px;flex-wrap:wrap;margin-bottom:14px;}
  .mot{padding:5px 14px;border-radius:20px;border:1.5px solid var(--border2);cursor:pointer;font-size:.81rem;font-weight:700;background:var(--card2);color:var(--text3);transition:all .2s;}
  .mot.on{background:var(--green2);color:white;border-color:var(--green2);}
  .dp-wrap{display:flex;gap:7px;flex-wrap:wrap;align-items:center;background:var(--card);padding:13px 16px;border-radius:13px;box-shadow:var(--shadow-sm);margin-bottom:18px;border:1px solid var(--border);}
  .dp-lbl{font-size:.82rem;color:var(--text2);font-weight:700;margin-left:4px;}
  .dp-btn{padding:7px 18px;border-radius:20px;border:1.5px solid var(--border2);cursor:pointer;font-size:.83rem;font-weight:700;background:var(--card2);color:var(--text3);transition:all .2s;font-family:'Tajawal',sans-serif;}
  .dp-btn.on{background:var(--green2);color:white;border-color:var(--green2);box-shadow:0 3px 12px var(--green-glow);}
  .dp-btn:hover:not(.on){background:rgba(64,145,108,.1);border-color:rgba(64,145,108,.4);color:var(--green);}
  .dkpi-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(185px,1fr));gap:13px;margin-bottom:18px;}
  .dkpi{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:18px 20px;box-shadow:var(--shadow-sm);border-right:4px solid;position:relative;overflow:hidden;transition:transform .2s,box-shadow .2s;}
  .dkpi:hover{transform:translateY(-2px);box-shadow:var(--shadow-md);}
  .dkpi-g{border-right-color:var(--green);}.dkpi-r{border-right-color:var(--red);}.dkpi-b{border-right-color:var(--blue);}.dkpi-o{border-right-color:var(--gold);}.dkpi-p{border-right-color:var(--purple);}
  .dkpi-lbl{font-size:.75rem;color:var(--text3);margin-bottom:7px;font-weight:600;}
  .dkpi-val{font-size:1.5rem;font-weight:900;color:var(--text);line-height:1.1;}
  .dkpi-unit{font-size:.72rem;color:var(--text3);margin-right:3px;}
  .dkpi-delta{font-size:.73rem;margin-top:5px;}
  .d-up{color:#68d391;font-weight:700;}.d-dn{color:#fc8181;font-weight:700;}.d-na{color:var(--text3);}
  .pl-wrap{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:20px;box-shadow:var(--shadow-sm);margin-bottom:18px;}
  .pl-title{font-weight:800;color:var(--text);font-size:.95rem;margin-bottom:14px;}
  .pl-tbl{width:100%;border-collapse:collapse;}
  .pl-tbl th{background:rgba(64,145,108,.1);padding:10px 12px;text-align:right;font-size:.78rem;color:#68d391;border-bottom:1px solid rgba(64,145,108,.2);font-weight:700;white-space:nowrap;}
  .pl-tbl td{padding:9px 12px;border-bottom:1px solid var(--border);font-size:.83rem;color:var(--text);}
  .pl-tbl tbody tr:hover td{background:var(--card2);}
  .pl-tot td{border-bottom:none;font-weight:800;background:var(--bg3);}
  .pl-pos{color:#68d391;font-weight:700;}.pl-neg{color:#fc8181;font-weight:700;}
  .pos-section{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:20px 24px;box-shadow:var(--shadow-sm);margin-bottom:18px;border-top:3px solid var(--blue);}
  .pos-title{font-weight:800;color:var(--text);font-size:.95rem;margin-bottom:14px;display:flex;align-items:center;gap:9px;}
  .pos-badge{background:rgba(49,130,206,.15);color:#63b3ed;padding:3px 11px;border-radius:20px;font-size:.74rem;font-weight:700;}
  .pos-kpi-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:11px;margin-bottom:16px;}
  .pos-kpi{border-radius:11px;padding:14px 16px;text-align:center;border:1px solid var(--border);}
  .pos-kpi-rev{background:rgba(64,145,108,.08);}.pos-kpi-cost{background:rgba(229,62,62,.08);}.pos-kpi-gp{background:rgba(49,130,206,.08);}.pos-kpi-np{background:rgba(128,90,213,.08);}.pos-kpi-disc{background:rgba(214,158,46,.08);}
  .pos-kpi .kl{font-size:.73rem;color:var(--text3);margin-bottom:5px;font-weight:600;}
  .pos-kpi .kv{font-size:1.3rem;font-weight:900;color:var(--text);}
  .pos-kpi .ku{font-size:.7rem;color:var(--text3);}
  .closing-card{background:linear-gradient(135deg,#0a1f13 0%,var(--green3) 40%,var(--green2) 100%);color:white;border-radius:14px;padding:22px 26px;margin-bottom:18px;box-shadow:0 6px 30px rgba(27,67,50,.5);border:1px solid rgba(64,145,108,.3);}
  .cl-title{font-size:1rem;font-weight:800;margin-bottom:16px;border-bottom:1px solid rgba(255,255,255,.15);padding-bottom:12px;}
  .cl-row{display:flex;justify-content:space-between;align-items:center;padding:9px 0;border-bottom:1px solid rgba(255,255,255,.08);}
  .cl-row:last-of-type{border-bottom:none;}
  .cl-label{font-size:.86rem;opacity:.85;}
  .cl-val{font-size:1.05rem;font-weight:800;}
  .cl-final{background:rgba(255,255,255,.12);border-radius:11px;padding:13px 17px;margin-top:13px;display:flex;justify-content:space-between;align-items:center;border:1px solid rgba(255,255,255,.15);}
  .cl-final-lbl{font-size:.92rem;font-weight:700;}
  .cl-final-val{font-size:1.5rem;font-weight:900;}
  .u-row{display:flex;align-items:center;gap:12px;padding:14px;border-bottom:1px solid var(--border);}
  .u-row:last-child{border-bottom:none;}
  .u-av{width:40px;height:40px;border-radius:50%;background:var(--grad-main);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:.95rem;flex-shrink:0;}
  .u-info{flex:1;}.u-name{font-weight:700;color:var(--text);font-size:.9rem;}.u-email{font-size:.78rem;color:var(--text3);}
  .u-acts{display:flex;gap:6px;flex-shrink:0;}
  .toast{position:fixed;top:24px;left:50%;transform:translateX(-50%);color:white;padding:11px 24px;border-radius:12px;font-weight:700;z-index:9999;font-size:.88rem;box-shadow:0 6px 30px rgba(0,0,0,.4);animation:tIn .3s ease;border:1px solid rgba(255,255,255,.15);}
  @keyframes tIn{from{top:-20px;opacity:0}to{top:24px;opacity:1}}
  .nd{text-align:center;padding:36px 16px;color:var(--text3);}
  .nd-i{font-size:2.5rem;margin-bottom:10px;opacity:.5;}
  .set-sec{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:20px 22px;box-shadow:var(--shadow-sm);margin-bottom:14px;}
  .set-t{font-weight:800;font-size:.95rem;color:var(--text);margin-bottom:13px;}
  .pd-hdr{background:linear-gradient(135deg,#0d1f3a,#1a365d,#2b6cb0);color:white;border-radius:13px;padding:15px 19px;margin-bottom:16px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;box-shadow:0 4px 20px rgba(49,130,206,.3);}
  .pd-hdr-title{font-size:1.05rem;font-weight:900;}
  .pd-hdr-actions{display:flex;gap:8px;flex-wrap:wrap;}
  .pd-statsbar{background:var(--card);padding:11px 17px;display:flex;gap:18px;flex-wrap:wrap;border-radius:13px;box-shadow:var(--shadow-sm);margin-bottom:14px;font-size:.83rem;border:1px solid var(--border);}
  .pd-sb-item{display:flex;align-items:center;gap:6px;}
  .pd-sb-lbl{color:var(--text3);}.pd-sb-val{font-weight:800;font-size:.93rem;}
  .pd-dp-wrap{display:flex;gap:7px;flex-wrap:wrap;align-items:center;background:var(--card);padding:12px 16px;border-radius:13px;box-shadow:var(--shadow-sm);margin-bottom:18px;border-right:3px solid var(--blue);border-top:1px solid var(--border);border-bottom:1px solid var(--border);border-left:1px solid var(--border);}
  .pd-dp-btn{padding:7px 17px;border-radius:20px;border:1.5px solid var(--border2);cursor:pointer;font-size:.83rem;font-weight:700;background:var(--card2);color:var(--text3);transition:all .2s;font-family:'Tajawal',sans-serif;}
  .pd-dp-btn.on{background:#1a365d;color:white;border-color:#1a365d;}
  .pd-dp-btn:hover:not(.on){background:rgba(49,130,206,.1);border-color:rgba(49,130,206,.4);color:#63b3ed;}
  .pd-kpi-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(165px,1fr));gap:12px;margin-bottom:18px;}
  .pd-kpi{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:16px 18px;box-shadow:var(--shadow-sm);border-top:3px solid var(--border);}
  .pd-kpi-b{border-top-color:var(--blue);}.pd-kpi-g{border-top-color:var(--green);}.pd-kpi-r{border-top-color:var(--red);}.pd-kpi-o{border-top-color:var(--gold);}.pd-kpi-p{border-top-color:var(--purple);}
  .pd-kl{font-size:.74rem;color:var(--text3);margin-bottom:5px;font-weight:600;}
  .pd-kv{font-size:1.4rem;font-weight:900;color:var(--text);line-height:1.1;}
  .pd-ku{font-size:.7rem;color:var(--text3);font-weight:400;}
  .pd-kd{font-size:.72rem;margin-top:5px;}
  .pd-ch-card{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:18px;box-shadow:var(--shadow-sm);margin-bottom:0;}
  .pd-ch-title{font-weight:800;color:var(--text);margin-bottom:13px;font-size:.9rem;display:flex;align-items:center;justify-content:space-between;}
  .pd-ch-title small{font-size:.74rem;color:var(--text3);font-weight:400;}
  .pd-type-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:9px;margin-bottom:14px;}
  .pd-type-box{border-radius:11px;padding:12px 13px;text-align:center;border:1px solid var(--border);}
  .pd-tb-cash{background:rgba(64,145,108,.1);}.pd-tb-del{background:rgba(49,130,206,.1);}.pd-tb-oth{background:rgba(128,90,213,.1);}
  .pd-type-name{font-size:.78rem;font-weight:700;color:var(--text2);margin-bottom:6px;}
  .pd-type-val{font-size:1.1rem;font-weight:900;color:var(--text);}
  .pd-type-detail{font-size:.71rem;color:var(--text3);margin-top:3px;}
  .pd-disc-summary{display:flex;gap:18px;margin-bottom:14px;flex-wrap:wrap;}
  .pd-disc-stat{text-align:center;}
  .pd-disc-stat .dv{font-size:1.35rem;font-weight:900;color:var(--text);}
  .pd-disc-stat .dl{font-size:.73rem;color:var(--text3);margin-top:2px;}
  .pd-disc-row{display:flex;align-items:center;gap:9px;margin-bottom:7px;}
  .pd-disc-label{width:65px;font-size:.79rem;color:var(--text2);text-align:right;flex-shrink:0;font-weight:600;}
  .pd-disc-bar-wrap{flex:1;background:var(--bg3);border-radius:4px;height:22px;overflow:hidden;position:relative;}
  .pd-disc-bar-fill{height:100%;border-radius:4px;transition:width .6s ease;}
  .pd-disc-bar-txt{position:absolute;left:8px;top:50%;transform:translateY(-50%);font-size:.72rem;font-weight:700;color:white;}
  .pd-disc-num{width:75px;font-size:.76px;color:var(--text2);flex-shrink:0;font-weight:600;}
  .pd-insight-box{border-radius:10px;padding:11px 14px;margin-bottom:9px;font-size:.83rem;}
  .pd-insight-warn{background:rgba(214,158,46,.1);border-right:4px solid var(--gold);color:#f6ad55;}
  .pd-insight-good{background:rgba(64,145,108,.1);border-right:4px solid var(--green);color:#68d391;}
  .pd-insight-info{background:rgba(49,130,206,.1);border-right:4px solid var(--blue);color:#63b3ed;}
  .pd-b-cash{background:rgba(104,211,145,.15);color:#68d391;}
  .pd-b-del{background:rgba(99,179,237,.15);color:#63b3ed;}
  .pd-b-oth{background:rgba(214,137,252,.15);color:#d6bcfa;}
  .pd-b-paid{background:rgba(104,211,145,.15);color:#68d391;}
  .pd-b-unpaid{background:rgba(252,129,129,.15);color:#fc8181;}
  .pd-pos{color:#68d391;font-weight:700;}.pd-neg{color:#fc8181;font-weight:700;}
  .at-hdr{background:linear-gradient(135deg,#0a1f13 0%,#22543d 50%,#276749 100%);color:white;border-radius:13px;padding:15px 19px;margin-bottom:16px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;box-shadow:0 4px 20px rgba(39,103,73,.35);}
  .at-hdr-title{font-size:1.05rem;font-weight:900;}
  .at-clock-box{background:rgba(255,255,255,.12);border-radius:11px;padding:10px 20px;text-align:center;border:1px solid rgba(255,255,255,.15);}
  .at-clock{font-size:1.7rem;font-weight:900;font-variant-numeric:tabular-nums;letter-spacing:3px;direction:ltr;}
  .at-clock-date{font-size:.74rem;opacity:.85;margin-top:3px;}
  .at-reg-card{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:20px 22px;box-shadow:var(--shadow-sm);margin-bottom:16px;border-right:3px solid var(--green);}
  .at-reg-title{font-weight:800;font-size:.95rem;color:#68d391;margin-bottom:14px;}
  .at-reg-row{display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end;}
  .at-rec-btn{background:var(--grad-main);color:white;border:none;border-radius:11px;padding:11px 28px;font-size:.95rem;font-weight:800;cursor:pointer;transition:all .2s;font-family:'Tajawal',sans-serif;white-space:nowrap;box-shadow:0 4px 15px var(--green-glow);}
  .at-rec-btn:hover{transform:translateY(-2px);box-shadow:0 6px 20px var(--green-glow);}
  .at-rec-btn:disabled{opacity:.5;cursor:default;transform:none;box-shadow:none;}
  .at-type-in{background:var(--grad-main);}
  .at-type-out{background:linear-gradient(135deg,#6b0a15,var(--red));}
  .at-kpi-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin-bottom:16px;}
  .at-kpi{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:16px 18px;box-shadow:var(--shadow-sm);border-right:3px solid var(--green);}
  .at-kpi-g{border-right-color:var(--green);}.at-kpi-b{border-right-color:var(--blue);}.at-kpi-r{border-right-color:var(--red);}.at-kpi-o{border-right-color:var(--gold);}.at-kpi-p{border-right-color:var(--purple);}
  .at-kl{font-size:.75rem;color:var(--text3);margin-bottom:5px;font-weight:600;}
  .at-kv{font-size:1.45rem;font-weight:900;color:var(--text);line-height:1.1;}
  .at-ku{font-size:.72rem;color:var(--text3);font-weight:400;}
  .at-sess-ok{background:rgba(104,211,145,.15);color:#68d391;padding:2px 9px;border-radius:12px;font-size:.74rem;font-weight:700;}
  .at-sess-err{background:rgba(252,129,129,.15);color:#fc8181;padding:2px 9px;border-radius:12px;font-size:.74rem;font-weight:700;}
  .at-emp-sec{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:20px 22px;box-shadow:var(--shadow-sm);margin-bottom:16px;}
  .at-emp-title{font-weight:800;font-size:.95rem;color:var(--text);margin-bottom:12px;}
  .at-emp-chip{display:inline-flex;align-items:center;gap:6px;background:rgba(64,145,108,.12);border:1.5px solid rgba(64,145,108,.3);border-radius:20px;padding:4px 12px;font-size:.82rem;font-weight:700;color:#68d391;margin:3px;}
  .at-chip-del{background:none;border:none;color:#fc8181;cursor:pointer;font-size:.85rem;padding:0 2px;line-height:1;font-weight:900;}
  .at-rate-row{display:flex;align-items:center;gap:8px;padding:7px 0;border-bottom:1px solid var(--border);font-size:.85rem;}
  .at-rate-name{flex:1;font-weight:600;color:var(--text);}
  .at-rate-inp{width:90px;padding:5px 9px;border:1.5px solid var(--border2);border-radius:8px;font-size:.84rem;font-family:'Tajawal',sans-serif;text-align:center;background:var(--bg3);color:var(--text);}
  .at-rate-save{padding:5px 12px;background:var(--green2);color:white;border:none;border-radius:7px;font-size:.79rem;cursor:pointer;font-weight:700;font-family:'Tajawal',sans-serif;}
  @media(max-width:580px){
    .type-grid{grid-template-columns:repeat(2,1fr);}
    .content{padding:12px 14px;}
    .hdr{padding:11px 14px;}
    .bal-amt{font-size:1.3rem;}
    .ph-name{font-size:1.1rem;}
    .t-bar{gap:12px;padding:8px 14px;}
    .tab{padding:11px 14px;font-size:.84rem;}
  }
</style>"""

# ── HTML body (identical to original, just minor label tweaks) ────────────────
body_html = original[339:47562]   # <body> ... <!-- JAVASCRIPT comment -->

# Patch small color refs that were hardcoded
body_html = body_html.replace("color:#a0aec0;", "color:var(--text3);")

# ── Assemble ─────────────────────────────────────────────────────────────────
head = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>صيدلية عصفرة — النسخة المطوّرة</title>
  <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet">
  <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore-compat.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>
"""

output = head + dark_css + "\n</head>\n" + body_html + "\n" + js_block + "\n" + modals

with open(dest, 'w', encoding='utf-8') as f:
    f.write(output)

print("SUCCESS")
print(f"Output: {len(output):,} chars = {len(output.encode('utf-8'))/1024:.1f} KB")
