#!/bin/bash

### Installing the Cardano nod on shelly testnet (https://github.com/input-output-hk/cardano-tutorials/blob/master/node-setup/000_install.md)

#Commands ran

export ROOT_DIR=$(pwd)
export POOL_DIR=$(pwd)/pool
export NODE_DIR=$POOL_DIR/relay

sudo apt-get update
sudo apt-get upgrade -y

sudo ufw allow proto tcp from any to any port 22 #Open the firewall to ssh

sudo ufw allow proto tcp from any to any port 3001 # this will be our relay node

sudo ufw allow proto tcp from any to any port 3000 #block producing node

sudo ufw enable #to enable these rules, I was not able to do it, it threw errors for me

# ERROR: problem running ufw-init
# iptables-restore v1.8.4 (legacy): Couldn't load match `limit':No such file or directory

# Error occurred at line: 63
# Try `iptables-restore -h' or 'iptables-restore --help' for more information.
# iptables-restore v1.8.4 (legacy): Couldn't load match `limit':No such file or directory

# Error occurred at line: 30
# Try `iptables-restore -h' or 'iptables-restore --help' for more information.
# ip6tables-restore v1.8.4 (legacy): Couldn't load match `limit':No such file or directory

# Error occurred at line: 30
# Try `ip6tables-restore -h' or 'ip6tables-restore --help' for more information.

# Problem running '/etc/ufw/before.rules'
# Problem running '/etc/ufw/user.rules'
# Problem running '/etc/ufw/user6.rules'


#lets see if this creates a problem later on, this is for DigitalOcean, we will look into it later, but it seems like all that is missing now is the firewall which is not a huge deal in the test env

#Had to run sudo ufw disbale to be able tu run the dependencies

sudo ufw disable

#installing dependencies

sudo apt-get update -y
sudo apt-get install build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y

#installing cabal

export CABAL_URL="https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz"

wget $CABAL_URL
tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz
rm cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal.sig
mkdir -p ~/.local/bin
mv cabal ~/.local/bin/

#This is not in the guide but hopefully it will work

# sudo apt install cabal-install

#exporting to ba able to use cabal from the terminal

cd # just in case you were not already in the home directory


printf '\n\n#ADDING PATHS\n' >> ~/.bashrc
printf 'export PATH=~/.local/bin:$PATH' >> ~/.bashrc
printf '\nexport PATH=~/.cabal/bin:$PATH' >> ~/.bashrc

#relogin to get the new paths

source ~/.bashrc


cabal update

cd

mkdir pool #This is not in the official tutorial but in the youtube video
cd pool

# Download and install GHC:

wget https://downloads.haskell.org/~ghc/8.6.5/ghc-8.6.5-x86_64-deb9-linux.tar.xz
tar -xf ghc-8.6.5-x86_64-deb9-linux.tar.xz
rm ghc-8.6.5-x86_64-deb9-linux.tar.xz
cd ghc-8.6.5
./configure
sudo make install
cd ..

#Install Libsodium

git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

printf "\n\n#ADDING LIBSODIUM PATH\n" >> ~/.bashrc
printf 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc

source ~/.bashrc

cd ~/pool

git clone https://github.com/input-output-hk/cardano-node.git

cd cardano-node

# git fetch --all --tags
# git tag
# git checkout tags/1.14.2 #this is not in the youtube tutorial, there it is 1.13.0, if there are errors we will try to change this

git fetch --all --tags
git tag
git checkout tags/1.13.0 #this is not in the youtube tutorial, there it is 1.13.0, if there are errors we will try to change this

cabal install cardano-node cardano-cli



# Get genesis, config and topology files; start the node (https://github.com/input-output-hk/cardano-tutorials/blob/master/node-setup/010_getConfigFiles_AND_Connect.md)

mkdir ~/pool/cardano-node/relay
cd ~/pool/cardano-node/relay


wget https://hydra.iohk.io/build/7654130/download/1/testnet-config.json
wget https://hydra.iohk.io/build/7654130/download/1/testnet-shelley-genesis.json
wget https://hydra.iohk.io/build/7654130/download/1/testnet-topology.json #this was shelly testnet topology at web tutorial but link was dead (https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/shelley_testnet-topology.json)


#Run it in a multiplexer (press ctrl+b and then d to detach)

tmux


cardano-node run \
   --topology ~/pool/cardano-node/relay/testnet-topology.json \
   --database-path ~/pool/cardano-node/relay/db \
   --socket-path ~/pool/cardano-node/relay/db/node.socket \
   --host-addr 192.168.0.24 \
   --port 3001 \
   --config ~/pool/cardano-node/relay/testnet-config.json


cd cardano-node
git fetch --all --tags && git tag
git checkout tags/1.19.1
echo -e "package cardano-crypto-praos\n flags: -external-libsodium-vrf" > cabal.project.local
cabal clean
cabal update
cabal build all