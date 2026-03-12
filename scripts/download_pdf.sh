#!/bin/bash
#
# download_pdf.sh - 从巨潮资讯网下载 A 股财报 PDF
#
# 数据源：巨潮资讯网 (http://www.cninfo.com.cn/)
# 用法：
#   ./download_pdf.sh <股票代码> --years N --output-dir <目录> [--progress]
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# 打印警告信息
#######################################
warn() {
    echo -e "${YELLOW}警告：${NC}$1"
}

#######################################
# 验证 A 股代码格式
#######################################
validate_a_share_code() {
    local code="$1"
    if [[ "$code" =~ ^[0-9]{6}$ ]]; then
        return 0
    fi
    return 1
}

#######################################
# 显示使用说明
#######################################
show_help() {
    cat << EOF
download_pdf - 从巨潮资讯网下载 A 股财报 PDF

用法:
  $0 <股票代码> --years N --output-dir <目录> [--progress]

参数:
  <股票代码>          A 股代码（6 位数字，如 600519）

选项:
  --years N          下载最近 N 年的财报 PDF
  --output-dir <目录> 输出目录
  --progress         显示下载进度
  --help             显示此帮助

示例:
  $0 600519 --years 3 --output-dir ./pdfs
  $0 000858 --years 5 --output-dir ./earnings --progress

EOF
}

#######################################
# 使用 Python 下载 PDF
# 参数：股票代码，年份数，输出目录，是否显示进度
#######################################
download_pdfs() {
    local code="$1"
    local years_count="$2"
    local output_dir="$3"
    local show_progress="$4"
    
    # 创建输出目录
    local stock_dir="$output_dir/A_${code}_PDFs"
    mkdir -p "$stock_dir"
    
    progress "正在从巨潮资讯网获取 $code 的财报 PDF..."
    
    # 使用 Python 脚本处理
    python3 << PYTHON_SCRIPT
import sys
import os
import re
import json
import time
import urllib.request
import urllib.parse
from datetime import datetime
from html import unescape

# 配置
STOCK_CODE = "$code"
YEARS_COUNT = $years_count
OUTPUT_DIR = "$stock_dir"
SHOW_PROGRESS = "$show_progress" == "true"

# 巨潮资讯网 API
CNINFO_SEARCH_URL = "http://www.cninfo.com.cn/new/hisAnnouncement/query"
CNINFO_DETAIL_URL = "http://www.cninfo.com.cn/new/disclosure/detail?plate=sse&stockCode={stock_code}&announcementId={ann_id}"

# 请求头
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Referer": "http://www.cninfo.com.cn/new/commonUrl/pageOfSearch?url=disclosure/list/search&lastPageNumber=1&stock=" + STOCK_CODE,
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "X-Requested-With": "XMLHttpRequest",
}

# 财报类型关键词
REPORT_KEYWORDS = [
    "年度报告", "半年度报告", "季度报告",
    "年报", "半年报", "季报",
    "财务报告", "财务报表",
    "abstract", "annual report", "quarterly report"
]

def log(message, level="info"):
    """打印日志"""
    if SHOW_PROGRESS or level == "error":
        prefix = {
            "info": "  ",
            "success": "✓ ",
            "warning": "⚠ ",
            "error": "✗ "
        }.get(level, "  ")
        print(f"{prefix}{message}")

def get_current_year_range():
    """获取需要下载的年份范围"""
    current_year = datetime.now().year
    return list(range(current_year - YEARS_COUNT, current_year + 1))

def build_search_params(page=1, page_size=30):
    """构建搜索参数"""
    params = {
        "stock": STOCK_CODE,
        "channelId": "",
        "category": "",
        "pageNum": str(page),
        "pageSize": str(page_size),
        "tabName": "fulltext",
    }
    return urllib.parse.urlencode(params)

def search_announcements(page=1, page_size=30):
    """搜索公告"""
    try:
        url = f"{CNINFO_SEARCH_URL}?{build_search_params(page, page_size)}"
        req = urllib.request.Request(url, headers=HEADERS, method="GET")
        
        with urllib.request.urlopen(req, timeout=10) as response:
            data = response.read().decode('utf-8')
            return json.loads(data)
    except Exception as e:
        log(f"搜索 API 请求失败：{e}", "error")
        return None

