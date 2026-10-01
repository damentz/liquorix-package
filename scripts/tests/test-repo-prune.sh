#!/bin/bash
# Checks scripts/prune/repo-prune.py keeps the newest builds of the newest series and removes the rest.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
fail=0
expect() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'" >&2; fail=1; fi; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
prune="$PWD/../prune/repo-prune.py"

# reprepro stub: "list" prints the fixture, "remove" records what it was asked to delete
mkdir -p "$tmp/bin" "$tmp/deb/conf"
echo 'Codename: forky' > "$tmp/deb/conf/distributions"
cat > "$tmp/bin/reprepro" <<EOF
#!/bin/bash
case "\$3" in
    list) cat "$tmp/listing" ;;
    remove) shift 3; echo "\$*" >> "$tmp/removed" ;;
esac
EOF
chmod +x "$tmp/bin/reprepro"
{
    # 7.2 has four complete builds and an older one that lost its image, 7.1 has only two,
    # and 6.19 is the fourth-newest series
    for build in 7.2.4-1:7.2-9.1 7.2.4-2:7.2-10.1 7.2.6-1:7.2-11.1 7.2.7-1:7.2-12.2 7.1.5-1:7.1-3.1 7.1.6-1:7.1-4.1 \
                 7.0.9-1:7.0-20.1 6.19.8-1:6.19-12.1; do
        echo "forky|main|amd64: linux-image-${build%%:*}-liquorix-amd64 ${build##*:}~forky"
        echo "forky|main|amd64: linux-headers-${build%%:*}-liquorix-amd64 ${build##*:}~forky"
    done
    echo "forky|main|amd64: linux-headers-7.2.3-1-liquorix-amd64 7.2-8.1~forky"
    echo "forky|main|amd64: linux-image-liquorix-amd64 7.2-12.2~forky"
} > "$tmp/listing"

PATH="$tmp/bin:$PATH" "$prune" --dry-run "reprepro:$tmp/deb" > /dev/null
expect "dry run removes nothing" "no" "$([[ -e "$tmp/removed" ]] && echo yes || echo no)"
PATH="$tmp/bin:$PATH" "$prune" "reprepro:$tmp/deb" > /dev/null
expect "reprepro drops the fourth-newest series" \
    "forky linux-image-6.19.8-1-liquorix-amd64 linux-headers-6.19.8-1-liquorix-amd64" "$(sed -n 1p "$tmp/removed")"
expect "reprepro removes builds older than the newest three" \
    "forky linux-headers-7.2.3-1-liquorix-amd64 linux-image-7.2.4-1-liquorix-amd64 linux-headers-7.2.4-1-liquorix-amd64" \
    "$(sed -n 2p "$tmp/removed")"

# Arch: five builds of 7.2 and one each of three older series, the database points at the newest
mkdir "$tmp/arch"
for version in 7.2.4.lqx1-1 7.2.4.lqx2-1 7.2.6.lqx1-1 7.2.10.lqx1-1 7.2.10.lqx1-2 7.1.12.lqx1-1 7.0.14.lqx1-1 6.19.8.lqx1-1; do
    for package in linux-lqx linux-lqx-headers linux-lqx-docs; do
        touch "$tmp/arch/$package-$version-x86_64.pkg.tar.zst"{,.sig}
    done
done
mkdir "$tmp/db" "$tmp/db/linux-lqx-7.2.10.lqx1-2"
tar -cf "$tmp/arch/liquorix.db" -C "$tmp/db" linux-lqx-7.2.10.lqx1-2
"$prune" "arch:$tmp/arch" > /dev/null
expect "arch keeps three builds of three series" "7.0.14.lqx1-1 7.1.12.lqx1-1 7.2.6.lqx1-1 7.2.10.lqx1-1 7.2.10.lqx1-2" \
    "$(find "$tmp/arch" -name 'linux-lqx-[0-9]*.zst' -printf '%f\n' | sed -E 's/^linux-lqx-(.*)-x86_64.*/\1/' | sort -V | xargs)"
expect "arch removes every file of a stale build" "30" "$(find "$tmp/arch" -name '*.zst*' | wc -l)"

expect "keep must be positive" "failed" "$("$prune" --keep 0 "arch:$tmp/arch" 2>/dev/null || echo failed)"
expect "series must be positive" "failed" "$("$prune" --series 0 "arch:$tmp/arch" 2>/dev/null || echo failed)"
exit $fail
