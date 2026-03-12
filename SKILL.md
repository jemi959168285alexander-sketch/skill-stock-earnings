# stock-earnings Skill

获取上市公司财报数据。支持 A 股（东方财富/雪球/akshare API）、美股（SEC EDGAR/Yahoo Finance/akshare）、港股（HKEX 披露易/akshare）。

## 激活条件

当用户提到以下关键词时激活此技能：
- 财报、财务报告、earnings、financial report
- 季度报告、年报、季报
- 上市公司财务数据
- 具体股票代码查询财报（如 AAPL 财报、腾讯财报）
- 下载财报、批量下载财报
- 股票历史数据、股价查询
- 财务指标、资产负债表、利润表

## 命令格式

### 基本查询
```bash
/stock-earnings <股票代码> [--quarter Q1|Q2|Q3|Q4] [--year YYYY] [--market A|US|HK]
```

### 批量下载
```bash
/stock-earnings <股票代码> --years N --format <格式> --output-dir <目录>
/stock-earnings <股票代码> --years N --pdf --output-dir <目录>
```

### akshare 直接调用
```bash
python scripts/fetch_data_akshare.py <股票代码> [--market A|US|HK] [--start-date YYYYMMDD] [--end-date YYYYMMDD] [--output-format json|csv]
python scripts/fetch_data_akshare.py <股票代码> --earnings [--years N] [--output-dir <目录>]
```

### 参数说明

#### 基本查询参数
- `<股票代码>`: 必填。股票代码（如 AAPL、600519、0700）
- `--quarter`: 可选。季度（Q1-Q4），默认为最新季度
- `--year`: 可选。年份，默认为最新年份
- `--market`: 可选。市场类型（A=A 股，US=美股，HK=港股），自动检测时可省略

#### 批量下载参数
- `--years N`: 必填。下载最近 N 年的财报（如 --years 3 下载最近 3 年）
- `--format <格式>`: 可选。输出格式（json/csv），默认 json
- `--pdf`: 可选。下载官方财报 PDF（仅支持 A 股，从巨潮资讯网）
- `--output-dir <目录>`: 必填。输出目录，自动创建股票/年份文件夹结构
- `--progress`: 可选。显示下载进度（批量下载时自动启用）

### 示例

#### 单次查询
```bash
# 查询苹果最新财报
/stock-earnings AAPL

# 查询茅台 2024 年 Q3 财报
/stock-earnings 600519 --quarter Q3 --year 2024

# 查询腾讯控股年报
/stock-earnings 0700 --market HK

# 查询特斯拉 2023 年报
/stock-earnings TSLA --year 2023
```

#### akshare 示例
```bash
# 使用 akshare 查询A股历史数据
python scripts/fetch_data_akshare.py 000001 --market A --start-date 20230101 --end-date 20231231

# 使用 akshare 查询美股数据
python scripts/fetch_data_akshare.py AAPL --market US

# 使用 akshare 查询港股数据
python scripts/fetch_data_akshare.py 0700 --market HK

# 使用 akshare 查询财报数据
python scripts/fetch_data_akshare.py 600519 --earnings --years 3 --output-dir ./earnings
```

#### 批量下载
```bash
# 下载苹果最近 3 年财报（JSON 格式）
/stock-earnings AAPL --years 3 --format json --output-dir ./earnings

# 下载茅台最近 5 年财报（CSV 格式）
/stock-earnings 600519 --years 5 --format csv --output-dir ./a_shares

# 下载茅台最近 3 年财报 PDF（官方文件）
/stock-earnings 600519 --years 3 --pdf --output-dir ./pdfs

# 下载五粮液最近 5 年财报 PDF（带进度显示）
/stock-earnings 000858 --years 5 --pdf --output-dir ./earnings --progress

# 下载腾讯最近 2 年财报
/stock-earnings 0700 --years 2 --format json --output-dir ./hk_stocks

# 下载特斯拉最近 10 年财报（JSON 格式）
/stock-earnings TSLA --years 10 --format json --output-dir ./us_stocks
```

## 数据来源

### akshare（新增）
- Python 库，提供实时股票数据
- 支持 A 股、美股、港股历史数据
- 提供财报数据功能

