{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

let
  src = fetchFromGitHub {
    owner = "yuxqiu";
    repo = "vscode-unicode-highlight.nvim";
    rev = "0c5d9148262ac2da2be6725934fa28ecb30b0f63"; # follow:branch main
    hash = "sha256-3iQs4FGQNVZvr+QmnEYjfRb63utx7wp8cTiwts6Br28=";
  };
in
vimUtils.buildVimPlugin {
  pname = "unicode-highlight-nvim";
  version = "unstable-2026-06-16";

  inherit src;

  meta = {
    description = "Highlights ambiguous and invisible Unicode characters, similar to VS Code";
    homepage = "https://github.com/racakenon/vscode-unicode-highlight.nvim";
    license = lib.licenses.mit;
  };
}
