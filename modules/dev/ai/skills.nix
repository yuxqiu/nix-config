{ inputs, ... }:
{
  flake.modules.homeManager.skills =
    { pkgs, ... }:
    {
      imports = [ inputs.agent-skills-nix.homeManagerModules.default ];

      programs.agent-skills = {
        enable = true;

        sources = {
          mattpocock-skills = {
            path = pkgs.fetchFromGitHub {
              owner = "mattpocock";
              repo = "skills";
              rev = "v1.3.2";
              hash = "sha256-ej0ATi0BWaAx+83dBwgCQxr9J2L2qEwKhUIeIRJ03Go=";
            };
            subdir = "skills/engineering";
          };
        };

        skills.enableAll = [
          "mattpocock-skills"
        ];

        targets.agents.enable = true;
      };
    };
}
