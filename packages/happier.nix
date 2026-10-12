# Happier CLI + daemon - https://github.com/happier-dev/happier
# Repackages the upstream release tarball (a Bun-compiled `happier` binary
# that loads `package-dist/` and `node_modules/` from beside itself).
#
# To update:
#   1. Change `version`
#   2. Update each `hashes` entry (set to "" and build — nix will tell you)
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

let
  version = "0.2.16";
  arch =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system};
  hashes = {
    x64 = "sha256-UAGPMGyOmF6hvQUSjXPxKKKfIp64p7Mqe7QpTObKejI=";
    arm64 = "sha256-N9rZzeVUXYK4Q6SbcimUkhMiHE6XboxYo1+zTXbpsgs=";
  };
in
stdenv.mkDerivation {
  pname = "happier";
  inherit version;

  src = fetchurl {
    url = "https://github.com/happier-dev/happier/releases/download/cli-v${version}/happier-v${version}-linux-${arch}.tar.gz";
    hash = hashes.${arch};
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  # Stripping corrupts the payload Bun appends to the compiled executable.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Native modules ship for every libc; keep only the glibc ones so
    # autoPatchelf has nothing unresolvable to chase.
    find . -depth -type d -name '*musl*' -exec rm -rf {} +
    find . -type f -name '*.musl.node' -delete

    mkdir -p $out/lib/happier $out/bin
    cp -r . $out/lib/happier

    # Updates come from Nix, never from the CLI itself.
    makeWrapper $out/lib/happier/happier $out/bin/happier \
      --set HAPPIER_CLI_UPDATE_CHECK 0 \
      --set HAPPIER_NO_PATH_UPDATE 1

    runHook postInstall
  '';

  meta = {
    description = "Multi-device control room for coding agents (CLI and daemon)";
    homepage = "https://github.com/happier-dev/happier";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "happier";
  };
}
