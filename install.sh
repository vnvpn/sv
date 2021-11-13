#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Loi：${plain}Ban phai su dung tai khoan root de chay tap lenh nay!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Khong phat hien duoc phien ban he thong, vui long lien he voi tac gia https://vnvpn.pw!!${plain}\n" && exit 1
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phan mem nay khong ho tro he thong 32-bit (x86), vui long su dung he thong 64-bit (x86_64), neu phat hien sai, vui long lirn he https://vnvpn.pw"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui long su dung he thong phien ban CentOS 7 tro len!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui long su dung he thong phien ban Ubuntu 16 tro len${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui long su dung he thong phien ban Debian 8 tro len!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat -y
    else
        apt install wget curl tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/soga.service ]]; then
        return 2
    fi
    temp=$(systemctl status soga | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_soga() {
    cd /usr/local/
    if [[ -e /usr/local/soga/ ]]; then
        rm /usr/local/soga/ -rf
    fi

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/RManLuo/crack-soga-v2ray/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Khong phat hien duoc phien ban soga, phien ban nay co the vuot qua gioi han API Github, vui long thu lai sau hoac chi dinh phien ban soga de cai dat theo cach thu cong${plain}"
            exit 1
        fi
        echo -e "Phien ban moi nhat cua soga duoc phat hien:${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz https://github.com/john8911/crack-soga-v2ray/releases/download/${last_version}/soga-cracked-linux64.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tai xuong soga khong thanh cong, vui long dam bao may chu cua ban co the tai xuong tep Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/john8911/crack-soga-v2ray/releases/download/${last_version}/soga-cracked-linux64.tar.gz"
        echo -e "Bat dau cai dat soga v$1"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tai xuong soga v$1 khong thanh cong, hay dam bao rang phien ban nay ton tai${plain}"
            exit 1
        fi
    fi

    tar zxvf soga.tar.gz
    rm soga.tar.gz -f
    cd soga
    chmod +x soga
    mkdir /etc/soga/ -p
    rm /etc/systemd/system/soga.service -f
    cp -f soga.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop soga
    systemctl enable soga
    echo -e "${green}soga v${last_version}${plain} Qua trinh cai dat hoan tat va qua trinh khoi dong da duoc thiet lap de bat dau tu dong"
    if [[ ! -f /etc/soga/soga.conf ]]; then
        cp soga.conf /etc/soga/
        echo -e ""
        echo -e "De câi dat moi, vui long tham khao huong dẫn wiki truoc: https://github.com/vnvpn/sv/wiki, cau hinh noi dung can thiet"
    else
        systemctl start soga
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}Soga khoi dong lai thanh cong${plain}"
        else
            echo -e "${red}Soga co the khong khoi dong duoc. Vui long su dung nhat ky soga de kiem tra thong tin nhat ky sau. Neu khong khoi dong duoc, dinh dang cau hinh co the da bi thay doi. Vui long truy cap wiki de kiem tra：https://github.com/vnvpn/sv/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/soga/blockList ]]; then
        cp blockList /etc/soga/
    fi
    if [[ ! -f /etc/soga/dns.yml ]]; then
        cp dns.yml /etc/soga/
    fi
    curl -o /usr/bin/soga -Ls https://raw.githubusercontent.com/vnvpn/sv/master/soga.sh
    chmod +x /usr/bin/soga
    echo -e ""
echo "Cach su dung tap lenh quan ly soga:"
     echo "------------------------------------------"
     echo "soga				- Hien thi menu quan ly  (nhieu chuc nang hon)"
     echo "soga start			- Khoi dong soga"
     echo "soga stop			- Dung soga"
     echo "soga restart			- Khoi dong lai soga"
     echo "soga status			- Kiem tra tinh trang soga"
     echo "soga enable			- Cai soga tu dong bat dau sau khi khoi dong"
     echo "soga disable			- Huy bo khoi dong soga tu dau"
     echo "soga log			- Kiem tra nhat ky soga"
     echo "soga update			- Cap nhat phien ban moi soga"
     echo "soga update x.x.x		- Cap nhat phien ban duoc chi dinh cua soga"
     echo "soga install			- Cai dat ban cap nhat soga"
     echo "soga uninstall		- Go cai dat ban cap nhat soga"
     echo "soga version			- Kiem tra phien ban soga"
     echo "------------------------------------------"
}

echo -e "${green}Bat dau cai dat${plain}"
install_base
install_acme
install_soga $1
