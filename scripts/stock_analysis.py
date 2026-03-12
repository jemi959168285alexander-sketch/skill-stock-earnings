#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
股票财务分析脚本
获取中际旭创 (300308) 的财务数据
"""

import akshare as ak
import pandas as pd
from datetime import datetime


def fetch_stock_financial_data(symbol="300308"):
    """
    获取股票财务摘要数据
    
    Args:
        symbol: 股票代码
        
    Returns:
        df: DataFrame格式的财务数据
    """
    try:
        # 获取财务摘要数据
        df = ak.stock_financial_abstract_new_ths(symbol=symbol)
        return df
    except Exception as e:
        print(f"获取财务数据时出错: {e}")
        return None


def save_to_csv(df, symbol="300308", output_dir="/Users/peterzhang/Documents/stock-analysis/financial-data/"):
    """
    保存数据到CSV文件
    
    Args:
        df: DataFrame数据
        symbol: 股票代码
        output_dir: 输出目录
        
    Returns:
        str: 文件路径
    """
    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{symbol}_financial_{timestamp}.csv"
        filepath = f"{output_dir}{filename}"
        
        df.to_csv(filepath, index=False, encoding='utf-8-sig')
        return filepath
    except Exception as e:
        print(f"保存文件时出错: {e}")
        return None


def get_summary_stats(df):
    """
    获取关键财务指标摘要
    
    Args:
        df: DataFrame数据
        
    Returns:
        dict: 关键指标字典
    """
    if df is None or df.empty:
        return {}
    
    summary = {}
    
    # 获取列名
    columns = df.columns.tolist()
    summary['total_columns'] = len(columns)
    summary['columns'] = columns[:10]  # 前10个列名
    
    # 获取数据行数
    summary['total_rows'] = len(df)
    
    return summary


def main():
    """主函数"""
    print("=" * 60)
    print("中际旭创 (300308) 财务数据分析")
    print("=" * 60)
    
    # 设置参数
    symbol = "300308"
    output_dir = "/Users/peterzhang/Documents/stock-analysis/financial-data/"
    
    # 确保输出目录存在
    import os
    os.makedirs(output_dir, exist_ok=True)
    
    # Step 1: 获取财务数据
    print("\n[步骤 1] 正在获取财务数据...")
    df = fetch_stock_financial_data(symbol=symbol)
    
    if df is None:
        print("获取数据失败！")
        return
    
    print(f"✓ 成功获取 {len(df)} 行数据")
    
    # Step 2: 显示数据概览
    print("\n[步骤 2] 数据概览:")
    print(f"  - 股票代码: {symbol}")
    print(f"  - 数据行数: {len(df)}")
    print(f"  - 数据列数: {len(df.columns)}")
    
    # Step 3: 保存到CSV
    print(f"\n[步骤 3] 正在保存到 {output_dir}...")
    filepath = save_to_csv(df, symbol=symbol, output_dir=output_dir)
    
    if filepath:
        print(f"✓ 文件已保存: {filepath}")
    else:
        print("保存文件失败！")
        return
    
    # Step 4: 显示关键数据预览
    print("\n[步骤 4] 关键数据预览:")
    print("-" * 60)
    
    # 显示列名
    print(f"\n所有财务指标 ({len(df.columns)} 个):")
    for i, col in enumerate(df.columns, 1):
        print(f"  {i:2d}. {col}")
    
    # 显示数据前几行
    print("\n数据前5行预览:")
    print(df.head())
    
    # Step 5: 完成
    print("\n" + "=" * 60)
    print("分析完成！")
    print("=" * 60)
    print(f"\n最终输出文件: {filepath}")
    print(f"财务指标总数: {len(df.columns)}")
    
    return filepath, df


if __name__ == "__main__":
    result = main()
