#!/bin/bash

# Cursor AI Generated Code - Start
# 灵活的代码统计脚本 - 支持时间过滤参数
# Flexible Code Statistics Script - Support time filtering parameters

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示使用帮助
show_help() {
    echo -e "${CYAN}代码统计分析工具${NC}"
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -s, --since DATE    分析指定时间之后的提交 (格式: YYYY-MM-DD HH:MM:SS)"
    echo "  -u, --until DATE    分析指定时间之前的提交 (格式: YYYY-MM-DD HH:MM:SS)"
    echo "  -a, --all          分析所有提交"
    echo "  -h, --help         显示此帮助信息"
    echo
    echo "默认行为:"
    echo "  如果不指定任何参数，默认分析 2025-06-01 00:00:00 之后的提交"
    echo
    echo "示例:"
    echo "  $0                                    # 使用默认时间"
    echo "  $0 --since \"2025-06-01 00:00:00\""
    echo "  $0 --since \"2024-01-01\" --until \"2024-12-31\""
    echo "  $0 --all"
}

# 检查是否在git仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}错误: 当前目录不是git仓库${NC}"
    exit 1
fi

# 默认参数
SINCE_DATE=""
UNTIL_DATE=""
ANALYZE_ALL=true
DEFAULT_SINCE_DATE="2025-06-01 00:00:00"

# 保存原始参数数量
ORIGINAL_ARGS_COUNT=$#

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--since)
            SINCE_DATE="$2"
            ANALYZE_ALL=false
            shift 2
            ;;
        -u|--until)
            UNTIL_DATE="$2"
            ANALYZE_ALL=false
            shift 2
            ;;
        -a|--all)
            ANALYZE_ALL=true
            SINCE_DATE=""
            UNTIL_DATE=""
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 如果没有指定任何参数，使用默认时间
if [ $ORIGINAL_ARGS_COUNT -eq 0 ]; then
    SINCE_DATE="$DEFAULT_SINCE_DATE"
    ANALYZE_ALL=false
fi

echo -e "${CYAN}=== 代码统计分析工具 ===${NC}"
echo -e "${YELLOW}正在分析git提交历史...${NC}"

# 构建git log命令
GIT_LOG_CMD="git log --oneline --pretty=format:\"%H|%s\""

if [ "$ANALYZE_ALL" = false ]; then
    if [ -n "$SINCE_DATE" ]; then
        GIT_LOG_CMD="$GIT_LOG_CMD --since=\"$SINCE_DATE\""
        echo -e "${YELLOW}分析时间范围: ${SINCE_DATE} 之后${NC}"
    fi
    if [ -n "$UNTIL_DATE" ]; then
        GIT_LOG_CMD="$GIT_LOG_CMD --until=\"$UNTIL_DATE\""
        echo -e "${YELLOW}分析时间范围: ${UNTIL_DATE} 之前${NC}"
    fi
    if [ -n "$SINCE_DATE" ] && [ -n "$UNTIL_DATE" ]; then
        echo -e "${YELLOW}分析时间范围: ${SINCE_DATE} 到 ${UNTIL_DATE}${NC}"
    fi
else
    echo -e "${YELLOW}分析所有提交${NC}"
fi
echo

# 获取提交
commits=$(eval $GIT_LOG_CMD)

# 检查是否有符合条件的提交
if [ -z "$commits" ]; then
    echo -e "${RED}没有找到符合条件的提交${NC}"
    echo -e "${YELLOW}提示: 请检查时间格式或确认是否有符合条件的提交${NC}"
    exit 0
fi

# 初始化计数器
human_lines=0
cursor_lines=0
total_commits=0
human_commits=0
cursor_commits=0

echo -e "${BLUE}提交详情:${NC}"
echo "----------------------------------------"

