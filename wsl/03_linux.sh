#!/bin/bash
# Part Three
# Setup basic Ubuntu environmen in WSL2

echo 'Update sudoers'
sudo tee <<EOF /etc/sudoers.d/custom &>/dev/null
${USER}    ALL=(ALL) NOPASSWD:ALL
EOF
sudo chmod 0440 /etc/sudoers.d/custom
echo ''

echo "Add user ${USER} to group docker"
sudo usermod -a -G docker ${USER}
echo ''

echo 'Create /etc/wsl.conf'
sudo tee <<EOF /etc/wsl.conf &>/dev/null
[network]
generateResolvConf=false
EOF
echo ''

sudo cp /etc/resolv.conf /etc/resolv.conf.bkp &>/dev/null
sudo unlink /etc/resolv.conf &>/dev/null
echo ''

echo 'APT Proxy Setting'
sudo tee <<EOF /etc/apt/apt.conf.d/90-proxy &>/dev/null
Acquire::http::Proxy "http://<url>:<port>";
Acquire::https::Proxy "https://<url>:<port>";
Acquire::ftp::Proxy "ftp://<url>:<port>";
EOF
echo ''

echo 'Update Ubuntu'
# Setup Resolve conf
RESOLVE_DIR=$(mktemp -d)
RESOLVE_SR=$(mktemp -p "$RESOLVE_DIR")
RESOLVE_CITY=$(mktemp -p "$RESOLVE_DIR")
RESOLVE_CONF=$(mktemp -p "$RESOLVE_DIR")
for X in $(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "Get-DnsClientServerAddress -AddressFamily ipv4 | Select-Object -ExpandProperty ServerAddresses" | grep '^134.25' | sort | uniq | tr -d '\r')
  do echo "nameserver $X" >> "$RESOLVE_SR"
done
for Z in $(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "Get-DnsClientServerAddress -AddressFamily ipv4 | Select-Object -ExpandProperty ServerAddresses" | grep -v '^134.25' | sort | uniq | tr -d '\r')
  do echo "nameserver $Z" >> "$RESOLVE_CITY"
  done
cat "$RESOLVE_SR" "$RESOLVE_CITY" > "$RESOLVE_CONF"
echo 'search sr.se'>> "$RESOLVE_CONF"
sudo cp "$RESOLVE_CONF" /etc/resolv.conf
sudo chmod 0644 /etc/resolv.conf
sudo chown root:root /etc/resolv.conf
rm -rf "$RESOLVE_DIR"

# APT Update & Upgrade
sudo apt update --quiet
sudo apt full-upgrade --quiet --yes
sudo apt autoremove --quiet --yes
sudo apt clean
echo ''

echo 'Setup SSL Trust for <my-organisation>'
sudo mkdir -p /usr/local/share/ca-certificates/<my-organisation>
echo ' <my-organisation> CA Root'
echo ' > /usr/local/share/ca-certificates/<my-organisation>/cert_ca_root.crt'
sudo tee <<EOF /usr/local/share/ca-certificates/<my-organisation>/cert_ca_root.crt &>/dev/null
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
EOF
echo ''

echo ' <my-organisation> CA Intermediate'
echo ' > /usr/local/share/ca-certificates/<my-organisation>/cert_ca_intermediate.crt'
sudo tee <<EOF /usr/local/share/ca-certificates/<my-organisation>/cert_ca_intermediate.crt &>/dev/null
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
EOF
echo ''

echo 'Install SSL certificates system wide'
sudo update-ca-certificates
echo ''

