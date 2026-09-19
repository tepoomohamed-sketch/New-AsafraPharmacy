import csv
import os
from datetime import datetime

# تحويل timestamp إلى تاريخ قابل للقراءة
def convert_timestamp(ts):
    if not ts or ts == '':
        return ''
    try:
        # تحويل milliseconds إلى seconds
        ts_float = float(ts) / 1000
        dt = datetime.fromtimestamp(ts_float)
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    except:
        return ts

# تحويل created_at من ISO إلى PostgreSQL format
def convert_created_at(created_at):
    if not created_at or created_at == '':
        return ''
    try:
        # إذا كان يحتوي على +00 بالفعل، أبقه
        if '+00' in created_at:
            return created_at
        # وإلا، أضف +00 في النهاية
        return created_at.strip() + '+00'
    except:
        return created_at

# معالجة ملف entries
print("📄 معالجة ملف entries...")
input_file = r'D:\new\asafra pharmacy\بيانات\entries_rows (2).csv'
output_file = r'D:\new\asafra pharmacy\بيانات\entries_import.csv'

with open(input_file, 'r', encoding='utf-8') as fin, \
     open(output_file, 'w', encoding='utf-8', newline='') as fout:
    
    reader = csv.DictReader(fin)
    fieldnames = reader.fieldnames
    writer = csv.DictWriter(fout, fieldnames=fieldnames)
    writer.writeheader()
    
    count = 0
    for row in reader:
        # تحويل created_at فقط (نصي)
        if 'created_at' in row:
            row['created_at'] = convert_created_at(row['created_at'])
        
        # ts يبقى كما هو (bigint) - لا نغيره!
        # pos_reviewed_at و deleted_at كذلك (bigint)
        
        writer.writerow(row)
        count += 1
    
    print(f"✅ تم معالجة {count} قيد → {output_file}")

# معالجة ملف attendance
print("\n📄 معالجة ملف attendance...")
input_file = r'D:\new\asafra pharmacy\بيانات\attendance_rows (1).csv'
output_file = r'D:\new\asafra pharmacy\بيانات\attendance_import.csv'

with open(input_file, 'r', encoding='utf-8') as fin, \
     open(output_file, 'w', encoding='utf-8', newline='') as fout:
    
    reader = csv.DictReader(fin)
    fieldnames = reader.fieldnames
    writer = csv.DictWriter(fout, fieldnames=fieldnames)
    writer.writeheader()
    
    count = 0
    for row in reader:
        # تحويل created_at
        if 'created_at' in row:
            row['created_at'] = convert_created_at(row['created_at'])
        
        writer.writerow(row)
        count += 1
    
    print(f"✅ تم معالجة {count} سجل حضور → {output_file}")

print("\n🎉 انتهى! استخدم الملفات الجديدة:")
print("   - entries_import.csv")
print("   - attendance_import.csv")
