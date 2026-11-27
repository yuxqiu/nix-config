{
  flake.modules.homeManager.nvim = {
    # State that features configured here read back across sessions: undo
    # history (`undofile`), shada (recent files for telescope's oldfiles,
    # command/search history, marks), and the data directory (resession's
    # per-folder sessions, the recent-projects list, telescope prompt
    # history). Logs and swap files in ~/.local/state/nvim are not kept.
    persistence.directories = [
      ".local/share/nvim"
      {
        directory = ".local/state/nvim/undo";
        mode = "0700";
      }
      {
        directory = ".local/state/nvim/shada";
        mode = "0700";
      }
    ];
    programs.nixvim.opts = {
      encoding = "utf-8";
      hidden = true;
      number = true;
      relativenumber = true;
      showmatch = true;
      shiftwidth = 4;
      tabstop = 4;
      expandtab = true;
      smarttab = true;
      formatoptions = "croqln";
      backup = false;
      writebackup = false;
      undofile = true;
      wrap = false;
      ignorecase = true;
      smartcase = true;
      hlsearch = true;
      mouse = "a";
      autoindent = true;
      cursorline = true;
      signcolumn = "yes";
      splitbelow = true;
      splitright = true;
      updatetime = 250;
      timeoutlen = 300;
      scrolloff = 8;
      sidescrolloff = 8;
      termguicolors = true;
      clipboard = "unnamedplus";
      showtabline = 2;
      laststatus = 3;
      pumheight = 10;
      inccommand = "split";
      winborder = "rounded";
    };

    programs.nixvim.extraConfigLua = ''
      vim.opt.diffopt:append("algorithm:histogram")
      vim.opt.whichwrap:append("<,>,h,l,[,]")

      -- Temporary files may hold secrets:
      -- no undo file, no swap file, and skip writing shada for this session
      vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile", "BufWritePre" }, {
        pattern = "/tmp/*",
        callback = function()
          vim.opt_local.undofile = false
          vim.opt_local.swapfile = false
          vim.o.shada = ""
        end,
      })
    '';

    # Delete undo files not touched in 90 days
    systemd.user.tmpfiles.rules = [ "e %h/.local/state/nvim/undo - - - 90d" ];
  };
}
