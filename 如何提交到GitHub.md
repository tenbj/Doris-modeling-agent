# 如何将项目提交到GitHub

## 方法一：使用批处理脚本（推荐）

1. **双击运行 `git_commit.bat` 文件**
   - 这将自动初始化Git仓库并提交所有文件

2. **在GitHub上创建新仓库**
   - 访问 https://github.com/new
   - 输入仓库名称（例如：`doris-data-modeling-agent`）
   - 选择Public或Private
   - **不要**勾选"Initialize this repository with a README"
   - 点击"Create repository"

3. **将本地代码推送到GitHub**
   - 在项目目录打开命令行（右键 → Git Bash Here 或使用CMD）
   - 复制GitHub显示的命令，类似：
   ```bash
   git remote add origin https://github.com/你的用户名/仓库名.git
   git branch -M main
   git push -u origin main
   ```

## 方法二：手动执行命令

在项目目录打开命令行，依次执行：

```bash
# 1. 初始化Git仓库
git init

# 2. 添加所有文件到暂存区
git add .

# 3. 提交更改
git commit -m "feat: 初始化Doris数据建模AI Agent系统"

# 4. 连接到GitHub仓库（替换为你的仓库地址）
git remote add origin https://github.com/你的用户名/仓库名.git

# 5. 设置主分支名称
git branch -M main

# 6. 推送到GitHub
git push -u origin main
```

## 常见问题

### 1. 如果遇到权限问题
确保你已经配置了Git用户信息：
```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

### 2. 如果需要使用SSH方式
```bash
# 使用SSH URL而不是HTTPS
git remote add origin git@github.com:你的用户名/仓库名.git
```

### 3. 如果已经添加了remote但地址错误
```bash
# 删除现有的remote
git remote remove origin

# 重新添加正确的remote
git remote add origin https://github.com/你的用户名/仓库名.git
```

## 后续更新

当你修改了代码后，使用以下命令提交更新：

```bash
git add .
git commit -m "描述你的更改"
git push
```

## 建议的提交信息格式

遵循约定式提交（Conventional Commits）：

- `feat:` 新功能
- `fix:` 修复bug
- `docs:` 文档更新
- `style:` 代码格式调整
- `refactor:` 代码重构
- `test:` 测试相关
- `chore:` 构建或辅助工具变动

示例：
```bash
git commit -m "feat: 添加用户维度拉链表模板"
git commit -m "fix: 修复SQL语法错误"
git commit -m "docs: 更新README使用说明"
```

