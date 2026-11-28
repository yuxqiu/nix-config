{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  cacert,
}:

stdenv.mkDerivation rec {
  pname = "opencode-queue";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "mirsella";
    repo = "opencode-queue";
    rev = "v${version}";
    hash = "sha256-DYHYlg+YUs3lud+QwRcpw6EDuvEDw2Vr0fNwP6mUNfw=";
  };

  passthru.nodeModules = stdenv.mkDerivation {
    pname = "opencode-queue-node-modules";
    inherit version src;

    nativeBuildInputs = [
      bun
      cacert
    ];

    dontBuild = true;
    # fixupPhase's patchShebangs would inject store paths, forbidden in a FOD
    dontFixup = true;

    installPhase = ''
      mkdir $out
      bun install --production
      rm -rf node_modules/.cache node_modules/.bin
      cp -r node_modules $out/
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    # bun installs @opentui/core's native package for the build platform only
    # (core-linux-x64 / core-linux-arm64), so the output differs per system.
    outputHash =
      {
        x86_64-linux = "sha256-XkIvUIknx/7OFBrQPI+4IJh85m5eSFr+F/5uZy65PcA=";
        aarch64-linux = "sha256-6f/TCV6dZJ3b6ldUJnOVeUkY5Xd/Vkrw05WUALCaiuY=";
      }
      .${stdenv.hostPlatform.system}
        or (throw "opencode-queue: no node_modules hash for ${stdenv.hostPlatform.system}");
  };

  nativeBuildInputs = [ bun ];

  buildPhase = ''
    runHook preBuild
    cp -r ${passthru.nodeModules}/node_modules .
    bun build ./index.ts --outdir dist --target bun
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/opencode-queue
    cp dist/index.js $out/lib/opencode-queue/
    runHook postInstall
  '';

  meta = {
    description = "Queue OpenCode input until the current session is idle";
    homepage = "https://github.com/mirsella/opencode-queue";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
