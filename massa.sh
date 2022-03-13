#!/bin/bash
# Version 0.0.1

curl -s https://raw.githubusercontent.com/testnets-io/core/main/logo.sh | bash # grab testnets.io ascii logo

sleep 1

CHOICE=$(
whiptail --title "Massa Manager" --menu "Make a Choice" 25 78 16 \
	"1" "Node Installation."   \
	"2" "Node & Client Update."  \
	"3" "Routability." \
	"4" "Bootstrapping." \
	"5" "Firewall." \
	"6" "Start Client." \
    "7" "Create Wallet." \
    "8" "View wallet." \
    "9" "Buy Rolls." \
	"10" "End script"  3>&2 2>&1 1>&3	
)

clear 

curl -s https://raw.githubusercontent.com/testnets-io/core/main/logo.sh | bash # grab testnets.io ascii logo

case $CHOICE in

1) # 1 - NODE INSTALLATION
sudo apt update -y && sudo apt upgrade -y < "/dev/null"
sudo apt install curl make clang pkg-config libssl-dev build-essential git mc jq unzip wget -y
sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
sleep 1
rustup toolchain install nightly
rustup default nightly
cd $HOME
git clone --branch testnet https://github.com/massalabs/massa.git
cd $HOME/massa
git checkout TEST.8.0
cd $HOME/massa/massa-node/
cargo build --release
cd ~/massa/massa-client/
cargo build --release
cp $HOME/massa/target/release/massa-client ~/massa/massa-client/

sudo tee <<EOF >/dev/null /etc/systemd/system/massa.service
[Unit]
Description=Massa Node Service
After=network-online.target
[Service]
Environment=RUST_BACKTRACE=full
User=$USER
Restart=always
RestartSec=3
LimitNOFILE=65535
WorkingDirectory=$HOME/massa/massa-node
ExecStart=$HOME/massa/target/release/massa-node
[Install]
WantedBy=multi-user.target
EOF

sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable massa
sudo systemctl start massa
echo "Node installed and running"
echo "Please restart your terminal before completing any of the other options"
;;


2) # NODE & CLIENT UPDATE
echo "Updating......"
cd $HOME
if [ ! -d $HOME/massabackup/ ]; then
	mkdir -p $HOME/massabackup
	cp $HOME/massa/massa-node/config/node_privkey.key $HOME/massabackup/
	cp $HOME/massa/massa-client/wallet.dat $HOME/massabackup/
fi

sudo systemctl stop massa
cd $HOME/massa/
rustup default nightly
rustup update
git stash
git remote set-url origin https://github.com/massalabs/massa.git
git checkout testnet
git pull
rm $HOME/massa/target/release/massa-node
cd $HOME/massa/massa-node/
cargo build --release
cp $HOME/massabackup/wallet.dat $HOME/massa/massa-client/wallet.dat
sudo systemctl start massa
sleep 10
;;


3) # 3 - ROUTABILITY
# if there is already a entry under routable ip, then comment it out with a "#"
sed -i 's/.*routable_ip/# \0/' "$HOME/massa/massa-node/base_config/config.toml"
# insert a new entry for routable ip. 
sed -i "/\[network\]/a routable_ip=\"$(curl -s ifconfig.me)\"" "$HOME/massa/massa-node/base_config/config.toml"
echo "Ip address added to $HOME/massa/massa-node/base_config/config.toml"
echo "Restarting Node..."     
sudo systemctl restart massa
;;


4) # 4 - COMMUNITY NODE BOOTSTRAPPING
sudo tee -a <<EOF >/dev/null $HOME/massa/massa-node/config/config.toml
[bootstrap]
    max_ping = 10000
    bootstrap_list = [ 
        [ "65.21.255.119:31245"  , "8kMaPna8idUQDMuzrYyFmiuKN9e8CSd8k9uXxhSoKQc6iC15qD" , ] ,
        [ "149.202.86.103:31245" , "5GcSNukkKePWpNSjx9STyoEZniJAN4U4EUzdsQyqhuP3WYf6nj" , ] ,
        [ "149.202.89.125:31245" , "5wDwi2GYPniGLzpDfKjXJrmHV3p1rLRmm4bQ9TUWNVkpYmd4Zm" , ] ,
        [ "158.69.120.215:31245" , "5QbsTjSoKzYc8uBbwPCap392CoMQfZ2jviyq492LZPpijctb9c" , ] ,
        [ "158.69.23.120:31245"  , "8139kbee951YJdwK99odM7e6V3eW7XShCfX5E2ovG3b9qxqqrq" , ] ,
        [ "172.105.115.99:31245" , "7dTV8ZZ36kPk5kArvmXEuKscwjR1UxeUsACt6QjyiqcJ4Fg6vn" , ] ,
        [ "88.99.184.211:31245"  , "5PwxspzMTnxeEsRELCxHwtow5QykBuTZYAHo93gmXxZmu5yBW8" , ] ,
    ] 
EOF
echo "Community bootstrap ip addresses added"
echo "Restarting Node..."     
sudo systemctl restart massa
;;


5) # 5 - CONFIGURE FIREWALL
echo "Adding firewall rules"  
sudo ufw allow 31244  
sudo ufw allow 31245 
sudo ufw allow 22
sudo ufw --force enable
;;


6) # 6 - START CLIENT
cd $HOME/massa/massa-client/
./massa-client
;;

7) # 7 - CREATE WALLET 
cd $HOME/massa/massa-client/
./massa-client --wallet wallet.dat wallet_generate_private_key
;;

8) # 8 - VIEW WALLET
cd $HOME/massa/massa-client/
./massa-client -- wallet_info
;;

9) # 9 - BUY ROLLS
cd $HOME/massa/massa-client/
massa_wallet_address=$(./massa-client -- wallet_info | grep Address  |awk '{print $2}')
./massa-client -- buy_rolls $massa_wallet_address 1 0
./massa-client -- register_staking_keys $(./massa-client -- wallet_info | grep Private | awk '{print $3}')
;;

10) # 10 - EXIT
exit
;;



*) echo "Not an option";;
esac
