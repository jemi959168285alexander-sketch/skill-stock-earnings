#!/usr/bin/env python3
"""
Generate Comprehensive Stock Analysis Report
一键生成股票综合分析报告
"""

import os
import sys
import json
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, Any, List, Tuple

try:
    import akshare as ak
except ImportError:
    print("Error: akshare not installed. Install with: pip install akshare")
    sys.exit(1)

# Output paths
OUTPUT_DIR = "/Users/peterzhang/Documents/stock-analysis/reports"
CHARTS_DIR = "/Users/peterzhang/Documents/stock-analysis/charts"

# Ensure directories exist
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(CHARTS_DIR, exist_ok=True)

# Test stocks: (code, name)
TEST_STOCKS = [
    ("300308", "Zhongji Innolight", "中际旭创"),
    ("300502", "Ecostar", "新易盛"),
]


def fetch_stock_basic_info(symbol: str) -> Optional[Dict[str, Any]]:
    """获取股票基本信息（代码、名称、行业、市值）"""
    try:
        # 获取A股信息
        df = ak.stock_individual_info_em(symbol=symbol)
        if df is None or df.empty:
            return None
            
        info = {}
        for _, row in df.iterrows():
            key = row.get('item', '')
            value = row.get('value', '')
            if key and value:
                info[key] = value
        
        # 确保包含必要字段
        result = {
            "code": symbol,
            "name": info.get("股票名称", ""),
            "industry": info.get("行业", ""),
            "market_cap": info.get("流通市值", "N/A"),
            "total_shares": info.get("总股本", ""),
        }
        
        return result
    except Exception as e:
        print(f"Error fetching basic info for {symbol}: {e}")
        return None


def fetch_financial_abstract(symbol: str) -> Optional[pd.DataFrame]:
    """获取财务摘要数据（22个指标）"""
    try:
        df = ak.stock_financial_abstract_new_ths(symbol=symbol)
        return df
    except Exception as e:
        print(f"Error fetching financial abstract for {symbol}: {e}")
        return None


def fetch_northbound_holdings(symbol: str, start_date: str = "20251201", end_date: str = "20260312") -> Optional[Dict[str, Any]]:
    """获取北向资金持股数据"""
    try:
        # 尝试多种API获取北向持股数据
        df = ak.stock_hsgt_stock_statistics_em(symbol=symbol, start_date=start_date, end_date=end_date)
        
        # 如果返回空数据，尝试其他API
        if df is None or df.empty:
            # 尝试使用stock_hsgt_hold_stock_em
            try:
                import requests
                url = f"https://emwapos3.10jqka.com.cn/api/stock cgi?code={symbol}&type= northbound"
                # This would require API key or different approach
                pass
            except:
                pass
        
        if df is None or df.empty:
            return None
            
        result = {
            "holdings_history": df.to_dict(orient="records") if len(df) > 0 else [],
            "latest": {},
        }
        
        # 获取最新数据
        if len(df) > 0:
            latest = df.iloc[-1]
            result["latest"] = {
                "date": str(latest.get("日期", "N/A")),
                "shares": latest.get("持股数量", 0),
                "ratio": latest.get("占流通股比例", "N/A"),
                "market_value": latest.get("市值", 0),
                "increase": latest.get("增减", "N/A"),
            }
        
        return result
    except Exception as e:
        print(f"Error fetching northbound holdings for {symbol}: {e}")
        return None


def fetch_fund_flow_summary() -> Optional[pd.DataFrame]:
    """获取北向资金流向摘要"""
    try:
        df = ak.stock_hsgt_fund_flow_summary_em()
        return df
    except Exception as e:
        print(f"Error fetching fund flow summary: {e}")
        return None


