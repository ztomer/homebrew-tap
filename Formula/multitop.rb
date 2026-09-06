class Multitop < Formula
  desc "Multi-server TUI dashboard — SSH into servers, watch system stats side by side"
  homepage "https://github.com/ztomer/multitop"
  url "https://github.com/ztomer/multitop/archive/refs/tags/v0.46.1.tar.gz"
  sha256 "d4ff871e693728458eaa7e4390e4f370098113789c6b9109f068696a11d1ad2e"
  license "MIT"
  head "https://github.com/ztomer/multitop.git", branch: "main"

  depends_on "rust" => :build
  depends_on "cargo-zigbuild" => :build
  depends_on "zig" => :build

  def install
    # build.sh cross-compiles static musl agents for x86_64 and aarch64
    # Linux, embeds them in the local binary, then builds the host binary.
    system "./build.sh", "--backend", "zigbuild"
    bin.install "target/release/multitop"
  end

  def caveats
    <<~EOS
      multitop connects to servers listed in ~/.config/multitop/config.toml.

      Create it from the example:
        mkdir -p ~/.config/multitop
        cp #{opt_share}/config.example.toml ~/.config/multitop/config.toml

      Requires passwordless SSH (key-based auth) to each monitored host.
    EOS
  end

  test do
    assert_match "multitop", shell_output("#{bin}/multitop --help 2>&1", 1)
  end
end