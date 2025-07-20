#!/bin/bash

# 🔧 云助通Web端 - 手动部署指导脚本
# 当API出现8000000错误时的备用方案

echo "🔧 云助通Web端 - 手动部署指导"
echo "================================"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

print_info "检测到Cloudflare API 8000000错误，启动手动部署模式..."

# 构建应用
print_info "构建Flutter Web应用..."
flutter clean > /dev/null 2>&1
flutter build web --release

if [ $? -eq 0 ]; then
    print_success "Flutter Web构建完成"
else
    print_error "Flutter Web构建失败"
    exit 1
fi

# 显示手动部署指导
echo ""
print_warning "🤖 自动部署暂时不可用，请按以下步骤手动部署："
echo ""
echo "📋 手动部署步骤："
echo "================================"
echo ""
echo "1️⃣  打开Cloudflare Pages控制台:"
echo "   https://dash.cloudflare.com/pages"
echo ""
echo "2️⃣  找到项目 'yunzhutong-web' 并点击"
echo ""
echo "3️⃣  点击 '创建部署' 或 'Create deployment'"
echo ""
echo "4️⃣  上传文件夹："
echo "   📁 选择: $(pwd)/build/web"
echo "   📂 或者拖拽整个build/web文件夹到页面"
echo ""
echo "5️⃣  等待上传完成 (约1-2分钟)"
echo ""
echo "6️⃣  点击 '部署站点' 或 'Deploy site'"
echo ""
echo "🎉 部署完成后访问："
echo "   🌐 https://yunzhutong-web.pages.dev"
echo ""
echo "================================"
print_success "构建文件已准备完成，可以进行手动上传！"
echo ""
print_info "💡 小贴士："
echo "   - API错误通常2-4小时内会自动修复"
echo "   - 修复后可以继续使用 ./deploy-silent.sh"
echo "   - 手动部署同样享受全球CDN加速"
echo ""

# 显示构建统计
TOTAL_SIZE=$(du -sh build/web | cut -f1)
FILE_COUNT=$(find build/web -type f | wc -l | tr -d ' ')
echo "📊 构建统计:"
echo "   📦 总大小: $TOTAL_SIZE"
echo "   📄 文件数: $FILE_COUNT"
echo "   🔇 静默版: 已应用"
echo ""

print_warning "是否现在打开Cloudflare Pages控制台？(y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    if command -v open &> /dev/null; then
        open "https://dash.cloudflare.com/pages"
        print_success "已打开Cloudflare Pages控制台"
    else
        print_info "请手动打开: https://dash.cloudflare.com/pages"
    fi
fi

echo ""
print_success "手动部署指导完成！" 