def fetch_valuation_metrics(symbol: str) -> Optional[Dict[str, Any]]:
    """获取估值指标（PE、PB、历史分位）"""
    try:
        result = {}
        
        # 获取市盈率 - 获取市场整体PE数据
        pe_df = ak.stock_market_pe_lg(symbol=symbol)
        if pe_df is not None and not pe_df.empty:
            # 获取最新的PE数据
            latest = pe_df.iloc[-1]
            result["pe_latest"] = {
                "date": latest.get("日期", "N/A"),
                "pe_ratio": latest.get("市盈率", "N/A"),
            }
            
        # 获取市净率 - 获取市场整体PB数据
        pb_df = ak.stock_market_pb_lg(symbol=symbol)
        if pb_df is not None and not pb_df.empty:
            latest = pb_df.iloc[-1]
            result["pb_latest"] = {
                "date": latest.get("日期", "N/A"),
                "pb_ratio": latest.get("市净率", "N/A"),
            }
        
        return result
    except Exception as e:
        print(f"Error fetching valuation metrics for {symbol}: {e}")
        return None


def fetch_stock_hist_data(symbol: str, days: int = 60) -> Optional[pd.DataFrame]:
    """获取股票历史价格数据"""
    try:
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y%m%d")
        df = ak.stock_zh_a_hist(
            symbol=symbol,
            period="daily",
            start_date=start_date,
            end_date=datetime.now().strftime("%Y%m%d"),
            adjust="qfq"
        )
        return df
    except Exception as e:
        print(f"Error fetching historical data for {symbol}: {e}")
        return None


def fetch_charts_info() -> List[Dict[str, str]]:
    """获取图表信息"""
    charts = []
    
    # K线图
    kline_path = os.path.join(CHARTS_DIR, "300308_kline.png")
    if os.path.exists(kline_path):
        charts.append({
            "name": "K-Line Chart",
            "path": kline_path,
            "description": "Daily K-line for Zhongji Innolight (300308)"
        })
    
    # 资金流向图
    flow_path = os.path.join(CHARTS_DIR, "300308_fund_flow.png")
    if os.path.exists(flow_path):
        charts.append({
            "name": "Fund Flow Chart",
            "path": flow_path,
            "description": "Fund inflow/outflow for Zhongji Innolight (300308)"
        })
    
    # 财务对比图
    fin_path = os.path.join(CHARTS_DIR, "financial_metrics_comparison.png")
    if os.path.exists(fin_path):
        charts.append({
            "name": "Financial Metrics Comparison",
            "path": fin_path,
            "description": "Financial comparison between Zhongji Innolight and Ecostar"
        })
    
    # 价格与北向资金对比图
    price_path = os.path.join(CHARTS_DIR, "price_northbound_comparison.png")
    if os.path.exists(price_path):
        charts.append({
            "name": "Price vs Northbound",
            "path": price_path,
            "description": "Price vs Northbound Capital comparison"
        })
    
    return charts


