{
  flake.modules.homeManager.nvim = {
    programs.nixvim.plugins.which-key = {
      enable = true;
      settings = {
        replace = {
          "<leader>" = "SPC";
          "<cr>" = "RET";
          "<tab>" = "TAB";
        };
        spec = [
          {
            __unkeyed-1 = "<leader>R";
            group = "remote";
            icon = "󰢟";
          }
          {
            __unkeyed-1 = "<leader>c";
            group = "code";
            icon = "󰚌";
          }
          {
            __unkeyed-1 = "<leader>d";
            group = "debug";
            icon = "󰃤";
          }
          {
            __unkeyed-1 = "<leader>f";
            group = "find";
            icon = "󰈞";
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
            icon = "󰊢";
          }
          {
            __unkeyed-1 = "<leader>j";
            group = "jump";
            icon = "󰆔";
          }
          {
            __unkeyed-1 = "<leader>l";
            group = "line";
            icon = "󰅂";
          }
          {
            __unkeyed-1 = "<leader>p";
            group = "paste";
            icon = "󰅌";
          }
          {
            __unkeyed-1 = "<leader>Q";
            group = "macro";
            icon = "󰑁";
          }
          {
            __unkeyed-1 = "<leader>q";
            group = "session";
            icon = "󰅴";
          }
          {
            __unkeyed-1 = "<leader>s";
            group = "search";
            icon = "󰍉";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "trouble";
            icon = "󰀨";
          }
          {
            __unkeyed-1 = "<leader>w";
            group = "window";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>u";
            group = "toggle";
            icon = "󰔲";
          }
        ];
      };
    };
  };
}
