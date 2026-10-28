#!/usr/bin/env python3
"""租房线索技能的命令行入口：只做三件事——记住名字、提交线索、补齐线索。

只用 Python 标准库，不依赖任何第三方包。后台地址可用 RENT_LEAD_API 覆盖。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from urllib import error, request

DEFAULT_API = "http://182.92.214.51:8789"
API = os.environ.get("RENT_LEAD_API", DEFAULT_API).rstrip("/")
HOME = Path(os.environ.get("RENT_LEAD_HOME", str(Path.home() / ".rent-lead")))
CONFIG = HOME / "whoami.json"


def _utf8() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
        except (AttributeError, OSError):
            pass


def _print(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2))


def get_name() -> str:
    try:
        data = json.loads(CONFIG.read_text("utf-8"))
    except (OSError, ValueError):
        return ""
    return str(data.get("name") or "").strip()


def set_name(raw: str) -> str:
    name = " ".join(raw.split())[:32]
    if not name:
        raise SystemExit("名字不能为空")
    HOME.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text(
        json.dumps(
            {"name": name, "saved_at": datetime.now().isoformat(timespec="seconds")},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return name


def parse_fields(raw: str) -> dict[str, object] | None:
    if not raw.strip():
        return None
    try:
        data = json.loads(raw)
    except ValueError as exc:
        raise SystemExit(f"--fields 需要 JSON 对象：{exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit("--fields 需要 JSON 对象")
    return data


def post(path: str, payload: dict[str, object]) -> tuple[dict[str, object], int]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = request.Request(
        API + path,
        data=body,
        method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8")), 0
    except error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            data = json.loads(raw)
        except ValueError:
            data = {
                "ok": False,
                "code": "http_error",
                "message": f"后台返回 HTTP {exc.code}",
                "data": {"body": raw[:300]},
            }
        return data, 1
    except (error.URLError, TimeoutError, OSError) as exc:
        return {
            "ok": False,
            "code": "network_error",
            "message": f"连不上后台：{exc}",
            "data": {},
        }, 1


def require_name() -> str:
    name = get_name()
    if not name:
        _print(
            {
                "ok": False,
                "code": "no_name",
                "message": "请先填写你的名字或称号，再提交线索。",
                "data": {},
            }
        )
        raise SystemExit(2)
    return name


def cmd_whoami(args: argparse.Namespace) -> int:
    if args.set_name:
        print(set_name(args.set_name))
        return 0
    print(get_name())
    return 0


def cmd_submit(args: argparse.Namespace) -> int:
    name = require_name()
    payload: dict[str, object] = {
        "advertiser": name,
        "channel": "skill",
        "raw_text": args.text,
    }
    fields = parse_fields(args.fields)
    if fields is not None:
        payload["fields"] = fields
    if args.client_id:
        payload["client_msg_id"] = args.client_id
    if args.ts:
        payload["ts"] = args.ts
    data, code = post("/skill/v1/submit_lead", payload)
    _print(data)
    return code


def cmd_update(args: argparse.Namespace) -> int:
    name = require_name()
    fields = parse_fields(args.fields)
    if fields is None:
        raise SystemExit("--fields 不能为空")
    payload: dict[str, object] = {
        "advertiser": name,
        "candidate_id": args.candidate_id,
        "fields": fields,
    }
    if args.text:
        payload["raw_text"] = args.text
    data, code = post("/skill/v1/update_lead", payload)
    _print(data)
    return code


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="租房线索技能")
    sub = parser.add_subparsers(dest="command", required=True)

    who = sub.add_parser("whoami", help="读取或设置引流员名字")
    who.add_argument("--set", dest="set_name", default="", help="设置名字或称号")
    who.set_defaults(func=cmd_whoami)

    submit = sub.add_parser("submit", help="提交一条线索")
    submit.add_argument("--text", required=True, help="客户原话，完整保留")
    submit.add_argument("--fields", default="", help="已识别字段的 JSON")
    submit.add_argument("--client-id", default="", help="同一消息重试时保持不变")
    submit.add_argument("--ts", default="", help="消息时间，ISO 格式，可省略")
    submit.set_defaults(func=cmd_submit)

    update = sub.add_parser("update", help="补齐或修正一条线索")
    update.add_argument("--candidate-id", type=int, required=True)
    update.add_argument("--fields", required=True, help="本次补充字段的 JSON")
    update.add_argument("--text", default="", help="客户补充的原话")
    update.set_defaults(func=cmd_update)
    return parser


def main() -> int:
    _utf8()
    args = build_parser().parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
