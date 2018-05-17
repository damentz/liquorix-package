#!/usr/bin/env python2

import os
from launchpadlib.launchpad import Launchpad


def delete_source(launchpad, entry):
    """
    Delete source package if no non-superseded published binaries are found.
    """

    obj = launchpad.load(entry['self_link'])
    binaries = obj.getPublishedBinaries()

    no_binaries = True
    for binary_entry in binaries.entries:
        if not delete_binary(launchpad, binary_entry):
            no_binaries = False

    if no_binaries:
        print("[INFO ] Deleting superseded source: " +
              entry["display_name"])
        obj.requestDeletion(
            removal_comment='Automated removal of superseded package.')
    else:
        print("[WARN ] Published binaries still exist for source, not deleting sources.")

    return


def delete_binary(launchpad, entry):
    """
    Delete package if not already removed.

    This method returns True if package is deleted successfully or already deleted.
    """

    if entry['status'] == 'Deleted':
        return True

    print("[INFO ] Deleting superseded binary: " + entry["display_name"])
    obj = launchpad.load(entry['self_link'])
    obj.requestDeletion(
        removal_comment='Automated removal of superseded package.')

    return True


def main():
    """Find and delete superseded packages in Liquorix PPA"""
    cachedir = os.path.expanduser('~/.launchpadlib/cache')
    launchpad = Launchpad.login_with(
        'Liquorix', 'production', cachedir, version='devel')
    ppa = launchpad.me.getPPAByName(name="liquorix")

    # We can either delete superseded sources or binaries.  Sources supersede
    # immediately while binaries only superseded after a new binary has been
    # published.  This works in our favor since we only want to delete the
    # package if there's a new version available for download.
    #
    # However, I've found that even though you may delete the superseded
    # binaries, they get stuck in the PPA until the package is removed
    # through the published source.  So in that case, this script will
    # find superseded sources, attempt to delete any superseded binaries in
    # the process.  If any binaries that can't be removed are found, then
    # the sources will not be deleted.
    sources = ppa.getPublishedSources(status="Superseded")

    for source_entry in sources.entries:
        delete_source(launchpad, source_entry)

    print("[INFO ] Script complete!")


if __name__ == "__main__":
    main()
