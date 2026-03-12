#!/usr/bin/env python3
"""
Stock Chart Generator Script
Generates various stock analysis charts with English captions to avoid Chinese character encoding issues.
"""

import os
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import mplfinance as mpf
from datetime import datetime, timedelta

# Output directory
OUTPUT_DIR = "/Users/peterzhang/Documents/stock-analysis/charts"

# Ensure output directory exists
os.makedirs(OUTPUT_DIR, exist_ok=True)


def generate_kline_chart(symbol="300308", symbol_name="Zhongji Innolight"):
    """
    Generate K-line (Candlestick) chart for a stock
    
    Args:
        symbol: Stock code (e.g., '300308')
        symbol_name: Full name of the stock (in English)
    """
    # Generate sample data for demonstration
    dates = pd.date_range(start='2025-12-01', end='2025-12-31', freq='D')
    np.random.seed(42)
    
    open_prices = 50 + np.cumsum(np.random.randn(len(dates)))
    close_prices = open_prices + np.random.randn(len(dates)) * 5
    high_prices = np.maximum(open_prices, close_prices) + np.abs(np.random.randn(len(dates)) * 3)
    low_prices = np.minimum(open_prices, close_prices) - np.abs(np.random.randn(len(dates)) * 3)
    volume = np.random.randint(100, 500, len(dates)) * 10000  # Add volume column
    
    data = pd.DataFrame({
        'Open': open_prices,
        'High': high_prices,
        'Low': low_prices,
        'Close': close_prices,
        'Volume': volume
    }, index=dates)
    data.index.name = 'Date'
    
    # Generate K-line chart
    output_path = os.path.join(OUTPUT_DIR, f'{symbol}_kline.png')
    fig, axes = mpf.plot(
        data,
        type='candle',
        style='charles',
        title=f'{symbol_name} ({symbol}) - Daily K-Line Chart',
        ylabel='Price (CNY)',
        volume=True,
        returnfig=True,
        savefig=dict(fname=output_path, dpi=150, bbox_inches='tight')
    )
    plt.close(fig)
    plt.close(fig)
    
    return output_path


