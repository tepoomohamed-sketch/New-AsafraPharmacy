"""
تحليل البيانات المالية - صيدلية عصفرة
Pharmacy Financial Analysis — Plotly Interactive Charts
=======================================================
الاستخدام:
  1. صدّر ملف Google Sheets بصيغة CSV (ملف > تنزيل > CSV)
  2. ضع الملف في نفس المجلد وسمّه  pharmacy_data.csv
  3. شغّل:  python pharmacy_analysis.py
"""

import sys, os
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots

# ──────────────────────────────────────────────────────────────
#  قراءة البيانات
# ──────────────────────────────────────────────────────────────
CSV_FILE = "pharmacy_data.csv"

HARDCODED_DATA = {
    "monthly": {
        "month":    ["مارس", "أبريل", "مايو (جزئي)"],
        "revenue":  [257850,  284859,  141245],
        "orders":   [204909,  218870,   90595],
        "expenses": [ 41365,   38720,    8975],
    },
    "daily_march": {
        "day":     list(range(1, 32)),
        "revenue": [9400,9670,5230,2440,11195,7570,9170,8725,13220,10660,
                    7825,8480,7440,8950,9215,6220,9220,5820,4685,6795,
                    5460,5690,6930,7230,9345,11530,13465,8715,5900,13320,8355],
        "paid":    [9620,6125,3465,2835,12870,8335,9710,5045,5585,24280,
                    7250,8940,4885,7655,4790,9495,6980,7380,8840,1900,
                    20,5260,20915,5150,9490,5560,4575,8760,7205,12410,10159],
    },
    "expenses_breakdown": {
        "category": ["رواتب","ايجار الصيدلية","د.محمد سحب","كهرباء",
                     "صيانة كمبيوتر/سيستم","صيانة عجلة","إنترنت",
                     "تليفون","مستلزمات نظافة","أخرى"],
        "amount":   [56295, 19500, 23930, 2670, 3520, 2880, 1230, 630, 260, 4145],
    },
    "suppliers": {
        "name":   ["فارما جروب","ميراميديكال","اللوتس","فارما اوفر سيز",
                   "كريم فارما","الابرار","ماستر كوزمو","كيو فارما","تاج","تارجت"],
        "amount": [9880, 3000, 950, 28110, 675, 950, 1515, 2225, 805, 1240],
    },
}


def load_csv_data(path):
    """تحميل CSV إذا وُجد، وإلا استخدام البيانات المضمّنة."""
    if not os.path.exists(path):
        print(f"⚠  لم يُعثر على {path} — يتم استخدام البيانات النموذجية.")
        return None
    try:
        df = pd.read_csv(path, encoding="utf-8-sig")
        # تنظيف الأعمدة الأساسية
        df.columns = [c.strip() for c in df.columns]
        df["التاريخ"]       = pd.to_datetime(df["التاريخ"], dayfirst=True, errors="coerce")
        df["المبلغ المدفوع"]  = pd.to_numeric(df["المبلغ المدفوع"], errors="coerce").fillna(0)
        df["الباقي من العهدة"] = pd.to_numeric(df["الباقي من العهدة"], errors="coerce").fillna(0)
        df["الاضافي"]        = pd.to_numeric(df["الاضافي"], errors="coerce").fillna(0)
        df = df.dropna(subset=["التاريخ"])
        print(f"✅  تم تحميل {len(df)} سطر من {path}")
        return df
    except Exception as e:
        print(f"⚠  خطأ في تحميل CSV: {e} — يتم استخدام البيانات النموذجية.")
        return None


