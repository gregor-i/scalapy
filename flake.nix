{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    utils.url = "github:numtide/flake-utils";
    sbtDerivation.url = "github:zaninime/sbt-derivation";
    sbtDerivation.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, utils, sbtDerivation }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        fs = pkgs.lib.fileset;
        mkSbtDerivation = sbtDerivation.mkSbtDerivation.${system};
        sbt = pkgs.sbt;
        python = pkgs.python3; # or .python39, python310 ... python313

      in {
        devShells.default = pkgs.mkShell {
          packages = [ sbt python pkgs.clang ];
          shellHook = ''
            JAVA_OPTS='-Djna.library.path=${python}/lib'
            echo "python: $(python --version)"
          '';
        };

        checks.default = mkSbtDerivation {
          pname = "tests";
          version = "1.0.0";

          src = fs.toSource {
            root = ./.;
            fileset = fs.unions [
              ./README.md
              ./build.sbt
              ./project/plugins.sbt
              ./project/build.properties
              ./core
              ./coreMacros
              ./bench
            ];
          };

          depsSha256 = "sha256-62PM611SbtZ/2EILshHLKur3/EzOuxCjygPpyKZaRzs=";

          nativeBuildInputs = [ python pkgs.clang pkgs.which ];
          depsWarmupCommand = ''
            JAVA_OPTS='-Djna.library.path=${python}/lib'
            sbt +Test/compile
          '';

          buildPhase = ''
            JAVA_OPTS='-Djna.library.path=${python}/lib'
            sbt ";+coreJVM/test ;+coreNative/test ;benchJVM/compile ;benchNative/compile"
            touch $out
          '';
        };

        formatter = pkgs.nixfmt;
      });
}
