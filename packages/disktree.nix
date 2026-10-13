{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  fontconfig,
  freetype,
  libxkbcommon,
  vulkan-loader,
  wayland,
  libx11,
  libxcb,
}:

rustPlatform.buildRustPackage rec {
  pname = "disktree";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "tobi";
    repo = "disktree";
    rev = "v${version}";
    hash = "sha256-b7VP3VgOS+zUTR2bhOh6JNcN5mIIeHL/fe3u/eHC+X4=";
  };

  cargoHash = "sha256-k+iLvOS+6o5oC+JcG9BJ3UUAzZAQpcpNelKCXsDx0Fw=";

  cargoBuildFlags = [
    "--package"
    "disktree-app"
  ];

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    fontconfig
    freetype
    libxkbcommon
    wayland
    libx11
    libxcb
  ];

  doCheck = false;

  postInstall = ''
    install -Dm644 assets/disktree.svg $out/share/icons/hicolor/scalable/apps/disktree.svg
    install -Dm644 packaging/disktree.desktop.in $out/share/applications/disktree.desktop
    substituteInPlace $out/share/applications/disktree.desktop \
      --replace-fail '@BINDIR@/' "" \
      --replace-fail '@VERSION@' '${version}'
  '';

  # GPUI dlopens Vulkan, Wayland and xkbcommon at runtime.
  postFixup = ''
    wrapProgram $out/bin/disktree \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          vulkan-loader
          wayland
          libxkbcommon
          libx11
          libxcb
        ]
      }
  '';
}
