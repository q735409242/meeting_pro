#!/bin/bash

# 🔇🚀 云助通Web端 - 一键静默部署脚本
# 自动构建静默版本 → 部署到Cloudflare Pages → 恢复原始配置

set -e

echo "🔇🚀 云助通Web端 - 一键静默部署"
echo "=================================="

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_deploy() { echo -e "${PURPLE}🚀 $1${NC}"; }

# 错误处理函数
cleanup_and_exit() {
    print_error "部署过程中发生错误，正在恢复原始配置..."
    restore_original_files
    exit 1
}

# 设置错误处理
trap 'cleanup_and_exit' ERR

# 恢复原始文件函数
restore_original_files() {
    print_info "恢复原始配置文件..."
    
    # 恢复Service Worker
    if [ -f "web/sw-debug.js.bak" ]; then
        cp web/sw-debug.js.bak web/sw.js
        rm web/sw-debug.js.bak
        print_success "已恢复原始Service Worker"
    fi
    
    # 恢复HTML（如果有备份）
    if [ -f "web/index-debug.html.bak" ]; then
        cp web/index-debug.html.bak web/index.html
        rm web/index-debug.html.bak
        print_success "已恢复原始HTML配置"
    fi
}

# 检查依赖
check_dependencies() {
    print_info "检查系统依赖..."
    
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter未安装，请先安装Flutter SDK"
        exit 1
    fi
    
    if ! command -v npx &> /dev/null; then
        print_error "npx未安装，请先安装Node.js"
        exit 1
    fi
    
    print_success "系统依赖检查通过"
}

# 备份原始文件
backup_original_files() {
    print_info "备份原始配置文件..."
    
    # 备份Service Worker
    if [ -f "web/sw.js" ]; then
        cp web/sw.js web/sw-debug.js.bak
        print_info "已备份原始Service Worker"
    fi
    
    # 备份HTML（如果需要修改）
    if [ -f "web/index.html" ]; then
        cp web/index.html web/index-debug.html.bak
        print_info "已备份原始HTML"
    fi
}

# 应用静默配置
apply_silent_config() {
    print_info "应用静默配置..."
    
    # 使用静默版Service Worker
    if [ -f "web/sw-silent.js" ]; then
        cp web/sw-silent.js web/sw.js
        print_success "已启用静默版Service Worker"
    else
        print_warning "静默版Service Worker不存在，将创建简化版本"
        # 创建简化的静默SW
        cat > web/sw.js << 'EOF'
// 静默版Service Worker - 自动生成
const CACHE_NAME = 'yunzhutong-silent-v1';
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => self.clients.claim());
self.addEventListener('fetch', e => {
  if (e.request.method === 'GET') {
    e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
  }
});
EOF
    fi
}

# 构建Flutter应用
build_flutter_app() {
    print_info "构建Flutter Web应用（静默版）..."
    
    # 清理构建
    flutter clean > /dev/null 2>&1
    
    # 构建生产版本
    flutter build web --release
    
    if [ $? -eq 0 ]; then
        print_success "Flutter Web构建完成"
    else
        print_error "Flutter Web构建失败"
        exit 1
    fi
}

# 准备部署文件
prepare_deployment_files() {
    print_info "准备部署文件..."
    
    # 复制静默脚本
    if [ -f "web/console-silence.js" ]; then
        cp web/console-silence.js build/web/
        print_success "静默脚本已复制"
    fi
    
    # 复制路由配置
    if [ -f "_routes.json" ]; then
        cp _routes.json build/web/
        print_info "Pages路由配置已复制"
    fi
    
    # 生成部署信息
    cat > build/web/deploy-info.json << EOF
{
  "buildTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "1.0.0",
  "mode": "silent-production",
  "consoleSilenced": true,
  "serviceWorker": "silent",
  "deployedBy": "deploy-silent.sh",
  "description": "云助通Web主控端 - 静默版一键部署"
}
EOF
    
    print_info "部署信息已生成"
}

# 部署到Cloudflare Pages
deploy_to_cloudflare() {
    print_deploy "开始部署到Cloudflare Pages..."
    
    # 检查是否有wrangler
    if ! command -v wrangler &> /dev/null; then
        print_info "安装Wrangler CLI..."
        npm install -g wrangler
    fi
    
    # 检查登录状态
    print_info "检查Cloudflare登录状态..."
    if ! wrangler whoami > /dev/null 2>&1; then
        print_warning "需要登录Cloudflare账户"
        print_info "即将打开浏览器进行登录..."
        read -p "按回车键继续..." -n 1 -r
        wrangler login
    fi
    
    # 部署
    print_deploy "正在部署到Cloudflare Pages..."
    wrangler pages deploy build/web --project-name yunzhutong-web
    
    if [ $? -eq 0 ]; then
        print_success "部署成功！"
    else
        print_error "部署失败"
        exit 1
    fi
}

# 显示部署结果
show_deployment_result() {
    TOTAL_SIZE=$(du -sh build/web | cut -f1)
    FILE_COUNT=$(find build/web -type f | wc -l | tr -d ' ')
    
    echo ""
    print_success "🎉 一键静默部署完成！"
    echo "=================================="
    echo ""
    echo "📊 构建统计:"
    echo "   📁 总大小: $TOTAL_SIZE"
    echo "   📄 文件数: $FILE_COUNT"
    echo "   🔇 控制台: 完全静默"
    echo "   🛡️ Service Worker: 静默版"
    echo ""
    echo "🌐 部署信息:"
    echo "   🚀 平台: Cloudflare Pages"
    echo "   🌍 CDN: 200+全球节点"
    echo "   🔒 SSL: 自动免费证书"
    echo "   ⚡ 性能: 毫秒级响应"
    echo ""
    echo "🔗 访问地址:"
    echo "   主域名: https://yunzhutong-web.pages.dev"
    echo "   备用: 您配置的自定义域名"
    echo ""
    echo "🔧 后续操作:"
    echo "   📊 查看分析: wrangler pages deployment list --project-name yunzhutong-web"
    echo "   📝 查看日志: wrangler pages deployment tail --project-name yunzhutong-web"
    echo "   🔄 再次部署: ./deploy-silent.sh"
    echo ""
    print_success "原始开发配置已自动恢复，可继续本地开发！"
}

# 主流程
main() {
    echo ""
    print_deploy "开始一键静默部署流程..."
    echo ""
    
    # 1. 检查依赖
    check_dependencies
    
    # 2. 备份原始文件
    backup_original_files
    
    # 3. 应用静默配置
    apply_silent_config
    
    # 4. 构建Flutter应用
    build_flutter_app
    
    # 5. 准备部署文件
    prepare_deployment_files
    
    # 6. 部署到Cloudflare Pages
    deploy_to_cloudflare
    
    # 7. 恢复原始配置（无论成功失败都执行）
    restore_original_files
    
    # 8. 显示部署结果
    show_deployment_result
}

# 启动主流程
main "$@" 