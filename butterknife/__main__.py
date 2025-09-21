"""Entry point for `python -m butterknife`."""

from .cli import run

if __name__ == "__main__":  # pragma: no cover - module entry point
    raise SystemExit(run())
