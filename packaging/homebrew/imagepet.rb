class Imagepet < Formula
  desc "Local-first macOS batch image compressor"
  homepage "https://imagepet.gewill.org/"
  url "https://github.com/gewill/ImagePet/releases/download/v1.1/imagepet-cli-v1.1-macos-arm64.zip"
  sha256 "073ad3d82f2d8a266743389bd86797bece8d8ae677901079f52d35b03be45362"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :ventura

  def install
    bin.install "imagepet"
  end

  test do
    assert_match "ImagePet", shell_output("#{bin}/imagepet --help")
    assert_match "1.1", shell_output("#{bin}/imagepet --version")
  end
end
