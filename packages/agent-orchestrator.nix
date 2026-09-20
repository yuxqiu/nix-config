{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:

let
  pname = "agent-orchestrator";
  version = "0.13.0";

  src = fetchurl {
    url = "https://github.com/Untrivial-ai/agent-orchestrator/releases/download/v${version}/agent-orchestrator-linux-x64.AppImage";
    hash = "sha256-MSyFKMFU0Y9aVHAd6mTK+YTerk1DEuttfhHguNXvpxI=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/agent-orchestrator.desktop \
      $out/share/applications/agent-orchestrator.desktop
    install -m 444 -D ${appimageContents}/agent-orchestrator.png \
      $out/share/icons/hicolor/1024x1024/apps/agent-orchestrator.png
    substituteInPlace $out/share/applications/agent-orchestrator.desktop \
      --replace-fail 'Exec=AppRun %U' 'Exec=${pname} %U'

    # https://orchestrator.inc/docs -> docs/telemetry.md: disable PostHog telemetry
    wrapProgram $out/bin/${pname} \
      --set AO_TELEMETRY_RENDERER off \
      --set AO_TELEMETRY_EVENTS off \
      --set AO_TELEMETRY_REMOTE off
  '';

  meta = {
    description = "Run and supervise teams of coding agents from planning to merge";
    homepage = "https://github.com/Untrivial-ai/agent-orchestrator";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "agent-orchestrator";
  };
}
