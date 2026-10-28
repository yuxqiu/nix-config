{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "agent-lsp";
  version = "0.23.5";

  src = fetchFromGitHub {
    owner = "blackwell-systems";
    repo = "agent-lsp";
    rev = "v${version}";
    hash = "sha256-3xbTets43vqCR+tsQqL/BR4FcDfV0Wfglxa+ULn8EyQ=";
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
