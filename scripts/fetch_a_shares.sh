#!/bin/bash
#
# fetch_a_shares.sh - 获取 A 股财报数据
#
# 数据源：东方财富、雪球
# 用法：
#   ./fetch_a_shares.sh <股票代码> [年份] [季度]
#   ./fetch_a_shares.sh <股票代码> --years N --format <格式> --output-dir <目录>
#   ./fetch_a_shares.sh <股票代码> --years N --pdf --output-dir <目录>
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
# 验证 A 股代码格式
# 参数：股票代码
# 返回：0=有效，1=无效
#######################################
validate_a_share_code() {
    local code="$1"
    
    # A 股代码为 6 位数字
    if [[ "$code" =~ ^[0-9]{6}$ ]]; then
        return 0
    fi
    
    # 带市场前缀的格式 (如 600519.SH)
    if [[ "$code" =~ ^[0-9]{6}\.(SH|SZ)$ ]]; then
        return 0
    fi
    
    return 1
}

#######################################
# 从东方财富获取主要财务指标
# 参数：股票代码，年份，季度
#######################################
fetch_from_eastmoney() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    
    info "从东方财富获取数据：$code"
    
    # 构建股票代码（添加市场后缀）
    local secucode="$code"
    if [[ "$code" =~ ^6 ]]; then
        secucode="${code}.SH"
    elif [[ "$code" =~ ^[03] ]]; then
        secucode="${code}.SZ"
    fi
    
    # 东方财富 API
    local api_url="https://datacenter.eastmoney.com/securities/api/data/v1/get"
    local params="reportName=RPT_F10_FINANCE_MAINFINADATA&columns=ALL&filter=(SECUCODE=\"$secucode\")&pageNumber=1&pageSize=20"
    
    # 发送请求
    local response
    response=$(curl -s -H "User-Agent: Mozilla/5.0" \
        -H "Referer: https://data.eastmoney.com/" \
        "$api_url?$params" 2>/dev/null) || {
        error "东方财富 API 请求失败"
        return 1
    }
    
    # 检查响应
    if ! echo "$response" | grep -q '"success"'; then
        error "东方财富 API 返回错误"
        echo "原始响应：${response:0:200}..."
        return 1
    fi
    
    # 使用 Python 解析
    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'result' in data and 'data' in data['result']:
        for item in data['result']['data'][:10]:  # 最多显示 10 条
            report_date = item.get('TRADE_DATE', 'N/A')
            # 如果指定了年份，过滤数据
            if '$year' and report_date != 'N/A':
                try:
                    report_year = str(report_date).split('-')[0] if '-' in str(report_date) else str(report_date)[:4]
                    if '$year' and report_year != '$year':
                        continue
                except:
                    pass
            print(f\"报告期：{report_date}\")
            print(f\"  营收：{item.get('TOTAL_OPERATE_INCOME', 'N/A')}元\")
            print(f\"  净利润：{item.get('PARENT_NETPROFIT', 'N/A')}元\")
            print(f\"  EPS: {item.get('BASIC_EPS', 'N/A')}元\")
            print(f\"  ROE: {item.get('WEIGHT_AVG_ROE', 'N/A')}%\")
            print()
    else:
        print('未找到数据')
except Exception as e:
    print(f'解析错误：{e}')
" 2>/dev/null || echo "$response"
    
    return 0
}

#######################################
# 下载 A 股财报数据（批量）
# 参数：股票代码，年份数，格式，输出目录
#######################################
download_a_shares() {
    local code="$1"
    local years_count="$2"
    local format="$3"
    local output_dir="$4"
    
    # 构建股票代码（添加市场后缀）
    local secucode="$code"
    if [[ "$code" =~ ^6 ]]; then
        secucode="${code}.SH"
    elif [[ "$code" =~ ^[03] ]]; then
        secucode="${code}.SZ"
    fi
    
    # 创建股票目录
    local stock_dir="$output_dir/A_${code}"
    mkdir -p "$stock_dir"
    
    # 东方财富 API
    local api_url="https://datacenter.eastmoney.com/securities/api/data/v1/get"
    local params="reportName=RPT_F10_FINANCE_MAINFINADATA&columns=ALL&filter=(SECUCODE=\"$secucode\")&pageNumber=1&pageSize=50"
    
    progress "正在获取财报数据..."
    
    # 发送请求
    local response
    response=$(curl -s -H "User-Agent: Mozilla/5.0" \
        -H "Referer: https://data.eastmoney.com/" \
        "$api_url?$params" 2>/dev/null) || {
        error "东方财富 API 请求失败"
        return 1
    }
    
    # 使用 Python 处理和保存数据
    local current_year
    current_year=$(date +%Y)
    
    echo "$response" | python3 << PYTHON_SCRIPT
import sys, json
import os
from datetime import datetime

try:
    data = json.load(sys.stdin)
    if 'result' not in data or 'data' not in data['result']:
        print('未找到数据')
        sys.exit(1)
    
    earnings_data = data['result']['data']
    
    # 获取当前年份
    current_year = $current_year
    years_count = $years_count
    format_type = "$format"
    stock_dir = "$stock_dir"
    
    # 过滤最近 N 年的数据
    filtered_data = []
    for item in earnings_data:
        report_date = item.get('TRADE_DATE', '')
        if report_date:
            try:
                if '-' in str(report_date):
                    report_year = int(str(report_date).split('-')[0])
                else:
                    report_year = int(str(report_date)[:4])
                
                if current_year - report_year < years_count:
                    filtered_data.append(item)
            except:
                continue
    
    if not filtered_data:
        print('没有找到符合条件的数据')
        sys.exit(1)
    
    print(f'找到 {len(filtered_data)} 条财报数据')
    
    # 按年份组织数据
    years_data = {}
    for item in filtered_data:
        report_date = item.get('TRADE_DATE', '')
        if '-' in str(report_date):
            year = str(report_date).split('-')[0]
        else:
            year = str(report_date)[:4]
        
        if year not in years_data:
            years_data[year] = []
        years_data[year].append(item)
    
    # 保存数据
    for year, items in sorted(years_data.items(), reverse=True):
        year_dir = os.path.join(stock_dir, year)
        os.makedirs(year_dir, exist_ok=True)
        
        # 根据格式保存
        if format_type == 'json':
            output_file = os.path.join(year_dir, f'{code}_{year}_earnings.json')
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(items, f, ensure_ascii=False, indent=2)
            print(f'  ✓ {year}: {output_file}')
        
        elif format_type == 'csv':
            output_file = os.path.join(year_dir, f'{code}_{year}_earnings.csv')
            if items:
                import csv
                keys = items[0].keys()
                with open(output_file, 'w', newline='', encoding='utf-8-sig') as f:
                    writer = csv.DictWriter(f, fieldnames=keys)
                    writer.writeheader()
                    writer.writerows(items)
            print(f'  ✓ {year}: {output_file}')
    
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
# 从雪球获取数据（备选）
# 参数：股票代码
#######################################
fetch_from_xueqiu() {
    local code="$1"
    
    info "从雪球获取数据：$code"
    
    # 雪球需要 cookie，这里提供基本框架
    # 实际使用时需要获取有效的 cookie
    
    local cookie="${XUEQIU_COOKIE:-}"
    if [[ -z "$cookie" ]]; then
        warn "未设置 XUEQIU_COOKIE，跳过雪球数据获取"
        info "设置方法：export XUEQIU_COOKIE='your_cookie_here'"
        return 0
    fi
    
    # 构建股票代码
    local symbol="$code"
    if [[ "$code" =~ ^6 ]]; then
        symbol="SH${code}"
    elif [[ "$code" =~ ^[03] ]]; then
        symbol="SZ${code}"
    fi
    
    local api_url="https://stock.xueqiu.com/v5/stock/quote.json"
    local response
    response=$(curl -s -H "Cookie: $cookie" \
        -H "User-Agent: Mozilla/5.0" \
        "$api_url?symbol=$symbol" 2>/dev/null) || {
        warn "雪球 API 请求失败"
        return 0
    }
    
    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'data' in data and 'quote' in data['data']:
        quote = data['data']['quote']
        print(f\"雪球数据：{quote.get('name', 'N/A')} ({quote.get('symbol', 'N/A')})\")
        print(f\"  当前价：{quote.get('current', 'N/A')}\")
        print(f\"  涨跌幅：{quote.get('percent', 'N/A')}%\")
except Exception as e:
    pass
" 2>/dev/null
    
    return 0
}

#######################################
# 获取 A 股财报文件链接
# 参数：股票代码
#######################################
get_report_links() {
    local code="$1"
    
    echo ""
    echo "📄 财报文件链接:"
    echo "  东方财富：https://emweb.securities.eastmoney.com/PC_HSF10/OperationsRequired/index?type=web&code=${code}"
    echo "  巨潮资讯：http://www.cninfo.com.cn/new/commonUrl/pageOfSearch?url=disclosure/list/search&lastPageNumber=1&stock=$code"
}

#######################################
# 显示使用说明
#######################################
show_help() {
    cat << EOF
fetch_a_shares - 获取 A 股财报数据

用法:
  $0 <股票代码> [年份] [季度]
  $0 <股票代码> --years N --format <格式> --output-dir <目录>
  $0 <股票代码> --years N --pdf --output-dir <目录>

参数:
  <股票代码>          A 股代码（6 位数字，如 600519）
  [年份]             可选，指定年份
  [季度]             可选，指定季度

选项:
  --years N          下载最近 N 年的财报
  --format <格式>    输出格式：json, csv（默认：json）
  --pdf              下载官方财报 PDF（从巨潮资讯网）
  --output-dir <目录> 输出目录
  --progress         显示下载进度
  --help             显示此帮助

示例:
  $0 600519                      # 查询茅台最新财报
  $0 600519 2024 Q3              # 查询茅台 2024 年 Q3
  $0 600519 --years 3 --format json --output-dir ./earnings
  $0 600519 --years 3 --pdf --output-dir ./pdfs
  $0 600519 --years 5 --pdf --output-dir ./pdfs --progress

EOF
}

#######################################
# 主函数
#######################################
main() {
    local code=""
    local year=""
    local quarter=""
    local years_count=""
    local format="json"
    local output_dir=""
    local download_mode=false
    local pdf_mode=false
    local show_progress="false"
    
    # 解析参数
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
            --pdf)
                pdf_mode=true
                format="pdf"
                download_mode=true
                shift
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --progress)
                show_progress="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                error "未知选项：$1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$code" ]]; then
                    code="$1"
                elif [[ -z "$year" ]]; then
                    year="$1"
                elif [[ -z "$quarter" ]]; then
                    quarter="$1"
                else
                    error "多余的参数：$1"
                    exit 1
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
    if ! validate_a_share_code "$code"; then
        error "无效的 A 股代码格式：$code"
        echo "A 股代码应为 6 位数字（如 600519）"
        exit 1
    fi
    
    # 去除市场后缀
    code="${code%.*}"
    
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
        if [[ "$pdf_mode" == true ]]; then
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}📄 A 股财报 PDF 下载${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            # 调用 PDF 下载脚本
            "$SCRIPT_DIR/download_pdf.sh" "$code" --years "$years_count" --output-dir "$output_dir" $([[ "$show_progress" == "true" ]] && echo "--progress")
        else
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}📊 A 股财报批量下载${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            download_a_shares "$code" "$years_count" "$format" "$output_dir"
        fi
    else
        # 单次查询模式
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}📊 A 股财报数据${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # 获取东方财富数据
        if ! fetch_from_eastmoney "$code" "$year" "$quarter"; then
            error "获取东方财富数据失败"
        fi
        
        # 获取雪球数据（备选）
        fetch_from_xueqiu "$code"
        
        # 获取财报文件链接
        get_report_links "$code"
        
        echo ""
        info "数据来源：东方财富、雪球"
        info "财报数据可能有所延迟，请以官方披露为准"
    fi
}

# 运行主函数
main "$@"
