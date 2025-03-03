{
  description = "Dev environment with Cardano testnet and some tools";
  outputs = { self }: {
    devShell =
      { system
      , nixpkgs
      , cardano-node
      , cardano-transaction-lib ? null
      , ogmios ? null
      , ogmios-datum-cache ? null
      , kupo ? null
      , NETWORK
      , TM
      , FAUCET_KEY ? ""
      , CONFIG_ROOT_DIR
      , DATA_ROOT_DIR
      , CONFIG_DIR ? "${CONFIG_ROOT_DIR}/network/${NETWORK}/cardano-node"
      , DATA_DIR ? "${DATA_ROOT_DIR}/${NETWORK}"
      , KUPO_WORKDIR ? "${DATA_DIR}/kupo"
      , CARDANO_NODE_SOCKET_PATH ? "${DATA_DIR}/node.socket"
      , CARDANO_NODE_NETWORK_ID ? TM
      }:
      let
        optional = option: value: if isNull option then null else value;
        pkgs = nixpkgs.legacyPackages.${system};

        cardano-node' = cardano-node.packages.${system}.cardano-node;
        cardano-cli' = cardano-node.packages.${system}.cardano-cli;
        ogmios' = optional ogmios ogmios.packages.${system}."ogmios:exe:ogmios";
        kupo' = optional kupo kupo.packages.${system}.kupo;
        ogmios-datum-cache' = if isNull ogmios-datum-cache then null else ogmios-datum-cache.packages.${system}.ogmios-datum-cache;
        ctl-server =
          if !(isNull cardano-transaction-lib) && builtins.hasAttr "ctl-server:exe:ctl-server" cardano-transaction-lib.packages.${system}
          then cardano-transaction-lib.packages.${system}."ctl-server:exe:ctl-server"
          else null;

        start-node = pkgs.writeShellApplication
          {
            name = "start-node";
            runtimeInputs = [ cardano-node' ];
            text = ''
              export CONFIG_DIR=${CONFIG_DIR}
              export DATA_DIR=${DATA_DIR}
              export CARDANO_NODE_SOCKET_PATH=${CARDANO_NODE_SOCKET_PATH}

              cardano-node run \
                --topology "${CONFIG_DIR}/topology.json" \
                --database-path "${DATA_DIR}/chain" \
                --socket-path "${CARDANO_NODE_SOCKET_PATH}" \
                --port 3001 \
                --config "${CONFIG_DIR}/config.json"
            '';
          };

        start-ogmios =
          optional ogmios'
            (pkgs.writeShellApplication
              {
                name = "start-ogmios";
                runtimeInputs = [ ogmios ];
                text = ''
                  export CONFIG_DIR=${CONFIG_DIR}
                  export CARDANO_NODE_SOCKET_PATH=${CARDANO_NODE_SOCKET_PATH}

                  ogmios \
                    --node-socket "${CARDANO_NODE_SOCKET_PATH}" \
                    --node-config "${CONFIG_DIR}/config.json" \
                    --port 1337 \
                    --log-level Debug \
                    --timeout 180
                '';
              });


        start-datum-cache =
          optional ogmios-datum-cache'
            (pkgs.writeShellApplication
              {
                name = "start-datum-cache";
                runtimeInputs = [ ogmios-datum-cache ];
                text = ''
                  ogmios-datum-cache \
                    --db-port 5432 \
                    --db-host 127.0.0.1 \
                    --db-user postgres \
                    --db-name postgres \
                    --ogmios-port 1337 \
                    --ogmios-address 127.0.0.1 \
                    --db-password password \
                    --server-api user:pass \
                    --server-port 9999
                '';
              });

        start-postgres = pkgs.writeShellApplication {
          name = "start-postgres";
          text = ''
            docker run --name ${NETWORK}-odc-postgres -e POSTGRES_PASSWORD=password -d -p 5432:5432 postgres ||
            docker start ${NETWORK}-odc-postgres

          '';
        };

        stop-postgres = pkgs.writeShellApplication {
          name = "stop-postgres";
          text = "docker stop ${NETWORK}-odc-postgres";
        };

        start-kupo =
          optional kupo'
            (pkgs.writeShellApplication
              {
                name = "start-kupo";
                runtimeInputs = [ kupo' ];
                text = ''
                  if [ ! -d "${KUPO_WORKDIR}" ]; then mkdir "${KUPO_WORKDIR}"; fi
                  kupo \
                    --node-socket "${CARDANO_NODE_SOCKET_PATH}" \
                    --node-config "${CONFIG_DIR}/config.json" \
                    --workdir "${KUPO_WORKDIR}" \
                    --match "*" \
                    --since origin \
                    --defer-db-indexes
                '';
              });

        start-ctl-server =
          optional ctl-server
            (pkgs.writeShellApplication
              {
                name = "start-ctl-server";
                runtimeInputs = [ ctl-server ];
                text = "ctl-server";
              });
      in
      {
        inherit CARDANO_NODE_SOCKET_PATH CARDANO_NODE_NETWORK_ID TM;

        buildInputs = [
          start-node
          start-ogmios
          start-postgres
          stop-postgres
          start-datum-cache
          start-ctl-server
          start-kupo
          cardano-node'
          cardano-cli'
          ogmios'
          kupo'
          ogmios-datum-cache'
          ctl-server
        ];
      };
  };
}
