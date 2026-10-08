{
  lib,
  vimUtils,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  chromium,
}:

vimUtils.buildVimPlugin rec {
  pname = "vellum.nvim";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "blackhat-7";
    repo = "vellum.nvim";
    rev = "v${version}";
    hash = "sha256-LZOKPiy9tpCEe84ZrbKKfdhBjqrTSsmSeVAjBbrqMFM=";
  };

  # What the upstream build.lua does with `npm ci`.
  passthru.render = buildNpmPackage {
    pname = "vellum-render";
    inherit version;
    src = "${src}/render";
    npmDepsHash = "sha256-Zcitez2/UGHu4Reux1XwTBwLMzyMDg17Ywa6QXWGTYQ=";
    dontNpmBuild = true;
    env.PUPPETEER_SKIP_DOWNLOAD = "1";
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  # Use nixpkgs node and Chromium instead of PATH and puppeteer's download.
  postPatch = ''
    substituteInPlace lua/vellum/browser.lua lua/vellum/health.lua \
      --replace-fail "'node'" "'${lib.getExe nodejs}'"
    substituteInPlace render/browser.mjs \
      --replace-fail "headless: 'shell'," "headless: 'shell', executablePath: '${lib.getExe chromium}',"
  '';

  postInstall = ''
    ln -s ${passthru.render}/node_modules $out/render/node_modules
  '';

  # test/ and build.lua require a dev setup
  doCheck = false;

  meta = {
    description = "Live GitHub-markdown preview beside your buffer, with mermaid diagrams as images";
    homepage = "https://github.com/blackhat-7/vellum.nvim";
    license = lib.licenses.mit;
  };
}
