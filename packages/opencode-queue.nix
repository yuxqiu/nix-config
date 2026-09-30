{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  cacert,
}:

let
  src = fetchFromGitHub {
    owner = "mirsella";
    repo = "opencode-queue";
    rev = "4212b48f3b2c22d2ac4d40eeffd3251497fdf3c9"; # follow:branch main
    hash = "sha256-LV8ug2eDemTdSuHWCz8FjsB9LjriXBf7xUTio6ugSQg=";
  };

  nodeModules = stdenv.mkDerivation {
    pname = "opencode-queue-node-modules";
    version = "0.10.0";
    inherit src;

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
    outputHash = "sha256-yRHauQF/+UbKCKlKbTg1mE9EClFWEVgYXBPjblMiUDQ=";
  };
in
stdenv.mkDerivation {
  pname = "opencode-queue";
  version = "0.10.0";

  inherit src;

  nativeBuildInputs = [ bun ];

  buildPhase = ''
    runHook preBuild
    cp -r ${nodeModules}/node_modules .
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
