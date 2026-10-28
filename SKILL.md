---
name: rent-lead-intake
description: 当用户提供租房客户线索（区域、预算、户型、电话、微信、入住时间等）时，把客户原话登记到租房线索后台。适用于豆包工作、WorkBuddy 等支持 Agent Skills 的宿主。首次使用会先询问引流员的名字或称号并保存在本机，之后自动带上。
metadata:
  version: "0.1.1"
  display_name: "租房线索登记"
  author: "rent-lead-hub"
---

# 租房线索登记

## 什么时候用

- 用户说出任何租房客户需求：区域、预算、户型、电话、微信、入住时间、特殊要求。
- 用户说“登记一下 / 记一下 / 帮我录 / 有个客户要租房 / 这条线索记我名下”。
- 不用于：找房源、算佣金、替客服联系客户、承诺看房。

## 第一次使用：先记住名字

1. 在本技能目录运行：

   ```bash
   python scripts/lead.py whoami
   ```

2. 如果输出为空，先问用户：

   > 先告诉我你的名字或称号，之后这条线索会记在你名下。

3. 用户回答后运行：

   ```bash
   python scripts/lead.py whoami --set "小王"
   ```

4. 如果输出已经有名字，直接继续，不要再问。

说明：

- 名字只用于归属和统计，不是密码，不要向用户索要 token。
- 如果宿主不能运行 Python，用 `scripts/lead.ps1`（Windows）或看下面的“HTTP 兜底”。
- 如果宿主不允许写本地文件，就在每个新会话问一次名字，不要跳过。

## 提交一条线索

1. `--text` 放用户原话，完整保留，不要改写、不要总结。
2. `--fields` 只填能确定的字段；不确定就留空。字段名：

   `nickname`、`phone`、`wechat_id`、`area`、`budget_min`、`budget_max`、`layout`、`move_in`、`tags`

3. 运行：

   ```bash
   python scripts/lead.py submit --text "高新区两室 预算2500 电话13900000001 王女士" --fields '{"area":"高新区","layout":"2室","budget_min":2500,"budget_max":2500,"phone":"13900000001","nickname":"王女士"}'
   ```

4. 读返回的 JSON：

   - `created`：告诉用户“已登记，编号 X”。
   - `needs_info`：按 `data.missing` 一次追问一个；用户补充后调用 `update`。
   - `duplicate`：告诉用户“这条 X 时间已经提交过，没有重复登记”，不要新建。
   - `invalid`：请用户补充区域、预算、户型或联系方式。
   - `unauthorized`：名字被停用，请联系管理员；不要换名字重试。
   - `rate_limited`：稍后再试，不要连续重试。
   - `network_error`：说明后台暂时连不上；先按下面“云端沙盒与代理”处理一次，仍失败再让用户稍后再试。

## 补齐一条线索

```bash
python scripts/lead.py update --candidate-id 12 --fields '{"phone":"13900000002"}' --text "电话13900000002"
```

- `candidate_id` 必须来自上一次 `submit` 的返回，不要自己编。
- 补电话或微信时，`--text` 必须是客户说这句话的原话，否则后台会丢掉这个号码。
- 只补这次新说的字段，不要把旧字段全部重发。

## 硬性规则

- 不编电话、微信、预算、区域、户型；没有就说没有。
- 不承诺“已经加微信 / 已经联系客户 / 已经安排看房”，你只负责登记。
- 一个客户提交一次；一个对话里有多个客户时，分别记住各自的 `candidate_id`，不要混用。
- 用户没说名字时，先问名字，不要提交。
- 用户说的“测试一下”不要提交；只有真实客户需求才登记。

## HTTP 兜底（宿主不能运行脚本时）

如果宿主没有 shell / Python，但有 HTTP 请求工具，直接发：

```http
POST http://182.92.214.51:8789/skill/v1/submit_lead
Content-Type: application/json

{"advertiser":"小王","raw_text":"高新区两室 预算2500 电话13900000001","fields":{"area":"高新区","layout":"2室","budget_min":2500,"budget_max":2500,"phone":"13900000001"}}
```

补齐时发 `POST /skill/v1/update_lead`，带上 `advertiser`、`candidate_id`、`fields` 和 `raw_text`。完整返回码见 `references/api.md`。

## 云端沙盒与代理

豆包等宿主可能在云端沙盒里运行技能，沙盒会强制走 HTTP 代理（如 `vortex-*.volces.com:8080`）。这类代理访问 `IP:8789` 常回 502，但同一请求绕过代理直连是通的。

- 内置脚本已经是“直连优先、系统代理兜底”，正常情况下不用手动处理。
- 如果仍然返回 `network_error`：设置环境变量 `NO_PROXY=182.92.214.51` 后重试一次；还失败就告诉用户“当前宿主的网络连不上后台”，不要反复重试。
- 出现 502 时不要继续走同一个代理重试，改用直连；宿主只能通过代理出网时，在本机运行技能或等 HTTPS 域名。
- WorkBuddy 是否走沙盒代理尚未实测；本机运行通常没有这个问题。

## 更新技能

仓库：<https://github.com/QiuMr/rent-lead-intake>

让 AI 从 GitHub 重新安装最新版即可；本机保存的名字在 `~/.rent-lead/whoami.json`，不会被覆盖。

## 隐私

本技能只把 `advertiser`、`raw_text` 和 `fields` 发到上面的后台地址，不读取其他文件、不访问其他网站。后台地址可用环境变量 `RENT_LEAD_API` 覆盖。
