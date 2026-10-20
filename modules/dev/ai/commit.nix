{
  flake.modules.nixos.commit =
    {
      config,
      pkgs,
      ...
    }:
    let
      geminicommitWithConfig = pkgs.symlinkJoin {
        name = "geminicommit";
        paths = [ pkgs.geminicommit ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/geminicommit" \
            --add-flags "--config ${config.sops.secrets."geminicommit.toml".path}"
        '';
      };

      # Generates a commit message from the staged diff with `opencode run`.
      # By default tries each free OpenCode Zen model (`opencode/*-free`)
      # until one succeeds; pin one with OPENCODECOMMIT_MODEL=provider/model
      # (see `opencode models`).
      opencodecommit = pkgs.writeShellApplication {
        name = "opencodecommit";
        runtimeInputs = [
          pkgs.git
          pkgs.gnugrep
          pkgs.jq
        ];
        text = ''
          if git diff --cached --quiet; then
            echo "opencodecommit: nothing staged" >&2
            exit 1
          fi

          # Keep the built-in read-only agent and deny shell, web and subagents.
          # A private server is required for this per-invocation config to apply.
          export OPENCODE_CONFIG_CONTENT='{"agents":{"plan":{"permissions":[{"action":"shell","resource":"*","effect":"deny"},{"action":"webfetch","resource":"*","effect":"deny"},{"action":"websearch","resource":"*","effect":"deny"},{"action":"subagent","resource":"*","effect":"deny"}]}}}'

          prompt="Write a git commit message for the staged diff on stdin.
          Use Conventional Commits (type(scope): summary), imperative mood,
          subject at most 72 characters. Add a short body only if the change
          needs explaining. Match the style of these recent commits:
          $(git log --format=%s -n 10 2>/dev/null || true)

          Output only the commit message, no code fences or commentary."

          if [ -n "''${OPENCODECOMMIT_MODEL:-}" ]; then
            models=("$OPENCODECOMMIT_MODEL")
          else
            model_list=$(opencode models --standalone)
            mapfile -t models < <(printf '%s\n' "$model_list" | grep '^opencode/.*-free$')
          fi

          if [ "''${#models[@]}" -eq 0 ]; then
            echo "opencodecommit: no free OpenCode models available; set OPENCODECOMMIT_MODEL=provider/model" >&2
            exit 1
          fi

          diff=$(git diff --cached)
          for model in "''${models[@]}"; do
            echo "opencodecommit: using $model" >&2
            if msg=$(printf '%s\n' "$diff" | opencode run --standalone --format json --agent plan -m "$model" "$prompt" |
              jq -ers '[.[] | select(.type == "text") | .part.text] | join("\n") | select(test("\\S"))'); then
              if git commit -e -m "$msg"; then
                exit 0
              else
                status=$?
                printf '\nopencodecommit: commit failed; generated message:\n%s\n' "$msg" >&2
                exit "$status"
              fi
            fi
            echo "opencodecommit: $model failed" >&2
          done

          echo "opencodecommit: no model succeeded" >&2
          exit 1
        '';
      };
    in
    {
      users.groups.geminicommit = { };
      users.users.geminicommit = {
        isSystemUser = true;
        group = "geminicommit";
        home = "/var/lib/geminicommit";
        createHome = true;
        description = "geminicommit service user";
      };

      sops.secrets."geminicommit.toml" = {
        mode = "0440";
        owner = config.users.users.geminicommit.name;
        group = config.users.users.geminicommit.group;
      };

      environment.systemPackages = [
        geminicommitWithConfig
        opencodecommit
      ];
    };
}
