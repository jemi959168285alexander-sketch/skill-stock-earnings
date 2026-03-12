# stock-earnings

OpenClaw 技能：获取上市公司财报数据。

## 功能特性

- ✅ **多市场支持**: A 股、美股、港股
- ✅ **多数据源**: 东方财富、雪球、SEC EDGAR、Yahoo Finance、HKEX 披露易、巨潮资讯网
- ✅ **历史数据**: 支持查询指定年份和季度的财报
- ✅ **批量下载**: 支持下载最近 N 年的财报数据
- ✅ **多格式输出**: JSON、CSV、PDF（官方文件）
- ✅ **自动组织**: 批量下载时自动创建股票/年份文件夹结构
- ✅ **进度显示**: 批量下载时显示下载进度
- ✅ **结构化输出**: 清晰的财报数据展示
- ✅ **错误处理**: 完善的异常处理和用户提示
- ✅ **PDF 下载**: A 股可从巨潮资讯网下载官方财报 PDF
- ✅ **akshare 集成**: 使用 akshare 库获取实时股票数据（Python）

## 安装

### 基础安装

将本技能目录放置在 OpenClaw 的 skills 目录下：

```bash
# 假设 OpenClaw workspace 在 ~/.openclaw/workspace
cp -r stock-earnings ~/.openclaw/workspace/skills/
```

### akshare 依赖安装（推荐）

#### 方式一：使用 conda（推荐）

```bash
cd ~/.openclaw/workspace/skills/stock-earnings

# 创建 conda 环境
conda env create -f environment.yml

# 或更新现有环境
conda env update -f environment.yml --prune
```

#### 方式二：使用 pip

```bash
pip install akshare pandas mplfinance -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host=mirrors.aliyun.com
```

#### 验证安装

```bash
# 测试 akshare 是否正常工作
python scripts/fetch_data_akshare.py 000001 --market A
```

## 使用方法

### 基本查询

```bash
# 查询最新财报
/stock-earnings <股票代码>

# 示例
/stock-earnings AAPL      # 苹果
/stock-earnings 600519    # 贵州茅台
/stock-earnings 0700      # 腾讯控股
```

### 指定报告期

```bash
# 查询特定季度
/stock-earnings AAPL --quarter Q4

# 查询特定年份
/stock-earnings TSLA --year 2023

# 查询特定年份季度
/stock-earnings 600519 --year 2024 --quarter Q3
```

### 指定市场

```bash
# 强制指定市场类型
/stock-earnings BABA --market US    # 阿里巴巴（美股）
/stock-earnings 9988 --market HK    # 阿里巴巴（港股）
```

### 使用 akshare 数据源

```bash
# 使用 akshare 获取 A 股数据
/stock-earnings 600519 --akshare

# 使用 akshare 获取美股数据
/stock-earnings AAPL --market US --akshare

# 使用 akshare 获取港股数据
/stock-earnings 0700 --market HK --akshare
```

### 批量下载（数据格式）

```bash
# 下载最近 3 年财报（JSON 格式）
/stock-earnings AAPL --years 3 --format json --output-dir ./earnings

# 下载最近 5 年财报（CSV 格式）
/stock-earnings 600519 --years 5 --format csv --output-dir ./a_shares

# 下载最近 2 年港股财报
/stock-earnings 0700 --years 2 --format json --output-dir ./hk_stocks

# 下载最近 10 年美股财报
/stock-earnings MSFT --years 10 --format json --output-dir ./us_stocks

# 使用 akshare 下载 A 股财报（JSON 格式）
/stock-earnings 600519 --years 3 --format json --output-dir ./a_shares_akshare --akshare
```

### akshare 单次查询示例

```bash
# 使用 akshare 获取 A 股历史数据
python scripts/fetch_data_akshare.py 000001 --market A --start-date 20230101 --end-date 20231231 --output-format csv

# 使用 akshare 获取美股数据
python scripts/fetch_data_akshare.py AAPL --market US --start-date 20230101 --end-date 20231231 --output-format json

# 使用 akshare 获取港股数据
python scripts/fetch_data_akshare.py 0700 --market HK --output-format json

# 使用 akshare 获取财报数据
python scripts/fetch_data_akshare.py 600519 --earnings --years 3 --output-dir ./earnings
```

### 批量下载（PDF 文件）

```bash
# 下载茅台最近 3 年财报 PDF（官方文件）
/stock-earnings 600519 --years 3 --pdf --output-dir ./pdfs

# 下载五粮液最近 5 年财报 PDF（带进度显示）
/stock-earnings 000858 --years 5 --pdf --output-dir ./earnings --progress

# 下载平安银行最近 2 年财报 PDF
/stock-earnings 000001 --years 2 --pdf --output-dir ./bank_pdfs
```