def generate_price_northbound_chart(symbol1="300308", symbol2="300502", symbol1_name="Zhongji Innolight", symbol2_name="Ecostar"):
    """
    Generate Price vs Northbound Capital chart
    
    Args:
        symbol1, symbol2: Stock codes
        symbol1_name, symbol2_name: Stock names in English
    """
    # Generate sample data
    dates = pd.date_range(start='2025-11-01', end='2025-12-10', freq='D')
    np.random.seed(42)
    
    # Price data
    price1 = 50 + np.cumsum(np.random.randn(len(dates)) * 2)
    price2 = 30 + np.cumsum(np.random.randn(len(dates)) * 1.5)
    
    # Northbound capital data (in billion CNY)
    northbound1 = 2 + np.cumsum(np.random.randn(len(dates)) * 0.3)
    northbound2 = 1 + np.cumsum(np.random.randn(len(dates)) * 0.2)
    
    # Create figure with two y-axes
    fig, ax1 = plt.subplots(figsize=(14, 8))
    
    color1 = 'tab:red'
    ax1.set_xlabel('Date')
    ax1.set_ylabel('Price (CNY)', color=color1)
    ax1.plot(dates, price1, color=color1, label=f'{symbol1_name} ({symbol1}) Price', linewidth=2)
    ax1.plot(dates, price2, color='tab:orange', label=f'{symbol2_name} ({symbol2}) Price', linewidth=2)
    ax1.tick_params(axis='y', labelcolor=color1)
    
    ax2 = ax1.twinx()
    color2 = 'tab:blue'
    ax2.set_ylabel('Northbound Capital (Billion CNY)', color=color2)
    ax2.plot(dates, northbound1, color=color2, linestyle='--', label=f'{symbol1_name} Northbound')
    ax2.plot(dates, northbound2, color='tab:cyan', linestyle='--', label=f'{symbol2_name} Northbound')
    ax2.tick_params(axis='y', labelcolor=color2)
    
    # Combine legends
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, loc='upper left')
    
    plt.title(f'Price vs Northbound Capital: {symbol1_name} vs {symbol2_name}')
    fig.tight_layout()
    
    output_path = os.path.join(OUTPUT_DIR, 'price_northbound_comparison.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    
    return output_path


def generate_financial_metrics_comparison(symbols=["300308", "300502"], symbol_names=["Zhongji Innolight", "Ecostar"]):
    """
    Generate Financial Metrics Comparison chart
    
    Args:
        symbols: List of stock codes
        symbol_names: List of stock names in English
    """
    # Sample financial metrics data
    metrics = ['Revenue (B CNY)', 'Net Profit (B CNY)', 'ROE (%)', 'PE Ratio', 'PB Ratio']
    stock1_data = [12.5, 3.2, 15.8, 35.2, 4.8]
    stock2_data = [8.3, 2.1, 12.5, 28.6, 3.9]
    
    x = np.arange(len(metrics))
    width = 0.35
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    bars1 = ax.bar(x - width/2, stock1_data, width, label=f'{symbol_names[0]} ({symbols[0]})', color='tab:blue')
    bars2 = ax.bar(x + width/2, stock2_data, width, label=f'{symbol_names[1]} ({symbols[1]})', color='tab:orange')
    
    ax.set_ylabel('Values')
    ax.set_title(f'Financial Metrics Comparison: {symbol_names[0]} vs {symbol_names[1]}')
    ax.set_xticks(x)
    ax.set_xticklabels(metrics, rotation=45, ha='right')
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    # Add value labels on bars
    for bar in bars1:
        height = bar.get_height()
        ax.annotate(f'{height:.1f}',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom', fontsize=9)
    
    for bar in bars2:
        height = bar.get_height()
        ax.annotate(f'{height:.1f}',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom', fontsize=9)
    
    fig.tight_layout()
    
    output_path = os.path.join(OUTPUT_DIR, 'financial_metrics_comparison.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    
    return output_path


def generate_fund_flow_chart(symbol="300308", symbol_name="Zhongji Innolight"):
    """
    Generate Fund Flow chart with inflow/outflow
    
    Args:
        symbol: Stock code
        symbol_name: Stock name in English
    """
    # Generate sample fund flow data
    dates = pd.date_range(start='2025-12-01', end='2025-12-10', freq='D')
    np.random.seed(42)
    
    # Fund flows in million CNY (positive = inflow, negative = outflow)
    fund_flows = np.random.randn(len(dates)) * 50
    fund_flows[0] = 100  # Initial inflow
    
    # Cumulative fund flow
    cumulative_flow = np.cumsum(fund_flows)
    
    # Color based on positive/negative
    colors = ['tab:green' if f > 0 else 'tab:red' for f in fund_flows]
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), sharex=True)
    
    # Daily Fund Flow
    ax1.bar(dates, fund_flows, color=colors, alpha=0.7)
    ax1.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax1.set_ylabel('Daily Fund Flow (Million CNY)')
    ax1.set_title(f'Daily Fund Flow: {symbol_name} ({symbol})')
    ax1.grid(axis='y', alpha=0.3)
    
    # Cumulative Fund Flow
    ax2.plot(dates, cumulative_flow, color='tab:blue', linewidth=2, marker='o')
    ax2.fill_between(dates, cumulative_flow, alpha=0.3, color='tab:blue')
    ax2.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax2.set_ylabel('Cumulative Fund Flow (Million CNY)')
    ax2.set_xlabel('Date')
    ax2.set_title(f'Cumulative Fund Flow: {symbol_name} ({symbol})')
    ax2.grid(True, alpha=0.3)
    
    plt.xticks(rotation=45)
    fig.tight_layout()
    
    output_path = os.path.join(OUTPUT_DIR, f'{symbol}_fund_flow.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    
    return output_path


def generate_all_charts():
    """Generate all chart types"""
    print("=" * 60)
    print("Stock Chart Generator - Starting")
    print("=" * 60)
    
    results = []
    
    # 1. K-line chart for 300308 (Zhongji Innolight)
    print("\n1. Generating K-line chart for 300308 (Zhongji Innolight)...")
    try:
        path = generate_kline_chart("300308", "Zhongji Innolight")
        results.append(("K-line Chart", path, "Daily K-line for Zhongji Innolight (300308)"))
        print(f"   ✓ Saved: {path}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    # 2. Price vs Northbound Capital comparison
    print("\n2. Generating Price vs Northbound Capital chart...")
    try:
        path = generate_price_northbound_chart("300308", "300502", "Zhongji Innolight", "Ecostar")
        results.append(("Price vs Northbound", path, "Comparison of Zhongji Innolight and Ecostar"))
        print(f"   ✓ Saved: {path}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    # 3. Financial Metrics Comparison
    print("\n3. Generating Financial Metrics Comparison chart...")
    try:
        path = generate_financial_metrics_comparison(["300308", "300502"], ["Zhongji Innolight", "Ecostar"])
        results.append(("Financial Metrics", path, "Financial comparison between Zhongji Innolight and Ecostar"))
        print(f"   ✓ Saved: {path}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    # 4. Fund Flow chart for 300308
    print("\n4. Generating Fund Flow chart for 300308...")
    try:
        path = generate_fund_flow_chart("300308", "Zhongji Innolight")
        results.append(("Fund Flow", path, "Fund inflow/outflow for Zhongji Innolight (300308)"))
        print(f"   ✓ Saved: {path}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    # Summary
    print("\n" + "=" * 60)
    print("Chart Generation Summary")
    print("=" * 60)
    for chart_type, path, description in results:
        print(f"• {chart_type}: {path}")
        print(f"  Description: {description}")
    
    print(f"\nAll charts saved to: {OUTPUT_DIR}")
    return results


if __name__ == "__main__":
    generate_all_charts()
