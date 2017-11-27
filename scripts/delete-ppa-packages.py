#!/usr/bin/env python3

import os
import datetime
from launchpadlib.launchpad import Launchpad
from launchpadlib.credentials import Credentials

if __name__ == "__main__":
    cachedir = os.path.expanduser('~/.launchpadlib/cache')
    launchpad = Launchpad.login_with(
        'Liquorix', 'production', cachedir, version='devel')
    ppa = launchpad.me.getPPAByName(name="liquorix")

    # We can either user superseded sources or binaries.  Sources supersede
    # immediately while binaries only superseded after a new binary has been
    # published.  This works in our favor since we only want to delete the
    # package if there's a new version available for download.
    superseded_binaries = ppa.getPublishedBinaries(status="Superseded")

    if superseded_binaries:
        for entry in superseded_binaries.entries:

            # Deleted packages have a time stamp for their date_removed
            # attribute.  No need to request deletion on these.
            if entry['date_removed']:
                continue

            print("[INFO ] Deleting superseded package: " +
                  entry["display_name"])

            entry_obj = launchpad.load(entry['self_link'])
            entry_obj.requestDeletion(
                removal_comment='Automated removal of superseded package.')

    print("[INFO ] Script complete!")
