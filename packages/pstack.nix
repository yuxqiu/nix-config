{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchzip,
  bun,
}:
let
  # The only production dependency in poteto-mode/scripts/package.json.
  commander = fetchzip {
    url = "https://registry.npmjs.org/commander/-/commander-14.0.0.tgz";
    hash = "sha256-stak6QI5o/SGDAVOVuiDUAGqCx6ZJrgzYEgKLiaVjUc=";
  };
in
stdenvNoCC.mkDerivation rec {
  pname = "pstack";
  version = "0.9.99";

  src = fetchFromGitHub {
    owner = "michael-denyer";
    repo = "pstack-claude";
    rev = "v${version}";
    hash = "sha256-9CNViVBkV8TwLNDbtvIn0avCF/RpwMhS7oN5NUBdO5o=";
  };

  nativeBuildInputs = [ bun ];

  buildPhase = ''
    runHook preBuild
    scripts=plugins/pstack/skills/poteto-mode/scripts
    mkdir -p "$scripts/node_modules"
    ln -s ${commander} "$scripts/node_modules/commander"

    # Nix supplies dependencies at build time; these entrypoints need no installer.
    for entry in watch-pr/watch-pr watch-pr/ship-pr orch/orch.ts; do
      substituteInPlace "$scripts/$entry" \
        --replace-fail 'import { ensureDependenciesInstalled } from "../bootstrap.ts";' "" \
        --replace-fail 'ensureDependenciesInstalled();' ""
      # Bun needs a TypeScript extension to bundle the extensionless wrappers.
      mv "$scripts/$entry" "$scripts/$entry.build.ts"
      bun build "$scripts/$entry.build.ts" --target=bun --outfile="$scripts/$entry"
      rm "$scripts/$entry.build.ts"
      chmod +x "$scripts/$entry"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/skills"
    cp -r plugins/pstack/skills/. "$out/skills/"
    rm -r "$out/skills/poteto-mode/scripts/node_modules"

    # Preserve the existing tdd skill from the other shared collection.
    mv "$out/skills/tdd" "$out/skills/pstack-tdd"
    substituteInPlace "$out/skills/pstack-tdd/SKILL.md" \
      --replace-fail 'name: tdd' 'name: pstack-tdd'
    substituteInPlace "$out/skills/poteto-help/SKILL.md" \
      --replace-fail '../tdd/SKILL.md' '../pstack-tdd/SKILL.md' \
      --replace-fail '/tdd' '/pstack-tdd'
    substituteInPlace "$out/skills/poteto-help/references/recipes.md" \
      --replace-fail '/tdd' '/pstack-tdd'
    substituteInPlace "$out/skills/poteto-mode/playbooks/bug-fix.md" \
      --replace-fail '**tdd**' '**pstack-tdd**'
    runHook postInstall
  '';

  meta = {
    description = "pstack agent workflows with offline runtime dependencies";
    homepage = "https://github.com/michael-denyer/pstack-claude";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
