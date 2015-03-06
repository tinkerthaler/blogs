let 
  pkgs = import <nixpkgs> {};
  haskellPackages = pkgs.haskellPackages.override {
    extension = self: super: {
      th-blog = self.callPackage ./th-blog.nix {};
    };
  };
  name = "th-blog";
  stdenv = pkgs.stdenv;
in stdenv.mkDerivation {
  buildInputs = [
    (haskellPackages.ghcWithPackagesOld (hs: ([
      hs.cabalInstall
      hs.hscolour
      hs.hoogle
      hs.haddock
      hs.hakyll
    ]
    ++ hs.th-blog.propagatedNativeBuildInputs
    )))
    pkgs.python
    pkgs.libxml2
    pkgs.postgresql
  ];  
  inherit name;
  ME_ENV = "Hello";
}
