# How to use this

- You have to clone [cardano-configurations](https://github.com/input-output-hk/cardano-configurations) somewhere and use an absolute path to it in your configuration
- You can set up a dev environment with cardano-node, ogmios, ogmios-datum-cache, kupo (optional) and ctl-server (optional) using the template below
- Use `nix develop` to spin up a shell, then use `start-node`, `start-ogmios`, `start-datum-cache`, `start-kupo` or `start-ctl-server` to start the applications
- Use `start-postgres` (hacky implementation) to create a docker container with postgres (required by ogmios-datum-cache) *Note: docker is not included in the flake*

*flake.nix*
```nix
{
  inputs = {
    cardano-dev-shell.url = "github:gege251/cardano-dev-shell";

    nixpkgs.follows = "cardano-node/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    # You have to set the cardanio-node and cardano-transaction-lib versions here
    cardano-node.url = "github:input-output-hk/cardano-node?ref=1.35.4";
    cardano-transaction-lib.url = "github:Plutonomicon/cardano-transaction-lib/v4.0.2";

    ogmios.follows = "cardano-transaction-lib/ogmios";
    ogmios-datum-cache.follows = "cardano-transaction-lib/ogmios-datum-cache";
    kupo.follows = "cardano-transaction-lib/kupo-nixos";

  };
  outputs = { self, nixpkgs, cardano-node, flake-utils, cardano-transaction-lib, ogmios, ogmios-datum-cache, kupo, cardano-dev-shell }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # You have to set a few variables for the environment
        NETWORK = "preview";                                     # Network name (as it appears in the cardano-configurations repo)
        TM = 2;                                                  # Testnet magic number
        CONFIG_ROOT_DIR = "/Users/gergo/cardano-configurations"; # Absolute path to cardano-configurations
        DATA_ROOT_DIR = "/Users/gergo/testnets/data";            # The chain data and other application data will be stored here

        cardanoDevShell = cardano-dev-shell.devShell {
          # Inherit all the required dependencies here
          inherit system nixpkgs cardano-transaction-lib cardano-node ogmios ogmios-datum-cache kupo NETWORK TM CONFIG_ROOT_DIR DATA_ROOT_DIR;
        };
      in
      { devShell = pkgs.mkShell cardanoDevShell; }
    );
}
```
