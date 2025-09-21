"""Filter rules for Butter Knife media extraction."""

from __future__ import annotations

import os
from typing import Dict, Iterable, Optional
from urllib.parse import urlparse

from .models import MediaType

FAVICON_NAMES = {
    "favicon.ico",
    "favicon.png",
    "apple-touch-icon.png",
    "apple-touch-icon-precomposed.png",
}

STREAMING_EXTENSIONS = {".m3u8", ".mpd"}
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mov", ".m4v", ".avi", ".mpg", ".mpeg"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".svg"}


def is_probably_favicon(url: str, attributes: Dict[str, str]) -> bool:
    parsed = urlparse(url)
    basename = os.path.basename(parsed.path).lower()
    rel = attributes.get("rel", "").lower()
    if "icon" in rel or "shortcut" in rel:
        return True
    return basename in FAVICON_NAMES


def classify_media_type(url: str, content_type: Optional[str], tag_name: str) -> MediaType:
    if content_type:
        lower = content_type.lower()
        if lower.startswith("image/"):
            return MediaType.IMAGE
        if lower.startswith("video/"):
            return MediaType.VIDEO
        if lower in {"application/vnd.apple.mpegurl", "application/dash+xml"}:
            return MediaType.STREAMING

    parsed = urlparse(url)
    ext = os.path.splitext(parsed.path)[1].lower()
    if ext in STREAMING_EXTENSIONS:
        return MediaType.STREAMING
    if ext in VIDEO_EXTENSIONS:
        return MediaType.VIDEO
    if ext in IMAGE_EXTENSIONS:
        return MediaType.IMAGE
    if tag_name == "video":
        return MediaType.VIDEO
    return MediaType.UNKNOWN


def should_keep(
    media_type: MediaType,
    *,
    content_length: Optional[int],
    min_bytes: int,
    allow_svg: bool,
    is_svg: bool,
    include_gif: bool,
    is_gif: bool,
    include_videos: bool,
) -> bool:
    if media_type is MediaType.STREAMING:
        return False

    if media_type is MediaType.VIDEO:
        return include_videos

    if media_type is MediaType.IMAGE:
        if not allow_svg and is_svg:
            return False
        if not include_gif and is_gif:
            return False
        if content_length is not None and content_length < min_bytes:
            return False
        return True

    if media_type is MediaType.UNKNOWN:
        if content_length is not None and content_length >= min_bytes:
            return True
        return False

    return False


def summarize_types(items: Iterable[MediaType]) -> Dict[MediaType, int]:
    summary: Dict[MediaType, int] = {}
    for item_type in items:
        summary[item_type] = summary.get(item_type, 0) + 1
    return summary
