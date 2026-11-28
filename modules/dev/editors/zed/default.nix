{
  flake.modules.homeManager.zed =
    { config, lib, ... }:
    {
      programs.zed-editor = {
        enable = true;
        enableMcpIntegration = true;
        userSettings = {
          auto_update = false;
          base_keymap = "VSCode";
          collaboration_panel = {
            button = false;
          };
          colorize_brackets = true;
          diagnostics = {
            include_warnings = true;
            inline = {
              enabled = true;
            };
          };
          format_on_save = "on";
          inlay_hints = {
            enabled = true;
          };
          # Disabled for better performance on large monitors
          minimap = {
            show = "never";
          };
          project_panel = {
            sticky_scroll = false;
          };
          tabs = {
            "file_icons" = true;
          };
          telemetry = {
            metrics = false;
            diagnostics = false;
          };
          theme = {
            mode = "dark";
            light = "Catppuccin Mocha (Blur)";
            dark = "Catppuccin Mocha (Blur)";
          };
          title_bar = {
            show_onboarding_banner = false;
            show_user_picture = false;
            show_sign_in = false;
          };
          toolbar = {
            agent_review = false;
          };
          vim_mode = true;
          vim = {
            toggle_relative_line_numbers = true;
          };

          # AI
          show_edit_predictions = false;
          agent = {
            button = true;
            enable_feedback = false;
            show_turn_stats = true;
            default_model = {
              enable_thinking = true;
              provider = "openrouter";
              model = "openrouter/free";
            };
          };
          agent_servers = {
            gemini = {
              type = "registry";
            };
            codex-acp = {
              type = "registry";
            };
            OpenCode = {
              type = "custom";
              args = [
                "acp"
              ];
              command = "opencode";
            };
          };
        };
        userKeymaps = [
          {
            "context" = "vim_mode == insert";
            "bindings" = {
              "ctrl-c" = "editor::Copy";
              "ctrl-s" = "workspace::Save";
              "ctrl-x" = "editor::Cut";
              "ctrl-v" = "editor::Paste";
              "ctrl-w" = "pane::CloseActiveItem";
              "ctrl-shift-k" = "editor::MoveLineUp";
              "ctrl-shift-j" = "editor::MoveLineDown";
            };
          }
          {
            # disable collaboration panel
            "context" = "!Terminal";
            "bindings" = {
              "ctrl-shift-c" = null;
            };
          }
          {
            "context" = "(ProjectPanel && not_editing)";
            "bindings" = {
              "n" = "project_panel::NewFile";
              "shift-n" = "project_panel::NewDirectory";
              "d" = "project_panel::Delete";
              "r" = "project_panel::Rename";
            };
          }
          {
            "context" = "Editor && (showing_code_actions || showing_completions)";
            "bindings" = {
              "ctrl-j" = "editor::ContextMenuNext";
              "ctrl-k" = "editor::ContextMenuPrevious";
            };
          }
          {
            "bindings" = {
              "ctrl-o" = [
                "projects::OpenRecent"
                {
                  "create_new_window" = true;
                }
              ];
            };
          }
          {
            "context" = "vim_mode == normal || vim_mode == visual";
            "bindings" = {
              "s" = "vim::PushSneak";
              "shift-s" = "vim::PushSneakBackward";
            };
          }
          {
            "bindings" = {
              "ctrl-?" = "agent::Toggle";
            };
          }
          {
            "context" = "vim_operator == a || vim_operator == i || vim_operator == cs";
            "bindings" = {
              # Traditional Vim behavior
              "q" = "vim::AnyQuotes";
              "b" = "vim::AnyBrackets";

              # mini.ai plugin behavior
              "Q" = "vim::MiniQuotes";
              "B" = "vim::MiniBrackets";
            };
          }
        ];
        extensions = [
          "catppuccin-blur"
          "codex-acp"
          "editorconfig"
        ];
        installRemoteServer = false;
      };

      # snippets/<lang>.json is installed only when that language is enabled.
      xdg.configFile = lib.listToAttrs (
        map (file: lib.nameValuePair "zed/snippets/${file}" { source = ./snippets + "/${file}"; }) (
          builtins.filter (file: config.dev.languages ? ${lib.removeSuffix ".json" file}) (
            builtins.attrNames (builtins.readDir ./snippets)
          )
        )
      );

      # stylix: use zed theme
      stylix.targets.zed.colors.enable = false;

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "dev.zed.Zed";
            background-effect.blur = true;
          };
        }
      ];
    };
}
