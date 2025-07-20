#!/bin/bash

# 🔇 云助通Web端 - 静默版生产构建脚本
# 自动使用静默版Service Worker和配置

set -e

echo "🔇 开始构建静默版Web应用..."
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

# 1. 备份原始文件
print_info "备份原始Service Worker..."
if [ -f "web/sw.js" ]; then
    cp web/sw.js web/sw-debug.js.bak
    print_info "已备份调试版Service Worker"
fi

# 2. 使用静默版Service Worker
print_info "切换到静默版Service Worker..."
if [ -f "web/sw-silent.js" ]; then
    cp web/sw-silent.js web/sw.js
    print_success "已启用静默版Service Worker"
else
    print_warning "静默版Service Worker不存在，继续使用现有版本"
fi

# 3. 构建Flutter Web应用
print_info "构建Flutter Web应用（生产模式）..."
flutter clean
flutter build web --release

if [ $? -eq 0 ]; then
    print_success "Flutter Web构建完成"
else
    print_error "Flutter Web构建失败"
    exit 1
fi

# 4. 复制静默脚本到构建目录
print_info "复制静默脚本到构建目录..."
if [ -f "web/console-silence.js" ]; then
    cp web/console-silence.js build/web/
    print_success "静默脚本已复制"
fi

if [ -f "_routes.json" ]; then
    cp _routes.json build/web/
    print_info "Pages路由配置已复制"
fi

# 5. 生成部署信息
print_info "生成部署信息..."
cat > build/web/deploy-info.json << EOF
{
  "buildTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "1.0.0",
  "mode": "silent",
  "consoleSilenced": true,
  "serviceWorker": "silent",
  "description": "云助通Web主控端 - 静默版生产构建"
}
EOF

# 6. 显示构建统计
TOTAL_SIZE=$(du -sh build/web | cut -f1)
FILE_COUNT=$(find build/web -type f | wc -l | tr -d ' ')

echo ""
print_success "静默版构建完成！"
echo "================================"
echo "📊 构建统计:"
echo "   📁 总大小: $TOTAL_SIZE"
echo "   📄 文件数: $FILE_COUNT"
echo "   🔇 控制台: 完全静默"
echo "   🛡️ Service Worker: 静默版"
echo ""
echo "🚀 部署选项:"
echo ""
echo "1️⃣  Cloudflare Pages (推荐):"
echo "   npx wrangler pages deploy build/web --project-name yunzhutong-web"
echo ""
echo "2️⃣  手动上传:"
echo "   上传 build/web 文件夹到任何静态托管服务"
echo ""
echo "3️⃣  本地测试:"
echo "   cd build/web && python3 -m http.server 8000"
echo "   然后访问 http://localhost:8000"
echo ""

# 7. 恢复原始文件（可选）
read -p "是否恢复原始Service Worker供开发使用？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "web/sw-debug.js.bak" ]; then
        cp web/sw-debug.js.bak web/sw.js
        rm web/sw-debug.js.bak
        print_info "已恢复开发版Service Worker"
    fi
else
    # 清理备份文件
    if [ -f "web/sw-debug.js.bak" ]; then
        rm web/sw-debug.js.bak
    fi
fi

echo ""
print_success "构建流程完成！"
echo "🔇 Web应用现在完全静默，不会显示任何控制台信息"
echo "🌐 在生产环境部署后用户将看到干净的控制台" 