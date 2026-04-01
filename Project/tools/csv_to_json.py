"""
CSV 转 JSON 转换工具
用法: python csv_to_json.py
将 assets/cardInfo.csv 转换为 assets/cardData.json
"""

import csv
import json
import os

# 配置路径 - 基于项目根目录
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(PROJECT_ROOT, "assets", "cardInfo.csv")
JSON_PATH = os.path.join(PROJECT_ROOT, "assets", "cardData.json")

# 字段类型映射 (CSV列名 -> JSON字段名)
FIELD_MAP = {
    "base_cardName": "id",
    "index": "index",
    "base_displayName": "displayName",
    "base_cardClass": "cardClass",
    "base_desc": "desc",
    "base_price": "price",
    "base_card": "card",
    "base_max": "max",
    "site_area": "siteArea",
    "npc_sched": "npcSched",
    "food_HP": "foodHP",
    "eventId": "eventId"
}

# 需要转换为整数的字段
INT_FIELDS = {"index", "price", "card", "max", "siteArea", "npcSched", "foodHP", "eventId"}


def convert_csv_to_json():
    if not os.path.exists(CSV_PATH):
        print(f"错误: CSV文件不存在 - {CSV_PATH}")
        return False
    
    items = {}
    
    # 尝试多种编码
    for encoding in ['utf-8', 'gbk', 'gb2312', 'latin1']:
        try:
            with open(CSV_PATH, 'r', encoding=encoding) as f:
                reader = csv.DictReader(f)
                rows = list(reader)
            print(f"使用编码: {encoding}")
            break
        except UnicodeDecodeError:
            continue
    else:
        print("错误: 无法识别 CSV 文件编码")
        return False
    
    for row in rows:
        # 跳过空行
        if not row.get('base_cardName'):
            continue
        
        item = {}
        for csv_field, json_field in FIELD_MAP.items():
            value = row.get(csv_field, "")
            
            # 整数转换
            if json_field in INT_FIELDS:
                try:
                    value = int(value) if value else 0
                except ValueError:
                    value = 0
            
            item[json_field] = value
        
        item_id = item.pop('id')
        items[item_id] = item
    
    # 构建输出数据
    output = {
        "_metadata": {
            "version": "1.0",
            "description": "卡牌游戏配置数据 (由CSV转换)",
            "source": "cardInfo.csv",
            "generated": __import__('datetime').datetime.now().isoformat()
        },
        "items": items
    }
    
    # 写入JSON文件
    with open(JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"转换完成! 共 {len(items)} 条记录")
    print(f"输出文件: {JSON_PATH}")
    return True


if __name__ == "__main__":
    convert_csv_to_json()
