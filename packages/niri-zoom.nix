{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "niri-zoom";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Ahmedhossamdev";
    repo = "niri-zoom";
    rev = "v${version}";
    hash = "sha256-PuLdv0/spVNhUF865+D4uZXOqPquLCb6Ve5Nt2Hh/Co=";
  };

  cargoHash = "sha256-ISKNipvoRpaZ9mx6J9XUialXwuTrpRlNb+0Y5DaNIxY=";

  doCheck = false;

  meta = {
    description = "External Ctrl+scroll magnifier/zoom tool for niri and other wlr-layer-shell/screencopy Wayland compositors";
    homepage = "https://github.com/Ahmedhossamdev/niri-zoom";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
