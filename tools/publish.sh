#!/bin/sh
# Export the game as one .pck and put it in the NAS public drop, where the `sub-of-seas`
# launcher (nixos-config: modules/nixos/programs/sub-of-seas.nix) picks it up on its next
# start. No export templates needed: a pack is just the project's files.
#   tools/publish.sh            from a clean tree (the build is named after the commit)
#   tools/publish.sh --dirty    allow uncommitted changes (build name gets "-dirty")
set -eu
cd "$(dirname "$0")/.."
if ! git diff --quiet HEAD && [ "${1:-}" != "--dirty" ]; then
	echo "publish: uncommitted changes; commit first or pass --dirty" >&2
	exit 1
fi
build="$(git rev-parse --short HEAD)"
git diff --quiet HEAD || build="$build-dirty"
dest=/mnt/nas/public/sub-of-seas
mkdir -p build "$dest"
echo "$build" > build.txt
trap 'rm -f build.txt' EXIT
godot --headless --path . --export-pack "Linux pack" build/sub-of-seas.pck > build/export.log 2>&1 ||
	{ tail -20 build/export.log; exit 1; }
cp build/sub-of-seas.pck "$dest/sub-of-seas.pck.part"
mv "$dest/sub-of-seas.pck.part" "$dest/sub-of-seas.pck"
sha256sum build/sub-of-seas.pck | cut -d' ' -f1 > "$dest/sub-of-seas.sha256"
echo "$build" > "$dest/version.txt"
echo "published build $build ($(du -h build/sub-of-seas.pck | cut -f1)) to $dest"
