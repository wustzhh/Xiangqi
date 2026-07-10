# 中国象棋 App

Flutter 实现的中国象棋手机/桌面应用，支持双人对弈、AI 对战（6档难度）、对局复盘、局面分析。

## 功能

### 🎮 对弈模式
- **双人对弈** — 两人轮流走棋
- **人机对战** — 6档AI难度

### 🤖 AI 难度
| 难度 | 算法 |
|------|------|
| 新手 | 1层搜索 + 30%随机 |
| 初级 | 2层搜索 |
| 中级 | 3层搜索 |
| 高级 | 开局库 + 4层搜索 |
| 大师 | 开局库 + 迭代加深 2→4→6层 |
| 传说 | 开局库 + DeepSeek AI + 6层搜索 |

### 📊 局面分析
- **护子** — 每个棋子的保护数量和保护者
- **攻击** — 敌方攻击范围可视化
- **安全** — 安全分（护-攻）7档着色
- **危险** — 格子危险度7档着色

### 📝 复盘系统
- 自动保存对局记录
- 前进/后退/跳转/自动播放
- 分支模拟（编辑模式）
- 战绩统计

### 🎨 画面
- CustomPainter 绘制木质棋盘棋子
- 走棋动画（抛物线弧线）
- 选中棋子抬起效果
- 行列坐标标注

## 技术栈

- Flutter + Dart
- CustomPainter 自绘棋盘
- Isolate 后台 AI 搜索
- Minimax + Alpha-Beta 剪枝
- Opening Book（Zobrist 哈希）
- JSON 本地存档

## 构建

```bash
flutter pub get
flutter build windows    # Windows
flutter build apk        # Android
flutter build ios        # iOS
```

## DeepSeek AI 配置

传说难度需配置 DeepSeek API Key：
1. 打开设置页面（主菜单右上角齿轮）
2. 填入 DeepSeek API Key
3. 选择传说难度开始对局

API Key 使用双层加密存储到本地。
