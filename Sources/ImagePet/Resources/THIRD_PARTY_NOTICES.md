# Third Party Notices

ImagePet uses the following third-party packages for image codec support and app interaction. Versions are locked by `Package.resolved`.

## KeyboardShortcuts

- Package: `KeyboardShortcuts`
- Product: `KeyboardShortcuts`
- Version: `3.0.0`
- Revision: `f7d08ba4109d5ca025e1a64165be169cdf089206`
- Source: https://github.com/sindresorhus/KeyboardShortcuts
- Build method: Swift Package Manager dependency linked by the `ImagePet` GUI target
- License: MIT

```text
MIT License

Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Swift-WebP

- Package: `SwiftWebP` (fork of `ainame/Swift-WebP`)
- Product: `SwiftWebP`
- Version: `0.7.0`
- Revision: `a85311f3d768a0ecbf4390d27d35071c840f6d77`
- Source: https://github.com/gewill/Swift-WebP
- Upstream: https://github.com/ainame/Swift-WebP
- Build method: Swift Package Manager dependency linked by `ImagePetCore`
- License: MIT

```text
MIT License

Copyright (c) 2016 Satoshi Namai

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## webp-spm

- Package: `webp-spm`
- Product: `WebP` (C library)
- Version: `1.6.0`
- Revision: `c5d21d16f5d7cca8fd635869410644be9dd96522`
- Source: https://github.com/gewill/webp-spm
- Build method: Transitive Swift Package Manager dependency of `SwiftWebP`
- License: MIT (wrapper) / BSD-3-Clause (upstream libwebp)

`webp-spm` packages the upstream `libwebp` source for Swift Package Manager builds. It replaces the previous `libwebp-Xcode` dependency used by the upstream `ainame/Swift-WebP`.

## libwebp

- Library: `libwebp`
- Version: `1.6.0`
- Source: https://github.com/webmproject/libwebp
- Build method: Bundled source compiled through `webp-spm`
- License: BSD-3-Clause

```text
Copyright (c) 2010, Google Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

  * Neither the name of Google nor the names of its contributors may
    be used to endorse or promote products derived from this software
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## mozjpeg.swift

- Package: `mozjpeg.swift`
- Product: `mozjpeg`
- Version: `1.1.3`
- Revision: `42aaf0105aa7cd5640397306577bda756863003a`
- Source: https://github.com/awxkee/mozjpeg.swift
- Build method: Swift Package Manager dependency linked by `ImagePetCore`
- License: CC0-1.0 for the Swift/Objective-C++ wrapper repository

`mozjpeg.swift` packages Swift and Objective-C++ bindings around a bundled `libturbojpeg.xcframework`. ImagePet uses it only for Advanced JPEG output.

## Bundled libturbojpeg / mozjpeg binary from mozjpeg.swift

- Library: `libturbojpeg`
- Package source: https://github.com/awxkee/mozjpeg.swift
- Bundled artifact: `Sources/libturbojpeg.xcframework`
- macOS artifact: `macos-arm64_x86_64/libturbojpeg.a`
- Reported header version: `LIBJPEG_TURBO_VERSION 4.1.0`
- Build method: Prebuilt static library distributed inside `mozjpeg.swift`
- Linked frameworks: `Accelerate`
- License summary: libjpeg-turbo / mozjpeg license roll-up; includes IJG License, Modified BSD License, and zlib-style SIMD notices where applicable.

Required attribution:

```text
This software is based in part on the work of the Independent JPEG Group.
```

ImagePet does not bundle `cjpeg`, `djpeg`, `jpegtran`, or other command-line tools from this dependency.
