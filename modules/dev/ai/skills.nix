{
  flake.modules.homeManager.skills =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.skills;

      # Every skill from every source in one directory, assembled at build
      # time: nothing here reads a source while evaluating, so a source may be
      # any package without its build being needed to evaluate the config.
      # A skill is a subdirectory of a source that holds a SKILL.md; two
      # skills with the same name fail the build.
      allSkills = pkgs.runCommandLocal "agent-skills" { } ''
        mkdir "$out"
        ${lib.concatStrings (
          lib.mapAttrsToList (name: dir: ''
            found=""
            for skill in ${lib.escapeShellArg dir}/*/; do
              skill="''${skill%/}"
              [ -f "$skill/SKILL.md" ] || continue
              id="$(basename "$skill")"
              if [ -e "$out/$id" ]; then
                echo "skills: '$id' from source ${name} clashes with a skill of the same name from another source" >&2
                exit 1
              fi
              cp -r "$skill" "$out/$id"
              found=1
            done
            if [ -z "$found" ]; then
              echo "skills: source ${name} (${dir}) has no subdirectory with a SKILL.md" >&2
              exit 1
            fi
          '') cfg.sources
        )}
      '';
    in
    {
      options.skills = {
        sources = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "Directories of skills by source name: each subdirectory holding a SKILL.md is one skill, named after the subdirectory.";
        };
        destinations = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Map of agent names to the skills directory they read, relative to $HOME.";
        };
      };

      config = {
        skills.sources.mattpocock-skills = "${
          pkgs.fetchFromGitHub {
            owner = "mattpocock";
            repo = "skills";
            rev = "v1.3.2";
            hash = "sha256-ej0ATi0BWaAx+83dBwgCQxr9J2L2qEwKhUIeIRJ03Go=";
          }
        }/skills/engineering";

        # The shared location several agents also read.
        skills.destinations.agents = ".agents/skills";

        # One link per file, so each directory stays a real directory that an
        # agent can add its own skills to (Codex writes ~/.codex/skills/.system).
        home.file = lib.mapAttrs' (_agent: dir: {
          name = dir;
          value = {
            source = allSkills;
            recursive = true;
          };
        }) cfg.destinations;
      };
    };
}
