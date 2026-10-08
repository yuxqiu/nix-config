{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      src = pkgs.fetchFromGitHub {
        owner = "blackhat-7";
        repo = "vellum.nvim";
        # follow:branch main
        rev = "c9a8665c5d306bf56c6df89896fed8bfaf3110b3";
        hash = "sha256-LZOKPiy9tpCEe84ZrbKKfdhBjqrTSsmSeVAjBbrqMFM=";
      };

      # What the upstream build.lua does with `npm ci`; Chrome comes from
      # nixpkgs instead of puppeteer's download.
      render = pkgs.buildNpmPackage {
        pname = "vellum-render";
        version = "0-unstable";
        src = "${src}/render";
        npmDepsHash = "sha256-Zcitez2/UGHu4Reux1XwTBwLMzyMDg17Ywa6QXWGTYQ=";
        dontNpmBuild = true;
        env.PUPPETEER_SKIP_DOWNLOAD = "1";
        installPhase = ''
          mkdir -p $out
          cp -r node_modules $out/
        '';
      };

      vellum = pkgs.vimUtils.buildVimPlugin {
        pname = "vellum.nvim";
        version = "0-unstable";
        inherit src;
        postInstall = ''
          ln -s ${render}/node_modules $out/render/node_modules
        '';
        # test/ and build.lua require a dev setup
        doCheck = false;
      };
    in
    lib.mkIf (config.my.dev.languages ? markdown) {
      programs.nixvim.extraPlugins = [ vellum ];
      programs.nixvim.extraPackages = [ pkgs.nodejs ];

      programs.nixvim.extraConfigLua = ''
        vim.env.PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium"
        -- snacks.scroll resets a scrolled window to its old view to animate
        -- from it; vellum then takes the preview's old topline for a user
        -- scroll and drags the source back to match.
        vim.api.nvim_create_autocmd("BufWinEnter", {
          pattern = "vellum://preview",
          callback = function(ev) vim.b[ev.buf].snacks_scroll = false end,
        })
        require("vellum").setup({})
        vim.keymap.set("n", "<leader>mp", "<cmd>Vellum<cr>", { desc = "Markdown preview" })
        vim.keymap.set("n", "<leader>mz", function() require("vellum").zoom() end, { desc = "Zoom image" })
      '';
    };
}
