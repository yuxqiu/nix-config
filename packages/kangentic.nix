# Packaged from the official .deb release rather than built from source:
# several native npm deps (better-sqlite3, node-pty, sherpa-onnx-node,
# sqlite-vec, sharp) ship prebuilt binaries ABI-pinned to upstream's exact
# Electron build, so repackaging with autoPatchelfHook is more robust.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemdLibs,
}:

stdenv.mkDerivation rec {
  pname = "kangentic";
  version = "0.42.0";

  src = fetchurl {
    url = "https://github.com/Kangentic/kangentic/releases/download/v${version}/kangentic_${version}_amd64.deb";
    hash = "sha256-dKkA6Djpc080TczLfhnVjp4CuEqb5Kos8COVM5DYKeM=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemdLibs
    (lib.getLib stdenv.cc.cc)
  ];

  # We call makeWrapper ourselves in installPhase, using gappsWrapperArgs.
  dontWrapGApps = true;

  # onnxruntime-node ships optional CUDA/TensorRT execution providers for GPU
  # inference. They're unused (sherpa-onnx-node's own CPU runtime handles the
  # app's voice features) and pulling in CUDA/TensorRT just to satisfy them
  # isn't worth it.
  autoPatchelfIgnoreMissingDeps = [
    "libcublasLt.so.13"
    "libcublas.so.13"
    "libcudart.so.13"
    "libcuda.so.1"
    "libcudnn.so.9"
    "libcurand.so.10"
    "libnvinfer.so.10"
    "libnvonnxparser.so.10"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share/applications $out/share/icons/hicolor/512x512/apps

    cp -r opt/Kangentic $out/opt/
    chmod +x $out/opt/Kangentic/kangentic

    install -Dm644 usr/share/icons/hicolor/512x512/apps/kangentic.png \
      $out/share/icons/hicolor/512x512/apps/kangentic.png

    substitute usr/share/applications/kangentic.desktop $out/share/applications/kangentic.desktop \
      --replace-fail /opt/Kangentic/kangentic $out/bin/kangentic

    # The bundled chrome-sandbox helper needs a setuid root bit that Nix
    # builds cannot set, so disable Chromium's OS sandbox instead.
    # https://github.com/Kangentic/kangentic/blob/main/docs/analytics.md
    makeWrapper $out/opt/Kangentic/kangentic $out/bin/kangentic \
      "''${gappsWrapperArgs[@]}" \
      --add-flags --no-sandbox \
      --set KANGENTIC_TELEMETRY 0

    runHook postInstall
  '';

  meta = {
    description = "Desktop kanban board for orchestrating agentic coding workflows across multiple agent CLIs";
    homepage = "https://www.kangentic.com/";
    changelog = "https://github.com/Kangentic/kangentic/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "kangentic";
    platforms = [ "x86_64-linux" ];
  };
}
