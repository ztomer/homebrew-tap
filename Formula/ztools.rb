class Ztools < Formula
  desc "Local LLM tools: weekend planner, twitter summarizer, model eval (native Rust port)"
  homepage "https://github.com/ztomer/ztools"
  url "https://github.com/ztomer/ztools/archive/refs/tags/v2.1.17.tar.gz"
  sha256 "bd41c6ff828581186a76417e1368828d956892f1ddc5ff7402e88ff4d5ed0dee"
  license "MIT"
  head "https://github.com/ztomer/ztools.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "rust")

    bin.install_symlink "ztools" => "weekend"
    bin.install_symlink "ztools" => "weekend-plan"
    bin.install_symlink "ztools" => "twitter"
    bin.install_symlink "ztools" => "twitter-summarize"
    bin.install_symlink "ztools" => "oeval"
    bin.install_symlink "ztools" => "model-eval"
    bin.install_symlink "ztools" => "rename_images"
    bin.install_symlink "ztools" => "image-renamer"
  end

  test do
    assert_match "usage", shell_output("#{bin}/ztools --help")
    assert_match "usage", shell_output("#{bin}/weekend --help")
    assert_match "usage", shell_output("#{bin}/twitter --help")
    assert_match "usage", shell_output("#{bin}/oeval --help")
    assert_match "usage", shell_output("#{bin}/rename_images --help")
  end
end
