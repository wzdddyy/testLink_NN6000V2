#!/usr/bin/env bash
set -e
set -o errexit
set -o errtrace

error_handler() {
    echo "Error occurred in script at line: ${BASH_LINENO[0]}, command: '${BASH_COMMAND}'"
}

trap 'error_handler' ERR

REPO_URL=$1
REPO_BRANCH=$2
BUILD_DIR=$3
COMMIT_HASH=$4

# Convert BUILD_DIR to absolute path
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$(pwd)/$BUILD_DIR"
fi

FEEDS_CONF="feeds.conf.default"
GOLANG_REPO="https://github.com/sbwml/packages_lang_golang"
GOLANG_BRANCH="26.x"
THEME_SET="argon"
LAN_ADDR="10.0.0.1"

SCRIPT_DIR=$(cd $(dirname $0) && pwd)
BASE_PATH=${BASE_PATH:-$(dirname "$SCRIPT_DIR")}

source "$SCRIPT_DIR/general.sh"
source "$SCRIPT_DIR/feeds.sh"
source "$SCRIPT_DIR/packages.sh"
source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/docker.sh"


main() {
    # 1. 环境准备
    clone_repo
    clean_up
    reset_feeds_conf
    
    # 2. Feeds 更新
    update_feeds
    
    # 3. 独立包安装
    install_timecontrol
    install_quickfile
    install_lucky
    install_diskman
    install_dockerman
    install_adguardhome
    install_passwall2
    install_easytier
    install_oaf
    # 4. 统一安装
    install_feeds
    # 5. 系统配置
    remove_tweaked_packages
    fix_default_set
    fix_miniupnpd
    update_golang
    change_dnsmasq2full
    fix_mk_def_depends
    update_default_lan_addr
    update_affinity_script
    update_ath11k_fw
    change_cpuusage
    set_custom_task
    apply_passwall_tweaks
    update_nss_pbuf_performance
    set_build_signature
    update_nss_diag
    fix_compile_coremark
    update_dnsmasq_conf
    add_backup_info_to_sysupgrade   
    # 6. 构建配置阶段
    set_nginx_default_config
    update_uwsgi_limit_as
    update_nginx_ubus_module
    fix_nginx_configure
    remove_attendedsysupgrade
    fix_kconfig_recursive_dependency
    update_docker_stack
    update_script_priority
    fix_openssl_ktls
    fix_opkg_check
    fix_quectel_cm
    
    # 7. PBR 配置阶段
    install_pbr_isp
    fix_pbr_ip_forward
}

main "$@"