def generate_report_content(
    symbol: str,
    name_zh: str,
    name_en: str,
    basic_info: Dict[str, Any],
    financial_df: pd.DataFrame,
    northbound: Dict[str, Any],
    valuation: Dict[str, Any],
    charts: List[Dict[str, str]]
) -> str:
    """生成报告内容"""
    date_str = datetime.now().strftime("%Y-%m-%d")
    
    # 构建报告
    lines = []
    lines.append(f"# Stock Analysis Report - {name_en} ({symbol})")
    lines.append(f"Generated: {date_str}")
    lines.append("")
    
    # 1. 公司概述
    lines.append("## 1. Company Overview")
    lines.append("")
    lines.append(f"**Stock Code:** `{symbol}`")
    lines.append(f"**Chinese Name:** {name_zh}")
    lines.append(f"**English Name:** {name_en}")
    lines.append(f"**Industry:** {basic_info.get('industry', 'N/A')}")
    lines.append(f"**Market Cap:** {basic_info.get('market_cap', 'N/A')}")
    lines.append(f"**Total Shares:** {basic_info.get('total_shares', 'N/A')}")
    lines.append("")
    
    # 2. 财务指标
    lines.append("## 2. Financial Metrics")
    lines.append("")
    
    if financial_df is not None and not financial_df.empty:
        # 获取最新数据行
        latest_row = financial_df.iloc[-1] if len(financial_df) > 0 else financial_df
        
        # 提取22个关键指标
        financial_summary = {}
        for i, (col, value) in enumerate(zip(financial_df.columns, latest_row), 1):
            if i <= 22:
                financial_summary[f"Metric_{i:02d}"] = {
                    "name": col,
                    "value": value
                }
                lines.append(f"**{i:02d}. {col}:** {value}")
        
        lines.append("")
    else:
        lines.append("*Financial data not available*")
        lines.append("")
    
    # 3. 北向资金分析
    lines.append("## 3. Northbound Capital Analysis")
    lines.append("")
    
    if northbound and northbound.get("latest"):
        latest = northbound["latest"]
        lines.append(f"**Latest Date:** {latest.get('date', 'N/A')}")
        lines.append(f"**Holdings:** {latest.get('shares', 'N/A')}")
        lines.append(f"**Holding Ratio:** {latest.get('ratio', 'N/A')}")
        lines.append(f"**Market Value:** {latest.get('market_value', 'N/A')}")
        lines.append(f"**Change vs Last Period:** {latest.get('increase', 'N/A')}")
        lines.append("")
        
        # 如果有历史数据，显示最近3条
        if northbound.get("holdings_history") and len(northbound["holdings_history"]) > 0:
            lines.append("### Recent Holdings History (Last 3 Records)")
            lines.append("")
            for record in northbound["holdings_history"][-3:]:
                lines.append(f"- {record.get('持股日期', 'N/A')}: "
                           f"持股 {record.get('持股数量', 'N/A')}, "
                           f"比例 {record.get('持股比例', 'N/A')}")
            lines.append("")
    else:
        lines.append("*Northbound capital data not available*")
        lines.append("")
    
    # 4. 图表
    lines.append("## 4. Charts")
    lines.append("")
    
    if charts:
        for i, chart in enumerate(charts, 1):
            filename = os.path.basename(chart["path"])
            lines.append(f"![{chart['name']}]({chart['path']})")
            lines.append(f"**Figure {i}:** {chart['description']}")
            lines.append("")
    else:
        lines.append("*No charts available*")
        lines.append("")
    
    # 5. 估值分析
    lines.append("## 5. Valuation")
    lines.append("")
    
    if valuation:
        # PE Ratio
        if valuation.get("pe_latest"):
            pe_data = valuation["pe_latest"]
            lines.append(f"**Latest PE Ratio:** {pe_data.get('pe_ratio', 'N/A')}")
            lines.append(f"**Pe Date:** {pe_data.get('date', 'N/A')}")
        
        # PB Ratio
        if valuation.get("pb_latest"):
            pb_data = valuation["pb_latest"]
            lines.append(f"**Latest PB Ratio:** {pb_data.get('pb_ratio', 'N/A')}")
            lines.append(f"**PB Date:** {pb_data.get('date', 'N/A')}")
        
        # PE Percentile
        if valuation.get("pe_percentile"):
            lines.append(f"**PE Historical Percentile:** {valuation['pe_percentile']}")
        
        lines.append("")
    else:
        lines.append("*Valuation data not available*")
        lines.append("")
    
    # 6. 风险提示
    lines.append("## 6. Risk Factors")
    lines.append("")
    lines.append("1. **Market Risk:** Stock prices may fluctuate due to market volatility")
    lines.append("2. **Industry Risk:**Changes in industry policies may affect company performance")
    lines.append("3. **Financial Risk:**Decrease in profitability may impact stock valuation")
    lines.append("4. **Liquidity Risk:**Low trading volume may affect stock convertibility")
    lines.append("5. **Northbound Capital Risk:**Changes in northbound capital flow may cause price volatility")
    lines.append("")
    
    return "\n".join(lines)


