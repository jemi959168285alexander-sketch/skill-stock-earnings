#!/bin/bash
#
# stock-earnings.sh - 获取上市公司财报数据
#
# 支持市场：A 股、美股、港股
# 数据来源：东方财富、雪球、SEC EDGAR、Yahoo Finance、HKEX 披露易、akshare
#
# 用法：
#   ./stock-earnings.sh <股票代码> [--quarter Q1|Q2|Q3|Q4] [--year YYYY] [--market A|US|HK]
#   ./stock-earnings.sh <股票代码> --years N --format json|csv|pdf --output-dir <目录>
#   ./stock-earnings.sh <股票代码> --years N --pdf --output-dir <目录>
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# conda 环境名称
CONDA_ENV="skill-stock-earnings"

# akshare Python 脚本路径
AKSHARE_SCRIPT="$SCRIPT_DIR/fetch_data_akshare.py"

# 默认参数
MARKET=""
YEAR=""
QUARTER=""
STOCK_CODE=""
YEARS=""
FORMAT="json"
OUTPUT_DIR=""
DOWNLOAD_MODE=false
PDF_MODE=false
SHOW_PROGRESS=false
USE_AKSHARE=false

#######################################
# 显示使用说明
#######################################
show_help() {
    cat << EOF
stock-earnings - 获取上市公司财报数据

用法:
  $0 <股票代码> [选项]
  $0 <股票代码> --years N --format <格式> --output-dir <目录>
  $0 <股票代码> --years N --pdf --output-dir <目录>

参数:
  <股票代码>          股票代码（必填）
                      A 股：6 位数字（如 600519）
                      美股：ticker symbol（如 AAPL）
                      港股：4 位数字（如 0700）

选项:
  --quarter Q1|Q2|Q3|Q4  查询指定季度
  --year YYYY            查询指定年份
  --market A|US|HK       指定市场类型（可选，自动检测）
  
  --years N              下载最近 N 年的财报（批量下载模式）
  --format <格式>        下载格式：json, csv（默认：json）
  --pdf                  下载官方财报 PDF（仅支持 A 股，从巨潮资讯网）
  --output-dir <目录>    输出目录（批量下载时必填）
  --progress             显示下载进度（批量下载时自动启用）
  --akshare              使用 akshare 数据源（默认使用）
  
  --help                 显示此帮助信息

示例:
  # 单次查询
  $0 AAPL                           # 查询苹果最新财报
  $0 600519 --quarter Q3 --year 2024  # 查询茅台 2024 年 Q3
  $0 0700 --market HK               # 查询腾讯控股

  # 批量下载（数据格式）
  $0 AAPL --years 3 --format json --output-dir ./earnings
  $0 600519 --years 5 --format csv --output-dir ./a_shares

  # 批量下载（PDF）
  $0 600519 --years 3 --pdf --output-dir ./pdfs
  $0 000858 --years 5 --pdf --output-dir ./earnings --progress

EOF
}

#######################################
# 打印错误信息
# 参数：错误消息
#######################################
error() {
    echo -e "${RED}错误：${NC}$1" >&2
}

#######################################
# 打印警告信息
# 参数：警告消息
#######################################
warn() {
    echo -e "${YELLOW}警告：${NC}$1"
}

#######################################
# 打印信息
# 参数：消息
#######################################
info() {
    echo -e "${BLUE}信息：${NC}$1"
}

#######################################
# 打印进度信息
# 参数：消息
#######################################
progress() {
    echo -e "${CYAN}▶${NC} $1"
}

