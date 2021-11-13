#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Loi: ${plain}Ban phai su dung tai khoan root de chay tap lenh nay!\n" && exit 1

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
    echo -e "${red}Khong phat hien duoc phien ban he thong, vui long lien he voi tac gia https://vnvpn.pw!${plain}\n" && exit 1
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
        echo -e "${red}Vui long su dung he thong phien ban Ubuntu 16 tro len!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui long su dung he thong phien ban Debian 8 tro len!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Mac dinh$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Co khoi dong lai soga" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhan Enter de quay lai menu chinh: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/vnvpn/vn/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhap phien bản duoc chi dinh (phien bân moi nhat mac dinh): " && read version
    else
        version=$2
    fi
#    confirm "Chuc nang nay se buoc cai dat lai phien ban moi nhat hien tai, du lieu se khong bi mat, cc tiep tuc khong?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}da huy${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/vnvpn/vn/main/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Cap nhat hoan tat, soga da duoc khoi dong lai tu dong, vui long su dung trang thai soga de kiem tra trang thai khoi dong ${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

uninstall() {
    confirm "Ban co chac chan muon go cai dat soga khong?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop soga
    systemctl disable soga
    rm /etc/systemd/system/soga.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/soga/ -rf
    rm /usr/local/soga/ -rf

    echo ""
    echo -e "Qua trinh go cai dat thanh cong. Neu bạn muon xoa tap lenh nay, hay thoat tap lenh va chay${green}rm /usr/bin/soga -f${plain} Xoa bo"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Soga da chay roi, khong can khoi dong lai, neu can khoi dong lai, vui long chon khoi dong loi${plain}"
    else
        systemctl start soga
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Soga da khoi dong thanh cong, vui long su dung trang thai soga de kiem tra tinh hinh khoi dong${plain}"
        else
            echo -e "${red}Soga co the khong khoi dong duoc, vui long su dung nhat ky soga de xem thong tin nhat ky sau nay${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop soga
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Dung soga thanh cong${plain}"
    else
        echo -e "${red}Khong dung duoc Soga. Co the do thoi gian dung vuot qua hai giay. Vui long kiem tra thong tin nhat ky sau.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart soga
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Soga da khoi dong lai thanh cong, vui long su dung trang thai soga de kiem tra tinh hinh khoi dong${plain}"
    else
        echo -e "${red}Soga co the khong khoi dong duoc, vui long su dung nhat ky soga de xem thong tin nhat ky sau nay${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status soga --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable soga
    if [[ $? == 0 ]]; then
        echo -e "${green}Soga duoc thiet lap de bat dau chay sau khi khoi dong $${plain}"
    else
        echo -e "${red}Soga khong the thiet lap khoi dong tu dong${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable soga
    if [[ $? == 0 ]]; then
        echo -e "${green}Soga huy khoi dong va tu khoi dong thanh cong${plain}"
    else
        echo -e "${red}Soga huy bo loi tu dong khoi dong${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u soga.service -e --no-pager
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.000060000.xyz/tcp.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Cai dat thanh cong bbr, vui long khoi dong lai may chu${plain}"
    else
        echo ""
        echo -e "${red}Khong tai duoc tap lenh cai dat bbr, vui long kiem tra xem may co the ket noi voi Github khong${plain}"
    fi

    before_show_menu
}

update_shell() {
    wget -O /usr/bin/soga -N --no-check-certificate https://github.com/vnvpn/vn/main/soga.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Khong tai duoc script xuong, vui long kiem tra xem may có the ket noi voi Github khong${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/soga
        echo -e "${green}Tap lenh nang cap thanh cong, vui long chay lai tap lenh{plain}" && exit 0
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

check_enabled() {
    temp=$(systemctl is-enabled soga)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Soga da duoc cai dat, vui long khong lap lai cai dat${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui long cai dat soga truoc${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trang thai soga: ${green}Da chay${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trang thai soga: ${yellow}Khong chay${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trang thai soga: ${red}Chua cai dat${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Co tu dong khoi dong sau khi khoi dong khong: ${green}Co${plain}"
    else
        echo -e "Co tu dong khoi dong sau khi khoi dong khong: ${red}Khong${plain}"
    fi
}

show_soga_version() {
    echo -n "Phien ban soga:"
    /usr/local/soga/soga -v
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
echo "Cach su dung tap lenh quan ly soga:"
     echo "------------------------------------------"
     echo "soga				- Hiển thi menu quan ly  (nhieu chuc nang hon)"
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
show_menu() {
    echo -e "
  ${green}soga Tap lenh quan ly cua back-end，${plain}${red}không áp dụng cho docker${plain}
--- Ban quyen thuoc ve http://vnvpn.pw. Nghiem cam sao chep duoi moi hinh thuc ---
  ${green}0.${plain} Thoat tap lenh
————————————————
  ${green}1.${plain} Cai dat soga
  ${green}2.${plain} Cap nhat soga
  ${green}3.${plain} Gỡ cai dat soga
————————————————
  ${green}4.${plain} Khoi dong soga
  ${green}5.${plain} Dung soga
  ${green}6.${plain} Khoi dong lai soga
  ${green}7.${plain} Xem trang thai soga
  ${green}8.${plain} Xem nhat ky soga
————————————————
  ${green}9.${plain} Dat soga bat dau tu dong sau khi khoi dong
 ${green}10.${plain} Huy qua trinh tu khoi dong soga
————————————————
 ${green}11.${plain} Cai dat bang mot cu nhap chuot cua bbr (hat nhan moi nhat)
 ${green}12.${plain} Xem phien ban soga
 "
    show_status
    echo && read -p "Vui long nhap lua chon [0-12]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_soga_version
        ;;
        *) echo -e "${red}Vui long nhap so chinh xac [0-12]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_soga_version 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
