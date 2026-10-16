{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    {
      programs.nixvim = {
        # Sends LSP willRename/didRename (etc.) when files change in neo-tree,
        # so servers can update imports.
        extraPlugins = [ pkgs.vimPlugins.nvim-lsp-file-operations ];

        # setup() subscribes to neo-tree's events, so it must run after
        # neo-tree (lazy-loaded) is set up. The first neo-tree window only
        # exists after that, and file operations can only happen from it.
        autoCmd = [
          {
            event = "FileType";
            pattern = "neo-tree";
            once = true;
            callback.__raw = ''
              function()
                require("lsp-file-operations").setup()
              end
            '';
          }
        ];

        plugins.lsp.capabilities = ''
          capabilities.workspace = vim.tbl_deep_extend(
            "force",
            capabilities.workspace or {},
            require("lsp-file-operations").default_capabilities().workspace
          )
        '';
      };
    };
}
