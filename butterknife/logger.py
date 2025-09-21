"""Structured logging utilities for Butter Knife."""

from __future__ import annotations

import inspect
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional


def structured_log(
    logger: logging.Logger,
    level: int,
    message: str,
    *,
    system_section: str,
    method: str = "NONE",
    error: Optional[BaseException] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> None:
    frame = inspect.currentframe()
    try:
        if frame is None or frame.f_back is None:
            caller = None
        else:
            caller = frame.f_back

        filename = Path(caller.f_code.co_filename).name if caller else "<unknown>"
        function = caller.f_code.co_name if caller else "<unknown>"
        line_num = caller.f_lineno if caller else 0
        classname = caller.f_globals.get("__name__", "<module>") if caller else "<module>"

        payload: Dict[str, Any] = {
            "filename": filename,
            "timestamp": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
            "classname": classname,
            "function": function,
            "system_section": system_section,
            "line_num": line_num,
            "error": str(error) if error else None,
            "db_phase": "none",
            "method": method,
            "message": message,
        }
        if extra:
            payload.update(extra)

        logger.log(level, json.dumps(payload, ensure_ascii=False))
        derived = f"[The 17 Commandments of Quality Code] {message}"
        logger.log(level, derived)
    finally:
        del frame
        if 'caller' in locals():
            del caller
