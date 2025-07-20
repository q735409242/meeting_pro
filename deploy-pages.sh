#!/bin/bash

# 🌍 云助通Web主控端 - Cloudflare Pages一键部署脚本

set -e

echo "🚀 云助通Web主控端 - Cloudflare Pages部署"
echo "=========================================="

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

# 检查Flutter
if ! command -v flutter &> /dev/null; then
    print_error "Flutter未安装，请先安装Flutter SDK"
    exit 1
fi

# 构建Flutter Web应用
print_info "构建Flutter Web应用..."
flutter clean
flutter build web --release
print_success "Flutter应用构建完成"

# 复制路由配置到构建目录
if [ -f "_routes.json" ]; then
    cp _routes.json build/web/
    print_info "已复制Pages路由配置"
fi

# 显示构建信息
TOTAL_SIZE=$(du -sh build/web | cut -f1)
print_info "构建大小: $TOTAL_SIZE"

echo ""
print_success "构建完成！现在可以通过以下方式部署："
echo ""
echo "📖 方式1: 通过Cloudflare Dashboard手动上传"
echo "   1. 登录 https://dash.cloudflare.com"
echo "   2. 进入 Pages 菜单"
echo "   3. 点击 'Create a project'"
echo "   4. 选择 'Upload assets'"
echo "   5. 上传 build/web 文件夹中的所有内容"
echo ""
echo "🔧 方式2: 使用Wrangler命令行（推荐）"
echo "   npx wrangler pages deploy build/web --project-name yunzhutong-web"
echo ""
echo "📱 方式3: 连接Git仓库自动部署"
echo "   1. 推送代码到GitHub/GitLab"
echo "   2. 在Pages中连接仓库"
echo "   3. 设置构建命令: flutter build web --release"
echo "   4. 设置输出目录: build/web"
echo ""

# 询问是否直接部署
read -p "是否现在通过Wrangler直接部署？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "通过Wrangler部署到Cloudflare Pages..."
    
    # 检查wrangler
    if ! command -v wrangler &> /dev/null; then
        print_info "安装Wrangler..."
        npm install -g wrangler
    fi
    
    # 部署
    wrangler pages deploy build/web --project-name yunzhutong-web
    print_success "部署完成！"
else
    print_info "请手动上传build/web文件夹到Cloudflare Pages"
fi

echo ""
print_success "部署完成！应用将享有："
echo "   🌐 全球CDN加速"
echo "   🔒 免费SSL证书"  
echo "   📊 访问统计分析"
echo "   🛡️ DDoS防护"
echo "   ⚡ 毫秒级响应" 