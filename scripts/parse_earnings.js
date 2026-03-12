#!/usr/bin/env node
/**
 * parse_earnings.js - 财报数据解析工具
 * 
 * 用于解析和格式化来自不同数据源的财报数据
 * 支持 A 股、美股、港股的数据格式转换
 */

const fs = require('fs');
const path = require('path');

/**
 * 财报数据类
 */
class EarningsData {
    constructor() {
        this.company = {
            name: '',
            code: '',
            market: '',
            exchange: ''
        };
        this.reportPeriod = {
            year: null,
            quarter: null,
            fiscalYearEnd: null,
            reportDate: null,
            publishDate: null
        };
        this.metrics = {
            // 营收相关
            revenue: null,
            revenueGrowthYoY: null,
            revenueGrowthQoQ: null,
            
            // 利润相关
            grossProfit: null,
            grossMargin: null,
            operatingIncome: null,
            operatingMargin: null,
            netIncome: null,
            netMargin: null,
            
            // 每股数据
            eps: null,
            epsDiluted: null,
            bookValuePerShare: null,
            
            // 其他指标
            totalAssets: null,
            totalLiabilities: null,
            shareholdersEquity: null,
            cashAndEquivalents: null,
            totalDebt: null,
            
            // 现金流
            operatingCashFlow: null,
            freeCashFlow: null,
            capitalExpenditure: null
        };
        this.files = {
            report: null,
            presentation: null,
            pressRelease: null
        };
    }

    /**
     * 格式化货币值
     * @param {number} value - 数值
     * @param {string} currency - 货币单位
     * @returns {string} 格式化后的字符串
     */
    formatCurrency(value, currency = 'CNY') {
        if (value === null || value === undefined) return 'N/A';
        
        const symbols = {
            'CNY': '¥',
            'USD': '$',
            'HKD': 'HK$'
        };
        
        const symbol = symbols[currency] || currency;
        
        // 根据数值大小选择合适的单位
        if (Math.abs(value) >= 1e9) {
            return `${symbol}${(value / 1e9).toFixed(2)}B`;
        } else if (Math.abs(value) >= 1e6) {
            return `${symbol}${(value / 1e6).toFixed(2)}M`;
        } else if (Math.abs(value) >= 1e3) {
            return `${symbol}${(value / 1e3).toFixed(2)}K`;
        } else {
            return `${symbol}${value.toFixed(2)}`;
        }
    }

    /**
     * 格式化百分比
     * @param {number} value - 数值（小数形式，如 0.15 表示 15%）
     * @returns {string} 格式化后的百分比字符串
     */
    formatPercent(value) {
        if (value === null || value === undefined) return 'N/A';
        return `${(value * 100).toFixed(2)}%`;
    }

    /**
     * 计算同比增长率
     * @param {number} current - 当前值
     * @param {number} previous - 去年同期值
     * @returns {number|null} 增长率
     */
    calculateYoYGrowth(current, previous) {
        if (current === null || previous === null || previous === 0) return null;
        return (current - previous) / previous;
    }

    /**
     * 计算环比增长率
     * @param {number} current - 当前值
     * @param {number} previous - 上期值
     * @returns {number|null} 增长率
     */
    calculateQoQGrowth(current, previous) {
        if (current === null || previous === null || previous === 0) return null;
        return (current - previous) / previous;
    }

    /**
     * 输出格式化的财报数据
     * @param {string} format - 输出格式 (text|json|markdown)
     * @returns {string} 格式化后的输出
     */
    toString(format = 'text') {
        switch (format) {
            case 'json':
                return JSON.stringify(this, null, 2);
            case 'markdown':
                return this.toMarkdown();
            case 'text':
            default:
                return this.toText();
        }
    }

