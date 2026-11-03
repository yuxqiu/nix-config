{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

vimUtils.buildVimPlugin rec {
  pname = "sshfs-nvim";
  version = "2.1.1";

  src = fetchFromGitHub {
    owner = "uhs-robert";
    repo = "sshfs.nvim";
    rev = "v${version}";
    hash = "sha256-DxV1nVB+OqpFOFAn8MtH4pJc6TCboSD5cQnK+oz9d6g=";
  };

  meta = {
    description = "Mount hosts from your SSH config with SSHFS and browse, search and run commands on them from Neovim";
    homepage = "https://github.com/uhs-robert/sshfs.nvim";
    license = lib.licenses.mit;
  };
}
