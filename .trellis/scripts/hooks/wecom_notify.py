#!/usr/bin/env python3
"""企业微信任务通知 Hook。

读取 Trellis 任务生命周期事件，并通过企业微信群机器人发送任务状态通知。
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

# 企业微信机器人接口超时时间，避免通知阻塞任务命令。
REQUEST_TIMEOUT_SECONDS = 10

# 默认发送普通文本，保证从企业微信转发到微信时可正常查看。
DEFAULT_MESSAGE_TYPE = "text"

# 支持的企业微信机器人消息类型。
SUPPORTED_MESSAGE_TYPES = {"text", "markdown"}

# 生命周期事件展示文案，用于让群消息更贴近任务场景。
EVENT_LABELS = {
    "create": "任务创建",
    "start": "任务开始",
    "finish": "任务结束",
    "archive": "任务归档",
    "sync": "任务同步",
}


def _read_task_json_path() -> Path:
    """读取当前任务 JSON 路径。

    Returns:
        当前 Trellis 生命周期事件对应的 task.json 路径。

    Raises:
        RuntimeError: TASK_JSON_PATH 缺失时抛出。
    """
    task_json_path = os.environ.get("TASK_JSON_PATH", "").strip()
    if not task_json_path:
        raise RuntimeError("TASK_JSON_PATH 未设置")
    return Path(task_json_path)


def _find_trellis_dir(task_json_path: Path) -> Path:
    """定位当前仓库的 .trellis 目录。

    Args:
        task_json_path: 生命周期事件传入的 task.json 路径。

    Returns:
        当前任务所属的 .trellis 目录。
    """
    for parent in task_json_path.resolve().parents:
        # 归档任务路径和普通任务路径都位于 .trellis/tasks 下。
        if parent.name == ".trellis":
            return parent
    return Path(".trellis")


def _load_json(path: Path) -> dict[str, Any]:
    """读取 JSON 文件内容。

    Args:
        path: 需要读取的 JSON 文件路径。

    Returns:
        JSON 对象字典。
    """
    with path.open(encoding="utf-8") as file:
        data = json.load(file)
    return data if isinstance(data, dict) else {}


def _load_wecom_config(trellis_dir: Path) -> dict[str, str]:
    """读取企业微信机器人配置。

    Args:
        trellis_dir: 当前项目的 .trellis 目录。

    Returns:
        企业微信机器人配置；未配置时返回空字典。
    """
    config_path = trellis_dir / "hooks.local.json"
    if not config_path.is_file():
        return {}

    config = _load_json(config_path)
    wecom_config = config.get("wecom")
    if not isinstance(wecom_config, dict):
        return {}

    webhook = wecom_config.get("webhook", "")
    message_type = wecom_config.get("messageType", DEFAULT_MESSAGE_TYPE)
    return {
        "webhook": webhook.strip() if isinstance(webhook, str) else "",
        "messageType": message_type.strip() if isinstance(message_type, str) else DEFAULT_MESSAGE_TYPE,
    }


def _field_text(task: dict[str, Any], key: str, default: str) -> str:
    """读取任务字段展示值。

    Args:
        task: 当前任务 JSON 内容。
        key: 任务字段名。
        default: 字段缺失时的默认展示文案。

    Returns:
        可直接用于 Markdown 消息的字段文本。
    """
    value = task.get(key)
    if value is None or value == "":
        return default
    return str(value)


def _build_markdown(event_name: str, task: dict[str, Any]) -> str:
    """构建企业微信 Markdown 消息。

    Args:
        event_name: Trellis 生命周期事件名称。
        task: 当前任务 JSON 内容。

    Returns:
        企业微信机器人 markdown 消息正文。
    """
    event_label = EVENT_LABELS.get(event_name, event_name)
    title = _field_text(task, "title", _field_text(task, "name", "未命名任务"))
    status = _field_text(task, "status", "未知状态")
    priority = _field_text(task, "priority", "未设置")
    assignee = _field_text(task, "assignee", "未分配")

    # 按任务事件聚合关键字段，便于企业微信里快速判断进展。
    return "\n".join(
        [
            "## Trellis 任务通知",
            f"> 事件：<font color=\"info\">{event_label}</font>",
            f"> 任务：{title}",
            f"> 状态：{status}",
            f"> 优先级：{priority}",
            f"> 负责人：{assignee}",
        ]
    )


def _build_text(event_name: str, task: dict[str, Any]) -> str:
    """构建企业微信文本消息。

    Args:
        event_name: Trellis 生命周期事件名称。
        task: 当前任务 JSON 内容。

    Returns:
        企业微信机器人 text 消息正文。
    """
    event_label = EVENT_LABELS.get(event_name, event_name)
    title = _field_text(task, "title", _field_text(task, "name", "未命名任务"))
    status = _field_text(task, "status", "未知状态")
    priority = _field_text(task, "priority", "未设置")
    assignee = _field_text(task, "assignee", "未分配")

    # 文本消息转发到微信兼容性更好，避免 markdown 类型不被微信侧支持。
    return "\n".join(
        [
            "Trellis 任务通知",
            f"事件：{event_label}",
            f"任务：{title}",
            f"状态：{status}",
            f"优先级：{priority}",
            f"负责人：{assignee}",
        ]
    )


def _build_payload(message_type: str, event_name: str, task: dict[str, Any]) -> dict[str, Any]:
    """构建企业微信机器人请求体。

    Args:
        message_type: 企业微信机器人消息类型。
        event_name: Trellis 生命周期事件名称。
        task: 当前任务 JSON 内容。

    Returns:
        企业微信机器人请求体。

    Raises:
        RuntimeError: 消息类型不受支持时抛出。
    """
    if message_type not in SUPPORTED_MESSAGE_TYPES:
        raise RuntimeError(f"不支持的企业微信消息类型：{message_type}")

    # markdown 仅适合企业微信内查看，text 适合转发到微信。
    if message_type == "markdown":
        return {
            "msgtype": "markdown",
            "markdown": {
                "content": _build_markdown(event_name, task),
            },
        }

    return {
        "msgtype": "text",
        "text": {
            "content": _build_text(event_name, task),
        },
    }


def _send_payload(webhook: str, payload: dict[str, Any]) -> None:
    """发送消息到企业微信。

    Args:
        webhook: 企业微信机器人 Webhook 地址。
        payload: 企业微信机器人请求体。

    Raises:
        RuntimeError: 企业微信接口返回失败码时抛出。
        urllib.error.URLError: 网络请求失败时抛出。
    """
    request = urllib.request.Request(
        webhook,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    # 接口失败需要暴露给 hook runner，便于终端看到告警。
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        response_data = json.loads(response.read().decode("utf-8"))
    if response_data.get("errcode") != 0:
        raise RuntimeError(f"企业微信通知失败：{response_data}")


def main() -> int:
    """执行企业微信任务通知。

    Returns:
        进程退出码；缺少本地配置时返回 0，避免阻塞 Trellis 主流程。
    """
    event_name = sys.argv[1] if len(sys.argv) > 1 else "sync"
    task_json_path = _read_task_json_path()
    task = _load_json(task_json_path)
    trellis_dir = _find_trellis_dir(task_json_path)
    wecom_config = _load_wecom_config(trellis_dir)
    webhook = wecom_config.get("webhook", "")
    message_type = wecom_config.get("messageType", DEFAULT_MESSAGE_TYPE)

    # 未配置本地 Webhook 时跳过通知，方便仓库默认可运行。
    if not webhook:
        return 0

    payload = _build_payload(message_type, event_name, task)
    _send_payload(webhook, payload)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, urllib.error.URLError, json.JSONDecodeError) as error:
        print(f"企业微信通知 Hook 异常：{error}", file=sys.stderr)
        raise SystemExit(1)