    /**
     * 输出文本格式
     * @returns {string} 文本格式输出
     */
    toText() {
        const lines = [];
        const c = this.company;
        const m = this.metrics;
        const r = this.reportPeriod;

        lines.push(`📊 财报数据 - ${c.name} (${c.code})`);
        lines.push('━'.repeat(50));
        lines.push(`市场：${c.market} (${c.exchange || 'N/A'})`);
        
        if (r.year && r.quarter) {
            lines.push(`报告期：${r.year}年 ${r.quarter}`);
        } else if (r.year) {
            lines.push(`报告期：${r.year}财年`);
        }
        
        if (r.reportDate) {
            lines.push(`截止日：${r.reportDate}`);
        }
        if (r.publishDate) {
            lines.push(`发布日：${r.publishDate}`);
        }
        
        lines.push('');
        lines.push('核心指标:');
        
        if (m.revenue !== null) {
            const growth = m.revenueGrowthYoY !== null 
                ? ` (同比${m.revenueGrowthYoY >= 0 ? '+' : ''}${(m.revenueGrowthYoY * 100).toFixed(1)}%)` 
                : '';
            lines.push(`  营收：${this.formatCurrency(m.revenue)}${growth}`);
        }
        
        if (m.netIncome !== null) {
            const growth = m.netIncome !== null && m.revenue !== null
                ? ` (净利率${this.formatPercent(m.netIncome / m.revenue)})`
                : '';
            lines.push(`  净利润：${this.formatCurrency(m.netIncome)}${growth}`);
        }
        
        if (m.eps !== null) {
            lines.push(`  EPS: ${this.formatCurrency(m.eps)}`);
        }
        
        if (m.grossMargin !== null) {
            lines.push(`  毛利率：${this.formatPercent(m.grossMargin)}`);
        }
        
        if (m.operatingMargin !== null) {
            lines.push(`  营业利润率：${this.formatPercent(m.operatingMargin)}`);
        }

        // 添加现金流信息
        if (m.operatingCashFlow !== null || m.freeCashFlow !== null) {
            lines.push('');
            lines.push('现金流:');
            if (m.operatingCashFlow !== null) {
                lines.push(`  经营现金流：${this.formatCurrency(m.operatingCashFlow)}`);
            }
            if (m.freeCashFlow !== null) {
                lines.push(`  自由现金流：${this.formatCurrency(m.freeCashFlow)}`);
            }
        }

        // 添加财报文件链接
        if (this.files.report || this.files.pressRelease) {
            lines.push('');
            lines.push('财报文件:');
            if (this.files.report) {
                lines.push(`  - 财报原文：${this.files.report}`);
            }
            if (this.files.pressRelease) {
                lines.push(`  - 新闻稿：${this.files.pressRelease}`);
            }
        }

        return lines.join('\n');
    }

    /**
     * 输出 Markdown 格式
     * @returns {string} Markdown 格式输出
     */
    toMarkdown() {
        const c = this.company;
        const m = this.metrics;
        const r = this.reportPeriod;

        let md = `## 📊 财报数据 - ${c.name} (${c.code})\n\n`;
        md += `| 项目 | 值 |\n`;
        md += `|------|-----|\n`;
        md += `| 市场 | ${c.market} ${c.exchange ? `(${c.exchange})` : ''} |\n`;
        
        if (r.year) {
            md += `| 财年 | ${r.year} |\n`;
        }
        if (r.quarter) {
            md += `| 季度 | ${r.quarter} |\n`;
        }
        if (r.reportDate) {
            md += `| 报告截止日 | ${r.reportDate} |\n`;
        }

        md += `\n### 核心财务指标\n\n`;
        md += `| 指标 | 数值 | 同比变化 |\n`;
        md += `|------|------|----------|\n`;
        
        if (m.revenue !== null) {
            const growth = m.revenueGrowthYoY !== null 
                ? `${m.revenueGrowthYoY >= 0 ? '+' : ''}${(m.revenueGrowthYoY * 100).toFixed(1)}%` 
                : '-';
            md += `| 营收 | ${this.formatCurrency(m.revenue)} | ${growth} |\n`;
        }
        
        if (m.netIncome !== null) {
            md += `| 净利润 | ${this.formatCurrency(m.netIncome)} | - |\n`;
        }
        
        if (m.eps !== null) {
            md += `| EPS | ${this.formatCurrency(m.eps)} | - |\n`;
        }
        
        if (m.grossMargin !== null) {
            md += `| 毛利率 | ${this.formatPercent(m.grossMargin)} | - |\n`;
        }

        return md;
    }
}