echo 'Setup Personal Proxy Configuration'
mkdir ~/.environment.d &>/dev/null
cat <<EOF> ~/.environment.d/set-proxy
echo '  - bash'
export http_proxy="http://<url>:<port>" &>/dev/null
export https_proxy="https://<url>:<port>" &>/dev/null
export ftp_proxy="ftp://<url>:<port>" &>/dev/null
export no_proxy="localhost,127.0.0.1,::1,.<my-domain>" &>/dev/null
#
echo '  - git'
# Global proxy settings
git config --global http.proxy http://<url>:<port> &>/dev/null
git config --global https.proxy https://<url>:<port> &>/dev/null
#
# Disable proxy for GitLab on-prem and ignore SSL certifcate verification
git config --global http.http://<url>:<port>.sslVerify false &>/dev/null
git config --global http.http://<url>:<port>.proxy '' &>/dev/null
git config --global https.https://<url>:<port>.sslVerify false &>/dev/null
git config --global https.https://<url>:<port>.proxy '' &>/dev/null
#
# Disable proxy for GitHub on-prem
git config --global http.http://<url>:<port>.proxy '' &>/dev/null
git config --global https.https://<url>:<port>.proxy '' &>/dev/null
#
echo '  - npm'
npm config set proxy http://<url>:<port> &>/dev/null
npm config set https-proxy https://<url>:<port> &>/dev/null
#
echo '  - yarn'
yarn config set proxy http://<url>:<port> &>/dev/null
yarn config set https-proxy https://<url>:<port> &>/dev/null
EOF

cat <<EOF> ~/.environment.d/unset-proxy
echo '  - bash'
unset http_proxy &>/dev/null
unset https_proxy &>/dev/null
unset ftp_proxy &>/dev/null
unset no_proxy &>/dev/null
#
echo '  - git'
git config --global --unset http.proxy &>/dev/null
git config --global --unset https.proxy &>/dev/null
#
echo '  - npm'
npm config delete proxy &>/dev/null
npm config delete https-proxy &>/dev/null
#
echo '  - yarn'
yarn config delete proxy &>/dev/null
yarn config delete https-proxy &>/dev/null
EOF

cat <<EOF> ~/.wgetrc
use_proxy   = yes
https_proxy = https://<url>:<port>
http_proxy  = http://<url>:<port>
ftp_proxy   = ftp://<url>:<port>
no_proxy    = localhost,127.0.0.1,::1,.<my-domain>
EOF

echo 'Update ~/.bashrc'
cat <<EOF>> ~/.bashrc

# Setup PROXY
# Function for updating /etc/resolv.conf
RESOLVE_DIR=\$(mktemp -d)
RESOLVE_SR=\$(mktemp -p "\$RESOLVE_DIR")
RESOLVE_CITY=\$(mktemp -p "\$RESOLVE_DIR")
RESOLVE_CONF=\$(mktemp -p "\$RESOLVE_DIR")
resolve_conf() {
  for X in \$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "Get-DnsClientServerAddress -AddressFamily ipv4 | Select-Object -ExpandProperty ServerAddresses" | grep '^134.25' | sort | uniq | tr -d '\r')
    do echo "nameserver \$X" >> "\$RESOLVE_SR"
  done
  for Z in \$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "Get-DnsClientServerAddress -AddressFamily ipv4 | Select-Object -ExpandProperty ServerAddresses" | grep -v '^134.25' | sort | uniq | tr -d '\r')
    do echo "nameserver \$Z" >> "\$RESOLVE_CITY"
   done
  cat "\$RESOLVE_SR" "\$RESOLVE_CITY" > "\$RESOLVE_CONF"
  echo 'search sr.se'>> "\$RESOLVE_CONF"
  sudo cp "\$RESOLVE_CONF" /etc/resolv.conf
  sudo chmod 0644 /etc/resolv.conf
  sudo chown root:root /etc/resolv.conf
  rm -rf "\$RESOLVE_DIR"
}

echo 'Setting up Proxy environment'
echo '  - apt'
sudo sed -i 's/#//g' /etc/apt/apt.conf.d/90-proxy
source "\$HOME"/.environment.d/set-proxy
sed -i '/^use_proxy/ s/no/yes/' ~/.wgetrc
echo '  - resolve.conf'
resolve_conf

EOF
echo ''

echo 'Update PATH environment variable'
export PATH=${HOME}/bin:${PATH}
echo ''

echo 'Disable terminal bell'
sudo sed -i 's/^# set bell-style none/set bell-style none/g' /etc/inputrc
echo ''

echo '*** Ubuntu installation and configuration done!'
echo ''

read -t 5 -s -p '*** Shutting down WSL, and all running distributions, now***'

wsl.exe --shutdown
