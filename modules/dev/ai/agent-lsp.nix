{ inputs, ... }:
{
  flake.modules.homeManager.agent-lsp =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      agent-lsp = pkgs.callPackage (inputs.self + /packages/agent-lsp.nix) { };

      entry =
        ft: binary: extraArgs:
        "${ft}:${binary}${
          lib.optionalString (extraArgs != [ ]) ("," + lib.concatStringsSep "," extraArgs)
        }";

      langLsp = {
        go = [ (entry "go" "gopls" [ ]) ];
        c = [
          (entry "c" "clangd" [ ])
          (entry "cpp" "clangd" [ ])
        ];
        rust = [ (entry "rust" "rust-analyzer" [ ]) ];
        typst = [ (entry "typst" "tinymist" [ "lsp" ]) ];
        markdown = [ (entry "markdown" "markdown-oxide" [ ]) ];
        latex = [ (entry "latex" "texlab" [ ]) ];
        bash = [
          (entry "bash" "bash-language-server" [ "start" ])
          (entry "sh" "bash-language-server" [ "start" ])
        ];
        typescript = [
          (entry "typescript" "typescript-language-server" [ "--stdio" ])
          (entry "javascript" "typescript-language-server" [ "--stdio" ])
        ];
        python = [ (entry "python" "basedpyright-langserver" [ "--stdio" ]) ];
        nix = [ (entry "nix" "nixd" [ ]) ];
        lua = [ (entry "lua" "lua-language-server" [ ]) ];
        toml = [
          (entry "toml" "taplo" [
            "lsp"
            "stdio"
          ])
        ];
        json = [ (entry "json" "vscode-json-language-server" [ "--stdio" ]) ];
        css = [
          (entry "css" "vscode-css-language-server" [ "--stdio" ])
          (entry "scss" "vscode-css-language-server" [ "--stdio" ])
        ];
        yaml = [ (entry "yaml" "yaml-language-server" [ "--stdio" ]) ];
      };

      lspArgs = lib.flatten (
        lib.mapAttrsToList (
          name: entries: lib.optionals (config.my.dev.languages ? ${name}) entries
        ) langLsp
      );
    in
    {
      home.packages = [ agent-lsp ];

      programs.mcp.servers.lsp = {
        command = "agent-lsp";
        args = lspArgs;
      };
    };
}
