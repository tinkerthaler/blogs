# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, hakyll }:

cabal.mkDerivation (self: {
  pname = "th-blog";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  buildDepends = [ hakyll ];
  meta = {
    license = self.stdenv.lib.licenses.unfree;
    platforms = self.ghc.meta.platforms;
  };
})