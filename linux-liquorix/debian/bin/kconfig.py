#!/usr/bin/python3

import optparse
import re

from debian_linux.kconfig import KconfigFile


def merge(output, configs, overrides):
    kconfig = KconfigFile()
    for c in configs:
        with open(c, encoding="utf-8") as f:
            kconfig.read(f)
    for key, value in overrides.items():
        kconfig.set(key, value)
    with open(output, "w", encoding="utf-8") as f:
        f.write(str(kconfig))


def opt_callback_dict(option, _opt, value, parser):
    match = re.match(r"^\s*(\S+)=(\S+)\s*$", value)
    if not match:
        raise optparse.OptionValueError("not key=value")
    dest = option.dest
    data = getattr(parser.values, dest)
    data[match.group(1)] = match.group(2)


def main():
    opt_parser = optparse.OptionParser(usage="%prog [OPTION]... FILE...")
    opt_parser.add_option(
        "-o",
        "--override",
        action="callback",
        callback=opt_callback_dict,
        default={},
        dest="overrides",
        help="Override option",
        type="string",
    )
    options, args = opt_parser.parse_args()

    merge(args[0], args[1:], options.overrides)


if __name__ == "__main__":
    main()
