#!/bin/bash

# ==============================================================================
# 脚本名称: generate_rerun.sh
# 功能: 扫描失败的实验，提取参数，生成一个可以批量重跑的 Shell 脚本
# 适用: 基于 Hydra 的项目 (如 lightning-hydra-template)
# ==============================================================================

# --- 配置区域 ---
# 默认扫描目录
SEARCH_DIR="${1:-logs/}"
# 生成的目标脚本文件名
OUTPUT_SCRIPT="rerun_todo.sh"
# 你的训练入口文件 (根据实际情况修改，通常是 src/train.py 或 main.py)
ENTRY_POINT="src/train.py" 

# --- 颜色定义 ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}Scanning ${SEARCH_DIR} for failed runs...${NC}"

# 初始化输出脚本
echo "#!/bin/bash" > "$OUTPUT_SCRIPT"
echo "# Auto-generated rerun script by generate_rerun.sh" >> "$OUTPUT_SCRIPT"
echo "# Generated at: $(date)" >> "$OUTPUT_SCRIPT"
echo "echo 'Starting batch rerun...'" >> "$OUTPUT_SCRIPT"
echo "" >> "$OUTPUT_SCRIPT"

count=0

# 查找 .failed 文件
while IFS= read -r failed_file; do
    # 获取实验目录
    exp_dir=$(dirname "$failed_file")
    
    # 获取 Hydra 的参数文件
    overrides_file="${exp_dir}/.hydra/overrides.yaml"
    
    if [ -f "$overrides_file" ]; then
        ((count++))
        
        # --- 解析 YAML 参数 ---
        # 1. grep -v "hydra/": 过滤掉 hydra 内部配置 (如 hydra/launcher=...)
        # 2. sed 's/^- //': 去掉 yaml 列表项前面的 "- "
        # 3. tr '\n' ' ': 将多行合并为一行，用空格分隔
        # 4. tr -d "'": 去掉可能存在的单引号 (视具体 yaml 格式而定，通常不需要，但为了保险)
        params=$(grep -v "^hydra/" "$overrides_file" | sed 's/^- //' | tr '\n' ' ')
        
        # 写入命令到输出脚本
        # 增加一些 echo 提示，方便在重跑时知道跑到哪一个了
        echo "echo \"------------------------------------------------\"" >> "$OUTPUT_SCRIPT"
        echo "echo \"[Rerunning] Job from: $exp_dir\"" >> "$OUTPUT_SCRIPT"
        echo "echo \"[Command] python $ENTRY_POINT $params\"" >> "$OUTPUT_SCRIPT"
        
        # 写入实际运行命令
        # 如果你希望上一个任务失败后继续跑下一个，保持现状
        # 如果你希望一旦报错就停止整个重跑脚本，在下面加一行 'set -e'
        echo "python $ENTRY_POINT $params" >> "$OUTPUT_SCRIPT"
        
        echo -e "  Found: ${YELLOW}$exp_dir${NC}"
    else
        echo -e "  ${YELLOW}Skipping $exp_dir (No overrides.yaml found)${NC}"
    fi

done < <(find "$SEARCH_DIR" -type f -name ".failed")

# --- 结束处理 ---

if [ $count -eq 0 ]; then
    echo -e "${GREEN}No failed experiments found. Nothing to generate.${NC}"
    rm "$OUTPUT_SCRIPT" # 删除空文件
else
    # 赋予执行权限
    chmod +x "$OUTPUT_SCRIPT"

    echo "------------------------------------------------"
    echo -e "${GREEN}Success! Generated rerun script: ${OUTPUT_SCRIPT}${NC}"
    echo -e "Contains commands for ${GREEN}$count${NC} failed experiments."
    echo ""
    echo -e "To start rerunning, execute:"
    echo -e "  ${CYAN}./$OUTPUT_SCRIPT${NC}"
fi