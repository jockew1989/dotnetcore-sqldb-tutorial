#!/bin/bash

sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y

curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# Please follow the instructions and provide the necessary input to the installer.

# Do you want ghcup to automatically add the required PATH variable to "/home/ubuntu/.bashrc"? - (P or enter)

# Do you want to install haskell-language-server (HLS)? - (N or enter)

# Do you want to install stack? - (N or enter)

# Press ENTER to proceed or ctrl-c to abort. (enter)

# Once complete, you should have ghc and cabal installed to your system.


# -------------------------------------------------- REBOOT --------------------------------------------------

#declaring variables
export TESTNET_ID=1097911063


ghcup install ghc 8.10.7
ghcup set ghc 8.10.7

mkdir -p $HOME/cardano-src
cd $HOME/cardano-src

git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

printf '\n\n#ADDING PATHS\n' >> ~/.bashrc
printf 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"\n' >> ~/.bashrc
printf 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' >> ~/.bashrc


cd $HOME/cardano-src

git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node
git fetch --all --recurse-submodules --tags

git checkout $(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r .tag_name)

cabal configure --with-compiler=ghc-8.10.7

cabal build cardano-node cardano-cli

mkdir -p $HOME/.local/bin
cp -p "$(./scripts/bin-path.sh cardano-node)" $HOME/.local/bin/
cp -p "$(./scripts/bin-path.sh cardano-cli)" $HOME/.local/bin/

export PATH="$HOME/.local/bin/:$PATH"

source $HOME/.bashrc

# Testnet / Sandbox
# NetworkMagic: 1097911063

curl -O -J https://hydra.iohk.io/build/7654130/download/1/testnet-topology.json
curl -O -J https://hydra.iohk.io/build/7654130/download/1/testnet-shelley-genesis.json
curl -O -J https://hydra.iohk.io/build/7654130/download/1/testnet-config.json
curl -O -J https://hydra.iohk.io/build/7654130/download/1/testnet-byron-genesis.json
curl -O -J https://hydra.iohk.io/build/7654130/download/1/testnet-alonzo-genesis.json

cardano-node run \
   --topology ~/cardano/testnet-topology.json \
   --database-path ~/cardano/db \
   --socket-path ~/cardano/db/node.socket \
   --host-addr 10.0.0.4 \
   --port 3001 \
   --config ~/cardano/testnet-config.json


mkdir -p $HOME/cardano/keys

cd $HOME/cardano/keys

#creating the payment key

cardano-cli shelley address key-gen \
   --verification-key-file payment.vkey \
   --signing-key-file payment.skey


#creating the stake key

cardano-cli shelley stake-address key-gen \
   --verification-key-file stake.vkey \
   --signing-key-file stake.skey


#creating the genesis address using the stake key and the payment key

cardano-cli shelley address build \
    --payment-verification-key-file payment.vkey \
    --stake-verification-key-file stake.vkey \
    --testnet-magic 1097911063 \
    --out-file payment.addr


#adding the node address to cli

printf 'export CARDANO_NODE_SOCKET_PATH=~/cardano/db/node.socket' >> ~/.bashrc

#querying the address

cd ~/cardano/keys2/

cardano-cli shelley query utxo \
    --address $(cat payment.addr) \
    --testnet-magic 1097911063


#creating the stake address, this can not be used to recive payments but only rewards

cardano-cli shelley stake-address build \
   --stake-verification-key-file stake.vkey \ #payment adress is already associated with this stake key
   --out-file stake.addr \
    --testnet-magic 1097911063


#getting money from the faucet

curl -v -XPOST "https://faucet.shelley-testnet.dev.cardano.org/send-money/$(cat payment.addr)"


#registering the address in the blockchain, we need to create a certificate for that

#create a registration certificate
#using the stake key that is based on our payment key

cardano-cli shelley stake-address registration-certificate \
   --stake-verification-key-file stake.vkey \
   --out-file stake.cert


#now we need to put that certificate into the blockchain
#for that we need to create a transaction

#we need to calculate the minimum fees and then use the keys associated with that transaction

#steps:
#1. get protocol parameters

cardano-cli shelley query protocol-parameters \
    --testnet-magic 1097911063 \
    --out-file protocol.json

#2. query the blockchain for the tip

cardano-cli shelley query tip \
    --testnet-magic 1097911063 \
    --out-file tip.json

# the current tip is the block number was in this case was 48324512 #TODO: update to fetch this programmatically
# we will add 2500 to the original 48324512 which equals to 48327012
# this is our TTL (time to live)


# -------------------------------------------------- LEGACY --------------------------------------------------
# this is all just legacy code at this point, I dont think I need it but it might be good to keep


#next is to calculate the fees

# cardano-cli shelley transaction calculate-min-fee \
#     --tx-in-count 1 \
#     --tx-out-count 1 \
#     --testnet-magic 1097911063 \
#     --protocol-params-file protocol.json \
#     --witness-count 3 \



#calculate with blockfrost, 

# curl -s  -H "project_id: testnetl3YeeEZ3vPGYR28FWuYEwqE0QMvloFep" https://cardano-mainnet.blockfrost.io/api/v0/epochs/latest | jq '. | .fees'