def save_report(content: str, symbol: str, name_en: str) -> str:
    """保存报告到文件"""
    date_str = datetime.now().strftime("%Y%m%d")
    filename = f"{symbol}_{name_en.replace(' ', '_').lower()}_{date_str}.md"
    filepath = os.path.join(OUTPUT_DIR, filename)
    
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    
    return filepath


def main():
    """主函数"""
    print("=" * 70)
    print("Generate Comprehensive Stock Analysis Report")
    print("=" * 70)
    
    results = []
    
    # 生成图表（如果不存在）
    print("\n[Step 0] Checking/generated charts...")
    charts = fetch_charts_info()
    print(f"  Found {len(charts)} chart files")
    
    # 处理每只股票
    for symbol, name_en, name_zh in TEST_STOCKS:
        print(f"\n[Step 1] Processing {symbol} ({name_zh})...")
        
        # 1. 获取基本信息
        print("  - Fetching basic info...")
        basic_info = fetch_stock_basic_info(symbol)
        if basic_info:
            print(f"    ✓ Name: {basic_info.get('name', 'N/A')}")
            print(f"    ✓ Industry: {basic_info.get('industry', 'N/A')}")
        
        # 2. 获取财务数据
        print("  - Fetching financial data...")
        financial_df = fetch_financial_abstract(symbol)
        if financial_df is not None and not financial_df.empty:
            print(f"    ✓ Columns: {len(financial_df.columns)}")
        
        # 3. 获取北向资金
        print("  - Fetching northbound capital data...")
        northbound = fetch_northbound_holdings(symbol)
        if northbound and northbound.get("latest"):
            print(f"    ✓ Latest holdings: {northbound['latest'].get('shares', 'N/A')}")
        
        # 4. 获取估值指标
        print("  - Fetching valuation metrics...")
        valuation = fetch_valuation_metrics(symbol)
        if valuation:
            print(f"    ✓ PE: {valuation.get('pe_latest', {}).get('pe_ratio', 'N/A')}")
        
        # 5. 生成报告内容
        print("  - Generating report content...")
        content = generate_report_content(
            symbol=symbol,
            name_zh=name_zh,
            name_en=name_en,
            basic_info=basic_info or {},
            financial_df=financial_df,
            northbound=northbound,
            valuation=valuation,
            charts=charts
        )
        
        # 6. 保存报告
        print("  - Saving report...")
        filepath = save_report(content, symbol, name_en)
        print(f"    ✓ Saved to: {filepath}")
        
        results.append({
            "symbol": symbol,
            "name_zh": name_zh,
            "name_en": name_en,
            "filepath": filepath,
            "basic_info": basic_info,
            "financial_columns": len(financial_df.columns) if financial_df is not None else 0,
            "northbound_latest": northbound.get("latest", {}) if northbound else {},
        })
    
    # 打印摘要
    print("\n" + "=" * 70)
    print("REPORT GENERATION SUMMARY")
    print("=" * 70)
    
    for r in results:
        print(f"\n{r['symbol']} - {r['name_zh']} ({r['name_en']})")
        print("-" * 60)
        print(f"  Report Path: {r['filepath']}")
        print(f"  Financial Metrics: {r['financial_columns']} columns")
        if r['northbound_latest']:
            print(f"  Northbound Latest: {r['northbound_latest'].get('shares', 'N/A')} shares")
    
    print("\n" + "=" * 70)
    print(f"All reports saved to: {OUTPUT_DIR}")
    print("=" * 70)
    
    # 打印第一份报告的预览
    if results:
        print("\n" + "=" * 70)
        print("REPORT PREVIEW (First 50 lines)")
        print("=" * 70)
        with open(results[0]["filepath"], "r", encoding="utf-8") as f:
            lines = f.readlines()[:50]
            print("".join(lines))
    
    return results


if __name__ == "__main__":
    main()