#######################################
# 检测股票代码所属市场
# 参数：股票代码
# 返回：市场类型 (A|US|HK)
#######################################
detect_market() {
    local code="$1"
    
    # A 股：6 位纯数字
    if [[ "$code" =~ ^[0-9]{6}$ ]]; then
        echo "A"
        return 0
    fi
    
    # 港股：4 位纯数字
    if [[ "$code" =~ ^[0-9]{4}$ ]]; then
        echo "HK"
        return 0
    fi
    
    # 美股：字母代码（可能包含数字）
    if [[ "$code" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
        echo "US"
        return 0
    fi
    
    return 1
}

#######################################
# 获取 A 股财报数据（东方财富 API）
# 参数：股票代码，年份，季度，格式，输出目录，年份数，PDF 模式，进度显示
#######################################
fetch_a_shares_earnings() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    local format="$4"
    local output_dir="$5"
    local years_count="$6"
    local pdf_mode="$7"
    local show_progress="$8"
    
    if [[ -n "$years_count" && -n "$output_dir" ]]; then
        # 批量下载模式
        if [[ "$pdf_mode" == "true" ]]; then
            progress "批量下载 A 股 PDF：$code (最近 $years_count 年)"
            "$SCRIPT_DIR/fetch_a_shares.sh" "$code" --years "$years_count" --pdf --output-dir "$output_dir" $([[ "$show_progress" == "true" ]] && echo "--progress")
        else
            progress "批量下载 A 股数据：$code (最近 $years_count 年)"
            "$SCRIPT_DIR/fetch_a_shares.sh" "$code" --years "$years_count" --format "$format" --output-dir "$output_dir"
        fi
    else
        # 单次查询模式
        info "正在获取 A 股数据：$code"
        "$SCRIPT_DIR/fetch_a_shares.sh" "$code" "$year" "$quarter"
    fi
}

#######################################
# 获取美股财报数据（Yahoo Finance API）
# 参数：股票代码，年份，季度，格式，输出目录，年份数
#######################################
fetch_us_stocks_earnings() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    local format="$4"
    local output_dir="$5"
    local years_count="$6"
    
    if [[ -n "$years_count" && -n "$output_dir" ]]; then
        # 批量下载模式
        progress "批量下载美股数据：$code (最近 $years_count 年)"
        "$SCRIPT_DIR/fetch_us_stocks.sh" "$code" --years "$years_count" --format "$format" --output-dir "$output_dir"
    else
        # 单次查询模式
        info "正在获取美股数据：$code"
        "$SCRIPT_DIR/fetch_us_stocks.sh" "$code" "$year" "$quarter"
    fi
}

#######################################
# 获取港股财报数据（HKEX 披露易）
# 参数：股票代码，年份，季度，格式，输出目录，年份数
#######################################
fetch_hk_stocks_earnings() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    local format="$4"
    local output_dir="$5"
    local years_count="$6"
    
    if [[ -n "$years_count" && -n "$output_dir" ]]; then
        # 批量下载模式
        progress "批量下载港股数据：$code (最近 $years_count 年)"
        "$SCRIPT_DIR/fetch_hk_stocks.sh" "$code" --years "$years_count" --format "$format" --output-dir "$output_dir"
    else
        # 单次查询模式
        info "正在获取港股数据：$code"
        "$SCRIPT_DIR/fetch_hk_stocks.sh" "$code" "$year" "$quarter"
    fi
}

