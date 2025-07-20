#!/bin/bash

# 🎯 云助通Web端 - 构建指导脚本

echo "🎯 云助通Web端 - 构建指导"
echo "==============================="

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_deploy() { echo -e "${PURPLE}🚀 $1${NC}"; }

echo ""
print_info "根据你的需求选择合适的构建方式："
echo ""

echo "🔧 开发调试 (本地测试有日志):"
echo "   ./clean-build.sh debug"
echo "   - 控制台显示所有调试信息"
echo "   - 无图标干净界面"
echo "   - 适合本地开发调试"
echo ""

echo "🚀 生产部署 (上传到Pages静默):"
echo "   ./clean-build.sh release"
echo "   - 控制台完全静默"
echo "   - 无图标干净界面"
echo "   - 适合生产环境部署"
echo ""

echo "🔇 一键静默部署 (自动上传):"
echo "   ./deploy-silent.sh"
echo "   - 自动构建生产版本"
echo "   - 自动部署到Cloudflare Pages"
echo "   - 自动备份恢复配置"
echo ""

echo "📋 手动部署指导:"
echo "   ./deploy-manual.sh"
echo "   - 当API有问题时的备用方案"
echo "   - 提供详细的手动上传指导"
echo ""

echo "==============================="
print_success "✨ 特性说明"
echo ""

echo "🎭 智能日志系统:"
echo "   • 开发环境(debug): 控制台有完整日志"
echo "   • 生产环境(release): 控制台完全静默"
echo "   • 本地测试: localhost有日志显示"
echo "   • 在线部署: 完全静默，专业体验"
echo ""

echo "🚫 无图标设计:"
echo "   • 移除所有favicon和PWA图标"
echo "   • 使用空白data:,替换图标引用"
echo "   • 减小部署包大小"
echo "   • 提供纯净的用户界面"
echo ""

echo "🔄 自动化流程:"
echo "   • 构建时自动删除图标文件"
echo "   • 生成详细的构建信息"
echo "   • 智能检测开发/生产环境"
echo "   • 自动复制必要配置文件"
echo ""

echo "==============================="
print_deploy "🚀 推荐工作流程"
echo ""

echo "1️⃣  开发阶段:"
echo "   flutter run -d chrome          # 本地调试"
echo "   ./clean-build.sh debug         # 测试构建"
echo ""

echo "2️⃣  发布阶段:"
echo "   ./clean-build.sh release       # 生产构建"
echo "   ./deploy-silent.sh              # 一键部署"
echo ""

echo "3️⃣  验证阶段:"
echo "   • 打开部署后的网址"
echo "   • 检查控制台应该完全静默"
echo "   • 确认无任何图标显示"
echo "   • 验证功能正常工作"
echo ""

echo "==============================="
print_warning "💡 故障排除"
echo ""

echo "• 如果API部署失败:"
echo "  → 使用 ./deploy-manual.sh 手动上传"
echo ""

echo "• 如果本地测试无日志:"
echo "  → 确保使用 debug 模式构建"
echo "  → 检查是否在 localhost 访问"
echo ""

echo "• 如果生产环境有日志:"
echo "  → 确保使用 release 模式构建"
echo "  → 检查 console-silence.js 是否生效"
echo ""

echo "==============================="
print_success "🎉 现在开始构建你的无图标静默Web应用吧！"
echo "" 