# Kitchen

基于 **Godot 4** 开发的游戏项目（含 Web 导出与 GitHub Pages 自动部署）。

## 在线试玩

GitHub Pages: <https://sangerozoz.github.io/kitchen/>

## 目录结构

- `scenes/` - 游戏场景
- `scripts/` - GDScript 脚本
- `assets/` - 美术与字体资源
- `shaders/` - 着色器
- `build/web/` - Web 导出产物（推送到 `main` 分支后由 GitHub Actions 自动部署至 GitHub Pages）
- `snack_stall_gdd.md` - 小吃摊模拟器玩法与数值设计文档

## 更新在线试玩版本

1. 在 Godot 编辑器中使用 `Web` 预设导出到 `build/web/index.html`
2. 提交并推送 `build/web/` 变更到 `main` 分支，GitHub Actions 会自动更新 GitHub Pages