#######################################
# 主函数
#######################################
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quarter)
                QUARTER="$2"
                shift 2
                ;;
            --year)
                YEAR="$2"
                shift 2
                ;;
            --market)
                MARKET="$2"
                shift 2
                ;;
            --years)
                YEARS="$2"
                DOWNLOAD_MODE=true
                shift 2
                ;;
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --pdf)
                PDF_MODE=true
                FORMAT="pdf"
                DOWNLOAD_MODE=true
                shift
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                DOWNLOAD_MODE=true
                shift 2
                ;;
            --progress)
                SHOW_PROGRESS=true
                DOWNLOAD_MODE=true
                shift
                ;;
            --akshare)
                USE_AKSHARE=true
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
                if [[ -z "$STOCK_CODE" ]]; then
                    STOCK_CODE="$1"
                else
                    error "多余的参数：$1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 验证股票代码
    if [[ -z "$STOCK_CODE" ]]; then
        error "请提供股票代码"
        show_help
        exit 1
    fi
    
    # 验证批量下载参数
    if [[ "$DOWNLOAD_MODE" == true ]]; then
        if [[ -z "$YEARS" ]]; then
            error "批量下载模式需要指定 --years 参数"
            exit 1
        fi
        if [[ -z "$OUTPUT_DIR" ]]; then
            error "批量下载模式需要指定 --output-dir 参数"
            exit 1
        fi
        if [[ "$PDF_MODE" != true && ! "$FORMAT" =~ ^(json|csv)$ ]]; then
            error "不支持的格式：$FORMAT (支持：json, csv)"
            exit 1
        fi
        # 创建输出目录
        mkdir -p "$OUTPUT_DIR"
    fi
    
    # 检测或验证市场
    if [[ -z "$MARKET" ]]; then
        MARKET=$(detect_market "$STOCK_CODE") || {
            error "无法识别股票代码格式：$STOCK_CODE"
            echo "请明确指定 --market 参数 (A|US|HK)"
            exit 1
        }
        if [[ "$DOWNLOAD_MODE" != true ]]; then
            info "自动检测到市场类型：$MARKET"
        fi
    fi
    
    # 根据市场类型获取数据
    case "$MARKET" in
        A)
            fetch_a_shares_earnings "$STOCK_CODE" "$YEAR" "$QUARTER" "$FORMAT" "$OUTPUT_DIR" "$YEARS" "$PDF_MODE" "$SHOW_PROGRESS"
            ;;
        US)
            if [[ "$USE_AKSHARE" == true ]]; then
                fetch_a_shares_earnings_akshare "$STOCK_CODE" "$YEAR" "$QUARTER" "$FORMAT" "$OUTPUT_DIR" "$YEARS"
            else
                fetch_us_stocks_earnings "$STOCK_CODE" "$YEAR" "$QUARTER" "$FORMAT" "$OUTPUT_DIR" "$YEARS"
            fi
            ;;
        HK)
            if [[ "$USE_AKSHARE" == true ]]; then
                fetch_a_shares_earnings_akshare "$STOCK_CODE" "$YEAR" "$QUARTER" "$FORMAT" "$OUTPUT_DIR" "$YEARS"
            else
                fetch_hk_stocks_earnings "$STOCK_CODE" "$YEAR" "$QUARTER" "$FORMAT" "$OUTPUT_DIR" "$YEARS"
            fi
            ;;
        A)
            if [[ "$USE_AKSHARE" == true ]]; then
                fetch_a_shares_earnings_akshare "$STOCK_CODE" "$YEAR" "$QUARTER" "$FORMAT" "$OUTPUT_DIR" "$YEARS" "$PDF_MODE" "$SHOW_PROGRESS"
            else
                fetch_a_shares_earnings "$STOCK_CODE" "$YEAR" "$QUARTER" "$FORMAT" "$OUTPUT_DIR" "$YEARS" "$PDF_MODE" "$SHOW_PROGRESS"
            fi
            ;;
        *)
            error "不支持的市场类型：$MARKET"
            exit 1
            ;;
    esac
    
    if [[ "$DOWNLOAD_MODE" != true ]]; then
        echo ""
        info "数据来源可能有所延迟，请以官方披露为准"
    fi
}

#######################################
# 使用 akshare 获取数据（新增功能）
# 参数：股票代码，年份，季度，格式，输出目录，年份数，PDF 模式，进度显示
#######################################
fetch_a_shares_earnings_akshare() {
    local code="$1"
    local year="$2"
    local quarter="$3"
    local format="$4"
    local output_dir="$5"
    local years_count="$6"
    local pdf_mode="${7:-false}"
    local show_progress="${8:-false}"
    
    # 检查 akshare 脚本是否存在
    if [[ ! -f "$AKSHARE_SCRIPT" ]]; then
        error "akshare Python 脚本不存在：$AKSHARE_SCRIPT"
        error "请确认安装了 akshare 依赖"
        return 1
    fi
    
    # 检查 conda 环境
    if ! conda env list | grep -q "$CONDA_ENV"; then
        warn "未找到 conda 环境 '$CONDA_ENV'"
        warn "请先运行以下命令创建环境："
        warn "  conda env create -f $SCRIPT_DIR/../environment.yml"
        warn "或使用 pip："
        warn "  pip install akshare pandas -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host=mirrors.aliyun.com"
    fi
    
    if [[ -n "$years_count" && -n "$output_dir" ]]; then
        # 批量下载模式
        if [[ "$pdf_mode" == "true" ]]; then
            progress "批量下载 A 股 PDF：$code (最近 $years_count 年)"
            "$SCRIPT_DIR/fetch_a_shares.sh" "$code" --years "$years_count" --pdf --output-dir "$output_dir" $([[ "$show_progress" == "true" ]] && echo "--progress")
        else
            progress "批量下载 A 股数据（akshare）：$code (最近 $years_count 年)"
            python "$AKSHARE_SCRIPT" "$code" --market A --output-dir "$output_dir" --output-format "$format" --earnings
        fi
    else
        # 单次查询模式
        if [[ "$DOWNLOAD_MODE" != "true" ]]; then
            info "正在获取数据（akshare）：$code"
            python "$AKSHARE_SCRIPT" "$code" --market "$MARKET" --output-dir "$output_dir" --output-format "$format" --info
        fi
    fi
}

# 运行主函数
main "$@"
