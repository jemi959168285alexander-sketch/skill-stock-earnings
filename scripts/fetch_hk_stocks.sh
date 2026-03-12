#!/bin/bash
#
# fetch_hk_stocks.sh - 获取港股财报数据
#
# 数据源：HKEX 披露易、Yahoo Finance
# 用法：
#   ./fetch_hk_stocks.sh <股票代码> [年份] [季度]
#   ./fetch_hk_stocks.sh <股票代码> --years N --format <格式> --output-dir <目录>
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
# 验证港股代码格式
# 参数：股票代码
# 返回：0=有效，1=无效
#######################################
validate_hk_stock_code() {
    local code="$1"
    
    # 港股代码为 4 位或 5 位数字
    if [[ "$code" =~ ^[0-9]{4,5}$ ]]; then
        return 0
    fi
    
    return 1
}

#######################################
# 从 HKEX 披露易获取信息
# 参数：股票代码，年份，季度
#######################################
fetch_from_hkex() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    
    info "从 HKEX 披露易获取数据：$code"
    
    # HKEX 披露易搜索 URL
    local search_url="https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode=$code"
    
    # 尝试获取公司基本信息
    # 注意：HKEX 没有公开 API，这里提供网页链接
    
    echo ""
    echo "📊 港股信息 - 代码：$code"
    echo ""
    echo "HKEX 披露易查询:"
    echo "  $search_url"
    echo ""
    
    # 尝试从其他来源获取数据
    fetch_from_yahoo_hk "$code"
    
    return 0
}

