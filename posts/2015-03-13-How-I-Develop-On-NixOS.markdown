---
title: How I Develop On NixOS
---

This post covers how I approach haskell development on my NixOS (virtual) machine.

First check out this post which inspired me initially to switch to NixOS: [How I Develop with Nix by Olivier Charles](https://ocharles.org.uk/blog/posts/2014-02-04-how-i-develop-with-nixos.html)

Let's start immediately by an example. I come across some haskell code repository, e.g. [types-compat](https://github.com/philopon/types-compat).

I have a folder in my home directory called _projects_. Here is the sample structure

    |- /home/<myuser>
      |- projects
        |- libraries
          |- haskell
        |- someProjectOfMine

So I checkout external sources inside ```~/projects/libraries/haskell```

    cd ~/projects/libraries/haskell
    git clone https://github.com/philopon/types-compat
    cd types-compat

I forgot to say that in my _default_ NixOS environment I try to keep it to a minimum so I don't have ghci available: 

    [me@mymachine:~/projects/libraries/haskell/types-compat]$ ghci
    ghci: command not found

As you'll see - if you read on - we're only a few lines away of having not only ghci but all the necessary dependencies at our fingertips! There are a few things to be setup only once. I'll mark them as _prerequisite_ so you can see that the second (and third and fourth) time should really set you up quickly 

So I want to have a nix-shell for this haskell library. First of all the cabal2nix utility has to be installed:

(_prerequisite:_)

    nix-env -i cabal2nix

Then I run it on the types-compat project:

    # (still in ~/projects/libraries/haskell/types-compat)
    cabal2nix . > types-compat.nix

There is some naming convention here. First of all types-compat nicely follows the standard naming for a repository and the output nix file should be named <project_name>.nix

Then I have bash function which I added to my .bashrc which looks like this: 

(_prerequisite:_)

    vi ~/.bashrc

Add this function called mk_nix_shell_std. It actually serves two purposes:

* first of all: when I have an empty folder (a new project) I run the mk_nix_shell_std script and it will create my nix files.
* secondly: as we are demonstrating in this post I use it to generate a shell.nix wrapper around an existing <project_name>.nix file so that I don't have to touch the generated nix file (and can thus regenerate as much as I want)

Some notes:

* The script is based on someone else's work (but I don't remember who. When I find out from whom I tweaked it I'll provide a link to the post)
* There is some _rubbish_ in the script (e.g. it sets a python dependency, a useless environment variable). It's for sample purposes (and my brain is rather limited so I like to keep them). Tweak it as you like.

You can find the script source at the bottom of this post to save some space here.

After you added it to ```.bashrc``` first run the following command to ensure it's loaded:

(_prerequisite:_)

    . ~/.bashrc

Now - assuming you are still in ```~/projects/libraries/haskell/types-compat``` - you can run it:

    mk_nix_shell_std

It generates a shell.nix similar to the template above. Note that the name is properly filled and that the types-compat.nix is loaded as a haskell extension package:

    haskellPackages = pkgs.haskellPackages.override {
        extension = self: super: {
          types-compat = self.callPackage ./types-compat.nix {};
        };
    };

Simply run

    nix-shell

and you're good to go:

    ghci 
    :l src/Data/Proxy/Compat.hs

Pretty neat, no?

Actually it doesn't always work this easy. For example the package [bytestring-read](https://github.com/philopon/bytestring-read) from the same author depends on types-compat. When we'd follow the above steps we'd run into:

    $ nix-shell
    error: anonymous function at "/home/me/projects/libraries/haskell/bytestring-read/bytestring-read.nix":3:1 called without required argument ‘typesCompat’, at "/nix/store/v0a5yjygwv6gq40664ik71c6nc3cm0cn-nixpkgs-15.05pre55774.b6f8d1f/nixpkgs/lib/customisation.nix":58:12
    (use ‘--show-trace’ to show detailed location information)

That's because nix-shell can resolve haskell packages that are in the haskellPackages of nixpks but it cannot resolve the ones that aren't.

So we need to tell our shell.nix script where it can find it. Basically we'll do the following (recursive) steps

* Locate the source 
* Clone the source in the ~/projects/libraries/haskell folder
* Apply the procedure above (```cabal2nix``` and ```mk_nix_shell_std```)
* Test it by running ```nix-shell```
* Recurse for other dependencies if needed

In the bytestring-read example the missing dependency is types-compat (the one I explained above). So because we already have it installed we can just update our shell.nix:

    vi shell.nix

Add the following line in the extension part (above bytestring-read):

    typesCompat = self.callPackage ../types-compat/types-compat.nix {};

So it looks like this

    ...
    haskellPackages = pkgs.haskellPackages.override {
        extension = self: super: {
            typesCompat = self.callPackage ../types-compat/types-compat.nix {};
            bytestring-read = self.callPackage ./bytestring-read.nix {};
        };
    };
      ...

Careful readers will notice an inconsitency in the names. And it's in fact a bug I need to fix some day.

The typesCompat in the extensions is the correct naming convention and the bytestring-read is not correct (should have been bytestringRead).

We do need to use typesCompat and not types-compat because the cabal2nix-generated bytestring-read.nix has the following dependencies:

    { cabal, doctest, tasty, tastyQuickcheck, typesCompat }:

Notice typesCompat there!

I started this post by saying that this is how _I_ do it but I'm actually really curious as to how other nixers do it. How do you bootstrap your own projects? Which are the dependencies that you _always_ include?

That and any other suggestions are more than welcome.

So here is the script:

(_prerequisite:_)

    # Stdenv
    mk_nix_shell_std() {
      loc=`pwd`
      name=`basename ${loc}`

      if [ ! -f "${name}.nix" ]; then
        echo "${name}.nix is not found. Create bare minimum version..."
        cat <<EOM > ${name}.nix
    # Template file!
    { cabal }:

    cabal.mkDerivation (self: {
      pname = "${name}";
      version = "0.1.0.0";
      src = ./.;
      buildDepends = [];
      meta = {
        license = self.stdenv.lib.licences.unfree;
        platforms = self.ghc.meta.platforms;
      };
    })
    EOM
      else
        echo "${name}.nix is found"
      fi

      cat <<EOM > shell.nix
    let
      pkgs = import <nixpkgs> {};
      haskellPackages = pkgs.haskellPackages.override {
        extension = self: super: {
          ${name} = self.callPackage ./${name}.nix {};
        };
      };
      name = "${name}";
      stdenv = pkgs.stdenv;
    in stdenv.mkDerivation {
      buildInputs = [
        (haskellPackages.ghcWithPackagesOld (hs: ([
          hs.cabalInstall
          hs.hscolour
          hs.hoogle
          hs.haddock
        ]
        ++ hs.${name}.propagatedNativeBuildInputs
        )))
        pkgs.python
        pkgs.libxml2
        pkgs.postgresql
      ];
      inherit name;
      ME_ENV = "Hello";
    }
    EOM
    }

-_T_-