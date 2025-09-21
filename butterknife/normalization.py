"""URL normalization utilities."""

from __future__ import annotations

from typing import Optional
from urllib.parse import ParseResult, parse_qsl, urljoin, urlparse, urlunparse, urlencode


def _sorted_query(parsed: ParseResult) -> str:
    query_items = parse_qsl(parsed.query, keep_blank_values=True)
    if not query_items:
        return ""
    return urlencode(sorted(query_items), doseq=True)


def normalize_candidate(page_url: str, candidate_url: str) -> Optional[str]:
    """Resolve and normalize a candidate media URL."""

    candidate_url = candidate_url.strip()
    if not candidate_url:
        return None
    if candidate_url.startswith("data:") or candidate_url.startswith("blob:"):
        return None

    resolved = urljoin(page_url, candidate_url)
    parsed = urlparse(resolved)
    if parsed.scheme not in {"http", "https"}:
        return None

    normalized = parsed._replace(fragment="", query=_sorted_query(parsed))
    return urlunparse(normalized)