def extract_pdf_url(announcement_id, stock_code):
    """提取 PDF 下载 URL"""
    # 巨潮资讯网的 PDF 下载 URL 格式
    # http://static.cninfo.com.cn/finalpage/{year}/{announcement_id}.PDF
    # 或者通过详情页面获取
    
    # 尝试直接构造 PDF URL
    year = datetime.now().year
    pdf_url = f"http://static.cninfo.com.cn/finalpage/{year}/{announcement_id}.PDF"
    
    return pdf_url

def is_financial_report(title):
    """判断是否为财报相关公告"""
    title_lower = title.lower()
    for keyword in REPORT_KEYWORDS:
        if keyword.lower() in title_lower:
            # 排除更正、补充等
            if any(exclude in title_lower for exclude in ["更正", "补充", "修订", "摘要"]):
                # 如果是摘要但包含财报关键词，也保留
                if "摘要" in title and any(k in title for k in ["年报摘要", "半年报摘要", "季报摘要"]):
                    return True
                continue
            return True
    return False

def sanitize_filename(name):
    """清理文件名中的非法字符"""
    # 移除非法字符
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    # 替换空格为下划线
    name = re.sub(r'\s+', '_', name)
    # 限制长度
    if len(name) > 100:
        name = name[:100]
    return name

def download_file(url, save_path):
    """下载文件"""
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        
        with urllib.request.urlopen(req, timeout=30) as response:
            content_length = response.headers.get('Content-Length')
            total_size = int(content_length) if content_length else 0
            
            downloaded = 0
            with open(save_path, 'wb') as f:
                while True:
                    chunk = response.read(8192)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    if SHOW_PROGRESS and total_size > 0:
                        percent = (downloaded / total_size) * 100
                        print(f"\r  下载进度：{percent:.1f}%", end='', flush=True)
            
            if SHOW_PROGRESS:
                print()  # 换行
        
        return True
    except Exception as e:
        log(f"下载失败：{e}", "error")
        return False