def build_charts(df=None):
    data = HARDCODED_DATA

    # إذا أُتيح CSV — استخراج البيانات الحقيقية
    if df is not None:
        df["الشهر"] = df["التاريخ"].dt.strftime("%Y-%m")
        grp = df.groupby(["الشهر", "نوع البند"])["المبلغ المدفوع"].sum().unstack(fill_value=0)
        grp_add = df.groupby(["الشهر", "نوع البند"])["الاضافي"].sum().unstack(fill_value=0)
        # ...يمكن توسيع هذا القسم حسب هيكل الـ CSV الفعلي

    # ── 1. مقارنة شهرية ────────────────────────────────────────────────────
    fig1 = go.Figure()
    months = data["monthly"]["month"]
    fig1.add_trace(go.Bar(name="الإيرادات",  x=months, y=data["monthly"]["revenue"],
                          marker_color="#22c55e", text=[f"{v:,}" for v in data["monthly"]["revenue"]],
                          textposition="outside"))
    fig1.add_trace(go.Bar(name="الطلبيات",  x=months, y=data["monthly"]["orders"],
                          marker_color="#f59e0b", text=[f"{v:,}" for v in data["monthly"]["orders"]],
                          textposition="outside"))
    fig1.add_trace(go.Bar(name="المصاريف",  x=months, y=data["monthly"]["expenses"],
                          marker_color="#ef4444", text=[f"{v:,}" for v in data["monthly"]["expenses"]],
                          textposition="outside"))
    fig1.update_layout(
        title="📊 مقارنة شهرية: الإيرادات / الطلبيات / المصاريف",
        barmode="group", template="plotly_dark",
        font=dict(family="Arial", size=13), yaxis_title="جنيه مصري",
        legend=dict(orientation="h", y=1.1)
    )
    fig1.write_html("chart1_monthly.html")
    print("✅  chart1_monthly.html")

    # ── 2. اتجاه يومي مارس ─────────────────────────────────────────────────
    days = [f"{d} مارس" for d in data["daily_march"]["day"]]
    fig2 = go.Figure()
    fig2.add_trace(go.Scatter(
        x=days, y=data["daily_march"]["revenue"], name="إيرادات يومية",
        mode="lines+markers", line=dict(color="#22c55e", width=2),
        fill="tozeroy", fillcolor="rgba(34,197,94,0.1)"))
    fig2.add_trace(go.Scatter(
        x=days, y=data["daily_march"]["paid"], name="مدفوعات يومية",
        mode="lines+markers", line=dict(color="#ef4444", width=2, dash="dot"),
        fill="tozeroy", fillcolor="rgba(239,68,68,0.07)"))
    fig2.update_layout(
        title="📅 التوزيع اليومي — مارس 2026",
        template="plotly_dark", font=dict(family="Arial", size=12),
        yaxis_title="جنيه مصري", legend=dict(orientation="h", y=1.1)
    )
    fig2.write_html("chart2_daily_march.html")
    print("✅  chart2_daily_march.html")

    # ── 3. توزيع المصاريف (Pie) ─────────────────────────────────────────────
    exp = data["expenses_breakdown"]
    fig3 = px.pie(
        names=exp["category"], values=exp["amount"],
        title="🔴 توزيع المصاريف التشغيلية",
        color_discrete_sequence=px.colors.sequential.Plasma_r,
        hole=0.45
    )
    fig3.update_layout(template="plotly_dark", font=dict(family="Arial", size=12))
    fig3.update_traces(textinfo="percent+label")
    fig3.write_html("chart3_expenses_pie.html")
    print("✅  chart3_expenses_pie.html")

    # ── 4. أكبر الموردين ────────────────────────────────────────────────────
    sup = pd.DataFrame(data["suppliers"]).sort_values("amount", ascending=True)
    fig4 = go.Figure(go.Bar(
        x=sup["amount"], y=sup["name"], orientation="h",
        marker=dict(color=sup["amount"], colorscale="Oranges"),
        text=[f"{v:,} ج" for v in sup["amount"]], textposition="outside"
    ))
    fig4.update_layout(
        title="📦 أكبر الموردين إنفاقاً (الإجمالي)",
        template="plotly_dark", font=dict(family="Arial", size=12),
        xaxis_title="المبلغ (جنيه)", height=420
    )
    fig4.write_html("chart4_suppliers.html")
    print("✅  chart4_suppliers.html")

    # ── 5. داشبورد مدمج (subplots) ──────────────────────────────────────────
    fig5 = make_subplots(
        rows=2, cols=2,
        subplot_titles=("المقارنة الشهرية", "التوزيع اليومي (مارس)",
                        "توزيع المصاريف", "أكبر الموردين"),
        specs=[[{"type":"bar"}, {"type":"scatter"}],
               [{"type":"pie"}, {"type":"bar"}]]
    )
    # panel 1
    for trace in fig1.data:
        fig5.add_trace(trace, row=1, col=1)
    # panel 2
    for trace in fig2.data:
        t = go.Scatter(x=trace.x, y=trace.y, name=trace.name,
                       mode="lines", line=dict(color=trace.line.color, width=1.5),
                       showlegend=False)
        fig5.add_trace(t, row=1, col=2)
    # panel 3
    fig5.add_trace(
        go.Pie(labels=exp["category"], values=exp["amount"],
               hole=0.4, showlegend=False, textinfo="percent"),
        row=2, col=1)
    # panel 4
    fig5.add_trace(
        go.Bar(x=sup["amount"], y=sup["name"], orientation="h",
               marker_color="#f59e0b", showlegend=False),
        row=2, col=2)
    fig5.update_layout(
        title_text="🏥 داشبورد مالي شامل — صيدلية عصفرة 2026",
        template="plotly_dark", height=800,
        font=dict(family="Arial", size=11)
    )
    fig5.write_html("chart5_dashboard_combined.html")
    print("✅  chart5_dashboard_combined.html")

    print("\n🎉 تم إنشاء جميع الملفات! افتحها مباشرةً في المتصفح.")


# ──────────────────────────────────────────────────────────────
#  تشغيل
# ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    csv_path = sys.argv[1] if len(sys.argv) > 1 else CSV_FILE
    df = load_csv_data(csv_path)
    build_charts(df)
