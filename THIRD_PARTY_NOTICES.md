# Third-party notices

## libbpg 0.9.8

The application statically links `deps/libbpg/libbpg.a` to decode BPG images. The BPG decoding library contains modified FFmpeg HEVC decoder code distributed under the GNU Lesser General Public License, version 2.1 (LGPL-2.1). Other BPG decoder code is under the BSD license. The corresponding upstream source archive and the script used to build the universal library are included in this repository. `deps/libbpg/COPYING.LGPLv2.1` contains the LGPL text.

The Xcode project and application source are included so recipients can rebuild the app and relink it against a modified libbpg build. The source archive preserves upstream notices and contains the GPL license for its optional x265 encoder; this project’s build disables x265 and does not link that encoder into the app.

Upstream source and licensing information: [BPG Image format](https://www.bellard.org/bpg/).

The upstream BPG project notes that some HEVC algorithms may be covered by patents in some countries. Copyright licenses do not grant patent rights.
