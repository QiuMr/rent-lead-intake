# 租房线索登记 Skill

给豆包工作 / WorkBuddy 安装的 Agent Skill：引流员直接跟 AI 说客户需求，技能把原话登记到租房线索后台，后台自动去重、归属、展示在公网线索页。

- 标准格式：一个文件夹 + `SKILL.md`，兼容 Agent Skills 开放标准。
- 不需要 token：第一次填名字或称号，保存在本机，后续自动带上。
- 默认自动入库：不再逐条人工审核；缺联系方式会标成异常。
- 公网线索页：<http://182.92.214.51:8789/leads>
- GitHub 仓库：<https://github.com/QiuMr/rent-lead-intake>

## 安装

直接下载仓库 zip：<https://github.com/QiuMr/rent-lead-intake/archive/refs/heads/main.zip>

### 豆包工作

1. 下载上面的 zip（或本目录的文件夹）。
2. 打开豆包工作 → 左侧「插件 · 技能 · 伙伴」→「技能」→ 右上角「+ 添加」→「上传技能」。
3. 选择 zip 或文件夹，按提示允许联网权限。
4. 在对话里输入 `/` 或 `@` 找到「租房线索登记」。

### WorkBuddy

1. 打开「技能」→「添加技能」→「上传技能」。
2. 选择 zip。
3. 安装后在对话里用 `/` 调用。

### 让 AI 自己装

把仓库地址发给支持技能安装的智能体：

```text
https://github.com/QiuMr/rent-lead-intake
```

或者直接把 `SKILL.md` 的 raw 链接发过去：

```text
https://raw.githubusercontent.com/QiuMr/rent-lead-intake/main/SKILL.md
```

## 第一次使用

对 AI 说一句客户需求，例如：

> 高新区两室 预算2500 电话13900000001 王女士

第一次会先问你名字或称号，例如「小王」。填一次后保存在 `~/.rent-lead/whoami.json`，以后不用再填。

## 测试话术

| 说 | 预期 |
|---|---|
| `高新区两室 预算2500 电话13900000001 王女士` | 已登记，编号 X |
| 同一句再说一遍 | 提示之前提交过，不重复登记 |
| `老城区 两室 1900 电梯房` | 提示缺联系方式，补电话后入库 |
| `你好` | 提示内容太短，请补充 |

## 更新

仓库已发布在 <https://github.com/QiuMr/rent-lead-intake>。

以后改技能：

```bash
cd skills/rent-lead-intake
git add .
git commit -m "rent-lead-intake v0.1.1"
git tag v0.1.1
git push origin main --tags
```

然后让用户/AI 重新从 GitHub 安装最新版；本机名字文件不会被覆盖。

## 后台地址

默认 `http://182.92.214.51:8789`，可用环境变量 `RENT_LEAD_API` 覆盖。

## 云端沙盒 / 代理

豆包等宿主可能在云端沙盒里运行技能，出站会被强制走 HTTP 代理（例如 `vortex-*.volces.com:8080`），访问 `IP:8789` 回 502；绕过代理直连是通的。技能脚本已经“直连优先、系统代理兜底”，一般不用处理。仍报 `network_error` 时，设置 `NO_PROXY=182.92.214.51` 重试一次；宿主强制代理时只能本机运行或等 HTTPS 域名。WorkBuddy 是否走沙盒代理尚未实测。

## 隐私

技能只把引流员名字、客户原话和已识别字段发到后台，不读取其他文件、不访问其他网站。公网线索页会展示客户联系方式，请只在内部使用。

## 本地测试

```bash
RENT_LEAD_API=http://127.0.0.1:8789 \
RENT_LEAD_HOME=/tmp/rent-lead-test \
python scripts/lead.py whoami --set 小王
```

Windows PowerShell：

```powershell
$env:RENT_LEAD_API="http://127.0.0.1:8789"
.\scripts\lead.ps1 whoami -Set "小王"
```

