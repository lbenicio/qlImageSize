# libbpg dependency

`libbpg.a` is a universal static library with arm64 and x86_64 slices, built from libbpg 0.9.8. The matching upstream source archive is `libbpg-0.9.8.tar.gz`.

Run `./deps/libbpg/build-universal.sh` from the repository root to rebuild both slices with Xcode Command Line Tools.

The BPG decoder is a mix of BSD-licensed code and modified FFmpeg HEVC decoder code under LGPL-2.1. The static library is linked into the app, so the repository and each release include the corresponding source archive, the app source/project needed to rebuild and relink, and `COPYING.LGPLv2.1`. Keep the license and copyright notices with the app.

The build script disables the optional x265 encoder; x265 is not linked into `libbpg.a`. The upstream source archive still contains x265 source and its GPL license file. The BPG upstream project notes that HEVC patent rights may be separate from copyright licenses.
