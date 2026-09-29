# CodeBurn - See where your AI coding tokens go
# Built from GitHub source using buildNpmPackage + tsup.
# Recipe adapted from https://github.com/selfhost-it/codeburn-nix
#
# To update:
#   1. Change `version`
#   2. Update `hash` (set to "" and build — nix will tell you the correct hash)
#   3. Update `npmDepsHash` (set to "" and build — nix will tell you the correct hash)
#   4. Update `dashDeps.hash` the same way (dashboard lockfile in dash/)
#   5. Run `nix build`
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs_22,
}:

buildNpmPackage rec {
  pname = "codeburn";
  version = "0.9.25";

  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "v${version}";
    hash = "sha256-MVgXl+fN9qZZmXhlgLXTX0toldDM1oH99Mc5bxScu7g=";
  };

  nodejs = nodejs_22;

  # Since v0.9.16 the React web dashboard lives in `dash/` as a separate npm
  # package with its own lockfile, and the root `build` script runs
  # `cd dash && npm install && npm run build`. That nested install cannot reach
  # the network in the sandbox, so its dependencies are vendored here as a
  # second fixed-output derivation and provisioned in `preBuild` instead.
  dashDeps = fetchNpmDeps {
    name = "codeburn-${version}-dash-npm-deps";
    src = "${src}/dash";
    hash = "sha256-tFERy8sO6e8MiopCbkSzXwRwTKEcWwVw8ucMVJY055E=";
  };

  npmDepsHash = "sha256-ucqpt5HTi8d8sD9eUl9ja7PyG0kyy1TASXgii/0xaNk=";

  postPatch = ''
    # dash/node_modules is provisioned offline in preBuild — drop the
    # in-script `npm ci`, which would otherwise fail against the
    # root-only npm cache set up by npmConfigHook.
    substituteInPlace package.json \
      --replace-fail \
        "cd dash && npm ci --no-audit --no-fund --silent && npm run build" \
        "cd dash && npm run build"
  '';

  # Install the dashboard's dependencies from the vendored cache. The cache is
  # copied out of the store because npm needs write access to it, and
  # npmConfigHook has already exported npm_config_offline=true for us.
  preBuild = ''
    cp -r ${dashDeps} "$TMPDIR/dash-npm-cache"
    chmod -R u+w "$TMPDIR/dash-npm-cache"
    npm_config_cache="$TMPDIR/dash-npm-cache" \
      npm ci --prefix dash --ignore-scripts --no-audit --no-fund
  '';

  # tsup bundles src/cli.ts -> dist/cli.js with a #!/usr/bin/env node banner.
  # The package.json `bin` field points to dist/cli.js, and `files: ["dist"]`
  # means npm pack ships only that. buildNpmPackage's default install phase
  # (npm pack + npm install --global into $out) handles the bin wrapper and
  # patches the shebang to the nodejs derivation in the closure.
  npmBuildScript = "build";

  meta = with lib; {
    description = "See where your AI coding tokens go - by task, tool, model, and project";
    homepage = "https://github.com/getagentseal/codeburn";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "codeburn";
  };
}
