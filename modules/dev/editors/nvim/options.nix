{
  flake.modules.homeManager.nvim = {
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

      local function change_font_size(delta)
        local guifont = vim.o.guifont
        if guifont == "" then return end
        local size = tonumber(guifont:match(":h(%d+)$")) or 12
        local new_size = math.max(6, size + delta)
        local base = guifont:gsub(":h%d+$", "")
        vim.o.guifont = base .. ":h" .. new_size
      end
    '';

    # Delete undo files not touched in 90 days
    systemd.user.tmpfiles.rules = [ "e %h/.local/state/nvim/undo - - - 90d" ];
  };
}
