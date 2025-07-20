#!/bin/bash

# 🔇🌐 云助通Web端 - 无图标干净构建脚本
# 本地开发有日志，生产部署静默无图标

set -e

echo "🔇🌐 云助通Web端 - 干净构建"
echo "============================"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# 检测构建模式
BUILD_MODE=${1:-release}
if [ "$BUILD_MODE" = "debug" ]; then
    print_info "构建开发版本（有日志输出）..."
    print_warning "开发版本：控制台会显示调试信息"
else
    print_info "构建生产版本（静默无图标）..."
    print_warning "生产版本：控制台完全静默，无任何图标"
fi

# 清理之前的构建
print_info "清理之前的构建..."
flutter clean > /dev/null 2>&1

# 构建Flutter Web应用
print_info "构建Flutter Web应用..."
if [ "$BUILD_MODE" = "debug" ]; then
    flutter build web --debug
else
    flutter build web --release
fi

# 删除构建结果中的图标文件（如果存在）
print_info "移除图标文件..."
rm -f build/web/favicon.png 2>/dev/null || true
rm -rf build/web/icons 2>/dev/null || true

# 复制必要文件
print_info "复制必要配置文件..."

# 复制路由配置
if [ -f "_routes.json" ]; then
    cp _routes.json build/web/
    print_info "Pages路由配置已复制"
fi

# 生成构建信息
cat > build/web/build-info.json << EOF
{
  "buildTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "1.0.0",
  "mode": "$BUILD_MODE",
  "features": {
    "consoleSilenced": $([ "$BUILD_MODE" = "release" ] && echo "true" || echo "false"),
    "iconsRemoved": true,
    "developmentLogs": $([ "$BUILD_MODE" = "debug" ] && echo "true" || echo "false")
  },
  "deployedBy": "clean-build.sh",
  "description": "云助通Web主控端 - 无图标干净版本"
}
EOF

# 显示构建统计
TOTAL_SIZE=$(du -sh build/web | cut -f1)
FILE_COUNT=$(find build/web -type f | wc -l | tr -d ' ')

echo ""
print_success "🎉 干净构建完成！"
echo "============================"
echo ""
echo "📊 构建统计:"
echo "   📁 总大小: $TOTAL_SIZE"
echo "   📄 文件数: $FILE_COUNT"
echo "   🚫 图标: 已完全移除"
if [ "$BUILD_MODE" = "debug" ]; then
    echo "   🔊 控制台: 开发模式，有日志输出"
else
    echo "   🔇 控制台: 生产模式，完全静默"
fi
echo ""
echo "🌐 本地预览:"
echo "   cd build/web && python3 -m http.server 8000"
echo "   http://localhost:8000"
echo ""
echo "🚀 部署选项:"
echo "   1. Cloudflare Pages: wrangler pages deploy build/web"
echo "   2. 手动上传: 上传整个 build/web 文件夹"
echo "   3. 静默部署: ./deploy-silent.sh"
echo ""

if [ "$BUILD_MODE" = "debug" ]; then
    print_warning "💡 提示: 开发版本在localhost会显示日志，这是正常的"
    print_info "生产部署请使用: ./clean-build.sh release"
else
    print_success "🎯 生产版本已准备完成，可以安全部署！"
fi

echo "============================" 