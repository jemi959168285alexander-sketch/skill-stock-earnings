#!/usr/bin/env python3
"""
fetch_data_akshare.py - 使用 akshare 库获取股票数据

支持：
- A 股历史数据 (stock_zh_a_hist)
- 美股数据 (stock_us_daily)
- 港股数据 (stock_hk_daily)
- 财报数据 (相关接口)

用法:
    python fetch_data_akshare.py <股票代码> [--market A|US|HK] [--start-date YYYYMMDD] [--end-date YYYYMMDD] [--output-format json|csv]
    python fetch_data_akshare.py <股票代码> --earnings [--years N] [--output-dir <目录>]

示例:
    python fetch_data_akshare.py 000001 --market A --start-date 20230101 --end-date 20231231 --output-format csv
    python fetch_data_akshare.py AAPL --market US --start-date 20230101 --end-date 20231231 --output-format json
    python fetch_data_akshare.py 0700 --market HK --output-format json
    python fetch_data_akshare.py 600519 --earnings --years 3 --output-dir ./earnings
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

import akshare as ak
import pandas as pd


def fetch_a_stock_hist(symbol, start_date="", end_date=""):
    """获取 A 股历史数据"""
    try:
        df = ak.stock_zh_a_hist(
            symbol=symbol,
            period="daily",
            start_date=start_date,
            end_date=end_date,
            adjust=""
        )
        return df
    except Exception as e:
        print(f"获取 A 股历史数据失败: {e}")
        return None


def fetch_us_stock_daily(symbol):
    """获取美股日线数据"""
    try:
        df = ak.stock_us_daily(symbol=symbol)
        return df
    except Exception as e:
        print(f"获取美股数据失败: {e}")
        return None


def fetch_hk_stock_daily(symbol):
    """获取港股日线数据"""
    try:
        df = ak.stock_hk_daily(symbol=symbol)
        return df
    except Exception as e:
        print(f"获取港股数据失败: {e}")
        return None


def fetch_a_stock_fundamentals(symbol):
    """获取 A 股基本面数据"""
    try:
        # 财务指标
        balance_sheet_df = ak.stock_financial_report_sina(stock=symbol, symbol="资产负债表")
        
        # 利润表
        income_statement_df = ak.stock_financial_report_sina(stock=symbol, symbol="利润表")
        
        # 现金流量表
        cash_flow_df = ak.stock_financial_report_sina(stock=symbol, symbol="现金流量表")
        
        return {
            "balance_sheet": balance_sheet_df.to_dict(orient="records") if balance_sheet_df is not None else None,
            "income_statement": income_statement_df.to_dict(orient="records") if income_statement_df is not None else None,
            "cash_flow": cash_flow_df.to_dict(orient="records") if cash_flow_df is not None else None
        }
    except Exception as e:
        print(f"获取 A 股基本面数据失败: {e}")
        return None


def fetch_stock_info(symbol, market):
    """获取股票基本信息"""
    try:
        if market == "A":
            # A 股基本信息
            info_df = ak.stock_profile_cn(symbol=symbol)
            return info_df.to_dict(orient="records") if info_df is not None else None
        elif market == "US":
            # 美股基本信息
            info_df = ak.stock_us_individual(symbol=symbol)
            return info_df.to_dict(orient="records") if info_df is not None else None
        elif market == "HK":
            # 港股基本信息
            info_df = ak.stock_hk_individual(symbol=symbol)
            return info_df.to_dict(orient="records") if info_df is not None else None
        return None
    except Exception as e:
        print(f"获取股票信息失败: {e}")
        return None


def save_data(df, output_format, output_path):
    """保存数据到文件"""
    try:
        if output_format == "json":
            df.to_json(output_path, orient="records", force_ascii=False, indent=2)
        elif output_format == "csv":
            df.to_csv(output_path, index=False, encoding="utf-8-sig")
        elif output_format == "parquet":
            df.to_parquet(output_path, index=False)
        print(f"数据已保存到: {output_path}")
        return True
    except Exception as e:
        print(f"保存数据失败: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="使用 akshare 获取股票数据",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
    %(prog)s 000001 --market A --start-date 20230101 --end-date 20231231 --output-format csv
    %(prog)s AAPL --market US --start-date 20230101 --end-date 20231231 --output-format json
    %(prog)s 0700 --market HK --output-format json
    %(prog)s 600519 --earnings --years 3 --output-dir ./earnings
        """
    )
    
    parser.add_argument("symbol", help="股票代码")
    parser.add_argument("--market", choices=["A", "US", "HK"], default="A",
                        help="市场类型 (A=A股, US=美股, HK=港股, 默认=A)")
    parser.add_argument("--start-date", help="开始日期 (格式: YYYYMMDD)")
    parser.add_argument("--end-date", help="结束日期 (格式: YYYYMMDD)")
    parser.add_argument("--output-format", choices=["json", "csv", "parquet"],
                        default="json", help="输出格式 (默认=json)")
    parser.add_argument("--output-dir", default="./output",
                        help="输出目录 (默认=./output)")
    parser.add_argument("--earnings", action="store_true",
                        help="获取财报数据 (仅支持 A 股)")
    parser.add_argument("--years", type=int, default=3,
                        help="获取最近 N 年财报 (默认=3)")
    parser.add_argument("--info", action="store_true",
                        help="仅获取股票基本信息")
    parser.add_argument("--hist", action="store_true",
                        help="仅获取历史数据")
    
    args = parser.parse_args()
    
    # 创建输出目录
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 清理股票代码（移除空格）
    symbol = args.symbol.strip()
    
    # 获取股票基本信息
    if args.info:
        info = fetch_stock_info(symbol, args.market)
        if info:
            output_path = output_dir / f"{symbol}_{args.market}_info.json"
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(info, f, indent=2, ensure_ascii=False)
            print(f"股票信息已保存到: {output_path}")
        return 0
    
    # 获取财报数据
    if args.earnings:
        if args.market != "A":
            print("警告: 财报数据功能目前仅支持 A 股")
            return 1
        
        print(f"正在获取 A 股财报数据: {symbol}")
        fundamentals = fetch_a_stock_fundamentals(symbol)
        
        if fundamentals:
            # 保存到 JSON
            output_path = output_dir / f"{symbol}_fundamentals.json"
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(fundamentals, f, indent=2, ensure_ascii=False)
            print(f"财报数据已保存到: {output_path}")
            
            # 同时保存为 CSV 格式
            for key, data in fundamentals.items():
                if data:
                    csv_path = output_dir / f"{symbol}_{key}.csv"
                    pd.DataFrame(data).to_csv(csv_path, index=False, encoding="utf-8-sig")
                    print(f"  [{key}] 已保存到: {csv_path}")
            
            return 0
        else:
            print("获取财报数据失败")
            return 1
    
    # 获取历史数据
    print(f"正在获取 {args.market} 股历史数据: {symbol}")
    
    if args.market == "A":
        df = fetch_a_stock_hist(symbol, args.start_date, args.end_date)
    elif args.market == "US":
        df = fetch_us_stock_daily(symbol)
    elif args.market == "HK":
        df = fetch_hk_stock_daily(symbol)
    else:
        print(f"不支持的市场类型: {args.market}")
        return 1
    
    if df is not None and not df.empty:
        # 获取当前日期作为文件名的一部分
        current_date = datetime.now().strftime("%Y%m%d")
        output_path = output_dir / f"{symbol}_{args.market}_history_{current_date}.{args.output_format}"
        
        success = save_data(df, args.output_format, output_path)
        
        # 输出数据摘要
        print(f"数据摘要:")
        print(f"  - 股票代码: {symbol}")
        print(f"  - 市场: {args.market}")
        print(f"  - 记录数: {len(df)}")
        if not df.empty:
            print(f"  - 日期范围: {df.iloc[0]['日期']} 至 {df.iloc[-1]['日期']}")
        
        return 0 if success else 1
    else:
        print("获取数据失败")
        return 1


if __name__ == "__main__":
    sys.exit(main())
