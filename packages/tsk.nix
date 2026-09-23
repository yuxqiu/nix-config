# Packaged from the official release binary (statically linked musl build,
# no patching needed) plus the skill file and Herdr plugin manifest/scripts,
# fetched separately since none of them ship in the release tarball itself
# (only the source repo has them, pinned here to the same v0.10.1 tag).
{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.10.1";
  srcTag = "v${version}";

  skill = fetchurl {
    url = "https://raw.githubusercontent.com/smarzban/tsk/${srcTag}/skills/tsk-cli/SKILL.md";
    hash = "sha256-3qFxOxrQ0oxGui+6My+yMNesUByZ1xI0T4zVHgev+DI=";
  };

  pluginManifest = fetchurl {
    url = "https://raw.githubusercontent.com/smarzban/tsk/${srcTag}/herdr-plugin.toml";
    hash = "sha256-BuwTD2SqwWyrcAEaUWR+gd6kfBlVFlkQfXScMpelv+I=";
  };

  openBoardScript = fetchurl {
    url = "https://raw.githubusercontent.com/smarzban/tsk/${srcTag}/scripts/open-board.sh";
    hash = "sha256-a5rKNBWWLsh7wGeHWhlHxkBnW1II4+AM5Eg7raMDIAw=";
  };

  openCaptureScript = fetchurl {
    url = "https://raw.githubusercontent.com/smarzban/tsk/${srcTag}/scripts/open-capture.sh";
    hash = "sha256-aZaCmvrcm2TQ/g0Ox8e8EsXYqI+Gtgy6oRM7uJwBYCc=";
  };
in
stdenv.mkDerivation {
  pname = "tsk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/smarzban/tsk/releases/download/${srcTag}/tsk-${srcTag}-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-gdyNiz8snsAyE2JD30tWzEfPdHUro7hFpFExr4Jl8TY=";
  };

  # The release tarball has no wrapping directory (just tsk, LICENSE,
  # README.md at the top level), so there's nothing for the default
  # unpackPhase to descend into.
  setSourceRoot = "sourceRoot=.";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 tsk $out/bin/tsk

    # share/skills/<name>/SKILL.md, for programs.agent-skills to discover.
    # A real copy, not a symlink: agent-skills-nix's scanner treats any
    # symlink entry as a directory to recurse into and fails if it resolves
    # to a file.
    install -Dm644 ${skill} $out/share/skills/tsk-cli/SKILL.md

    # Preserved as a whole directory (not just the binary): herdr-plugin.toml's
    # pane/action commands are relative paths resolved from this root by
    # `herdr plugin link`. Avoids `tsk setup herdr`, which mutates
    # ~/.config/herdr/config.toml directly and leaves a timestamped backup
    # file and a hash-keyed scratch directory behind on every version bump.
    mkdir -p $out/share/tsk-herdr-plugin/scripts $out/share/tsk-herdr-plugin/target/release
    install -Dm644 ${pluginManifest} $out/share/tsk-herdr-plugin/herdr-plugin.toml
    install -Dm755 ${openBoardScript} $out/share/tsk-herdr-plugin/scripts/open-board.sh
    install -Dm755 ${openCaptureScript} $out/share/tsk-herdr-plugin/scripts/open-capture.sh
    ln -s $out/bin/tsk $out/share/tsk-herdr-plugin/target/release/tsk

    runHook postInstall
  '';

  meta = {
    description = "Terminal task board for humans and AI agents, with a Herdr integration";
    homepage = "https://github.com/smarzban/tsk";
    changelog = "https://github.com/smarzban/tsk/blob/main/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "tsk";
    platforms = [ "x86_64-linux" ];
  };
}