/**
 * 解析东方财富 A 股数据
 * @param {Object} data - 原始数据
 * @returns {EarningsData} 解析后的财报数据
 */
function parseEastMoney(data) {
    const earnings = new EarningsData();
    
    try {
        const item = data.result?.data?.[0];
        if (!item) {
            throw new Error('无数据');
        }

        earnings.company = {
            name: item.SECURITY_NAME_ABBR || '',
            code: item.SECURITY_CODE || '',
            market: 'A',
            exchange: item.EXCHANGE_NAME || ''
        };

        earnings.reportPeriod = {
            reportDate: item.TRADE_DATE || null,
            year: item.TRADE_DATE ? new Date(item.TRADE_DATE).getFullYear() : null
        };

        earnings.metrics = {
            revenue: item.TOTAL_OPERATE_INCOME || null,
            netIncome: item.PARENT_NETPROFIT || null,
            eps: item.BASIC_EPS || null,
            grossProfit: item.TOTAL_OPERATE_COST ? 
                (item.TOTAL_OPERATE_INCOME - item.TOTAL_OPERATE_COST) : null
        };

    } catch (error) {
        console.error('解析东方财富数据失败:', error.message);
    }

    return earnings;
}

/**
 * 解析 Yahoo Finance 数据
 * @param {Object} data - 原始数据
 * @returns {EarningsData} 解析后的财报数据
 */
function parseYahooFinance(data) {
    const earnings = new EarningsData();
    
    try {
        const result = data.quoteSummary || {};
        
        // 获取财务数据
        if (result.financialData) {
            const fd = result.financialData;
            
            earnings.metrics.revenue = fd.totalRevenue?.raw || null;
            earnings.metrics.grossProfit = fd.grossProfits?.raw || null;
            earnings.metrics.netIncome = fd.netIncomeToCommon?.raw || null;
            earnings.metrics.operatingCashFlow = fd.operatingCashflow?.raw || null;
            earnings.metrics.freeCashFlow = fd.freeCashflow?.raw || null;
            
            // 计算毛利率
            if (earnings.metrics.revenue && earnings.metrics.grossProfit) {
                earnings.metrics.grossMargin = 
                    earnings.metrics.grossProfit / earnings.metrics.revenue;
            }
        }

        // 获取收益数据
        if (result.earnings) {
            const earningsData = result.earnings;
            if (earningsData.earningsChart?.currentQuarterEstimate) {
                earnings.metrics.eps = earningsData.earningsChart.currentQuarterEstimate;
            }
        }

    } catch (error) {
        console.error('解析 Yahoo Finance 数据失败:', error.message);
    }

    return earnings;
}

/**
 * 主函数 - 命令行接口
 */
function main() {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log('用法：parse_earnings.js <command> [options]');
        console.log('');
        console.log('命令:');
        console.log('  parse-eastmoney <json_file>  - 解析东方财富数据');
        console.log('  parse-yahoo <json_file>      - 解析 Yahoo Finance 数据');
        console.log('  format <json_file>           - 格式化财报数据');
        console.log('');
        process.exit(0);
    }

    const command = args[0];
    const file = args[1];

    if (!file) {
        console.error('错误：请提供 JSON 文件路径');
        process.exit(1);
    }

    let data;
    try {
        const content = fs.readFileSync(file, 'utf8');
        data = JSON.parse(content);
    } catch (error) {
        console.error(`错误：无法读取或解析文件 - ${error.message}`);
        process.exit(1);
    }

    let earnings;
    switch (command) {
        case 'parse-eastmoney':
            earnings = parseEastMoney(data);
            console.log(earnings.toString('text'));
            break;
        case 'parse-yahoo':
            earnings = parseYahooFinance(data);
            console.log(earnings.toString('text'));
            break;
        case 'format':
            // 假设文件已经是 EarningsData 格式
            earnings = new EarningsData();
            Object.assign(earnings, data);
            console.log(earnings.toString('text'));
            break;
        default:
            console.error(`未知命令：${command}`);
            process.exit(1);
    }
}

// 导出模块供其他脚本使用
module.exports = {
    EarningsData,
    parseEastMoney,
    parseYahooFinance
};

// 如果是直接执行则运行主函数
if (require.main === module) {
    main();
}