def main():
    """主函数"""
    log(f"开始下载 {STOCK_CODE} 的财报 PDF（最近 {YEARS_COUNT} 年）")
    
    # 获取年份范围
    year_range = get_current_year_range()
    log(f"年份范围：{min(year_range)} - {max(year_range)}")
    
    # 搜索公告
    all_announcements = []
    page = 1
    max_pages = 10  # 最多搜索 10 页
    
    log("正在搜索公告...")
    
    while page <= max_pages:
        result = search_announcements(page)
        
        if not result or 'announcementList' not in result.get('data', {}):
            log(f"第 {page} 页无数据或请求失败", "warning")
            break
        
        announcements = result['data']['announcementList']
        if not announcements:
            break
        
        all_announcements.extend(announcements)
        
        # 检查是否还有更多页
        total_records = result.get('totalRecordCount', 0)
        if page * 30 >= total_records:
            break
        
        page += 1
        time.sleep(0.5)  # 避免请求过快
    
    log(f"共找到 {len(all_announcements)} 条公告")
    
    # 过滤财报相关的公告
    financial_reports = []
    for ann in all_announcements:
        title = ann.get('announcementTitle', '')
        announcement_time = ann.get('announcementTime', 0)
        
        # 转换为年份
        if announcement_time:
            ann_year = datetime.fromtimestamp(announcement_time / 1000).year
        else:
            continue
        
        # 检查年份和类型
        if ann_year in year_range and is_financial_report(title):
            financial_reports.append(ann)
    
    log(f"找到 {len(financial_reports)} 条财报相关公告")
    
    if not financial_reports:
        log("未找到符合条件的财报 PDF", "warning")
        return
    
    # 去重（按年份和类型）
    seen = set()
    unique_reports = []
    for report in financial_reports:
        title = report.get('announcementTitle', '')
        ann_time = report.get('announcementTime', 0)
        ann_year = datetime.fromtimestamp(ann_time / 1000).year if ann_time else 0
        
        # 提取报告类型
        report_type = "unknown"
        if "年报" in title or "年度报告" in title:
            report_type = "annual"
        elif "半年报" in title or "半年度" in title:
            report_type = "semiannual"
        elif "一季报" in title or "第一季度" in title:
            report_type = "q1"
        elif "中报" in title or "半年度" in title:
            report_type = "semiannual"
        elif "三季报" in title or "第三季度" in title:
            report_type = "q3"
        elif "季报" in title or "季度" in title:
            report_type = "quarterly"
        
        key = f"{ann_year}_{report_type}"
        if key not in seen:
            seen.add(key)
            unique_reports.append(report)
    
    # 按年份排序
    unique_reports.sort(key=lambda x: x.get('announcementTime', 0), reverse=True)
    
    log(f"去重后共 {len(unique_reports)} 份财报")
    print()
    
    # 下载 PDF
    downloaded_count = 0
    for i, report in enumerate(unique_reports, 1):
        ann_id = report.get('announcementId', '')
        title = report.get('announcementTitle', '未知标题')
        ann_time = report.get('announcementTime', 0)
        ann_year = datetime.fromtimestamp(ann_time / 1000).year if ann_time else 0
        
        # 构建文件名
        safe_title = sanitize_filename(title)
        filename = f"{STOCK_CODE}_{ann_year}_{safe_title}.pdf"
        save_path = os.path.join(OUTPUT_DIR, filename)
        
        # 跳过已下载的文件
        if os.path.exists(save_path):
            log(f"[{i}/{len(unique_reports)}] 已存在：{filename}", "info")
            downloaded_count += 1
            continue
        
        # 构建 PDF URL
        # 尝试多种 URL 格式
        pdf_urls = [
            f"http://static.cninfo.com.cn/finalpage/{ann_year}/{ann_id}.PDF",
            f"http://static.cninfo.com.cn/finalpage/2024/{ann_id}.PDF",
            f"http://static.cninfo.com.cn/finalpage/2023/{ann_id}.PDF",
        ]
        
        log(f"[{i}/{len(unique_reports)}] 下载：{title[:50]}...")
        
        downloaded = False
        for pdf_url in pdf_urls:
            if download_file(pdf_url, save_path):
                # 检查文件是否有效（大于 1KB）
                if os.path.exists(save_path) and os.path.getsize(save_path) > 1024:
                    log(f"  ✓ 保存到：{filename}", "success")
                    downloaded = True
                    downloaded_count += 1
                    break
                else:
                    # 文件太小，删除
                    if os.path.exists(save_path):
                        os.remove(save_path)
        
        if not downloaded:
            log(f"  ✗ 下载失败：{title[:50]}", "error")
        
        # 避免请求过快
        time.sleep(1)
    
    print()
    log(f"下载完成！共下载 {downloaded_count}/{len(unique_reports)} 份 PDF")
    log(f"保存目录：{OUTPUT_DIR}")

if __name__ == "__main__":
    main()
PYTHON_SCRIPT
    
    return 0
}

#######################################
# 主函数
#######################################
main() {
    local code=""
    local years_count=""
    local output_dir=""
    local show_progress="false"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --years)
                years_count="$2"
                shift 2
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
    
    if ! validate_a_share_code "$code"; then
        error "无效的 A 股代码格式：$code"
        echo "A 股代码应为 6 位数字（如 600519）"
        exit 1
    fi
    
    if [[ -z "$years_count" ]]; then
        error "需要指定 --years 参数"
        show_help
        exit 1
    fi
    
    if [[ -z "$output_dir" ]]; then
        error "需要指定 --output-dir 参数"
        show_help
        exit 1
    fi
    
    # 去除代码中的市场后缀
    code="${code%.*}"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📄 巨潮资讯网 PDF 下载${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 下载 PDF
    download_pdfs "$code" "$years_count" "$output_dir" "$show_progress"
}

# 运行主函数
main "$@"
