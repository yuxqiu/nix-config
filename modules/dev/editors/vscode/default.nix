{
  flake.modules.homeManager.vscode =
    { pkgs, ... }:
    {
      programs.vscode = {
        enable = true;
        profiles.default = {
          extensions = with pkgs.vscode-marketplace; [
            albert.tabout
            antfu.icons-carbon
            asvetliakov.vscode-neovim
            copilot-arena.copilot-arena
            editorconfig.editorconfig
            gruntfuggly.todo-tree
            jasonlhy.hungry-delete
            juanblanco.solidity
            ms-azuretools.vscode-containers
            ms-azuretools.vscode-docker
            ms-vscode.hexeditor
            ms-vscode.remote-explorer
            ms-vscode-remote.remote-containers
            ms-vscode-remote.remote-ssh
            ms-vscode-remote.remote-ssh-edit
            ms-vsliveshare.vsliveshare
            nmsmith89.incrementor
            redhat.java
            thomanq.math-snippets
            usernamehw.errorlens
            vscjava.vscode-java-debug
            vscjava.vscode-java-test
            vscjava.vscode-maven
            yfzhao.hscopes-booster
            yfzhao.ultra-math-preview
          ];

          userSettings = {
            # Editor Settings
            "explorer.confirmDelete" = false;
            "explorer.confirmDragAndDrop" = false;
            "editor.smoothScrolling" = true;
            "window.openFoldersInNewWindow" = "on";
            "editor.cursorSmoothCaretAnimation" = "on";
            "editor.cursorBlinking" = "smooth";
            "editor.minimap.autohide" = "mouseover";
            "editor.guides.bracketPairs" = true;
            "editor.autoClosingOvertype" = "always";
            "editor.linkedEditing" = true;
            "editor.suggest.snippetsPreventQuickSuggestions" = false;
            "diffEditor.ignoreTrimWhitespace" = true;
            "editor.suggestSelection" = "recentlyUsed";
            "editor.renderLineHighlight" = "none";
            "editor.matchBrackets" = "never";
            "editor.quickSuggestionsDelay" = 0;
            "editor.unicodeHighlight.allowedLocales" = {
              "zh_cn" = true;
            };
            "git.terminalAuthentication" = false;
            "github.gitAuthentication" = false;
            "window.restoreWindows" = "none";
            "git.openRepositoryInParentFolders" = "always";
            "git.blame.statusBarItem.enabled" = true;

            # Terminal
            "terminal.integrated.enableFileLinks" = "off";

            # Files
            "files.autoGuessEncoding" = true;
            "files.trimFinalNewlines" = true;

            # Workbench
            "workbench.list.smoothScrolling" = true;
            "workbench.startupEditor" = "none";
            "workbench.editor.labelFormat" = "medium";
            "workbench.tips.enabled" = false;
            "workbench.productIconTheme" = "icons-carbon";
            "workbench.tree.renderIndentGuides" = "none";

            # Online Services
            "workbench.enableExperiments" = false;
            "workbench.settings.enableNaturalLanguageSearch" = false;
            "extensions.ignoreRecommendations" = true;
            "telemetry.telemetryLevel" = "off";
            "telemetry.feedback.enabled" = false;
            "typescript.surveys.enabled" = false;
            "update.mode" = "none";
            "workbench.cloudChanges.autoResume" = "off";
            "workbench.cloudChanges.continueOn" = "off";
            "redhat.telemetry.enabled" = false;
            "update.showReleaseNotes" = false;
            "workbench.welcomePage.walkthroughs.openOnInstall" = false;
            "settingsSync.keybindingsPerPlatform" = false;
            "npm.fetchOnlinePackageInfo" = false;
            "extensions.autoUpdate" = false;
            "git.ignoreLegacyWarning" = true;
            "git.confirmSync" = false;
            "git.suggestSmartCommit" = false;
            "typescript.disableAutomaticTypeAcquisition" = true;

            # Neovim
            "extensions.experimental.affinity" = {
              "asvetliakov.vscode-neovim" = 1;
            };

            "[java]" = {
              "editor.defaultFormatter" = "redhat.java";
            };

            # Copilot Arena
            "arena.codePrivacySettings" = "Private";
            "arena.enableTabAutocomplete" = false;

            # TabOut
            "tabout.charactersToTabOutFrom" = [
              {
                open = "[";
                close = "]";
              }
              {
                open = "{";
                close = "}";
              }
              {
                open = "(";
                close = ")";
              }
              {
                open = "'";
                close = "'";
              }
              {
                open = ''"'';
                close = ''"'';
              }
              {
                open = ":";
                close = ":";
              }
              {
                open = "=";
                close = "=";
              }
              {
                open = ">";
                close = ">";
              }
              {
                open = "<";
                close = "<";
              }
              {
                open = ".";
                close = ".";
              }
              {
                open = "`";
                close = "`";
              }
              {
                open = ";";
                close = ";";
              }
              {
                open = "$";
                close = "$";
              }
              {
                open = "*";
                close = "*";
              }
            ];

            # chat
            "chat.agent.enabled" = false;
            "chat.disableAIFeatures" = true;
            "chat.commandCenter.enabled" = false;

            # Minimalistic
            "window.commandCenter" = false;
            "window.menuBarVisibility" = "hidden";
            "workbench.editor.enablePreview" = false;
            "workbench.layoutControl.enabled" = false;
            "explorer.compactFolders" = false;
            "explorer.autoReveal" = "focusNoScroll";
            "editor.inlineSuggest.enabled" = true;
            "workbench.tree.enableStickyScroll" = false;
            "editor.stickyScroll.enabled" = false;
            "workbench.activityBar.location" = "top";
            "window.titleBarStyle" = "native";
            "window.menuStyle" = "custom";
            "window.customTitleBarVisibility" = "never";
            "workbench.secondarySideBar.defaultVisibility" = "hidden";
          };

          # Keybindings (keybindings.json)
          keybindings = [
            # Use ctrl+j/k to select quick fix/suggestion
            {
              key = "ctrl+j";
              command = "selectNextQuickFix";
              when = "editorFocus && quickFixWidgetVisible";
            }
            {
              key = "ctrl+k";
              command = "selectPrevQuickFix";
              when = "editorFocus && quickFixWidgetVisible";
            }
            {
              key = "ctrl+j";
              command = "selectNextSuggestion";
              when = "editorTextFocus && suggestWidgetMultipleSuggestions && suggestWidgetVisible";
            }
            {
              key = "ctrl+k";
              command = "selectPrevSuggestion";
              when = "editorTextFocus && suggestWidgetMultipleSuggestions && suggestWidgetVisible";
            }

            # Move lines up/down
            {
              key = "ctrl+shift+j";
              command = "editor.action.moveLinesDownAction";
              when = "editorTextFocus && !editorReadonly";
            }
            {
              key = "ctrl+shift+k";
              command = "editor.action.moveLinesUpAction";
              when = "editorTextFocus && !editorReadonly";
            }

            # File/Folder creation
            {
              key = "n";
              command = "workbench.files.action.createFileFromExplorer";
              when = "explorerViewletVisible && filesExplorerFocus && !inputFocus";
            }
            {
              key = "shift+n";
              command = "workbench.files.action.createFolderFromExplorer";
              when = "explorerViewletVisible && filesExplorerFocus && !inputFocus";
            }

            # Free Copy, Close (on insert), Select all (on insert)
            {
              key = "ctrl+c";
              command = "-vscode-neovim.escape";
              when = "editorTextFocus && neovim.ctrlKeysNormal.c && neovim.init && !dirtyDiffVisible && !findWidgetVisible && !inReferenceSearchEditor && !markersNavigationVisible && !notebookCellFocused && !notificationCenterVisible && !parameterHintsVisible && !referenceSearchVisible && neovim.mode == 'normal' && editorLangId not in 'neovim.editorLangIdExclusions'";
            }
            {
              key = "ctrl+c";
              command = "-vscode-neovim.escape";
              when = "editorTextFocus && neovim.ctrlKeysInsert.c && neovim.init && neovim.mode != 'normal' && editorLangId not in 'neovim.editorLangIdExclusions'";
            }
            {
              key = "ctrl+w";
              command = "-vscode-neovim.send";
              when = "editorTextFocus && neovim.ctrlKeysInsert.w && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
            }
            {
              key = "ctrl+a";
              command = "-vscode-neovim.send";
              when = "editorTextFocus && neovim.ctrlKeysInsert.a && neovim.init && neovim.mode == 'insert' && editorLangId not in 'neovim.editorLangIdExclusions'";
            }

            # Copilot Arena
            {
              key = "ctrl+shift+.";
              command = "arena.promptToDiff";
              when = "editorTextFocus";
            }

            {
              key = "ctrl+j";
              command = "editor.action.triggerSuggest";
              when = "editorHasCompletionItemProvider && textInputFocus && !editorReadonly && !suggestWidgetVisible";
            }

            # Allow arrow keys in neovim normal mode
            {
              key = "up";
              command = "cursorUp";
              when = "editorTextFocus && neovim.mode == 'normal' && !inDebugRepl && !suggestWidgetMultipleSuggestions && !suggestWidgetVisible";
            }
            {
              key = "down";
              command = "cursorDown";
              when = "editorTextFocus && neovim.mode == 'normal' && !inDebugRepl && !suggestWidgetMultipleSuggestions && !suggestWidgetVisible";
            }
          ];
        };
      };
    };
}
