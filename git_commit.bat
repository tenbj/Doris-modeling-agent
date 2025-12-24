@echo off
chcp 65001 >nul
echo 正在初始化Git仓库...

:: 检查是否已经是git仓库
if not exist .git (
    git init
    echo Git仓库初始化完成！
) else (
    echo Git仓库已存在
)

echo.
echo 正在添加文件到暂存区...
git add .

echo.
echo 正在提交更改...
git commit -m "feat: 初始化Doris数据建模AI Agent系统

- 添加需求分析Agent提示词
- 添加数据建模Agent提示词
- 添加表结构设计Agent提示词
- 添加SQL生成Agent提示词
- 添加质量检验Agent提示词
- 添加编排Agent协调逻辑
- 配置数据分层规则
- 添加项目文档和模板
"

echo.
echo 提交完成！
echo.
echo 接下来，你需要：
echo 1. 在GitHub上创建一个新仓库
echo 2. 运行以下命令将代码推送到GitHub：
echo.
echo    git remote add origin https://github.com/你的用户名/你的仓库名.git
echo    git branch -M main
echo    git push -u origin main
echo.
pause

