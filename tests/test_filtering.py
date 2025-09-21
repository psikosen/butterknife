from butterknife.filtering import (
    classify_media_type,
    is_probably_favicon,
    should_keep,
)
from butterknife.models import MediaType


def test_is_probably_favicon_by_rel():
    url = "https://example.com/icon.png"
    attributes = {"rel": "shortcut icon"}
    assert is_probably_favicon(url, attributes)


def test_classify_media_type_prefers_content_type():
    media_type = classify_media_type("https://example.com/video.mp4", "video/mp4", "video")
    assert media_type is MediaType.VIDEO


def test_should_keep_filters_small_images():
    keep = should_keep(
        MediaType.IMAGE,
        content_length=5000,
        min_bytes=10_000,
        allow_svg=False,
        is_svg=False,
        include_gif=True,
        is_gif=False,
        include_videos=True,
    )
    assert not keep


def test_should_keep_allows_large_images():
    keep = should_keep(
        MediaType.IMAGE,
        content_length=50_000,
        min_bytes=10_000,
        allow_svg=False,
        is_svg=False,
        include_gif=True,
        is_gif=False,
        include_videos=True,
    )
    assert keep
