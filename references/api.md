# 后台接口

Base URL：`http://182.92.214.51:8789`（可用环境变量 `RENT_LEAD_API` 覆盖）

不需要 token。身份由请求体里的 `advertiser`（引流员名字/称号）决定，后台首次见到名字会自动登记。

## 提交线索

`POST /skill/v1/submit_lead`

```json
{
  "advertiser": "小王",
  "channel": "skill",
  "raw_text": "高新区两室 预算2500 电话13900000001 王女士",
  "fields": {
    "nickname": "王女士",
    "area": "高新区",
    "layout": "2室",
    "budget_min": 2500,
    "budget_max": 2500,
    "phone": "13900000001",
    "wechat_id": null,
    "move_in": null,
    "tags": []
  },
  "client_msg_id": "optional-idempotency-key",
  "ts": "2026-10-28T10:12:00+08:00"
}
```

- `raw_text` 必填，放用户原话。
- `fields` 可省略；只填确定的字段。
- `client_msg_id` 可省略；同一条消息重试时保持不变。
- `ts` 可省略。

## 补齐线索

`POST /skill/v1/update_lead`

```json
{
  "advertiser": "小王",
  "candidate_id": 12,
  "fields": { "phone": "13900000002" },
  "raw_text": "电话13900000002"
}
```

- `candidate_id` 必须来自 `submit_lead` 的返回。
- 补电话/微信时，`raw_text` 必须是客户说这句话的原话，否则电话会因“原文找不到”被丢弃。

## 返回结构

```json
{
  "ok": true,
  "code": "created",
  "message": "已登记，已进入线索页。",
  "data": {
    "candidate_id": 12,
    "status": "accepted",
    "missing": [],
    "warnings": [],
    "duplicate": false
  }
}
```

## 返回码

| code | HTTP | 含义 | AI 该怎么回用户 |
|---|---|---|---|
| `created` | 200 | 已登记 | 已登记，编号 X |
| `needs_info` | 200 | 已登记但缺字段 | 还差 X，补一下 |
| `duplicate` | 200 | 电话/微信已存在 | 这条 X 时间提交过，没重复记 |
| `invalid` | 200 | 内容不足或名字为空 | 再说详细点 / 先填名字 |
| `unauthorized` | 403 | 名字被停用或无权修改 | 找管理员，不要换名字重试 |
| `rate_limited` | 429 | 提交太频繁 | 稍后再试 |
| `server_error` | 500 | 后台异常 | 稍后再试 |

`data.missing` 是 `needs_info` 时还需要追问的字段，例如 `["联系方式"]`、`["预算"]`。

## curl 示例

```bash
curl -X POST http://182.92.214.51:8789/skill/v1/submit_lead \
  -H "Content-Type: application/json" \
  -d '{"advertiser":"小王","raw_text":"高新区两室 预算2500 电话13900000001","fields":{"area":"高新区","layout":"2室","budget_min":2500,"budget_max":2500,"phone":"13900000001"}}'
```

公网线索页：`http://182.92.214.51:8789/leads`
