#!/usr/bin/env python3
"""Delete superseded packages from the Liquorix PPA."""

import argparse
import logging
import sys
import warnings
from collections import defaultdict
from pathlib import Path
from typing import Any

# Suppress pkg_resources deprecation warning from lazr (launchpadlib dependency)
warnings.filterwarnings(
    "ignore", message="pkg_resources is deprecated", category=UserWarning
)

from launchpadlib.launchpad import (  # type: ignore[import-untyped]  # noqa: E402  # pylint: disable=wrong-import-position
    Launchpad,
)

log = logging.getLogger(__name__)


def parse_series_name(series_link: str) -> str:
    """Extract the series name from a distro_series_link URL."""
    return series_link.rstrip("/").rsplit("/", 1)[-1]


def delete_source(
    launchpad: Launchpad,
    entry: dict[str, Any],
    *,
    dry_run: bool = False,
    force: bool = False,
) -> None:
    """Delete source package if no non-superseded published binaries are found.

    When force=True, delete regardless of binary status (for purging an
    obsolete series).
    """
    obj = launchpad.load(entry["self_link"])
    binaries = obj.getPublishedBinaries()

    all_binaries_deletable = all(
        delete_binary(launchpad, binary_entry, dry_run=dry_run, force=force)
        for binary_entry in binaries.entries
    )

    if all_binaries_deletable or force:
        log.info("Deleting source: %s", entry["display_name"])
        if not dry_run:
            obj.requestDeletion(
                removal_comment="Automated removal of superseded package."
            )
    else:
        log.warning("Published binaries still exist for source, not deleting sources.")


def delete_binary(
    launchpad: Launchpad,
    entry: dict[str, Any],
    *,
    dry_run: bool = False,
    force: bool = False,
) -> bool:
    """Delete binary package if not already removed.

    Returns True if the binary is deleted (or already deleted), False if it
    is in a state that prevents deletion (unless force=True).
    """
    status = entry["status"]

    if status == "Deleted":
        return True

    if not force and status != "Superseded":
        log.debug("Binary not deletable (status=%s): %s", status, entry["display_name"])
        return False

    log.info("Deleting binary (status=%s): %s", status, entry["display_name"])
    if not dry_run:
        obj = launchpad.load(entry["self_link"])
        obj.requestDeletion(removal_comment="Automated removal of superseded package.")

    return True


def _process_group(  # pylint: disable=too-many-arguments
    launchpad: Launchpad,
    name: str,
    series_link: str,
    entries: list[dict[str, Any]],
    *,
    keep: int,
    dry_run: bool,
) -> None:
    """Process a group of superseded sources for one package+series."""
    sname = parse_series_name(series_link)
    kept = entries[:keep]
    to_delete = entries[keep:]

    if not to_delete:
        log.info(
            "Keeping all %d superseded source(s) for %s (%s): %s",
            len(kept),
            name,
            sname,
            kept[0]["display_name"],
        )
        return

    for entry in kept:
        log.debug(
            "Keeping superseded source for %s (%s): %s",
            name,
            sname,
            entry["display_name"],
        )
    for entry in to_delete:
        delete_source(launchpad, entry, dry_run=dry_run)


def delete_superseded(
    launchpad: Launchpad,
    ppa: Any,
    *,
    series: str | None = None,
    keep: int = 1,
    dry_run: bool = False,
) -> int:
    """Delete superseded packages, optionally filtered to a single series."""
    sources = ppa.getPublishedSources(status="Superseded")

    grouped: defaultdict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for source_entry in sources.entries:
        series_name = parse_series_name(source_entry["distro_series_link"])
        if series and series_name != series:
            continue
        key = (source_entry["source_package_name"], source_entry["distro_series_link"])
        grouped[key].append(source_entry)

    for (name, series_link), entries in grouped.items():
        entries.sort(key=lambda e: e["date_published"], reverse=True)
        _process_group(
            launchpad, name, series_link, entries, keep=keep, dry_run=dry_run
        )

    log.info("Script complete!")
    return 0


def purge_series(
    launchpad: Launchpad, ppa: Any, series: str, *, dry_run: bool = False
) -> int:
    """Delete ALL packages (published, superseded, etc.) for an obsolete series."""
    log.info("Purging all packages for obsolete series: %s", series)

    for status in ("Published", "Superseded", "Pending"):
        sources = ppa.getPublishedSources(status=status)
        for source_entry in sources.entries:
            series_name = parse_series_name(source_entry["distro_series_link"])
            if series_name != series:
                continue
            log.info(
                "Purging %s source (status=%s): %s",
                series,
                status,
                source_entry["display_name"],
            )
            delete_source(launchpad, source_entry, dry_run=dry_run, force=True)

    log.info("Purge of series '%s' complete!", series)
    return 0


def main() -> int:
    """Find and delete superseded packages in Liquorix PPA."""
    parser = argparse.ArgumentParser(
        description="Delete superseded packages from the Liquorix PPA."
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="preview deletions without executing them",
    )
    parser.add_argument(
        "-k",
        "--keep",
        type=int,
        default=1,
        metavar="N",
        help="number of superseded versions to retain per package+series (default: 1)",
    )
    parser.add_argument(
        "-s",
        "--series",
        metavar="NAME",
        help="only process packages for this Ubuntu series (e.g. 'jammy')",
    )
    parser.add_argument(
        "--purge-series",
        metavar="NAME",
        help="delete ALL packages (including published) for an obsolete series",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="enable debug-level logging",
    )
    args = parser.parse_args()

    if args.purge_series and args.series:
        parser.error("--purge-series and --series are mutually exclusive")

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)-7s %(message)s",
    )
    if args.verbose:
        log.setLevel(logging.DEBUG)

    cachedir = Path.home() / ".launchpadlib" / "cache"
    launchpad = Launchpad.login_with(
        "Liquorix", "production", str(cachedir), version="devel"
    )
    ppa = launchpad.me.getPPAByName(name="liquorix")

    if args.dry_run:
        log.info("Dry-run mode enabled — no packages will be deleted.")

    if args.purge_series:
        return purge_series(launchpad, ppa, args.purge_series, dry_run=args.dry_run)

    return delete_superseded(
        launchpad, ppa, series=args.series, keep=args.keep, dry_run=args.dry_run
    )


if __name__ == "__main__":
    sys.exit(main())