## 输出示例

### 单次查询输出

```
📊 财报数据 - Apple Inc. (AAPL)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
市场：美股 (NASDAQ)
报告期：2024 财年 Q4 (截至 2024-09-30)

核心指标:
  营收：$94.93B (同比增长 6.1%)
  净利润：$14.74B (同比增长 1.8%)
  EPS: $0.97 (稀释)
  毛利率：46.2%

财报文件:
  - 10-K: https://www.sec.gov/cgi-bin/...
  - 新闻稿：https://investor.apple.com/...
```

### 批量下载输出

```
▶ 批量下载美股数据：AAPL (最近 3 年)
▶ 正在获取财报数据...
找到 3 年的财报数据
  ✓ 2024: ./earnings/US_AAPL/2024/AAPL_2024_earnings.json
  ✓ 2023: ./earnings/US_AAPL/2023/AAPL_2023_earnings.json
  ✓ 2022: ./earnings/US_AAPL/2022/AAPL_2022_earnings.json
  ✓ 完整数据：./earnings/US_AAPL/AAPL_full_data.json

下载完成！数据保存在：./earnings/US_AAPL
```

### 批量下载文件夹结构

```
earnings/
├── US_AAPL/
│   ├── AAPL_full_data.json      # 完整数据
│   ├── 2024/
│   │   └── AAPL_2024_earnings.json
│   ├── 2023/
│   │   └── AAPL_2023_earnings.json
│   └── 2022/
│       └── AAPL_2022_earnings.json
├── A_600519/
│   ├── 600519_full_data.json
│   ├── 2024/
│   │   └── 600519_2024_earnings.json
│   └── ...
└── HK_0700/
    ├── 0700_full_data.json
    ├── HKEX_links.txt           # HKEX 披露易链接
    └── 2024/
        └── 0700_2024_earnings.json
```

## 支持的股票代码格式

| 市场 | 格式示例 | 说明 |
|------|----------|------|
| A 股 | 600519, 000858, 300750 | 6 位数字代码 |
| 美股 | AAPL, TSLA, GOOGL |  ticker symbol |
| 港股 | 0700, 9988, 3690 | 4 位数字代码 |

## 下载格式说明

| 格式 | 文件扩展名 | 内容说明 |
|------|------------|----------|
| json | .json | 结构化 JSON 数据，包含完整财务指标、利润表、资产负债表等 |
| csv | .csv | CSV 表格格式，包含利润表等核心数据，可直接用 Excel 打开 |
| pdf | .pdf | 官方财报 PDF 文件（仅 A 股），从巨潮资讯网下载 |

### PDF 下载功能

**新增功能**：支持从巨潮资讯网下载 A 股上市公司的官方财报 PDF 文件。

