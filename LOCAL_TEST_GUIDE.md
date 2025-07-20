# 🧪 本地测试指南

## 系统要求检查

你的系统状态：
- ✅ Flutter 3.29.3 (支持Web)
- ✅ Safari 浏览器可用
- ❌ Chrome 未安装
- ✅ macOS 开发环境

## 🚀 测试方案选择

### 方案1: 使用Safari + Flutter开发服务器 (推荐)

这是最简单快速的测试方法：

```bash
# 1. 启动Flutter Web开发服务器
flutter run -d web-server --web-port=8080

# 2. 手动在Safari中打开
open -a Safari http://localhost:8080
```

### 方案2: 构建静态文件 + 本地Web服务器

```bash
# 1. 构建Web版本
flutter build web --release

# 2. 使用Python启动Web服务器
cd build/web
python3 -m http.server 8080

# 3. 在Safari中访问
open -a Safari http://localhost:8080
```

### 方案3: 安装Chrome浏览器 (可选)

```bash
# 使用Homebrew安装Chrome
brew install --cask google-chrome

# 安装后重新检查Flutter
flutter doctor
```

## 📱 完整测试流程

### Step 1: 启动Web主控端

选择上面任一方案启动Web应用，然后在浏览器中看到：

```
┌─────────────────────────────────────┐
│        云助通 - Web主控端            │
├─────────────────────────────────────┤
│  设备绑定                会议管理    │
│  [注册码输入框]         [暂无会议]   │
│  [绑定按钮]                         │
│                                     │
│  会议控制                           │
│  [创建新会议]                       │
│  [加入会议] [房间号输入框]          │
└─────────────────────────────────────┘
```

### Step 2: 绑定设备

1. 在"设备绑定"区域输入一个测试注册码
2. 点击"绑定"按钮
3. 观察绑定结果（成功/失败）

**预期行为**:
- 绑定成功：显示绑定的注册码，按钮变为可用
- 绑定失败：显示错误信息

### Step 3: 创建会议

1. 点击"创建新会议"按钮
2. 观察loading状态
3. 查看弹出的会议信息对话框

**预期结果**:
```
✅ 会议创建成功
房间号: 123456
分享方式:
- 移动端用户请使用房间号加入: 123456
- Web端用户可使用以下链接: http://localhost:8080#/join/123456
[复制房间号] [复制链接] [进入会议]
```

### Step 4: 测试移动端 (可选)

如果有Android设备或iOS模拟器：

```bash
# 启动Android应用
flutter run -d android

# 或启动iOS模拟器
flutter run -d ios
```

在移动端：
1. 点击"加入会议"
2. 输入Web端创建的房间号
3. 测试音视频连接

## 🔧 调试技巧

### 查看控制台日志

在Safari中：
1. 按 `Command + Option + I` 打开开发者工具
2. 切换到"控制台"选项卡
3. 观察API请求和错误信息

### 常见的控制台输出

```javascript
// 正常日志
绑定结果：{msg: "绑定成功", data: {...}}
开始创建房间，注册码: test123, 设备ID: WEB_darwin_1737380000000
创建房间API响应: {msg: "", data: {room_id: "123456", ...}}

// 错误日志
Web权限检查失败: NotAllowedError: Permission denied
创建房间异常: TypeError: Failed to fetch
```

### 网络请求监控

在Safari开发者工具中：
1. 切换到"网络"选项卡
2. 观察API请求到 `api.yunkefu.pro`
3. 检查请求状态码和响应内容

## 🌐 浏览器兼容性测试

### 测试不同浏览器

如果你有多个浏览器：

```bash
# Safari (系统自带)
open -a Safari http://localhost:8080

# Chrome (如果已安装)
open -a "Google Chrome" http://localhost:8080

# Firefox (如果已安装)
open -a Firefox http://localhost:8080
```

### 移动端浏览器模拟

在Safari开发者工具中：
1. 选择"开发"菜单
2. 选择"进入响应式设计模式"
3. 测试不同屏幕尺寸

## 📊 功能测试清单

### ✅ 基础功能测试

- [ ] 页面正常加载
- [ ] 设备绑定功能
- [ ] 会议创建功能
- [ ] 会议加入功能
- [ ] 响应式UI适配

### ✅ 交互功能测试

- [ ] 输入框正常工作
- [ ] 按钮点击响应
- [ ] 弹窗正常显示
- [ ] 复制功能工作
- [ ] 会议列表更新

### ✅ 权限功能测试

- [ ] 麦克风权限请求
- [ ] 权限被拒绝的处理
- [ ] 权限允许后的行为

## 🐛 常见问题解决

### 问题1: 页面无法加载

**现象**: 浏览器显示"无法连接"

**解决方法**:
```bash
# 检查端口是否被占用
lsof -i :8080

# 换个端口
flutter run -d web-server --web-port=8081
```

### 问题2: API请求失败

**现象**: 控制台显示网络错误

**解决方法**:
- 检查网络连接
- 确认API服务器状态
- 查看CORS设置

### 问题3: 麦克风权限问题

**现象**: "需要麦克风权限"提示

**解决方法**:
1. 在Safari中允许麦克风权限
2. 确保使用HTTPS或localhost
3. 检查系统隐私设置

### 问题4: 构建失败

**现象**: `flutter build web` 报错

**解决方法**:
```bash
# 清理并重新构建
flutter clean
flutter pub get
flutter build web --verbose
```

## 🎯 性能测试

### 加载时间测试

在Safari开发者工具中：
1. 切换到"时间线"选项卡
2. 刷新页面
3. 观察加载时间和性能指标

### 内存使用监控

1. 长时间使用应用
2. 创建多个会议
3. 观察内存使用情况

## 📈 测试数据记录

### 测试环境

| 项目 | 值 |
|------|---|
| 操作系统 | macOS 15.5 |
| Flutter版本 | 3.29.3 |
| 浏览器 | Safari |
| 网络环境 | 本地开发 |

### 测试结果

| 功能 | 状态 | 耗时 | 备注 |
|------|------|------|------|
| 页面加载 | ⏳ | - | 待测试 |
| 设备绑定 | ⏳ | - | 待测试 |
| 会议创建 | ⏳ | - | 待测试 |
| 会议加入 | ⏳ | - | 待测试 |

## 🚀 开始测试

选择一个方案开始测试：

```bash
# 推荐：快速开始
flutter run -d web-server --web-port=8080
open -a Safari http://localhost:8080
```

然后按照上面的测试流程逐步验证功能！ 