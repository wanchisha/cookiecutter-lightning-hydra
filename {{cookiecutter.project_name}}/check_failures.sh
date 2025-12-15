#!/bin/bash

# ==============================================================================
# 脚本名称: check_failures.sh
# 功能: 扫描 logs 目录，查找由 task_wrapper 标记的失败实验 (.failed 文件)
# 作者: Gemini (Assisted by User)
# ==============================================================================

# 设置默认搜索目录，默认为当前目录下的 logs/
SEARCH_DIR="${1:-logs/}"

# 颜色定义，方便终端查看
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}Starting scan for failed experiments in: ${SEARCH_DIR}...${NC}"
echo "--------------------------------------------------------"

# 计数器
count=0

# 使用 find 命令查找 .failed 文件
# 这里的逻辑是：找到 .failed 文件 -> 获取其所在的目录 -> 处理
while IFS= read -r failed_file; do
    ((count++))
    
    # 获取实验目录路径 (去掉 /.failed 后缀)
    exp_dir=$(dirname "$failed_file")
    
    echo -e "${RED}[FAILED]${NC} Found failure in: ${YELLOW}${exp_dir}${NC}"
    
    # --- 尝试提取 Hydra 的参数覆盖 (Overrides) ---
    # Hydra 会在 .hydra/overrides.yaml 中保存本次运行特有的参数
    overrides_path="${exp_dir}/.hydra/overrides.yaml"
    
    if [ -f "$overrides_path" ]; then
        # 简单读取 yaml 内容 (去掉列表符号，使其更易读)
        # 如果你安装了 yq 工具效果会更好，这里使用通用的 grep/sed 处理
        params=$(cat "$overrides_path" | grep -v "hydra/" | tr -d '\n' | sed 's/- //g')
        echo -e "    ${CYAN}Params:${NC} $params"
    else
        echo -e "    ${CYAN}Params:${NC} (No Hydra config found or not a Hydra run)"
    fi

    # --- 询问是否删除 (可选功能) ---
    # 如果你想做全自动清理，可以把下面的交互逻辑注释掉，或者改为根据参数执行
    # read -p "    Delete this failed folder? (y/n) " -n 1 -r
    # echo
    # if [[ $REPLY =~ ^[Yy]$ ]]; then
    #     rm -rf "$exp_dir"
    #     echo -e "    ${GREEN}Deleted.${NC}"
    # fi

    echo "--------------------------------------------------------"

done < <(find "$SEARCH_DIR" -type f -name ".failed")

# 总结
if [ $count -eq 0 ]; then
    echo -e "${GREEN}Great! No failed experiments found in $SEARCH_DIR.${NC}"
else
    echo -e "Total failed experiments found: ${RED}$count${NC}"
    echo -e "Tip: Check the log files inside these directories for the traceback."
fi