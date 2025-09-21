"""High-level extraction pipeline for Butter Knife."""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional

import requests
from bs4 import BeautifulSoup

from .filtering import classify_media_type, is_probably_favicon, should_keep
from .http import ProbeError, probe_url
from .logger import structured_log
from .models import ExtractionResult, MediaItem, MediaType
from .normalization import normalize_candidate

LOGGER = logging.getLogger(__name__)


@dataclass
class Candidate:
    url: str
    tag: str
    attributes: Dict[str, str]
    origin_description: str


DEFAULT_MIN_BYTES = 10 * 1024


def _pick_best_from_srcset(srcset: str) -> Optional[str]:
    candidates: List[tuple[float, str]] = []
    for entry in srcset.split(","):
        part = entry.strip()
        if not part:
            continue
        segments = part.split()
        if not segments:
            continue
        url = segments[0]
        descriptor = segments[1] if len(segments) > 1 else "1x"
        multiplier = 1.0
        if descriptor.endswith("w"):
            try:
                multiplier = float(descriptor[:-1])
            except ValueError:
                multiplier = 1.0
        elif descriptor.endswith("x"):
            try:
                multiplier = float(descriptor[:-1])
            except ValueError:
                multiplier = 1.0
        candidates.append((multiplier, url))
    if not candidates:
        return None
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def _gather_candidates(soup: BeautifulSoup) -> Iterable[Candidate]:
    for tag in soup.find_all("img"):
        attributes = {key: value for key, value in tag.attrs.items() if isinstance(value, str)}
        srcset = attributes.get("srcset")
        if srcset:
            best = _pick_best_from_srcset(srcset)
            if best:
                yield Candidate(best, "img", attributes | {"srcset": srcset}, "img[srcset]")
        src = attributes.get("src")
        if src:
            yield Candidate(src, "img", attributes, "img[src]")

    for tag in soup.find_all("source"):
        attributes = {key: value for key, value in tag.attrs.items() if isinstance(value, str)}
        src = attributes.get("src")
        if src:
            parent = tag.parent.name if tag.parent else "source"
            yield Candidate(src, parent, attributes, f"{parent}<source>")
        srcset = attributes.get("srcset")
        if srcset:
            best = _pick_best_from_srcset(srcset)
            if best:
                parent = tag.parent.name if tag.parent else "source"
                yield Candidate(best, parent, attributes | {"srcset": srcset}, f"{parent}<source srcset>")

    for tag in soup.find_all("video"):
        attributes = {key: value for key, value in tag.attrs.items() if isinstance(value, str)}
        poster = attributes.get("poster")
        if poster:
            yield Candidate(poster, "video", attributes, "video[poster]")
        src = attributes.get("src")
        if src:
            yield Candidate(src, "video", attributes, "video[src]")

    for tag in soup.find_all("link"):
        attributes = {key: value for key, value in tag.attrs.items() if isinstance(value, str)}
        href = attributes.get("href")
        if href:
            yield Candidate(href, "link", attributes, "link[href]")


def _candidate_id(normalized_url: str) -> str:
    return hashlib.sha1(normalized_url.encode("utf-8")).hexdigest()


def _is_gif(url: str, content_type: Optional[str]) -> bool:
    if content_type and content_type.lower().startswith("image/gif"):
        return True
    return url.lower().endswith(".gif")


def _is_svg(url: str, content_type: Optional[str]) -> bool:
    if content_type and content_type.lower().endswith("svg+xml"):
        return True
    return url.lower().endswith(".svg")


def extract_from_html(
    page_url: str,
    html: str,
    *,
    min_bytes: int = DEFAULT_MIN_BYTES,
    allow_svg: bool = False,
    include_gif: bool = True,
    include_videos: bool = True,
    session: Optional[requests.Session] = None,
) -> ExtractionResult:
    """Extract media items from an HTML payload."""

    soup = BeautifulSoup(html, "html.parser")
    result = ExtractionResult(page_url=page_url)
    seen: Dict[str, MediaItem] = {}
    http_session = session or requests.Session()

    for candidate in _gather_candidates(soup):
        normalized = normalize_candidate(page_url, candidate.url)
        if not normalized:
            structured_log(
                LOGGER,
                logging.DEBUG,
                "Candidate rejected due to unsupported URL scheme",
                system_section="extraction.filter",
                extra={"candidate_url": candidate.url},
            )
            result.skipped.add(unsupported_scheme=1)
            continue

        if candidate.tag == "link" and is_probably_favicon(normalized, candidate.attributes):
            structured_log(
                LOGGER,
                logging.DEBUG,
                "Candidate rejected as favicon",
                system_section="extraction.filter",
                extra={"url": normalized},
            )
            result.skipped.add(favicons=1)
            continue

        if normalized in seen:
            structured_log(
                LOGGER,
                logging.DEBUG,
                "Candidate rejected as duplicate",
                system_section="extraction.filter",
                extra={"url": normalized},
            )
            result.skipped.add(duplicates=1)
            continue

        try:
            probe = probe_url(http_session, normalized)
        except ProbeError as exc:
            structured_log(
                LOGGER,
                logging.WARNING,
                "Media probe failed",
                system_section="extraction.probe",
                method="HEAD",
                error=exc,
                extra={"url": normalized},
            )
            result.skipped.add(http_errors=1)
            continue

        media_type = classify_media_type(probe.url, probe.content_type, candidate.tag)
        is_svg = _is_svg(probe.url, probe.content_type)
        is_gif = _is_gif(probe.url, probe.content_type)

        keep = should_keep(
            media_type,
            content_length=probe.content_length,
            min_bytes=min_bytes,
            allow_svg=allow_svg,
            is_svg=is_svg,
            include_gif=include_gif,
            is_gif=is_gif,
            include_videos=include_videos,
        )
        if not keep:
            if (
                media_type is MediaType.IMAGE
                and probe.content_length is not None
                and probe.content_length < min_bytes
            ):
                result.skipped.add(below_threshold=1)
                reason = "below_threshold"
            else:
                result.skipped.add(unsupported_type=1)
                reason = "unsupported_type"
            structured_log(
                LOGGER,
                logging.INFO,
                "Candidate rejected by filter",
                system_section="extraction.filter",
                extra={
                    "url": normalized,
                    "reason": reason,
                    "media_type": media_type.value,
                    "content_length": probe.content_length,
                },
            )
            continue

        item = MediaItem(
            id=_candidate_id(normalized),
            type=media_type,
            url=probe.url,
            normalized_url=normalized,
            source_tag=candidate.origin_description,
            attributes=candidate.attributes,
            content_length=probe.content_length,
            content_type=probe.content_type,
            notes=None,
        )
        seen[normalized] = item
        structured_log(
            LOGGER,
            logging.INFO,
            "Media candidate accepted",
            system_section="extraction.selection",
            extra={
                "url": item.url,
                "media_type": item.type.value,
                "content_length": item.content_length,
            },
        )

    result.found.extend(seen.values())
    return result


def extract_from_url(
    page_url: str,
    *,
    min_bytes: int = DEFAULT_MIN_BYTES,
    allow_svg: bool = False,
    include_gif: bool = True,
    include_videos: bool = True,
    session: Optional[requests.Session] = None,
) -> ExtractionResult:
    """Fetch a page and extract media items."""

    http_session = session or requests.Session()
    response = http_session.get(page_url, timeout=10)
    response.raise_for_status()
    return extract_from_html(
        page_url=page_url,
        html=response.text,
        min_bytes=min_bytes,
        allow_svg=allow_svg,
        include_gif=include_gif,
        include_videos=include_videos,
        session=http_session,
    )
