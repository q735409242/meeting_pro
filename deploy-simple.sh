#!/bin/bash

# 🚀 云助通Web端 - 简化部署脚本（绕过API问题）

set -e

echo "🚀 云助通Web端 - 简化部署"
echo "=========================="

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

# 构建Flutter应用
print_info "构建Flutter Web应用..."
flutter clean > /dev/null 2>&1
flutter build web --release

if [ $? -eq 0 ]; then
    print_success "Flutter Web构建完成"
else
    print_error "Flutter Web构建失败"
    exit 1
fi

# 复制路由配置
if [ -f "_routes.json" ]; then
    cp _routes.json build/web/
    print_info "Pages路由配置已复制"
fi

# 方法1：使用wrangler.toml配置文件部署（推荐）
print_info "尝试方法1：使用wrangler.toml配置部署..."
if wrangler pages deploy --commit-dirty=true; then
    print_success "方法1成功：使用配置文件部署完成！"
    exit 0
fi

print_warning "方法1失败，尝试方法2..."

# 方法2：直接指定项目名称
print_info "尝试方法2：直接指定项目部署..."
if wrangler pages deploy build/web --project-name yunzhutong-web --commit-dirty=true; then
    print_success "方法2成功：直接部署完成！"
    exit 0
fi

print_warning "方法2失败，尝试方法3..."

# 方法3：创建新的部署（如果项目不存在）
print_info "尝试方法3：创建新项目部署..."
if wrangler pages deploy build/web --project-name yunzhutong-web-backup --commit-dirty=true; then
    print_success "方法3成功：备用项目部署完成！"
    print_info "访问地址: https://yunzhutong-web-backup.pages.dev"
    exit 0
fi

# 如果所有方法都失败
print_error "所有自动部署方法都失败了"
print_info "这可能是由于Cloudflare API临时问题"
print_warning "建议手动部署方案："
echo ""
echo "1. 手动上传到Cloudflare Pages Dashboard:"
echo "   https://dash.cloudflare.com/pages"
echo ""
echo "2. 或等待几分钟后重试:"
echo "   ./deploy-simple.sh"
echo ""
echo "3. 或使用传统Worker部署:"
echo "   ./deploy-pages.sh"

exit 1 