#!/bin/bash

# 🚀 云助通Web端 - 一键部署快捷脚本
# 直接调用静默部署脚本

echo "🚀 启动一键静默部署..."
echo ""

# 检查静默部署脚本是否存在
if [ ! -f "deploy-silent.sh" ]; then
    echo "❌ 找不到 deploy-silent.sh 脚本"
    exit 1
fi

# 确保脚本有执行权限
chmod +x deploy-silent.sh

# 运行静默部署
./deploy-silent.sh "$@" 