#######################################
# 从 Yahoo Finance 获取港股数据（备选）
# 参数：股票代码
#######################################
fetch_from_yahoo_hk() {
    local code="$1"
    
    info "从 Yahoo Finance 获取港股数据：$code"
    
    # 港股在 Yahoo Finance 的代码格式：0700.HK
    local yahoo_code="${code}.HK"
    
    local api_url="https://query1.finance.yahoo.com/v10/finance/quoteSummary/$yahoo_code"
    local params="modules=financialData,earnings"
    
    local response
    response=$(curl -s -H "User-Agent: Mozilla/5.0" \
        "$api_url?$params" 2>/dev/null) || {
        warn "Yahoo Finance 港股数据不可用"
        return 0
    }
    
    # 检查是否有数据
    if echo "$response" | grep -q '"error"'; then
        warn "Yahoo Finance 无此港股数据"
        return 0
    fi
    
    # 解析数据
    echo ""
    echo "📈 Yahoo Finance 数据:"
    echo "$response" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    result = data.get('quoteSummary', {})
    
    if not result:
        print('  无数据')
        sys.exit(0)
    
    # 获取财务数据
    if 'financialData' in result:
        fd = result['financialData']
        
        if 'totalRevenue' in fd:
            rev = fd['totalRevenue']
            print(f\"  总营收：{rev.get('fmt', 'N/A')}\")
        
        if 'grossProfits' in fd:
            gp = fd['grossProfits']
            print(f\"  毛利润：{gp.get('fmt', 'N/A')}\")
        
        if 'grossMargins' in fd:
            gm = fd['grossMargins']
            print(f\"  毛利率：{gm.get('fmt', 'N/A')}\")
        
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

except Exception as e:
    print(f'  解析错误：{e}')
" 2>/dev/null || true
    
    return 0
}

#######################################
# 下载港股财报数据（批量）
# 参数：股票代码，年份数，格式，输出目录
#######################################
download_hk_stocks() {
    local code="$1"
    local years_count="$2"
    local format="$3"
    local output_dir="$4"
    
    # 确保代码为 4 位（补零）
    code=$(printf "%04d" "$code" 2>/dev/null || echo "$code")
    
    # 创建股票目录
    local stock_dir="$output_dir/HK_${code}"
    mkdir -p "$stock_dir"
    
    # Yahoo Finance API（港股）
    local yahoo_code="${code}.HK"
    local api_url="https://query1.finance.yahoo.com/v10/finance/quoteSummary/$yahoo_code"
    local params="modules=financialData,earnings,incomeStatementHistory,balanceSheetHistory"
    
    progress "正在获取财报数据..."
    
    # 发送请求
    local response
    response=$(curl -s -H "User-Agent: Mozilla/5.0" \
        "$api_url?$params" 2>/dev/null) || {
        warn "Yahoo Finance 港股数据不可用，将仅保存 HKEX 链接"
        # 即使 API 失败，也创建目录结构
        create_hkex_links "$code" "$years_count" "$stock_dir"
        return 0
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
        'balanceSheets': result.get('balanceSheetHistory', {}).get('balanceSheetStatements', [])
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
                    years_data[year] = {'incomeStatements': [], 'balanceSheets': []}
                years_data[year]['incomeStatements'].append(stmt)
    
    # 处理资产负债表
    for stmt in all_data['balanceSheets']:
        end_date = stmt.get('endDate', {}).get('raw', 0)
        if end_date:
            from datetime import datetime
            year = datetime.fromtimestamp(end_date).year
            if current_year - year < years_count:
                if year not in years_data:
                    years_data[year] = {'incomeStatements': [], 'balanceSheets': []}
                years_data[year]['balanceSheets'].append(stmt)
    
    if not years_data:
        print('没有找到符合条件的数据，将保存 HKEX 链接')
        # 即使没有数据，也创建年份目录和 HKEX 链接
        for y in range(current_year - 1, current_year - years_count - 1, -1):
            year_dir = os.path.join(stock_dir, str(y))
            os.makedirs(year_dir, exist_ok=True)
            hkex_url = f"https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode={code}"
            link_file = os.path.join(year_dir, f'HKEX_link.txt')
            with open(link_file, 'w', encoding='utf-8') as f:
                f.write(f'HKEX 披露易链接：{hkex_url}\n')
                f.write(f'请在上述页面搜索 {code} 的财报文件\n')
            print(f'  ✓ {y}: HKEX 链接已保存')
        print(f'\n链接文件保存在：{stock_dir}')
        sys.exit(0)
    
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
            'balanceSheets': years_data[year]['balanceSheets']
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
    
    # 保存 HKEX 链接
    hkex_url = f"https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode={code}"
    link_file = os.path.join(stock_dir, 'HKEX_links.txt')
    with open(link_file, 'w', encoding='utf-8') as f:
        f.write(f'HKEX 披露易链接：{hkex_url}\n')
        f.write(f'请在上述页面搜索 {code} 的财报文件\n')
        for year in sorted(years_data.keys(), reverse=True):
            f.write(f'\n{year} 年财报搜索:\n')
            f.write(f'  年报：https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode={code}&titletype=Annual%20Report&year={year}\n')
            f.write(f'  中报：https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode={code}&titletype=Interim%20Report&year={year}\n')
    print(f'  ✓ HKEX 链接：{link_file}')
    
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
# 创建 HKEX 链接文件
# 参数：股票代码，年份数，输出目录
#######################################
create_hkex_links() {
    local code="$1"
    local years_count="$2"
    local stock_dir="$3"
    
    local current_year
    current_year=$(date +%Y)
    
    progress "创建 HKEX 链接文件..."
    
    # 保存 HKEX 链接
    local hkex_url="https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode=$code"
    local link_file="$stock_dir/HKEX_links.txt"
    
    {
        echo "HKEX 披露易链接：$hkex_url"
        echo "请在上述页面搜索 $code 的财报文件"
        echo ""
        echo "最近 $years_count 年财报搜索:"
        
        for ((y=current_year-1; y>=current_year-years_count; y--)); do
            echo ""
            echo "$y 年财报:"
            echo "  年报：https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode=$code&titletype=Annual%20Report&year=$y"
            echo "  中报：https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode=$code&titletype=Interim%20Report&year=$y"
        done
    } > "$link_file"
    
    success "HKEX 链接已保存：$link_file"
}

#######################################
# 获取财报文件链接
# 参数：股票代码，年份，季度
#######################################
get_report_links() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    
    echo ""
    echo "📄 财报文件链接:"
    echo ""
    echo "  HKEX 披露易:"
    echo "    https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode=$code"
    echo ""
    echo "  财报类型:"
    echo "    - 年度报告 (Annual Report) - 通常在 3-4 月发布"
    echo "    - 中期报告 (Interim Report) - 通常在 8-9 月发布"
    echo "    - 季度报告 (Quarterly Report) - 部分公司发布"
    echo ""
    
    # 如果指定了年份
    if [[ -n "$year" ]]; then
        echo "  $year 年财报:"
        echo "    年报：https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode=$code&titletype=Annual%20Report&year=$year"
        echo "    中报：https://www.hkexnews.hk/search/dissemination/search.aspx?stockcode=$code&titletype=Interim%20Report&year=$year"
    fi
    
    echo ""
    echo "  其他来源:"
    echo "    公司官网：请搜索 \"$code 投资者关系\""
    echo "    AAStocks: http://www.aastocks.com/tc/stocks/quote/financial-report.aspx?stockcode=$code"
}

#######################################
# 获取公司基本信息
# 参数：股票代码
#######################################
get_company_info() {
    local code="$1"
    
    # 尝试从 AAStocks 获取公司信息
    local aastocks_url="http://www.aastocks.com/tc/stocks/quote/stock-profile.aspx?stockcode=$code"
    
    echo ""
    echo "🏢 公司信息:"
    echo "  查看公司简介：$aastocks_url"
    echo ""
}

#######################################
# 显示使用说明
#######################################
show_help() {
    cat << EOF
fetch_hk_stocks - 获取港股财报数据

用法:
  $0 <股票代码> [年份] [季度]
  $0 <股票代码> --years N --format <格式> --output-dir <目录>

参数:
  <股票代码>          港股代码（4-5 位数字，如 0700, 9988）
  [年份]             可选，指定年份
  [季度]             可选，指定季度

选项:
  --years N          下载最近 N 年的财报
  --format <格式>    输出格式：json, csv, pdf（默认：json）
  --output-dir <目录> 输出目录
  --help             显示此帮助

示例:
  $0 0700                      # 查询腾讯最新财报
  $0 9988 2024                 # 查询阿里巴巴 2024 年财报
  $0 0700 --years 3 --format json --output-dir ./earnings

注意:
  港股财报数据以 HKEX 披露易官方文件为准
  货币单位：港元 (HKD)

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
    if ! validate_hk_stock_code "$code"; then
        error "无效的港股代码格式：$code"
        echo "港股代码应为 4-5 位数字（如 0700, 9988）"
        exit 1
    fi
    
    # 确保代码为 4 位（补零）
    code=$(printf "%04d" "$code" 2>/dev/null || echo "$code")
    
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
        echo -e "${GREEN}📊 港股财报批量下载${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        download_hk_stocks "$code" "$years_count" "$format" "$output_dir"
    else
        # 单次查询模式
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}📊 港股财报数据${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # 获取 HKEX 数据
        fetch_from_hkex "$code" "$year" "$quarter"
        
        # 获取公司信息
        get_company_info "$code"
        
        # 获取财报文件链接
        get_report_links "$code" "$year" "$quarter"
        
        echo ""
        info "数据来源：HKEX 披露易、Yahoo Finance"
        info "港股财报以 HKEX 披露易官方文件为准"
        info "货币单位：港元 (HKD)"
    fi
}

# 运行主函数
main "$@"