- **数据源**：巨潮资讯网 (http://www.cninfo.com.cn/) - 中国证监会指定信息披露网站
- **支持市场**：仅 A 股（美股、港股暂不支持）
- **支持类型**：年度报告、半年度报告、季度报告等财报文件
- **文件命名**：`股票代码_年份_公告标题.pdf`
- **自动去重**：同一年份的同类报告自动去重，避免重复下载
- **进度显示**：使用 `--progress` 参数可显示详细下载进度

## 数据来源说明

### akshare 数据源（新增）
- **akshare**: Python 库，提供 A 股、美股、港股的历史数据和财报数据
- **支持功能**：历史行情、财务报表、股票信息等
- **安装方式**：conda 或 pip

### A 股数据
- **东方财富**: 提供实时和历史的财务数据
- **雪球**: 补充数据和财报原文链接
- **巨潮资讯网**: 官方财报 PDF 下载

### 美股数据
- **SEC EDGAR**: 官方财报文件（10-K, 10-Q, 8-K）
- **Yahoo Finance**: 结构化财务指标

### 港股数据
- **HKEX 披露易**: 官方公告和财报文件
- **Yahoo Finance**: 补充财务数据

## API 限制

### akshare
- 免费接口可能存在频率限制
- 数据更新可能存在延迟
- 部分历史数据可能需要更高权限

### 其他数据源
- 免费 API 可能有调用频率限制
- 部分历史数据需要付费订阅
- 财报披露有固定时间表，非披露期数据可能不完整
- 批量下载建议单次不超过 10 年数据

## 故障排除

### 常见问题

**Q: 提示"股票代码无效"**
A: 检查代码格式是否正确。A 股 6 位数字，美股字母代码，港股 4 位数字。

**Q: 数据加载失败**
A: 可能是网络问题或 API 限流。稍后重试。

**Q: 找不到指定季度的数据**
A: 财报披露有延迟，最新季度数据可能在披露期后 1-2 周才可用。

**Q: 批量下载时提示参数缺失**
A: 批量下载需要同时指定 `--years` 和 `--output-dir` 参数。

**Q: 港股数据只有链接没有实际数据**
A: HKEX 披露易不提供公开 API，港股数据主要通过 Yahoo Finance 获取，部分港股可能无数据，此时会保存 HKEX 查询链接供手动下载。

**Q: akshare 安装失败**
A: 尝试使用阿里云镜像安装：
```bash
pip install akshare -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host=mirrors.aliyun.com
```

**Q: akshare 数据为空**
A: 可能是股票代码格式不正确或数据源暂时不可用。检查代码格式并稍后重试。

**Q: akshare 与原有数据源结果不一致**
A: 不同数据源的数据更新时间可能不同，以官方披露为准。

### 获取帮助

```bash
# 查看主脚本帮助
/stock-earnings --help

# 查看 akshare 脚本帮助
python scripts/fetch_data_akshare.py --help
```

## 开发说明

## 开发说明

### 目录结构

```
stock-earnings/
├── SKILL.md           # 技能定义（激活条件、命令格式）
├── README.md          # 使用说明
├── environment.yml    # conda 环境配置
├── requirements.txt   # pip 依赖列表
├── scripts/
│   ├── stock-earnings.sh    # 主脚本
│   ├── fetch_a_shares.sh    # A 股数据获取（原有）
│   ├── fetch_us_stocks.sh   # 美股数据获取（原有）
│   ├── fetch_hk_stocks.sh   # 港股数据获取（原有）
│   ├── fetch_data_akshare.py # akshare 数据获取（新增）
│   └── download_pdf.sh      # PDF 下载（巨潮资讯网）
└── references/
    └── api_docs.md          # API 文档参考
```

### 添加新数据源

1. 在 `scripts/` 目录创建新的获取脚本
2. 在主脚本中添加调用逻辑
3. 更新 `SKILL.md` 中的数据来源说明

### 测试

```bash
# 测试 A 股数据（原有）
./scripts/fetch_a_shares.sh 600519

# 测试美股数据（原有）
./scripts/fetch_us_stocks.sh AAPL

# 测试港股数据（原有）
./scripts/fetch_hk_stocks.sh 0700

# 测试 akshare 脚本
python scripts/fetch_data_akshare.py 000001 --market A
python scripts/fetch_data_akshare.py AAPL --market US
python scripts/fetch_data_akshare.py 0700 --market HK
python scripts/fetch_data_akshare.py 600519 --earnings

# 测试批量下载
./scripts/fetch_us_stocks.sh AAPL --years 3 --format json --output-dir ./test_output
```

## 更新日志

### v2.1 (新增 PDF 下载功能)
- ✅ 添加 `--pdf` 参数，支持下载官方财报 PDF
- ✅ 数据源：巨潮资讯网 (http://www.cninfo.com.cn/)
- ✅ 支持指定年份范围：`--years 3 --pdf` 下载最近 3 年财报 PDF
- ✅ PDF 保存到指定目录：`--output-dir <DIR>`
- ✅ 显示下载进度：`--progress`
- ✅ 文件名规范化：`股票代码_年份_公告标题.pdf`
- ✅ 自动去重：同一年份的同类报告自动去重

### v2.0 (新增批量下载功能)
- ✅ 添加 `--years` 参数，支持下载指定年份范围的财报
- ✅ 支持多种下载格式：JSON、CSV
- ✅ 批量下载时自动创建文件夹（按股票/年份组织）
- ✅ 添加下载进度显示
- ✅ 优化数据结构和输出格式

### v1.0
- ✅ 支持 A 股、美股、港股财报查询
- ✅ 支持指定年份和季度
- ✅ 多数据源支持
- ✅ 结构化输出

### v3.0 (新增 akshare 集成)
- ✅ 添加 akshare Python 脚本以获取实时股票数据
- ✅ 支持 A 股、美股、港股历史数据获取
- ✅ 添加财报数据功能（仅 A 股）
- ✅ 提供 conda 环境配置文件 (`environment.yml`)
- ✅ 提供 requirements.txt 作为备选安装方案
- ✅ 保留原有数据源作为 fallback

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request 来改进此技能。
