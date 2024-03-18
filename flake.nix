{
  description = "Geospatial NIX";

  nixConfig = {
    extra-substituters = [
      "https://geonix.cachix.org"
      "https://devenv.cachix.org"
    ];
    extra-trusted-public-keys = [
      "geonix.cachix.org-1:iyhIXkDLYLXbMhL3X3qOLBtRF8HEyAbhPXjjPeYsCl0="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    bash-prompt = "\\[\\033[1m\\][geonix]\\[\\033\[m\\]\\040\\w >\\040";
  };

  inputs = {
    geonix.url = "github:imincik/geospatial-nix";
    nixpkgs.follows = "geonix/nixpkgs";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "geonix/nixpkgs";
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "geonix/nixpkgs";
    };
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      imports = [ inputs.devenv.flakeModule ];

      systems = [ "x86_64-linux" ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:

        let

          glibc_2_27 =
            (import (builtins.fetchGit {
              name = "glibc_2_18";
              url = "https://github.com/NixOS/nixpkgs/";
              ref = "refs/heads/nixos-19.09";
              rev = "b79f64b5eb5fa8ca2f844ddb4d7c186b6c69a293";
            }) { inherit system; }).glibc;

          gcc_8_3_0 =
            (import (builtins.fetchGit {
              name = "gcc_8_3_0";
              url = "https://github.com/NixOS/nixpkgs/";
              ref = "refs/heads/nixpkgs-unstable";
              rev = "a9eb3eed170fa916e0a8364e5227ee661af76fde";
            }) { inherit system; }).gcc-unwrapped;

          getCustomGccStdenv =
            customGcc: customGlibc: origStdenv:
            { pkgs, ... }:
            with pkgs;
            let
              compilerWrapped = wrapCCWith {
                cc = customGcc;
                bintools = wrapBintoolsWith {
                  bintools = binutils-unwrapped;
                  libc = customGlibc;
                };
              };
            in
            overrideCC origStdenv compilerWrapped;
          gcc_8_3_0_glibc_2_27 = getCustomGccStdenv gcc_8_3_0 glibc_2_27 pkgs.stdenv pkgs;
        in

        {

          packages.geonixcli = inputs.geonix.packages.${system}.geonixcli;

          packages.gdal = inputs.geonix.packages.${system}.gdal.overrideAttrs (
            finalAttrs: previousAttrs: { stdenv = gcc_8_3_0_glibc_2_27; }
          );
        };

      flake = { };
    };
}
