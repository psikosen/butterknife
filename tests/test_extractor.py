from pathlib import Path

import responses

from butterknife.extractor import extract_from_html
from butterknife.models import MediaType

FIXTURE_HTML = (
    Path(__file__).parent / "fixtures" / "sample.html"
).read_text()


def add_head(url: str, length: int, content_type: str) -> None:
    responses.add(
        responses.HEAD,
        url,
        body=b'0' * length,
        headers={"Content-Type": content_type, "Content-Length": str(length)},
    )


@responses.activate
def test_extract_from_html_filters_favicons_and_small_assets():
    page_url = "https://example.com/article"

    add_head("https://example.com/images/hero-large.jpg", 20480, "image/jpeg")
    add_head("https://example.com/images/logo.png", 1024, "image/png")
    add_head("https://example.com/images/hero-small.jpg", 5120, "image/jpeg")
    add_head("https://example.com/video/promo.mp4", 51200, "video/mp4")
    add_head("https://example.com/images/poster.jpg", 15360, "image/jpeg")

    result = extract_from_html(
        page_url,
        FIXTURE_HTML,
    )

    assert len(result.found) == 3
    media_types = {item.type for item in result.found}
    assert MediaType.IMAGE in media_types
    assert MediaType.VIDEO in media_types

    favicon_count = result.skipped.favicons
    below_threshold = result.skipped.below_threshold
    assert favicon_count == 1
    assert below_threshold == 2


@responses.activate
def test_extract_from_html_handles_probe_errors(caplog):
    page_url = "https://example.com/article"

    responses.add(
        responses.HEAD,
        "https://example.com/images/hero-large.jpg",
        body=responses.ConnectionError("boom"),
    )
    add_head("https://example.com/images/logo.png", 1024, "image/png")
    add_head("https://example.com/images/hero-small.jpg", 5120, "image/jpeg")
    add_head("https://example.com/video/promo.mp4", 51200, "video/mp4")
    add_head("https://example.com/images/poster.jpg", 15360, "image/jpeg")

    result = extract_from_html(
        page_url,
        FIXTURE_HTML,
    )

    assert len(result.found) == 2
    assert all("hero-large" not in item.url for item in result.found)
    assert result.skipped.http_errors == 1
    assert any("Media probe failed" in message for message in caplog.messages)


@responses.activate
def test_extract_from_html_head_fallback_to_get():
    page_url = "https://example.com/article"

    responses.add(
        responses.HEAD,
        "https://example.com/images/hero-large.jpg",
        status=405,
    )
    responses.add(
        responses.GET,
        "https://example.com/images/hero-large.jpg",
        body=b'0' * 20480,
        headers={"Content-Type": "image/jpeg", "Content-Length": "20480"},
    )
    add_head("https://example.com/images/logo.png", 1024, "image/png")
    add_head("https://example.com/images/hero-small.jpg", 5120, "image/jpeg")
    add_head("https://example.com/video/promo.mp4", 51200, "video/mp4")
    add_head("https://example.com/images/poster.jpg", 15360, "image/jpeg")

    result = extract_from_html(
        page_url,
        FIXTURE_HTML,
    )

    assert len(result.found) == 3
