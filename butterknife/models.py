"""Data structures for Butter Knife media extraction."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional


class MediaType(str, Enum):
    """Canonical media types discovered on a page."""

    IMAGE = "image"
    VIDEO = "video"
    STREAMING = "streaming"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class MediaItem:
    """A single downloadable media candidate."""

    id: str
    type: MediaType
    url: str
    normalized_url: str
    source_tag: str
    attributes: Dict[str, str] = field(default_factory=dict)
    content_length: Optional[int] = None
    content_type: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    thumbnail_url: Optional[str] = None
    notes: Optional[str] = None


@dataclass
class SkippedStats:
    """Diagnostics for why candidates were skipped."""

    favicons: int = 0
    below_threshold: int = 0
    unsupported_scheme: int = 0
    duplicates: int = 0
    unsupported_type: int = 0
    http_errors: int = 0

    def as_dict(self) -> Dict[str, int]:
        return {
            "favicons": self.favicons,
            "below_threshold": self.below_threshold,
            "unsupported_scheme": self.unsupported_scheme,
            "duplicates": self.duplicates,
            "unsupported_type": self.unsupported_type,
            "http_errors": self.http_errors,
        }

    def add(self, **kwargs: int) -> None:
        for key, value in kwargs.items():
            if not hasattr(self, key):
                raise AttributeError(f"Unknown skip reason: {key}")
            current = getattr(self, key)
            setattr(self, key, current + int(value))


@dataclass
class ExtractionResult:
    """Full result from scanning a page."""

    page_url: str
    found: List[MediaItem] = field(default_factory=list)
    skipped: SkippedStats = field(default_factory=SkippedStats)

    def to_dict(self) -> Dict[str, object]:
        return {
            "page_url": self.page_url,
            "found": [item.__dict__ for item in self.found],
            "skipped": self.skipped.as_dict(),
        }
