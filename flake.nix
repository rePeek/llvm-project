{
  description = "LLVM / Clang / LLD / LLDB development";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      llvm = pkgs.llvmPackages;
    in
    {
      devShells.${system}.default =
        pkgs.mkShell.override {
          stdenv = llvm.stdenv;
        } {
          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            ccache
            python3
            swig
            pkg-config
            git
            clang-tools
            llvm.bintools
            just
          ];

          buildInputs = with pkgs; [
            zlib
            zstd
            xz
            libedit
            libxml2
            ncurses
          ];

          shellHook = ''
            echo "LLVM development environment"
            echo "CC=$CC"
            echo "CXX=$CXX"
          '';
        };
    };
}
