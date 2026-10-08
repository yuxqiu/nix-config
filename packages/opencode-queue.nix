{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  cacert,
}:

stdenv.mkDerivation rec {
  pname = "opencode-queue";
  version = "0.17.0";

  src = fetchFromGitHub {
    owner = "mirsella";
    repo = "opencode-queue";
    rev = "v${version}";
    hash = "sha256-9ANBuH8bUAV6TAEaX1+CZmVaN5iGq93BMhPrC1Vnvos=";
  };

  passthru.nodeModules = stdenv.mkDerivation {
    pname = "opencode-queue-node-modules";
    inherit version src;

    nativeBuildInputs = [
      bun
      cacert
    ];

    dontBuild = true;

    installPhase = ''
      mkdir $out
      bun install --production
      rm -rf node_modules/.cache node_modules/.bin
      cp -r node_modules $out/
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-ZnyfMav+RupjnV0dar8ZrkFX2XLvKqLbFHgewxr48tg=";
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
