{
  flake.modules.homeManager.antigravity = {
    persistence.directories = [ ".gemini" ];
    programs = {
      antigravity-cli = {
        enable = true;
        enableMcpIntegration = true;
        settings = {
          privacy.usageStatisticsEnabled = false;
          security.auth.selectedType = "oauth-personal";
        };
      };
    };
    skills.destinations.gemini = ".gemini/skills";
  };
}
