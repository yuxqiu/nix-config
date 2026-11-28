# EasyEffects presets and impulse responses converted from the Dolby DAX3
# speaker tuning of the ThinkBook 16 G8+ IPH (21VH). The converter writes
# presets and impulse responses only; autoload needs a live PipeWire graph to
# name the sink's profile, so the host writes that file itself.
{
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  python3,
}:
let
  # Dolby DAX3 tuning XML for the ThinkBook 16 G8+ IPH (21VH).
  # See the gist's README for how it was obtained.
  tuning = fetchurl {
    url = "https://gist.githubusercontent.com/yuxqiu/2ff3e5558b7bca0cb5a096f6e8c056a5/raw/19e60b261469cb4a6d1cdd1191d22ecb98dd2aa7/DEV_0287_SUBSYS_17AA3940_PCI_SUBSYS_388817AA.xml";
    hash = "sha256-CEbr60W6dUh9fQZ4xL84FXcHoDYF306dwa6ZBd6oWNM=";
  };
in
stdenvNoCC.mkDerivation rec {
  pname = "easyeffects-dolby";
  version = "2026.10";

  src = fetchFromGitHub {
    owner = "antoinecellerier";
    repo = "speaker-tuning-to-easyeffects";
    rev = "v${version}";
    hash = "sha256-N5UEvyaWKjTtPEA4z0w/3nyp1G7IG7/MtFZWqAKkq6c=";
  };

  nativeBuildInputs = [
    (python3.withPackages (ps: [
      ps.numpy
      ps.scipy
    ]))
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    export HOME=$TMPDIR
    python3 dolby_to_easyeffects.py ${tuning} \
      --output-dir $out/output \
      --irs-dir $out/irs \
      --no-reload \
      --skip-ee-check \
      --skip-closing \
      --no-color
    runHook postInstall
  '';
}
