#!/bin/bash
VERSION="1.0.0"
TARGETS=(
	"x86_64-linux"
	"aarch64-linux"
	"x86_64-macos"
	"aarch64-macos"
	)

mkdir -p release

for target in "${TARGETS[@]}"; do
	echo "Building for $target..."
	zig build -Doptimize=ReleaseFast -Dtarget=$target

	dir="zp-v$VERSION-$target"
	mkdir -p "release/$dir"

	cp zig-out/bin/zp "release/$dir/"

	cd release
	tar -czf "$dir.tar.gz" "$dir"
	sha256sum "$dir.tar.gz" > "$dir.tar.gz.sha256"
	cd ..

	rm -rf "release/$dir"
done

echo "Releases created"