# 遍历每个提交
while IFS='|' read -r commit_hash commit_message; do
    if [ -z "$commit_hash" ]; then
        continue
    fi
    
    total_commits=$((total_commits + 1))
    
    # 获取提交时间用于显示
    commit_date=$(git show -s --format="%ci" $commit_hash)
    
    # 获取该提交的代码行数变化（添加行数+删除行数）
    lines_changed=$(git show --numstat $commit_hash 2>/dev/null | awk '
        BEGIN { total = 0 }
        /^[0-9]/ { 
            if ($1 != "-") total += $1
            if ($2 != "-") total += $2
        }
        END { print total }
    ')
    
    # 如果无法获取行数，设为0
    if [ -z "$lines_changed" ] || ! [[ "$lines_changed" =~ ^[0-9]+$ ]]; then
        lines_changed=0
    fi
    
    # 判断提交类型
    if [[ $commit_message == Cursor-Generated* ]] || [[ $commit_message == "Cursor-Generated"* ]]; then
        cursor_lines=$((cursor_lines + lines_changed))
        cursor_commits=$((cursor_commits + 1))
        echo -e "${PURPLE}[AI] ${commit_message:0:50}... (+${lines_changed} 行) ${commit_date:0:16}${NC}"
    else
        # 所有其他提交都归类为human（包括human前缀和无前缀的）
        human_lines=$((human_lines + lines_changed))
        human_commits=$((human_commits + 1))
        if [[ $commit_message == human* ]]; then
            echo -e "${GREEN}[HUMAN] ${commit_message:0:50}... (+${lines_changed} 行) ${commit_date:0:16}${NC}"
        else
            echo -e "${GREEN}[HUMAN] ${commit_message:0:50}... (+${lines_changed} 行) ${commit_date:0:16}${NC}"
        fi
    fi
    
done <<< "$commits"

echo "----------------------------------------"
echo

# 计算总行数和AI率
total_lines=$((human_lines + cursor_lines))

# 使用awk进行浮点数计算
if [ $total_lines -gt 0 ]; then
    ai_rate=$(awk "BEGIN {printf \"%.2f\", $cursor_lines * 100 / $total_lines}")
    human_rate=$(awk "BEGIN {printf \"%.2f\", $human_lines * 100 / $total_lines}")
else
    ai_rate="0.00"
    human_rate="0.00"
fi

# 显示统计结果
echo -e "${CYAN}=== 统计结果 ===${NC}"
echo -e "${GREEN}Human 提交:${NC}"
echo -e "  提交次数: ${human_commits}"
echo -e "  代码行数: ${human_lines}"
echo -e "  占比: ${human_rate}%"
echo

echo -e "${PURPLE}Cursor AI 提交:${NC}"
echo -e "  提交次数: ${cursor_commits}"
echo -e "  代码行数: ${cursor_lines}"
echo -e "  占比: ${ai_rate}%"
echo

echo -e "${BLUE}总计:${NC}"
echo -e "  总提交次数: ${total_commits}"
echo -e "  总代码行数: ${total_lines}"
echo -e "  AI 代码生成率: ${ai_rate}%"
echo

# 生成图形化显示
echo -e "${CYAN}=== 可视化统计 ===${NC}"
if [ $total_lines -gt 0 ]; then
    # 计算条形图长度 (最大50个字符)
    human_bar_length=$(awk "BEGIN {printf \"%.0f\", $human_lines * 50 / $total_lines}")
    cursor_bar_length=$(awk "BEGIN {printf \"%.0f\", $cursor_lines * 50 / $total_lines}")
    
    # 确保长度不为负数
    if [ $human_bar_length -lt 0 ]; then human_bar_length=0; fi
    if [ $cursor_bar_length -lt 0 ]; then cursor_bar_length=0; fi
    
    # 生成条形图
    human_bar=""
    cursor_bar=""
    
    if [ $human_bar_length -gt 0 ]; then
        human_bar=$(printf "%*s" $human_bar_length | tr ' ' '█')
    fi
    
    if [ $cursor_bar_length -gt 0 ]; then
        cursor_bar=$(printf "%*s" $cursor_bar_length | tr ' ' '█')
    fi
    
    echo -e "${GREEN}Human:  [${human_bar}${NC}] ${human_rate}%"
    echo -e "${PURPLE}AI:     [${cursor_bar}${NC}] ${ai_rate}%"
else
    echo "暂无代码统计数据"
fi

echo
echo -e "${YELLOW}提示: 脚本自动识别提交类型${NC}"
echo -e "${YELLOW}AI提交格式: 'Cursor-Generated [描述]'${NC}"
echo -e "${YELLOW}Human提交: 所有其他提交（包括human前缀和普通提交）${NC}"

# Cursor AI Generated Code - End
