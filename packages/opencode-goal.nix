{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  cacert,
}:

stdenv.mkDerivation rec {
  pname = "opencode-goal";
  version = "0.1.84";

  src = fetchFromGitHub {
    owner = "prevalentWare";
    repo = "opencode-goal-plugin";
    rev = "v${version}";
    hash = "sha256-DXffNDPc9VFZhTyDGplizyB//6ev1OFFkiKmNsIjIjg=";
  };

  passthru.nodeModules = stdenv.mkDerivation {
    pname = "opencode-goal-node-modules";
    inherit version src;
    nativeBuildInputs = [
      bun
      cacert
    ];
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      bun install --frozen-lockfile --production --ignore-scripts
      rm -rf node_modules/.cache node_modules/.bin
      mkdir -p $out
      cp -r node_modules $out/
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-96lMN+fRSUYIjZPPlVr//cZOC0yuDlwKY4C0d9rI0U4=";
  };

  nativeBuildInputs = [ bun ];
  buildPhase = ''
    runHook preBuild
    cp -r ${passthru.nodeModules}/node_modules .
    # Bundle server dependencies; UI peers must come from the OpenCode host.
    bun build ./src/server.ts --outfile dist/server.js --target bun
    bun build ./src/tui.ts --outfile dist/tui.js --target bun \
      --external @opentui/solid --external solid-js
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/opencode-goal-plugin
    cp dist/server.js dist/tui.js $out/lib/opencode-goal-plugin/
    echo '{"name":"@prevalentware/opencode-goal-plugin","version":"${version}","type":"module","exports":{"./server":"./server.js","./tui":"./tui.js"}}' \
      > $out/lib/opencode-goal-plugin/package.json
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    bun -e 'const { default: plugin } = await import(process.argv[1]); if (plugin.id !== "local.goal-mode.server" || typeof plugin.setup !== "function") throw new Error("Missing OpenCode v2 entrypoint")' \
      "$out/lib/opencode-goal-plugin/server.js"
    runHook postInstallCheck
  '';

  meta = {
    description = "Session-scoped /goal workflow for OpenCode";
    homepage = "https://github.com/prevalentWare/opencode-goal-plugin";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
