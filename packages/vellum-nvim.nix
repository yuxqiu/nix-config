{
  lib,
  stdenv,
  vimUtils,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  playwright-driver,
}:

let
  # chrome-headless-shell instead of the full `chromium`: the latter still
  # phones home (GCM, component updater, account checks, DoH probes) despite
  # puppeteer's --disable-background-networking. The shell has none of those
  # services, so the only network traffic left is remote markdown images.
  headless-shell =
    let
      arch = if stdenv.hostPlatform.isAarch64 then "linux-arm64" else "linux64";
    in
    "${playwright-driver.components.chromium-headless-shell}/chrome-headless-shell-${arch}/chrome-headless-shell";
in

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

  # Use nixpkgs node and headless Chromium instead of PATH and puppeteer's download.
  postPatch = ''
    substituteInPlace lua/vellum/browser.lua lua/vellum/health.lua \
      --replace-fail "'node'" "'${lib.getExe nodejs}'"
    substituteInPlace render/browser.mjs \
      --replace-fail "headless: 'shell'," "headless: 'shell', executablePath: '${headless-shell}',"
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
