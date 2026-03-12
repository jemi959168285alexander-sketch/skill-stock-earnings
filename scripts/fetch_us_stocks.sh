#!/bin/bash
#
# fetch_us_stocks.sh - 获取美股财报数据
#
# 数据源：Yahoo Finance、SEC EDGAR
# 用法：
#   ./fetch_us_stocks.sh <股票代码> [年份] [季度]
#   ./fetch_us_stocks.sh <股票代码> --years N --format <格式> --output-dir <目录>
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#######################################
# 打印错误信息
#######################################
error() {
    echo -e "${RED}错误：${NC}$1" >&2
}

#######################################
# 打印警告信息
#######################################
warn() {
    echo -e "${YELLOW}警告：${NC}$1"
}

#######################################
# 打印信息
#######################################
info() {
    echo -e "${BLUE}信息：${NC}$1"
}

#######################################
# 打印进度信息
#######################################
progress() {
    echo -e "${CYAN}▶${NC} $1"
}

#######################################
# 打印成功信息
#######################################
success() {
    echo -e "${GREEN}✓${NC} $1"
}

#######################################
# 验证美股代码格式
# 参数：股票代码
# 返回：0=有效，1=无效
#######################################
validate_us_stock_code() {
    local code="$1"
    
    # 美股代码为字母开头，可包含字母和数字
    if [[ "$code" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
        return 0
    fi
    
    return 1
}

#######################################
# 从 Yahoo Finance 获取财报数据
# 参数：股票代码，年份，季度
#######################################
fetch_from_yahoo() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    
    info "从 Yahoo Finance 获取数据：$code"
    
    # Yahoo Finance API
    local api_url="https://query1.finance.yahoo.com/v10/finance/quoteSummary/$code"
    local params="modules=earnings,financialData,incomeStatementHistory,balanceSheetHistory"
    
    # 发送请求
    local response
    response=$(curl -s -H "User-Agent: Mozilla/5.0" \
        "$api_url?$params" 2>/dev/null) || {
        error "Yahoo Finance API 请求失败"
        return 1
    }
    
    # 检查响应是否包含错误
    if echo "$response" | grep -q '"error"'; then
        error "Yahoo Finance 返回错误"
        echo "原始响应：${response:0:200}..."
        return 1
    fi
    
    # 使用 Python 解析 JSON
    echo "$response" | python3 -c "
import sys, json
from datetime import datetime

try:
    data = json.load(sys.stdin)
    result = data.get('quoteSummary', {})
    
    if not result:
        print('未找到数据')
        sys.exit(1)
    
    # 获取财务数据
    if 'financialData' in result:
        fd = result['financialData']
        print('📈 财务指标:')
        
        if 'totalRevenue' in fd:
            rev = fd['totalRevenue']
            print(f\"  总营收：{rev.get('fmt', 'N/A')}\")
        
        if 'grossProfits' in fd:
            gp = fd['grossProfits']
            print(f\"  毛利润：{gp.get('fmt', 'N/A')}\")
        
        if 'grossMargins' in fd:
            gm = fd['grossMargins']
            print(f\"  毛利率：{gm.get('fmt', 'N/A')}\")
        
        if 'operatingMargins' in fd:
            om = fd['operatingMargins']
            print(f\"  营业利润率：{om.get('fmt', 'N/A')}\")
        
        if 'profitMargins' in fd:
            pm = fd['profitMargins']
            print(f\"  净利润率：{pm.get('fmt', 'N/A')}\")
        
        if 'netIncomeToCommon' in fd:
            ni = fd['netIncomeToCommon']
            print(f\"  净利润：{ni.get('fmt', 'N/A')}\")
        
        if 'trailingEps' in fd:
            print(f\"  EPS (TTM): {fd['trailingEps'].get('fmt', 'N/A')}\")
        
        if 'operatingCashflow' in fd:
            ocf = fd['operatingCashflow']
            print(f\"  经营现金流：{ocf.get('fmt', 'N/A')}\")
        
        if 'freeCashflow' in fd:
            fcf = fd['freeCashflow']
            print(f\"  自由现金流：{fcf.get('fmt', 'N/A')}\")
        
        print()
    
    # 获取收益数据
    if 'earnings' in result:
        earnings = result['earnings']
        print('📊 收益数据:')
        
        if 'earningsChart' in earnings:
            chart = earnings['earningsChart']
            if 'quarterly' in chart:
                print('  季度数据:')
                for q in chart['quarterly'][-4:]:  # 最近 4 个季度
                    print(f\"    {q.get('date', 'N/A')}: {q.get('actual', 'N/A')} (实际) vs {q.get('estimate', 'N/A')} (预期)\")
        
        if 'financialsChart' in earnings:
            financials = earnings['financialsChart']
            if 'yearly' in financials:
                print('  年度数据:')
                for y in financials['yearly'][-3:]:  # 最近 3 年
                    print(f\"    {y.get('date', 'N/A')}: 营收 {y.get('revenue', 'N/A')}, 利润 {y.get('earnings', 'N/A')}\")
        
        print()
    
    # 获取利润表历史
    if 'incomeStatementHistory' in result:
        ish = result['incomeStatementHistory']
        if 'incomeStatementHistory' in ish:
            print('📋 利润表摘要:')
            for stmt in ish['incomeStatementHistory'][-2:]:  # 最近 2 期
                end_date = stmt.get('endDate', {}).get('fmt', 'N/A')
                total_rev = stmt.get('totalRevenue', {}).get('fmt', 'N/A')
                gross_profit = stmt.get('grossProfit', {}).get('fmt', 'N/A')
                net_income = stmt.get('netIncome', {}).get('fmt', 'N/A')
                print(f\"  {end_date}: 营收 {total_rev}, 毛利 {gross_profit}, 净利 {net_income}\")

except Exception as e:
    print(f'解析错误：{e}')
    sys.exit(1)
" 2>/dev/null || {
        warn "数据解析失败，输出原始响应"
        echo "$response" | head -c 1000
        return 0
    }
    
    return 0
}

#######################################
# 下载美股财报数据（批量）
# 参数：股票代码，年份数，格式，输出目录
#######################################
download_us_stocks() {
    local code="$1"
    local years_count="$2"
    local format="$3"
    local output_dir="$4"
    
    # 转换为大写
    code=$(echo "$code" | tr '[:lower:]' '[:upper:]')
    
    # 创建股票目录
    local stock_dir="$output_dir/US_${code}"
    mkdir -p "$stock_dir"
    
    # Yahoo Finance API
    local api_url="https://query1.finance.yahoo.com/v10/finance/quoteSummary/$code"
    local params="modules=earnings,financialData,incomeStatementHistory,balanceSheetHistory,cashflowStatementHistory"
    
    progress "正在获取财报数据..."
    
    # 发送请求
    local response
    response=$(curl -s -H "User-Agent: Mozilla/5.0" \
        "$api_url?$params" 2>/dev/null) || {
        error "Yahoo Finance API 请求失败"
        return 1
    }
    
    # 获取当前年份
    local current_year
    current_year=$(date +%Y)
    
    # 使用 Python 处理和保存数据
    echo "$response" | python3 << PYTHON_SCRIPT
import sys, json
import os

try:
    data = json.load(sys.stdin)
    result = data.get('quoteSummary', {})
    
    if not result:
        print('未找到数据')
        sys.exit(1)
    
    years_count = $years_count
    format_type = "$format"
    stock_dir = "$stock_dir"
    code = "$code"
    current_year = $current_year
    
    # 收集所有财报数据
    all_data = {
        'company': code,
        'financialData': result.get('financialData', {}),
        'earnings': result.get('earnings', {}),
        'incomeStatements': result.get('incomeStatementHistory', {}).get('incomeStatementHistory', []),
        'balanceSheets': result.get('balanceSheetHistory', {}).get('balanceSheetStatements', []),
        'cashflows': result.get('cashflowStatementHistory', {}).get('cashflowStatements', [])
    }
    
    # 按年份组织数据
    years_data = {}
    
    # 处理利润表
    for stmt in all_data['incomeStatements']:
        end_date = stmt.get('endDate', {}).get('raw', 0)
        if end_date:
            from datetime import datetime
            year = datetime.fromtimestamp(end_date).year
            if current_year - year < years_count:
                if year not in years_data:
                    years_data[year] = {'incomeStatements': [], 'balanceSheets': [], 'cashflows': []}
                years_data[year]['incomeStatements'].append(stmt)
    
    # 处理资产负债表
    for stmt in all_data['balanceSheets']:
        end_date = stmt.get('endDate', {}).get('raw', 0)
        if end_date:
            from datetime import datetime
            year = datetime.fromtimestamp(end_date).year
            if current_year - year < years_count:
                if year not in years_data:
                    years_data[year] = {'incomeStatements': [], 'balanceSheets': [], 'cashflows': []}
                years_data[year]['balanceSheets'].append(stmt)
    
    # 处理现金流
    for stmt in all_data['cashflows']:
        end_date = stmt.get('endDate', {}).get('raw', 0)
        if end_date:
            from datetime import datetime
            year = datetime.fromtimestamp(end_date).year
            if current_year - year < years_count:
                if year not in years_data:
                    years_data[year] = {'incomeStatements': [], 'balanceSheets': [], 'cashflows': []}
                years_data[year]['cashflows'].append(stmt)
    
    if not years_data:
        print('没有找到符合条件的数据')
        sys.exit(1)
    
    print(f'找到 {len(years_data)} 年的财报数据')
    
    # 保存数据
    for year in sorted(years_data.keys(), reverse=True):
        year_dir = os.path.join(stock_dir, str(year))
        os.makedirs(year_dir, exist_ok=True)
        
        year_content = {
            'company': code,
            'year': year,
            'financialData': all_data['financialData'],
            'earnings': all_data['earnings'],
            'incomeStatements': years_data[year]['incomeStatements'],
            'balanceSheets': years_data[year]['balanceSheets'],
            'cashflows': years_data[year]['cashflows']
        }
        
        if format_type == 'json':
            output_file = os.path.join(year_dir, f'{code}_{year}_earnings.json')
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(year_content, f, ensure_ascii=False, indent=2)
            print(f'  ✓ {year}: {output_file}')
        
        elif format_type == 'csv':
            # 保存利润表为 CSV
            if years_data[year]['incomeStatements']:
                import csv
                output_file = os.path.join(year_dir, f'{code}_{year}_income.csv')
                stmts = years_data[year]['incomeStatements']
                if stmts:
                    # 展平数据
                    rows = []
                    for stmt in stmts:
                        row = {}
                        for key, value in stmt.items():
                            if isinstance(value, dict):
                                row[key] = value.get('raw', value.get('fmt', str(value)))
                            else:
                                row[key] = value
                        rows.append(row)
                    
                    keys = rows[0].keys() if rows else []
                    with open(output_file, 'w', newline='', encoding='utf-8-sig') as f:
                        writer = csv.DictWriter(f, fieldnames=keys)
                        writer.writeheader()
                        writer.writerows(rows)
                print(f'  ✓ {year} 利润表：{output_file}')
    
    # 保存完整 JSON 数据
    full_output = os.path.join(stock_dir, f'{code}_full_data.json')
    with open(full_output, 'w', encoding='utf-8') as f:
        json.dump(all_data, f, ensure_ascii=False, indent=2)
    print(f'  ✓ 完整数据：{full_output}')
    
    print(f'\n下载完成！数据保存在：{stock_dir}')

except Exception as e:
    print(f'处理错误：{e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_SCRIPT
    
    return 0
}

#######################################
# 从 SEC EDGAR 获取财报文件
# 参数：股票代码，年份，季度
#######################################
fetch_from_sec_edgar() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    
    info "查询 SEC EDGAR: $code"
    
    # SEC EDGAR 需要特定的 User-Agent
    local user_agent="OpenClaw stock-earnings skill contact@example.com"
    
    # 首先尝试获取 CIK
    local cik_url="https://www.sec.gov/cgi-bin/browse-edgar?CIK=$code&owner=include&count=10"
    
    local response
    response=$(curl -s -H "User-Agent: $user_agent" "$cik_url" 2>/dev/null) || {
        warn "SEC EDGAR 查询失败"
        return 0
    }
    
    # 输出 SEC 文件链接
    echo ""
    echo "📄 SEC EDGAR 文件:"
    echo "  公司 filings: https://www.sec.gov/cgi-bin/browse-edgar?CIK=$code"
    echo ""
    echo "  财报类型:"
    echo "    - 10-K: 年度报告"
    echo "    - 10-Q: 季度报告"
    echo "    - 8-K: 重大事件报告"
    echo ""
    
    # 如果指定了年份和季度，尝试获取对应文件
    if [[ -n "$year" && -n "$quarter" ]]; then
        local form_type="10-Q"
        if [[ "$quarter" == "Q4" || "$quarter" == "FY" ]]; then
            form_type="10-K"
        fi
        
        echo "  指定查询：$year 年 $quarter ($form_type)"
        echo "  链接：https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=$code&type=$form_type&dateb=&owner=include&count=40"
    fi
    
    return 0
}

#######################################
# 获取投资者关系页面链接
# 参数：股票代码
#######################################
get_ir_links() {
    local code="$1"
    
    local company_name
    company_name=$(echo "$code" | tr '[:upper:]' '[:lower:]')
    
    echo ""
    echo "🔗 投资者关系:"
    echo "  官网 IR: https://investor.${company_name}.com (如适用)"
    echo "  Seeking Alpha: https://seekingalpha.com/symbol/$code/earnings"
    echo "  Earnings Whispers: https://www.earningswhispers.com/stocks/$code"
}

#######################################
# 显示使用说明
#######################################
show_help() {
    cat << EOF
fetch_us_stocks - 获取美股财报数据

用法:
  $0 <股票代码> [年份] [季度]
  $0 <股票代码> --years N --format <格式> --output-dir <目录>

参数:
  <股票代码>          美股代码（如 AAPL, TSLA）
  [年份]             可选，指定年份
  [季度]             可选，指定季度

选项:
  --years N          下载最近 N 年的财报
  --format <格式>    输出格式：json, csv, pdf（默认：json）
  --output-dir <目录> 输出目录
  --help             显示此帮助

示例:
  $0 AAPL                      # 查询苹果最新财报
  $0 TSLA 2024 Q3              # 查询特斯拉 2024 年 Q3
  $0 AAPL --years 5 --format json --output-dir ./earnings

EOF
}

#######################################
# 主函数
#######################################
main() {
    local code="${1:-}"
    local year=""
    local quarter=""
    local years_count=""
    local format="json"
    local output_dir=""
    local download_mode=false
    
    # 解析参数
    shift 2>/dev/null || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --years)
                years_count="$2"
                download_mode=true
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$year" ]]; then
                    year="$1"
                elif [[ -z "$quarter" ]]; then
                    quarter="$1"
                fi
                shift
                ;;
        esac
    done
    
    # 验证参数
    if [[ -z "$code" ]]; then
        error "请提供股票代码"
        show_help
        exit 1
    fi
    
    # 验证代码格式
    if ! validate_us_stock_code "$code"; then
        error "无效的美股代码格式：$code"
        echo "美股代码应为字母开头（如 AAPL, TSLA）"
        exit 1
    fi
    
    # 转换为大写
    code=$(echo "$code" | tr '[:lower:]' '[:upper:]')
    
    if [[ "$download_mode" == true ]]; then
        # 批量下载模式
        if [[ -z "$years_count" ]]; then
            error "批量下载模式需要指定 --years 参数"
            exit 1
        fi
        if [[ -z "$output_dir" ]]; then
            error "批量下载模式需要指定 --output-dir 参数"
            exit 1
        fi
        
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}📊 美股财报批量下载${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        download_us_stocks "$code" "$years_count" "$format" "$output_dir"
    else
        # 单次查询模式
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}📊 美股财报数据${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # 获取 Yahoo Finance 数据
        if ! fetch_from_yahoo "$code" "$year" "$quarter"; then
            error "获取 Yahoo Finance 数据失败"
        fi
        
        # 获取 SEC EDGAR 文件
        fetch_from_sec_edgar "$code" "$year" "$quarter"
        
        # 获取投资者关系链接
        get_ir_links "$code"
        
        echo ""
        info "数据来源：Yahoo Finance, SEC EDGAR"
        info "财报数据可能有所延迟，请以官方披露为准"
    fi
}

# 运行主函数
main "$@"
