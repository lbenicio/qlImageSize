#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
build_root="$(mktemp -d)"
trap 'rm -rf "$build_root"' EXIT

archive="$repo_root/deps/libbpg/libbpg-0.9.8.tar.gz"
tar -xzf "$archive" -C "$build_root"
source_dir="$build_root/libbpg-0.9.8"

for arch in arm64 x86_64; do
	arch_dir="$build_root/$arch"
	cp -R "$source_dir" "$arch_dir"
	perl -0pi -e 's/^USE_X265=y$/#USE_X265=y/m; s/^USE_BPGVIEW=y$/#USE_BPGVIEW=y/m; s/^#CONFIG_APPLE=y$/CONFIG_APPLE=y/m; s/^CFLAGS\+=-g$/CFLAGS+=-g\nCFLAGS+=-mmacosx-version-min=12.0/m' "$arch_dir/Makefile"
	make -C "$arch_dir" clean
	make -C "$arch_dir" libbpg.a CC="clang -arch $arch" AR=ar CONFIG_APPLE=y USE_X265= USE_BPGVIEW= -j4
done

lipo -create "$build_root/arm64/libbpg.a" "$build_root/x86_64/libbpg.a" -output "$repo_root/deps/libbpg/libbpg.a"
