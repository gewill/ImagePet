class Imagepet < Formula
  desc "Local-first macOS batch image compressor"
  homepage "https://imagepet.gewill.org/"
  url "https://github.com/gewill/ImagePet/releases/download/v1.1/imagepet-cli-v1.1-macos-arm64.zip"
  sha256 "52ce5c2071b1f54f7c2ad91559b327ac192b0aec14e09910d83b5db62b7f6dcf"
  license "MIT"

  depends_on macos: :ventura
  depends_on arch: :arm64

  def install
    bin.install "imagepet"
  end

  test do
    assert_match "ImagePet", shell_output("#{bin}/imagepet --help")
    assert_match "1.1", shell_output("#{bin}/imagepet --version")
  end
end
