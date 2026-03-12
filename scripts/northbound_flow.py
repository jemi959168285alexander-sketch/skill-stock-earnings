#!/usr/bin/env python3
"""
Northbound Capital Flow Data Fetcher

Fetches northbound capital flow data from akshare for A-share market stocks.
Supports CSV and JSON output formats.
"""

import os
import sys
import json
import pandas as pd
from datetime import datetime
from typing import Optional, List, Dict, Any

try:
    import akshare as ak
except ImportError:
    print("Error: akshare not installed. Install with: pip install akshare")
    sys.exit(1)


# Output directory
OUTPUT_DIR = "/Users/peterzhang/Documents/stock-analysis/northbound/"

# Test stocks: (code, name)
TEST_STOCKS = [
    ("300308", "ZhouSir Creation"),
    ("300502", "NewEEE"),
    ("300750", "CATL"),
]


def ensure_output_dir():
    """Ensure output directory exists."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)


def get_individual_holdings(stock_code: str) -> pd.DataFrame:
    """
    Get northbound individual stock holdings history.
    
    Args:
        stock_code: Stock code (e.g., "300308")
    
    Returns:
        DataFrame with holdings data
    """
    try:
        df = ak.stock_hsgt_individual_em(symbol=stock_code)
        return df
    except Exception as e:
        print(f"Error fetching individual holdings for {stock_code}: {e}")
        return pd.DataFrame()


def get_daily_statistics(stock_code: str,
                         start_date: str = "20251201",
                         end_date: str = "20260312") -> pd.DataFrame:
    """
    Get daily northbound statistics for a specific stock.
    
    Args:
        stock_code: Stock code
        start_date: Start date in format "YYYYMMDD"
        end_date: End date in format "YYYYMMDD"
    
    Returns:
        DataFrame with statistics data
    """
    try:
        df = ak.stock_hsgt_stock_statistics_em(
            symbol=stock_code,
            start_date=start_date,
            end_date=end_date
        )
        return df
    except Exception as e:
        print(f"Error fetching daily statistics for {stock_code}: {e}")
        return pd.DataFrame()


def get_institution_statistics(date: str = None) -> pd.DataFrame:
    """
    Get daily northbound institution statistics.
    
    Args:
        date: Date in format "YYYYMMDD", defaults to today
    
    Returns:
        DataFrame with institution statistics
    """
    try:
        if date is None:
            date = datetime.now().strftime("%Y%m%d")
        
        df = ak.stock_hsgt_institution_statistics_em(date=date)
        return df
    except Exception as e:
        print(f"Error fetching institution statistics: {e}")
        return pd.DataFrame()


def get_historical_data() -> pd.DataFrame:
    """
    Get historical northbound capital flow data.
    
    Returns:
        DataFrame with historical data
    """
    try:
        df = ak.stock_hsgt_hist_em()
        return df
    except Exception as e:
        print(f"Error fetching historical data: {e}")
        return pd.DataFrame()


def get_fund_flow_summary() -> pd.DataFrame:
    """
    Get northbound capital fund flow summary.
    
    Returns:
        DataFrame with fund flow summary
    """
    try:
        df = ak.stock_hsgt_fund_flow_summary_em()
        return df
    except Exception as e:
        print(f"Error fetching fund flow summary: {e}")
        return pd.DataFrame()


def save_data(df: pd.DataFrame, 
              filename: str, 
              output_format: str = "csv") -> str:
    """
    Save data to file.
    
    Args:
        df: DataFrame to save
        filename: Output filename (without extension)
        output_format: Output format ("csv" or "json")
    
    Returns:
        Path to saved file
    """
    ensure_output_dir()
    
    if output_format.lower() == "json":
        filepath = os.path.join(OUTPUT_DIR, f"{filename}.json")
        # Convert DataFrame to JSON with proper encoding
        df.to_json(filepath, orient="records", force_ascii=False, indent=2)
    else:
        filepath = os.path.join(OUTPUT_DIR, f"{filename}.csv")
        df.to_csv(filepath, index=False, encoding="utf_8_sig")
    
    return filepath


def fetch_single_stock(stock_code: str, 
                       stock_name: str,
                       date_range: Dict[str, str]) -> Dict[str, Any]:
    """
    Fetch complete northbound data for a single stock.
    
    Args:
        stock_code: Stock code
        stock_name: Stock name
        date_range: Dict with "start" and "end" dates
    
    Returns:
        Dict with stock data and analysis
    """
    result = {
        "code": stock_code,
        "name": stock_name,
        "individual_holdings": None,
        "daily_stats": None,
        "filepath": None
    }
    
    # Get individual holdings history
    try:
        df = get_individual_holdings(stock_code)
        
        if not df.empty:
            filepath = save_data(
                df, 
                f"{stock_code}_northbound_individual",
                output_format="csv"
            )
            result["individual_holdings"] = df
            result["filepath"] = filepath
            
            # Get key metrics from latest data
            if len(df) > 0:
                latest = df.iloc[-1]
                result["latest"] = {
                    "date": str(latest.get("持股日期", "N/A")),
                    "holdings": latest.get("持股数量", "N/A"),
                    "ratio": latest.get("持股比例", "N/A"),
                    "market_value": latest.get("持股市值", "N/A")
                }
    except Exception as e:
        print(f"Error fetching individual data for {stock_code} ({stock_name}): {e}")
    
    # Get daily statistics
    try:
        stats_df = get_daily_statistics(
            stock_code=stock_code,
            start_date=date_range["start"],
            end_date=date_range["end"]
        )
        
        if not stats_df.empty:
            stats_path = save_data(
                stats_df,
                f"{stock_code}_northbound_statistics",
                output_format="csv"
            )
            result["daily_stats"] = stats_df
            
            # Add statistics info to latest
            if len(stats_df) > 0 and "latest" in result:
                latest = stats_df.iloc[-1]
                result["latest"]["stocks_on_hold"] = latest.get("持股股票", "N/A")
                result["latest"]["increase"] = latest.get("增减", "N/A")
    except Exception as e:
        print(f"Error fetching statistics for {stock_code}: {e}")
    
    return result


def print_summary(results: List[Dict[str, Any]]):
    """Print summary of fetched data."""
    print("\n" + "=" * 80)
    print("NORTHBOUND CAPITAL FLOW DATA SUMMARY")
    print("=" * 80)
    
    for result in results:
        if result["individual_holdings"] is None and result["daily_stats"] is None:
            continue
            
        print(f"\n{result['code']} - {result['name']}")
        print("-" * 60)
        
        if "latest" in result and result["latest"]:
            latest = result["latest"]
            print(f"  Latest Date: {latest['date']}")
            print(f"  Holdings: {latest['holdings']}")
            print(f"  Ratio: {latest['ratio']}")
            print(f"  Market Value: {latest['market_value']}")
        
        # Show top rows of individual holdings dataframe
        df = result["individual_holdings"]
        if df is not None and len(df) > 0:
            print(f"\n  Recent Individual Holdings (last {min(5, len(df))} records):")
            for idx, row in df.tail(5).iterrows():
                print(f"    {row.get('持股日期', 'N/A')}: "
                      f"持股 {row.get('持股数量', 'N/A')}, "
                      f"比例 {row.get('持股比例', 'N/A')}, "
                      f"市值 {row.get('持股市值', 'N/A')}")
        
        # Show statistics
        stats = result["daily_stats"]
        if stats is not None and len(stats) > 0:
            print(f"\n  Recent Statistics (last {min(5, len(stats))} records):")
            for idx, row in stats.tail(5).iterrows():
                print(f"    {row.get('日期', 'N/A')}: "
                      f"持股 {row.get('持股数量', 'N/A')}, "
                      f"占流通股 {row.get('占流通股比例', 'N/A')}, "
                      f"市值 {row.get('市值', 'N/A')}")


def main():
    """Main function to fetch northbound capital flow data."""
    print("Fetching Northbound Capital Flow Data...")
    print("=" * 60)
    
    # Ensure output directory exists
    ensure_output_dir()
    
    # Date range for analysis
    date_range = {
        "start": "20251201",
        "end": "20260312"
    }
    
    # Fetch data for test stocks
    results = []
    print("\nFetching individual stock data...")
    for stock_code, stock_name in TEST_STOCKS:
        print(f"  Processing {stock_code} ({stock_name})...")
        result = fetch_single_stock(stock_code, stock_name, date_range)
        results.append(result)
    
    # Get fund flow summary
    print("\nFetching fund flow summary...")
    flow_df = get_fund_flow_summary()
    if not flow_df.empty:
        flow_path = save_data(flow_df, "northbound_fund_flow_summary", "csv")
        print(f"  Saved fund flow summary to: {flow_path}")
    else:
        print("  No fund flow summary data available.")
    
    # Get historical data
    print("\nFetching historical northbound data...")
    hist_df = get_historical_data()
    if not hist_df.empty:
        hist_path = save_data(hist_df, "northbound_historical", "csv")
        print(f"  Saved historical data to: {hist_path}")
        
        # Print historical summary
        print("\n  Historical Data Summary:")
        if len(hist_df) > 0:
            print(f"    Latest date: {hist_df.iloc[-1].get('日期', 'N/A')}")
            print(f"    Net flow: {hist_df.iloc[-1].get('净流入', 'N/A')}")
            print(f"    Total flow: {hist_df.iloc[-1].get('资金流出', 'N/A')}")
    else:
        print("  No historical data available.")
    
    # Print summary
    print_summary(results)
    
    # Save results summary as JSON (convert DataFrames to dicts)
    summary_file = os.path.join(OUTPUT_DIR, "northbound_summary.json")
    
    def convert_to_native(obj):
        """Convert numpy/pandas types to native Python types for JSON serialization."""
        import numpy as np
        
        if pd.isna(obj) or obj is None:
            return None
        if isinstance(obj, (pd.Timestamp, datetime)):
            return str(obj)
        if isinstance(obj, np.integer):
            return int(obj)
        if isinstance(obj, np.floating):
            return float(obj)
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        if hasattr(obj, 'item'):  # numpy scalar types
            try:
                return obj.item()
            except:
                return str(obj)
        if isinstance(obj, (int, float, str, bool, list, dict)):
            return obj
        return str(obj)
    
    # Convert results to JSON-serializable format
    json_results = []
    for result in results:
        latest = result.get("latest", {})
        # Convert latest values to native types
        if latest:
            latest = {k: convert_to_native(v) for k, v in latest.items()}
        
        json_result = {
            "code": result["code"],
            "name": result["name"],
            "filepath": result["filepath"],
            "latest": latest
        }
        
        # Save DataFrame content separately as CSV files
        if result.get("individual_holdings") is not None:
            df = result["individual_holdings"]
            df_csv_path = save_data(df, f"{result['code']}_holdings_full", "csv")
            json_result["individual_holdings_file"] = df_csv_path
        
        if result.get("daily_stats") is not None:
            df = result["daily_stats"]
            df_csv_path = save_data(df, f"{result['code']}_stats_full", "csv")
            json_result["daily_stats_file"] = df_csv_path
        
        json_results.append(json_result)
    
    with open(summary_file, "w", encoding="utf-8") as f:
        json.dump(json_results, f, indent=2, ensure_ascii=False)
    
    print("\n" + "=" * 60)
    print(f"Data saved to: {OUTPUT_DIR}")
    print("=" * 60)


if __name__ == "__main__":
    main()
