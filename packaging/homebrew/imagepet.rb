class Imagepet < Formula
  desc "Local-first macOS batch image compressor"
  homepage "https://imagepet.gewill.org/"
  url "https://github.com/gewill/ImagePet/releases/download/v1.0/imagepet-cli-v1.0-macos-arm64.zip"
  sha256 "74d5eab54048481ef6e376735fc5952ab0d77eb0c2a757ef057b39875fc0ae94"
  license "MIT"

  depends_on macos: :ventura
  depends_on arch: :arm64

  def install
    bin.install "imagepet"
  end

  test do
    assert_match "ImagePet", shell_output("#{bin}/imagepet --help")
    assert_match "1.0", shell_output("#{bin}/imagepet --version")
  end
end
