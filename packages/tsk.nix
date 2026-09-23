# Built from source via rustPlatform.buildRustPackage. tsk-tui is a single
# non-workspace crate (bin `tsk`) with no git dependencies, so a plain
# cargoHash (no cargoLock.outputHashes) is enough. The skill file, Herdr
# plugin manifest, and its scripts already live in the same source tree, so
# postInstall copies them straight out instead of fetching each separately.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "tsk";
  inherit version;

  src = fetchFromGitHub {
    owner = "smarzban";
    repo = "tsk";
    rev = "v${version}";
    hash = "sha256-nkuCSQg6C1EVVYTdXdLDZV+TT0Xdu93kTV/LgBJEwGQ=";
  };

  cargoHash = "sha256-FMCxgtHvra3AYwL0M2s8x5XbYaLXRGRk1oZ8ezq51Js=";

  # Upstream's integration suite spawns the built binary, opens PTYs, and
  # writes to std::env::temp_dir() / real Herdr sockets, none of which are
  # available in the Nix build sandbox.
  doCheck = false;

  postInstall = ''
    # share/skills/<name>/SKILL.md, for programs.agent-skills to discover.
    # A real copy, not a symlink: agent-skills-nix's scanner treats any
    # symlink entry as a directory to recurse into and fails if it resolves
    # to a file.
    install -Dm644 skills/tsk-cli/SKILL.md $out/share/skills/tsk-cli/SKILL.md

    # Preserved as a whole directory (not just the binary): herdr-plugin.toml's
    # pane/action commands are relative paths resolved from this root by
    # `herdr plugin link`. Avoids `tsk setup herdr`, which mutates
    # ~/.config/herdr/config.toml directly and leaves a timestamped backup
    # file and a hash-keyed scratch directory behind on every version bump.
    mkdir -p $out/share/tsk-herdr-plugin/scripts $out/share/tsk-herdr-plugin/target/release
    install -Dm644 herdr-plugin.toml $out/share/tsk-herdr-plugin/herdr-plugin.toml
    install -Dm755 scripts/open-board.sh $out/share/tsk-herdr-plugin/scripts/open-board.sh
    install -Dm755 scripts/open-capture.sh $out/share/tsk-herdr-plugin/scripts/open-capture.sh
    ln -s $out/bin/tsk $out/share/tsk-herdr-plugin/target/release/tsk
  '';

  meta = {
    description = "Terminal task board for humans and AI agents, with a Herdr integration";
    homepage = "https://github.com/smarzban/tsk";
    changelog = "https://github.com/smarzban/tsk/blob/main/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "tsk";
    platforms = lib.platforms.linux;
  };
}
