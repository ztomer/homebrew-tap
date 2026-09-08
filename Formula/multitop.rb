class Multitop < Formula
  desc "Multi-server TUI dashboard — SSH into servers, watch system stats side by side"
  homepage "https://github.com/ztomer/multitop"
  url "https://github.com/ztomer/multitop/archive/refs/tags/v0.47.0.tar.gz"
  sha256 "e404c351c17ad44f0b54f46f7cd1e8e842404f4d8ae599748fa33755f108487b"
  license "MIT"
  head "https://github.com/ztomer/multitop.git", branch: "main"

  depends_on "rust" => :build

  # Prebuilt Linux agents, cross-compiled from this same tag via ./build.sh
  # and attached to the GitHub release. The brew sandbox has no musl target
  # std (and no network to fetch it), so agents cannot be cross-compiled here;
  # build.rs hard-gates that an embedded agent matches the workspace version,
  # which these do. Bump these URLs + shas with every version bump.
  resource "multitop-agent-x86_64" do
    url "https://github.com/ztomer/multitop/releases/download/v0.47.0/multitop-agent-x86_64-unknown-linux-musl"
    sha256 "f9bf50d9d46d766073dde34120cadb8b897fa5071d2eab40e48798b72f5d3990"
  end

  resource "multitop-agent-aarch64" do
    url "https://github.com/ztomer/multitop/releases/download/v0.47.0/multitop-agent-aarch64-unknown-linux-musl"
    sha256 "c8ee7fe306cd4699b49ce2aa8ee02b2ef3113d71c2ca198e5d54cd1d8e9ea07c"
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
