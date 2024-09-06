{
  description = "Zig cli";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      # Dev time (developing tools)
      devInputs = with pkgs; [
        zls
      ];
      # Build time (build tools; header libs)
      nativeBuildInputs = with pkgs; [
        zig
      ];
      # Run time (libs to link with)
      buildInputs = with pkgs; [
      ];

    in {
    # Utilized by `nix develop`
    devShell.x86_64-linux = pkgs.mkShell.override { stdenv = pkgs.clangStdenv; } {
      name = "cli";
      inherit buildInputs;
      nativeBuildInputs = nativeBuildInputs ++ devInputs;
    };

    # Utilized by `nix build`
    defaultPackage.x86_64-linux = pkgs.clangStdenv.mkDerivation rec {
      pname = "cli";
      version = "0.1.0";
      src = ./.;

      inherit nativeBuildInputs;
      inherit buildInputs;

      dontConfigure = true;
      dontInstall = true;
      doCheck = true;

      buildPhase = ''
        zig build install --cache-dir $$(pwd)/zig-cache --global-cache-dir $$(pwd)/.cache -Doptimize=ReleaseSafe --prefix $out
      '';
      installPhase = ''
        zig build test --cache-dir $$(pwd)/zig-cache --global-cache-dir $$(pwd)/.cache
      '';
    };

    # Utilized by `nix run`
    apps.x86_64-linux = {
      type = "app";
      program = self.packages.x86_64-linux.cli;
    };
  };
}
