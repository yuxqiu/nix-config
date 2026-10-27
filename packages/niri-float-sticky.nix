{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "niri-float-sticky";
  version = "0.0.9";

  src = fetchFromGitHub {
    owner = "probeldev";
    repo = "niri-float-sticky";
    rev = "v${version}";
    hash = "sha256-yXrVjHJEK1hoVywiD4YxOYzXqa8kC+qGOlkKb/JRz2g=";
  };

  vendorHash = "sha256-GqbY3qkPjMxyW9RTsN9hkgM3Bda6A8rb2kR4YQW1nFI=";

  meta = {
    description = "Make floating windows visible across all workspaces in niri";
    homepage = "https://github.com/probeldev/niri-float-sticky";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "niri-float-sticky";
  };
}
