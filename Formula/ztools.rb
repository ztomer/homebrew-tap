class Ztools < Formula
  desc "Local LLM tools: weekend planner, twitter summarizer, model eval"
  homepage "https://github.com/ztomer/ztools"
  url "https://github.com/ztomer/ztools/archive/refs/tags/v3.31.0.tar.gz"
  sha256 "c94f0872474c54cebc5a5b98e26a67bb1f9111e005d6fdb0a5e963484cf8a47e"
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
    assert_match "Usage", shell_output("#{bin}/ztools --help")
    assert_match "Usage", shell_output("#{bin}/weekend --help")
    assert_match "Usage", shell_output("#{bin}/twitter --help")
    assert_match "Usage", shell_output("#{bin}/oeval --help")
    assert_match "Usage", shell_output("#{bin}/rename_images --help")
  end
end
