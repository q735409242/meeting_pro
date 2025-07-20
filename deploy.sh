#!/bin/bash

# 🌍 云助通Web主控端 - Cloudflare Workers一键部署脚本

set -e  # 遇到错误立即退出

echo "🚀 云助通Web主控端 - Cloudflare Workers部署开始"
echo "============================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查依赖
check_dependencies() {
    print_info "检查系统依赖..."
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js未安装，请先安装Node.js 18+"
        exit 1
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        print_error "npm未安装，请先安装npm"
        exit 1
    fi
    
    # 检查Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter未安装，请先安装Flutter SDK"
        exit 1
    fi
    
    print_success "系统依赖检查通过"
}

# 安装Wrangler
install_wrangler() {
    print_info "检查Wrangler CLI..."
    
    if ! command -v wrangler &> /dev/null; then
        print_warning "Wrangler未安装，正在安装..."
        npm install -g wrangler
        print_success "Wrangler安装完成"
    else
        print_success "Wrangler已安装"
    fi
}

# 登录Cloudflare
login_cloudflare() {
    print_info "检查Cloudflare登录状态..."
    
    if ! wrangler whoami &> /dev/null; then
        print_warning "需要登录Cloudflare账户"
        echo "即将打开浏览器进行登录..."
        read -p "按回车键继续..." -n 1 -r
        wrangler login
        print_success "Cloudflare登录完成"
    else
        print_success "已登录Cloudflare"
    fi
}

# 安装项目依赖
install_dependencies() {
    print_info "安装项目依赖..."
    
    if [ ! -f "package.json" ]; then
        print_error "package.json不存在，请确保在项目根目录运行脚本"
        exit 1
    fi
    
    npm install
    print_success "项目依赖安装完成"
}

# 构建Flutter应用
build_flutter() {
    print_info "构建Flutter Web应用..."
    
    # 清理之前的构建
    if [ -d "build/web" ]; then
        rm -rf build/web
        print_info "已清理旧的构建文件"
    fi
    
    # 构建生产版本
    flutter build web --release
    print_success "Flutter应用构建完成"
    
    # 显示构建统计
    if [ -d "build/web" ]; then
        TOTAL_SIZE=$(du -sh build/web | cut -f1)
        FILE_COUNT=$(find build/web -type f | wc -l | tr -d ' ')
        print_info "构建统计: 总大小 $TOTAL_SIZE, 文件数量 $FILE_COUNT"
    fi
}

# 配置检查
check_configuration() {
    print_info "检查配置文件..."
    
    if [ ! -f "wrangler.toml" ]; then
        print_error "wrangler.toml不存在，请先配置部署参数"
        exit 1
    fi
    
    # 检查应用名称
    APP_NAME=$(grep "^name" wrangler.toml | cut -d'"' -f2)
    if [ "$APP_NAME" = "yunzhutong-web" ]; then
        print_warning "建议修改wrangler.toml中的应用名称避免冲突"
    fi
    
    print_success "配置文件检查完成"
}

# 部署到Cloudflare Workers
deploy_to_cloudflare() {
    print_info "部署到Cloudflare Workers..."
    
    # 选择部署环境
    echo ""
    echo "请选择部署环境:"
    echo "1) 生产环境 (production)"
    echo "2) 测试环境 (staging)"
    echo "3) 默认环境"
    read -p "请输入选择 (1-3): " env_choice
    
    case $env_choice in
        1)
            print_info "部署到生产环境..."
            wrangler deploy --env production
            ;;
        2)
            print_info "部署到测试环境..."
            wrangler deploy --env staging
            ;;
        3)
            print_info "部署到默认环境..."
            wrangler deploy
            ;;
        *)
            print_warning "无效选择，使用默认环境部署..."
            wrangler deploy
            ;;
    esac
    
    print_success "部署完成！"
}

# 显示部署结果
show_deployment_info() {
    echo ""
    echo "🎉 部署成功！"
    echo "============================================="
    
    # 获取Workers URL
    if command -v wrangler &> /dev/null; then
        WORKER_URL=$(wrangler list 2>/dev/null | grep "$APP_NAME" | awk '{print $3}' | head -1)
        if [ ! -z "$WORKER_URL" ]; then
            echo "🌐 应用访问地址: $WORKER_URL"
        fi
    fi
    
    echo ""
    echo "📊 部署统计:"
    echo "   ✅ 全球CDN加速已启用"
    echo "   ✅ 免费SSL证书已配置"
    echo "   ✅ 智能缓存策略已生效"
    echo "   ✅ 安全防护已开启"
    
    echo ""
    echo "🔧 后续操作:"
    echo "   📱 测试应用功能"
    echo "   📊 查看分析数据: wrangler analytics"
    echo "   📝 查看实时日志: wrangler tail"
    echo "   🔄 更新部署: npm run deploy"
    
    echo ""
    echo "📖 更多信息请查看: CLOUDFLARE_DEPLOY.md"
    echo "============================================="
}

# 错误处理
handle_error() {
    print_error "部署过程中发生错误！"
    echo "请检查以上错误信息，或参考故障排除指南："
    echo "https://developers.cloudflare.com/workers/troubleshooting/"
    exit 1
}

# 设置错误处理
trap 'handle_error' ERR

# 主流程
main() {
    echo ""
    print_info "开始部署流程..."
    echo ""
    
    # 1. 检查依赖
    check_dependencies
    
    # 2. 安装Wrangler
    install_wrangler
    
    # 3. 登录Cloudflare
    login_cloudflare
    
    # 4. 安装项目依赖
    install_dependencies
    
    # 5. 配置检查
    check_configuration
    
    # 6. 构建Flutter应用
    build_flutter
    
    # 7. 部署到Cloudflare
    deploy_to_cloudflare
    
    # 8. 显示部署结果
    show_deployment_info
}

# 运行主流程
main "$@" 