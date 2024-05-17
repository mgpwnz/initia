#!/bin/bash
# Default variables
function="install"
NODE="initia"
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

export DAEMON_HOME=$HOME/.initia
export DAEMON_NAME=initiad
if [ -d "$DAEMON_HOME" ]; then
    new_folder_name="${DAEMON_HOME}_$(date +"%Y%m%d_%H%M%S")"
    mv "$DAEMON_HOME" "$new_folder_name"
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
rm -rf initia
git clone https://github.com/initia-labs/initia
cd initia
git checkout v0.2.14

# Build binary
make install
$DAEMON_NAME config set client chain-id initiation-1
sleep 1
$DAEMON_NAME config set client keyring-backend test
$DAEMON_NAME config set client node tcp://localhost:25757
$DAEMON_NAME init "$INI_ALIAS" --chain-id initiation-1

# Download genesis and addrbook files
curl -L https://snapshots-testnet.nodejumper.io/initia-testnet/genesis.json > $DAEMON_HOME/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/initia-testnet/addrbook.json > $DAEMON_HOME/config/addrbook.json

# Set seeds
sed -i -e 's|^seeds *=.*|seeds = "2eaa272622d1ba6796100ab39f58c75d458b9dbc@34.142.181.82:26656,c28827cb96c14c905b127b92065a3fb4cd77d7f6@testnet-seeds.whispernode.com:25756,cd69bcb00a6ecc1ba2b4a3465de4d4dd3e0a3db1@initia-testnet-seed.itrocket.net:51656,093e1b89a498b6a8760ad2188fbda30a05e4f300@35.240.207.217:26656,2c729d33d22d8cdae6658bed97b3097241ca586c@195.14.6.129:26019"|' $DAEMON_HOME/config/config.toml

# Set minimum gas price
sed -i -e 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.15uinit,0.01uusdc"|' $DAEMON_HOME/config/app.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "17"|' \
  $DAEMON_HOME/config/app.toml
# Download latest chain data snapshot
curl "https://snapshots-testnet.nodejumper.io/initia-testnet/initia-testnet_latest.tar.lz4" | lz4 -dc - | tar -xf - -C "$DAEMON_HOME"

echo "[Unit]
Description=$NODE Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which initiad) start
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/$NODE.service
sudo mv $HOME/$NODE.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

wget -O $DAEMON_HOME/config/addrbook.json https://snapshots.nodes.guru/og/addrbook.json

echo -e '\n\e[42mChecking a ports\e[0m\n' && sleep 1
#CHECK PORTS
PORT=385
if ss -tulpen | awk '{print $5}' | grep -q ":26660$" ; then
    echo -e "\e[31mPort 26660 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:26660\"|:${PORT}60\"|g" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mPort 26660 changed to ${PORT}60.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":26656$" ; then
    echo -e "\e[31mPort 26656 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:26656\"|:${PORT}56\"|g" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mPort 26656 changed to ${PORT}56.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":26657$" ; then
    echo -e "\e[31mPort 26657 already in use\e[39m"
    sleep 2
    sed -i -e "s|:26657\"|:${PORT}57\"|" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mPort 26657 changed to ${PORT}57.\e[0m\n"
    sleep 2
    $DAEMON_NAME config node tcp://localhost:${PORT}57
fi
if ss -tulpen | awk '{print $5}' | grep -q ":26658$" ; then
    echo -e "\e[31mPort 26658 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:26658\"|:${PORT}58\"|" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mPort 26658 changed to ${PORT}58.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":6060$" ; then
    echo -e "\e[31mPort 6060 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:6060\"|:${PORT}60\"|" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mPort 6060 changed to ${PORT}60.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":1317$" ; then
    echo -e "\e[31mPort 1317 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:1317\"|:${PORT}17\"|" $DAEMON_HOME/config/app.toml
    echo -e "\n\e[42mPort 1317 changed to ${PORT}17.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":9090$" ; then
    echo -e "\e[31mPort 9090 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:9090\"|:${PORT}90\"|" $DAEMON_HOME/config/app.toml
    echo -e "\n\e[42mPort 9090 changed to ${PORT}90.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":9091$" ; then
    echo -e "\e[31mPort 9091 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:9091\"|:${PORT}91\"|" $DAEMON_HOME/config/app.toml
    echo -e "\n\e[42mPort 9091 changed to ${PORT}91.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":8545$" ; then
    echo -e "\e[31mPort 8545 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:8545\"|:${PORT}45\"|" $DAEMON_HOME/config/app.toml
    echo -e "\n\e[42mPort 8545 changed to ${PORT}45.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":8546$" ; then
    echo -e "\e[31mPort 8546 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:8546\"|:${PORT}46\"|" $DAEMON_HOME/config/app.toml
    echo -e "\n\e[42mPort 8546 changed to ${PORT}46.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":8080$" ; then
    echo -e "\e[31mPort 8080 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:8080\"|:${PORT}80\"|" $DAEMON_HOME/config/app.toml
    echo -e "\n\e[42mPort 8546 changed to ${PORT}80.\e[0m\n"
    sleep 2
fi
if ss -tulpen | awk '{print $5}' | grep -q ":6065$" ; then
    echo -e "\e[31mPort 6065 already in use.\e[39m"
    sleep 2
    sed -i -e "s|:6065\"|:${PORT}65\"|" $DAEMON_HOME/config/config.toml
    echo -e "\n\e[42mPort 6065 changed to ${PORT}65.\e[0m\n"
    sleep 2
fi
echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable $NODE
sudo systemctl restart $NODE
cd $HOME
echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service $NODE status | grep active` =~ "running" ]]; then
  echo -e "Your $NODE node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice initia status\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your $NODE node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
}
uninstall() {
read -r -p "You really want to delete the node? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        sudo systemctl stop initia
        sudo systemctl disable initia
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