# Third Party Notices

ImagePet v0.9 uses the following third-party packages for WebP support. Versions are locked by `Package.resolved`.

## Swift-WebP

- Package: `Swift-WebP`
- Product: `WebP`
- Version: `0.6.1`
- Revision: `4e7310667297f066e4884b6258a3a646cac8a50b`
- Source: https://github.com/ainame/Swift-WebP
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

## libwebp-Xcode

- Package: `libwebp-Xcode`
- Product: `libwebp`
- Version: `1.5.0`
- Revision: `0d60654eeefd5d7d2bef3835804892c40225e8b2`
- Source: https://github.com/SDWebImage/libwebp-Xcode
- Build method: Transitive Swift Package Manager dependency of `Swift-WebP`
- License: BSD-3-Clause via bundled upstream `libwebp`

`libwebp-Xcode` packages the upstream `libwebp` source for Apple platform builds. Its podspec points to `webmproject/libwebp` tag `v1.5.0` and declares the BSD license file from upstream `libwebp`.

## libwebp

- Library: `libwebp`
- Version: `1.5.0`
- Source: https://github.com/webmproject/libwebp
- Build method: Bundled source compiled through `libwebp-Xcode`
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
