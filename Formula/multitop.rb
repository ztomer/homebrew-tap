class Multitop < Formula
  desc "Multi-server TUI dashboard — SSH into servers, watch system stats side by side"
  homepage "https://github.com/ztomer/multitop"
  url "https://github.com/ztomer/multitop/archive/refs/tags/v0.53.0.tar.gz"
  sha256 "5c4a74845c7204b37eb4514e9e8447c2e0717740eae58a78f3b0b202ce1b546b"
  license "MIT"
  head "https://github.com/ztomer/multitop.git", branch: "main"

  depends_on "rust" => :build

  # Prebuilt Linux agents, cross-compiled from this same tag via ./build.sh
  # and attached to the GitHub release. The brew sandbox has no musl target
  # std (and no network to fetch it), so agents cannot be cross-compiled here;
  # build.rs hard-gates that an embedded agent matches the workspace version,
  # which these do. Bump these URLs + shas with every version bump.
  resource "multitop-agent-x86_64" do
    url "https://github.com/ztomer/multitop/releases/download/v0.53.0/multitop-agent-x86_64-unknown-linux-musl"
    sha256 "93846cf4422f486b90c9e6707da790323d17fef6c787cee77f1fa122e5b6e7ca"
  end

  resource "multitop-agent-aarch64" do
    url "https://github.com/ztomer/multitop/releases/download/v0.53.0/multitop-agent-aarch64-unknown-linux-musl"
    sha256 "82dddc0ddd05cd02d8f6c2c655dd63237219bf8abcca2cfe60abf07801520e65"
  end

  def install
    # Force a project-local target dir: a shared CARGO_TARGET_DIR in
    # ~/.cargo/config.toml would otherwise move artifacts elsewhere and the
    # hardcoded bin.install path below would miss them (same trap build.sh
    # avoids by resolving TARGET_DIR dynamically).
    ENV["CARGO_TARGET_DIR"] = buildpath/"target"

    agents = buildpath/"agents"
    resource("multitop-agent-x86_64").stage do
      agents.install "multitop-agent-x86_64-unknown-linux-musl"
    end
    resource("multitop-agent-aarch64").stage do
      agents.install "multitop-agent-aarch64-unknown-linux-musl"
    end
    ENV["MULTITOP_AGENT_X86_64"] = agents/"multitop-agent-x86_64-unknown-linux-musl"
    ENV["MULTITOP_AGENT_AARCH64"] = agents/"multitop-agent-aarch64-unknown-linux-musl"

    # Host-only install. Agents come from the resources above (picked up by
    # crates/multitop/build.rs via the MULTITOP_AGENT_* env vars), so no
    # musl cross toolchain is needed here.
    system "cargo", "install", *std_cargo_args(path: "crates/multitop")
    pkgshare.install "config.example.toml"

    # Ad-hoc sign so the binary has a stable identity for keychain
    # "Always Allow" (mirrors build.sh).
    system "codesign", "-s", "-", "--identifier", "com.ztomer.multitop", bin/"multitop"
  end

  def caveats
    <<~EOS
      multitop connects to servers listed in ~/.config/multitop/config.toml.

      Create it from the example:
        mkdir -p ~/.config/multitop
        cp #{pkgshare}/config.example.toml ~/.config/multitop/config.toml

      Requires passwordless SSH (key-based auth) to each monitored host.
    EOS
  end

  test do
    assert_match "multitop", shell_output("#{bin}/multitop --help")
  end
end