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
        runtimeInputs = [ pkgs.git ];
        text = ''
          if git diff --cached --quiet; then
            echo "opencodecommit: nothing staged" >&2
            exit 1
          fi

          # Zen's free tier rejects custom/tool-less agents, so use the
          # built-in read-only `plan` agent and also deny its shell, web and
          # subagent tools.
          export OPENCODE_CONFIG_CONTENT='{"agent":{"plan":{"permission":{"bash":"deny","webfetch":"deny","websearch":"deny","task":"deny"}}}}'

          prompt="Write a git commit message for the staged diff on stdin.
          Use Conventional Commits (type(scope): summary), imperative mood,
          subject at most 72 characters. Add a short body only if the change
          needs explaining. Match the style of these recent commits:
          $(git log --format=%s -n 10 2>/dev/null || true)

          Output only the commit message, no code fences or commentary."

          if [ -n "''${OPENCODECOMMIT_MODEL:-}" ]; then
            models=("$OPENCODECOMMIT_MODEL")
          else
            mapfile -t models < <(opencode models opencode --refresh 2>/dev/null | grep -- '-free$')
          fi

          diff=$(git diff --cached)
          for model in "''${models[@]}"; do
            if msg=$(printf '%s\n' "$diff" | opencode run --pure --agent plan -m "$model" "$prompt") && [ -n "$msg" ]; then
              exec git commit -e -m "$msg"
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
