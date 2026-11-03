{
  flake.modules.homeManager.git =
    {
      config,
      pkgs,
      ...
    }:
    {
      programs.git = {
        enable = true;

        settings = {
          init.defaultBranch = "main";

          branch.sort = "-committerdate";
          tag.sort = "version:refname";

          commit.verbose = true;
          help.autocorrect = "prompt";

          alias = {
            graph = "log --all --graph --decorate --oneline";
            rank = "shortlog -s -n --no-merges";
            fame = "!gitfame";
            info = "!onefetch";
            uncommit = ''
              !f() {
                if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
                  git reset --soft HEAD^;
                else
                  git update-ref -d HEAD;
                fi;
              }; f
            '';
          };

          diff = {
            algorithm = "histogram";
            colorMoved = false;
            mnemonicPrefix = true;
            renames = true;
          };

          fetch = {
            prune = true;
            pruneTags = true;
            all = true;
          };

          filter = {
            "lfs".clean = "git-lfs clean -- %f";
            "lfs".smudge = "git-lfs smudge -- %f";
            "lfs".process = "git-lfs filter-process";
            "lfs".required = true;
          };

          pull = {
            rebase = true;
          };

          push = {
            autoSetupRemote = true;
            followTags = true;
          };

          rebase = {
            autoStash = true;
          };
        };

        signing = {
          key = config.my.user.keys."github-sign";
          format = "ssh";
          signByDefault = true;
        };

        ignores = [
          "**/.DS_Store"
          "**/.idea"
          "**/target/"
          "**/__pycache__/"
          "**/.pytest_cache"
          "**/.dev"
          "**/.logs"
        ];
      };

      programs.zsh.shellAliases = {
        guc = "git uncommit";
      };

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
      };

      home.packages = with pkgs; [
        # `git wip [HOST]`: push the current branch to a private `<name>-wip`
        # GitHub repo, or to HOST:wip/<name>.git over SSH, creating it first.
        (writeShellApplication {
          name = "git-wip";
          runtimeInputs = [ gh ];
          text = ''
            if [[ $# -gt 1 ]]; then
              echo "usage: git wip [HOST]" >&2
              exit 2
            fi
            host=''${1:-}
            remote=wip''${host:+-$host}

            if ! git remote get-url "$remote" >/dev/null 2>&1; then
              if origin=$(git remote get-url origin 2>/dev/null); then
                name=$(basename "$origin" .git)
              else
                origin=$(git rev-parse --show-toplevel)
                name=$(basename "$origin")
              fi
              # Each wip repo records its source, so a same-named repo from
              # another project is never pushed into.
              desc="wip of $origin"

              if [[ -z $host ]]; then
                login=$(gh api user --jq .login)
                repo="$login/$name-wip"
                if existing=$(gh repo view "$repo" --json description --jq .description 2>/dev/null); then
                  [[ $existing == "$desc" ]] || { echo "git wip: $repo exists but is not the wip repo of $origin" >&2; exit 1; }
                else
                  gh repo create "$repo" --private --description "$desc" >/dev/null
                fi
                url="git@github.com:$repo.git"
              else
                path="wip/$name.git"
                # shellcheck disable=SC2029 # expanded locally on purpose
                existing=$(ssh "$host" "if [ -d $(printf %q "$path") ]; then cat $(printf %q "$path")/description; else git init -q --bare $(printf %q "$path") && printf %s $(printf %q "$desc") >$(printf %q "$path")/description && printf %s $(printf %q "$desc"); fi")
                [[ $existing == "$desc" ]] || { echo "git wip: $host:$path exists but is not the wip repo of $origin" >&2; exit 1; }
                url="$host:$path"
              fi
              git remote add "$remote" "$url"
              # The wip remote carries no tags, so fetch.pruneTags would
              # delete every local tag on each fetch from it. It is only
              # used explicitly, so plain `git fetch` (fetch.all) skips it.
              git config "remote.$remote.pruneTags" false
              git config "remote.$remote.skipFetchAll" true
              if origin_url=$(git remote get-url origin 2>/dev/null); then
                # `git switch <branch>` refuses a branch present on both remotes.
                git config checkout.defaultRemote >/dev/null || git config checkout.defaultRemote origin
                # On a TTY, gh refuses to choose between two GitHub remotes.
                if [[ -z $host && $origin_url == *github.com* ]] &&
                  ! git config --get-regexp '^remote\..*\.gh-resolved$' >/dev/null; then
                  git config remote.origin.gh-resolved base
                fi
              fi
            fi

            git push --no-follow-tags "$remote" HEAD
          '';
        })
        git-absorb
        git-cliff
        git-crypt
        git-lfs
        (pkgs.symlinkJoin {
          name = "git-fame";
          paths = [ pkgs.git-fame ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/git-fame \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.openssl ]}
          '';
        })
        mergiraf
        onefetch
      ];
    };
}
