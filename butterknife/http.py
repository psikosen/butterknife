"""Networking helpers for probing media metadata."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

import requests

from .logger import structured_log

LOGGER = logging.getLogger(__name__)


@dataclass
class ProbeResult:
    url: str
    content_type: Optional[str]
    content_length: Optional[int]


class ProbeError(RuntimeError):
    """Raised when a probe fails permanently."""


DEFAULT_TIMEOUT = 10


def _safe_int(value: Optional[str]) -> Optional[int]:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def probe_url(
    session: requests.Session,
    url: str,
    timeout: int = DEFAULT_TIMEOUT,
) -> ProbeResult:
    """Fetch metadata for a media URL using HEAD with GET fallback."""

    headers = {"User-Agent": "ButterKnife/1.0"}
    try:
        response = session.head(url, allow_redirects=True, timeout=timeout, headers=headers)
    except requests.RequestException as exc:
        structured_log(
            LOGGER,
            logging.DEBUG,
            "HEAD probe failed",
            system_section="network.probe",
            method="HEAD",
            error=exc,
            extra={"url": url},
        )
        response = None

    if response is None or response.status_code >= 400:
        try:
            response = session.get(
                url,
                allow_redirects=True,
                timeout=timeout,
                headers={**headers, "Range": "bytes=0-0"},
            )
        except requests.RequestException as exc:
            structured_log(
                LOGGER,
                logging.DEBUG,
                "GET probe failed",
                system_section="network.probe",
                method="GET",
                error=exc,
                extra={"url": url},
            )
            raise ProbeError(str(exc)) from exc

    if response is None:
        raise ProbeError("No response during probe")

    content_type = response.headers.get("Content-Type")
    content_length = _safe_int(response.headers.get("Content-Length"))

    structured_log(
        LOGGER,
        logging.DEBUG,
        "Probe succeeded",
        system_section="network.probe",
        method="HEAD" if response.request.method == "HEAD" else "GET",
        extra={
            "url": response.url or url,
            "content_type": content_type,
            "content_length": content_length,
        },
    )

    return ProbeResult(url=response.url or url, content_type=content_type, content_length=content_length)