# curl -H 'project_id: testnetl3YeeEZ3vPGYR28FWuYEwqE0QMvloFep'         https://cardano-testnet.blockfrost.io/api/v0/blocks/latest/parameters

# export TESTNET_ID=1097911063

# export TX_HASH=93a10a4f691d6d9df86312b9dd6731db43dbea0dcc8442e8f015b2a6101e283a#0
# export TX_IX=0
# export AVAILABLE_LOVELACE=1000000000
# export TX_FEE=0

# cardano-cli transaction build-raw \
#   --fee 0 \
#   --tx-in $(cat txtrans) \
#   --tx-out $(< payment.addr)+"$(($AVAILABLE_LOVELACE))"+"$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
#   --mint="$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
#   --out-file matx.raw



#   cardano-cli transaction build-raw \
#   --fee 0 \
#   --tx-in $TX_HASH \
#   --tx-out $(< payment.addr)+"$(($AVAILABLE_LOVELACE-$TX_FEE))"+"$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
#   --mint="$TOKEN_AMOUNT $(< policy/policyId).$TOKEN_NAME" \
#   --testnet-magic $TESTNET_ID \
#   --out-file matx.raw


# -------------------------------------------------- /LEGACY --------------------------------------------------

# I think what is happening now is that you create the transcation first and then you calculate the fees basd on the transaction

export TX_HASH=a3eb80ba8629698c94d94c5b02b9605e2700c9f0afaa13c68ab2155b87601f4d#0

#this works but what i am supposed to do is to calculate the fees based on the transaction and put the reamaining where it now sais 100000, will look into this
#basically the --tx-in is the transactionID from the transaction from the faucet and then i add #0 because it was the 0th trascation (see TxIx below)

#                            TxHash                                 TxIx        Amount
# --------------------------------------------------------------------------------------
# a3eb80ba8629698c94d94c5b02b9605e2700c9f0afaa13c68ab2155b87601f4d     0        1000000000 lovelace + TxOutDatumNone

cardano-cli transaction build-raw \
  --fee 400000 \
  --tx-in $TX_HASH \
  --tx-out $(cat payment.addr)+999600000 \
  --out-file matx.raw 

# I have no idea if this is correct but at least it gives me an answer that seems reasonable

cardano-cli transaction calculate-min-fee \
 --tx-body-file matx.raw \
 --testnet-magic 1097911063 \
 --protocol-params-file protocol.json \
 --tx-in-count 1 \
 --tx-out-count 1 \
 --witness-count 0

# I dont even think this is needed since i dont use the output anywhere, maybe the fees are calculated automatically?

#the cost i got was 165061 lovelace and I guess I should use the total i have (100000000) - 169593 - the keydeposit which is 400000 = 99434939

cardano-cli transaction sign \
 --signing-key-file payment.skey \
 --signing-key-file stake.skey \
 --testnet-magic 1097911063 \
 --tx-body-file matx.raw \
 --out-file matx.signed

cardano-cli transaction submit \
 --tx-file matx.signed \
 --testnet-magic 1097911063

 #so the above code works, seems like the fee is fixed at 400000, but i dont know if that is correct, it is submitted anyway



# ------------------------------------------------------ CREATING THE POOL ------------------------------------------------------


# create pool key directory

cd ~/cardano
mkdir pool-keys
cd pool-keys

# generate the keys
# genrate cold keys

cardano-cli node key-gen \
    --cold-verification-key-file cold.vkey \
    --cold-signing-key-file cold.skey \
    --operational-certificate-issue-counter-file cold.counter

# we use colde keys to generate hot keys

# generate VRF keys

cardano-cli node key-gen-VRF \
    --verification-key-file vrf.vkey \
    --signing-key-file vrf.skey


# Creating KES keys

cardano-cli node key-gen-KES \
    --verification-key-file kes.vkey \
    --signing-key-file kes.skey


#generate operational certificate, this needs some calculation

#this will give us the slotsperKESEvolution and slotsperKESPeriod
cat ~/cardano/testnet-shelley-genesis.json | grep KESPeriod

# in this example we get the following output:
# "slotsPerKESPeriod": 129600,
#   "maxKESEvolutions": 62,

#what this means is that that every 129600 slots (36h) there will be a new evolution of the KES key, and after 62 evolutions (36h * 62 = 2232h = 93 days)
# we need to create a new KES key and restart the node

# in order to get the kes-period for the next command we need to get the KESperiod from the genesis file and then the current tip of the blockchain with
cardano-cli query tip --testnet-magic 1097911063

#in my case we get 48381481 as the slot which measn that kes-period is 48381481/129600 = 373

cardano-cli node issue-op-cert \
    --kes-verification-key-file kes.vkey \
    --cold-signing-key-file cold.skey \
    --operational-certificate-issue-counter-file cold.counter \
    --kes-period 373 \
    --out-file node.cert


# Pause here for the day, next we will create different topology files, i have amended the one for the node but this caused it to work
# probably because it is trying to connect to a nod thet is not yet online

# this is to run the production node that will connect to the relay
cardano-node run \
   --topology ~/cardano-production/testnet-topology.json \
   --database-path ~/cardano-production/db \
   --socket-path ~/cardano-production/db/node.socket \
   --host-addr 10.0.0.4 \
   --port 3000 \
   --config ~/cardano-production/testnet-config.json