{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";

    mpv.url = "github:mpv-player/mpv";
    mpv.flake = false;
    mpv-build.url = "github:mpv-player/mpv-build";
    mpv-build.flake = false;
    libass.url = "github:libass/libass";
    libass.flake = false;
    libplacebo.url = "git+https://github.com/haasn/libplacebo?submodules=1";
    libplacebo.flake = false;
    ffmpeg.url = "github:FFmpeg/FFmpeg";
    ffmpeg.flake = false;
  };

  outputs = { self, nixpkgs, devshell, utils, ... }@inputs:
    utils.lib.eachSystem [ "aarch64-linux" "x86_64-linux" ] (system:
      let
        lib = nixpkgs.lib;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
        };
        dependencies = with pkgs; [
          autoconf
          automake
          fontconfig
          freetype
          fribidi
          harfbuzz
          libtool
          meson
          ninja
          pkg-config
          yasm
          python3
        ];
      in rec {
        packages = rec {
          default = packages.libmpv;
          libmpv = pkgs.stdenv.mkDerivation rec {
            name = "libmpv";
            version = "unstable-master";
            src = inputs.mpv-build;
            nativeBuildInputs = dependencies;
            prePatch = ''
              cp -r ${inputs.libplacebo} libplacebo
              cp -r ${inputs.libass} libass
              cp -r ${inputs.ffmpeg} ffmpeg
              cp -r ${inputs.mpv} mpv
              chmod -R +w .
            '';
            postPatch = ''
              patchShebangs mpv/version.* ./mpv/TOOLS/
            '';
            configurePhase = ''
              printf "%s\n" -Dlibmpv=true > mpv_options
            '';
            buildPhase = ''
              ./scripts/libass-config
              ./scripts/libass-build -j$(nproc)
              ./scripts/libplacebo-config
              ./scripts/libplacebo-build -j$(nproc)
              ./scripts/ffmpeg-config
              ./scripts/ffmpeg-build -j$(nproc)
              ./scripts/mpv-config
              ./scripts/mpv-build -j$(nproc)
            '';
            installPhase = ''
              mkdir -p $out/lib
              install -Dm0444 mpv/build/libmpv.so.2.2.0 -t $out/lib/ 
              install -Dm0444 mpv/build/libmpv.so -t $out/lib/ 
            '';
          };
        };
        devShells.default = (pkgs.devshell.mkShell {
          name = "libmpv-dev-shell";
          packages = with pkgs; [ ];
        });
        checks = {
          nixpkgs-fmt = pkgs.runCommand "nixpkgs-fmt" {
            nativeBuildInputs = [ pkgs.nixpkgs-fmt ];
          } "nixpkgs-fmt --check ${./.}; touch $out";
        };
      });
}

