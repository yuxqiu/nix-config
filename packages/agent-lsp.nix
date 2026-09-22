{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "agent-lsp";
  version = "0.19.5";

  src = fetchFromGitHub {
    owner = "blackwell-systems";
    repo = "agent-lsp";
    rev = "v${version}";
    hash = "sha256-lS6n868isxFOwhHSzmG9o/KY1jQmYOEXk5CExlvC0FI=";
  };

  vendorHash = "sha256-aBokNk3GGCkMX5UYotiQHzWRKfHF6Tc0EA4hIj5XIKg=";

  subPackages = [ "cmd/agent-lsp" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  meta = {
    description = "MCP server exposing 50+ language server protocol tools to AI agents";
    homepage = "https://github.com/blackwell-systems/agent-lsp";
    license = lib.licenses.mit;
    mainProgram = "agent-lsp";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
