"""Command line interface for Butter Knife extraction."""

from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path
from typing import Optional

import requests

from .extractor import extract_from_url
from .logger import structured_log

LOGGER = logging.getLogger("butterknife.cli")


def configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s %(message)s")


def download_media(session: requests.Session, url: str, destination: Path) -> Path:
    response = session.get(url, stream=True, timeout=30)
    response.raise_for_status()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as handle:
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                handle.write(chunk)
    return destination


def run(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Extract media assets from a web page.")
    parser.add_argument("url", help="Page URL to process")
    parser.add_argument("--min-bytes", type=int, default=10 * 1024, help="Minimum content length to keep")
    parser.add_argument("--allow-svg", action="store_true", help="Include SVG images in the results")
    parser.add_argument("--exclude-gif", action="store_true", help="Filter out animated GIFs")
    parser.add_argument("--exclude-video", action="store_true", help="Filter out video sources")
    parser.add_argument("--download", action="store_true", help="Download all found assets")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("downloads"),
        help="Directory to store downloads when --download is enabled",
    )
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")

    args = parser.parse_args(argv)
    configure_logging(args.verbose)

    session = requests.Session()
    result = extract_from_url(
        args.url,
        min_bytes=args.min_bytes,
        allow_svg=args.allow_svg,
        include_gif=not args.exclude_gif,
        include_videos=not args.exclude_video,
        session=session,
    )

    print(json.dumps(result.to_dict(), indent=2))

    structured_log(
        LOGGER,
        logging.INFO,
        "Extraction complete",
        system_section="cli",
        extra={
            "page_url": args.url,
            "found": len(result.found),
            "skipped": result.skipped.as_dict(),
        },
    )

    if args.download and result.found:
        for item in result.found:
            file_name = item.url.split("/")[-1] or f"asset-{item.id}"
            destination = args.output / file_name
            structured_log(
                LOGGER,
                logging.INFO,
                "Downloading media item",
                system_section="cli.download",
                method="GET",
                extra={
                    "url": item.url,
                    "destination": str(destination),
                    "media_type": item.type.value,
                },
            )
            download_media(session, item.url, destination)

    return 0


if __name__ == "__main__":  # pragma: no cover - CLI entry point
    raise SystemExit(run())
