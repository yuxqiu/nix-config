{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? rust) {
      # rust-analyzer's "Run"/"Debug" code lenses send a cargo invocation;
      # run it and show its output in a split titled `title`.
      programs.nixvim.extraConfigLua = ''
        local ra_cargo_in_split = function(title)
          return function(command)
            local r = command.arguments[1]
            local cmd = { "cargo", unpack(r.args.cargoArgs) }
            if r.args.executableArgs and #r.args.executableArgs > 0 then
              vim.list_extend(cmd, { "--", unpack(r.args.executableArgs) })
            end
            vim.system(cmd, { cwd = r.args.cwd, env = r.args.environment, text = true }, function(result)
              vim.schedule(function()
                if result.code == 0 then
                  _G.open_result_split(title, vim.split(result.stdout or "", "\n"))
                else
                  _G.open_result_split(
                    title .. " Error",
                    vim.split(result.stderr or result.stdout or "Command failed", "\n")
                  )
                end
              end)
            end)
          end
        end
      '';

      programs.nixvim.autoCmd = [
        {
          event = [ "LspAttach" ];
          callback.__raw = ''
            function(args)
              local client = vim.lsp.get_client_by_id(args.data.client_id)
              if client and client.name == "rust_analyzer" then
                vim.lsp.commands["rust-analyzer.runSingle"] = ra_cargo_in_split("Run Test")
                vim.lsp.commands["rust-analyzer.debugSingle"] = ra_cargo_in_split("Debug Test")
              end
            end
          '';
        }
      ];

      programs.nixvim.plugins.lsp.servers.rust_analyzer = {
        enable = true;
        # rustup (via the rust language module) provides rust-analyzer, cargo
        # and rustc matching each project's rust-toolchain pin; nixpkgs' copies
        # would come first on nvim's PATH.
        package = null;
        installCargo = false;
        installRustc = false;
      };
      programs.nixvim.plugins.conform-nvim.settings.formatters_by_ft.rust = [ "rustfmt" ];
      programs.nixvim.plugins.lint.lintersByFt.rust = [ "clippy" ];
      programs.nixvim.plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [
        rust
      ];
    };
}
