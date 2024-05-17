#!/bin/bash
# Default variables
function="install"
# Options
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
        case "$1" in
        -in|--install)
            function="install"
            shift
            ;;
        -un|--uninstall)
            function="uninstall"
            shift
            ;;
        *|--)
		break
		;;
	esac
done
install() {
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
	    . $HOME/.bash_profile
fi

if [ ! $INI_ALIAS ]; then
	read -p "Enter validator name: " INI_ALIAS
	echo 'export INI_ALIAS='\"${INI_ALIAS}\" >> $HOME/.bash_profile
fi
echo 'source $HOME/.bashrc' >> $HOME/.bash_profile
. $HOME/.bash_profile
sleep 1
cd $HOME
sudo apt update
sudo apt install make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-12-dev git jq ncdu bsdmainutils htop -y < "/dev/null"
sleep 1
VERSION=1.21.3
wget -O go.tar.gz https://go.dev/dl/go$VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go.tar.gz && rm go.tar.gz
echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
echo 'export GO111MODULE=on' >> $HOME/.bash_profile
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
go version

cd $HOME

# Clone project repository
cd && rm -rf initia
git clone https://github.com/initia-labs/initia
cd initia
git checkout v0.2.14

# Build binary
make install

# Set node CLI configuration
initiad config set client chain-id initiation-1
initiad config set client keyring-backend test
initiad config set client node tcp://localhost:25757

# Initialize the node
initiad init "$INI_ALIAS" --chain-id initiation-1

# Download genesis and addrbook files
curl -L https://snapshots-testnet.nodejumper.io/initia-testnet/genesis.json > $HOME/.initia/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/initia-testnet/addrbook.json > $HOME/.initia/config/addrbook.json

# Set seeds
sed -i -e 's|^seeds *=.*|seeds = "2eaa272622d1ba6796100ab39f58c75d458b9dbc@34.142.181.82:26656,c28827cb96c14c905b127b92065a3fb4cd77d7f6@testnet-seeds.whispernode.com:25756,cd69bcb00a6ecc1ba2b4a3465de4d4dd3e0a3db1@initia-testnet-seed.itrocket.net:51656,093e1b89a498b6a8760ad2188fbda30a05e4f300@35.240.207.217:26656,2c729d33d22d8cdae6658bed97b3097241ca586c@195.14.6.129:26019"|' $HOME/.initia/config/config.toml

# Set minimum gas price
sed -i -e 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.15uinit,0.01uusdc"|' $HOME/.initia/config/app.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "17"|' \
  $HOME/.initia/config/app.toml

# Change ports
sed -i -e "s%:1317%:25717%; s%:8080%:25780%; s%:9090%:25790%; s%:9091%:25791%; s%:8545%:25745%; s%:8546%:25746%; s%:6065%:25765%" $HOME/.initia/config/app.toml
sed -i -e "s%:26658%:25758%; s%:26657%:25757%; s%:6060%:25760%; s%:26656%:25756%; s%:26660%:25761%" $HOME/.initia/config/config.toml

# Download latest chain data snapshot
curl "https://snapshots-testnet.nodejumper.io/initia-testnet/initia-testnet_latest.tar.lz4" | lz4 -dc - | tar -xf - -C "$HOME/.initia"

# Create a service
sudo tee /etc/systemd/system/initiad.service > /dev/null << EOF
[Unit]
Description=Initia node service
After=network-online.target
[Service]
User=$USER
ExecStart=$(which initiad) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable initiad.service

# Start the service and check the logs
cd $HOME
sudo systemctl start initiad.service
sudo journalctl -u initiad.service -f --no-hostname -o cat

}
uninstall() {
read -r -p "You really want to delete the node? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        sudo systemctl stop initiad
        sudo systemctl disable initiad
        sudo rm -rf $(which initiad) $HOME/.initia
    echo "Done"
    cd $HOME
    ;;
    *)
        echo Сanceled
        return 0
        ;;
esac
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function