### A 股
- 东方财富 API (https://datacenter.eastmoney.com) - 财务数据
- 雪球 API (https://xueqiu.com) - 补充数据
- 巨潮资讯网 (http://www.cninfo.com.cn/) - 官方财报 PDF
- akshare (https://akshare.akshare.xyz/) - 历史数据和财报数据

### 美股
- SEC EDGAR (https://www.sec.gov/edgar)
- Yahoo Finance API
- akshare (https://akshare.akshare.xyz/) - 历史数据

### 港股
- HKEX 披露易 (https://www.hkexnews.hk)
- Yahoo Finance API（备选）
- akshare (https://akshare.akshare.xyz/) - 历史数据

## 输出格式

### 单次查询输出
返回结构化的财报数据，包括：
- 公司信息（名称、代码、市场）
- 报告期
- 核心财务指标（营收、净利润、EPS 等）
- 同比/环比变化
- 财报文件链接（如有）

### 批量下载输出
按股票和年份组织文件夹结构：
```
output-dir/
├── US_AAPL/
│   ├── AAPL_full_data.json
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
    ├── HKEX_links.txt
    └── 2024/
        └── 0700_2024_earnings.json
```

## 支持的下载格式

| 格式 | 说明 | 适用场景 |
|------|------|----------|
| json | 结构化 JSON 数据，包含完整财务指标 | 程序处理、数据分析 |
| csv | CSV 表格格式，包含利润表等数据 | Excel 分析、数据导入 |
| pdf | 官方财报 PDF 文件（仅 A 股） | 阅读官方财报原文、存档 |

### PDF 下载说明

- **仅支持 A 股**：目前 PDF 下载功能仅支持 A 股上市公司
- **数据源**：巨潮资讯网 (http://www.cninfo.com.cn/) - 中国证监会指定信息披露网站
- **文件命名**：`股票代码_年份_公告标题.pdf`
- **支持类型**：年度报告、半年度报告、季度报告等财报文件
- **自动去重**：同一年份的同类报告自动去重

### akshare 输出格式

| 格式 | 说明 | 适用场景 |
|------|------|----------|
| json | 结构化 JSON 数据 | 程序处理、数据分析 |
| csv | CSV 表格格式 | Excel 分析、数据导入 |
| parquet | Parquet 格式 | 大数据处理 |

## 注意事项

1. 财报数据可能存在延迟，以官方披露为准
2. 不同市场的财报格式和披露时间不同
3. A 股财报单位为人民币元，美股为美元，港股为港元
4. 部分历史数据可能需要付费 API 获取
5. 批量下载时会自动创建文件夹结构
6. 港股 PDF 财报需通过 HKEX 披露易链接手动下载
7. **PDF 下载仅支持 A 股**，美股和港股暂不支持 PDF 下载
8. PDF 下载依赖巨潮资讯网，如遇网站维护可能暂时不可用
9. 批量下载 PDF 时建议控制年份范围，避免单次下载过多文件

### akshare 注意事项

1. akshare 需要额外安装依赖（见安装说明）
2. akshare 数据源可能有频率限制
3. 部分港股数据可能不完整
4. 历史数据完整性取决于数据源

## 错误处理

- 股票代码无效：提示用户检查代码格式
- 数据不可用：说明原因并提供替代方案
- API 限流：等待后重试或提示用户稍后再试
- 网络错误：提供友好的错误信息
- 批量下载参数缺失：提示必需的 --years 和 --output-dir 参数

### akshare 错误处理

- akshare 未安装：提示用户安装 akshare 依赖
- akshare 环境未创建：提示运行 `conda env create -f environment.yml`
- 数据为空：可能是股票代码不正确或数据源暂时不可用

## 依赖

### 主脚本依赖
- curl (HTTP 请求)
- jq (JSON 解析，可选)
- Python 3 (数据处理)
- Node.js (可选，用于复杂数据处理)

### akshare 依赖
安装 akshare 需要以下 Python 包：
- python >= 3.7
- pandas
- numpy
- matplotlib
- mplfinance
- requests
- beautifulsoup4
- lxml
- pyarrow
- tqdm

安装命令（推荐使用阿里云镜像）：
```bash
# 方式一：使用 conda
conda env create -f environment.yml

# 方式二：使用 pip
pip install akshare pandas mplfinance -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host=mirrors.aliyun.com
```

## 安装

### 基础安装
将本技能目录放置在 OpenClaw 的 skills 目录下：
```bash
cp -r stock-earnings ~/.openclaw/workspace/skills/
```

### akshare 依赖安装
参考上面的依赖安装部分，推荐使用 conda：

```bash
cd ~/.openclaw/workspace/skills/stock-earnings
conda env create -f environment.yml
```

## 更新日志

### v3.0 (新增 akshare 集成)
- ✅ 添加 akshare Python 脚本以获取实时股票数据
- ✅ 支持 A 股、美股、港股历史数据获取
- ✅ 添加财报数据功能（仅 A 股）
- ✅ 提供 conda 环境配置文件 (`environment.yml`)
- ✅ 提供 requirements.txt 作为备选安装方案
- ✅ 保留原有数据源作为 fallback

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

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request 来改进此技能。
