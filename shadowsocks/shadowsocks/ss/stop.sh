#!/bin/sh
#--------------------------------------------------------------------------
# Variable definitions
# source /koolshare/configs/ss.sh
eval `dbus export shadowsocks`
eval `dbus export ss`
redsocks2=$(ps | grep "redsocks2" | grep -v "grep")
dnscrypt=$(ps | grep "dnscrypt-proxy" | grep -v "grep")
sokcs5=$(ps|grep ss-local|grep -vw rss-local|grep -v 23456|cut -d " " -f 1)
ssredir=$(ps | grep "ss-redir" | grep -v "grep" | grep -vw "rss-redir")
rssredir=$(ps | grep "rss-redir" | grep -v "grep" | grep -vw "ss-redir")
sstunnel=$(ps | grep "ss-tunnel" | grep -v "grep" | grep -vw "rss-tunnel")
rsstunnel=$(ps | grep "rss-tunnel" | grep -v "grep" | grep -vw "ss-tunnel")
pdnsd=$(ps | grep "pdnsd" | grep -v "grep")
chinadns=$(ps | grep "chinadns" | grep -v "grep")
DNS2SOCK=$(ps | grep "dns2socks" | grep -v "grep")
koolgame=$(ps | grep "koolgame" | grep -v "grep")
client_linux_arm5=$(ps | grep "client_linux_arm5" | grep -v "grep")
Pcap_DNSProxy=$(ps | grep "Pcap_DNSProxy" | grep -v "grep")
lan_ipaddr=$(nvram get lan_ipaddr)
ip_rule_exist=`ip rule show | grep "fwmark 0x1/0x1 lookup 300" | grep -c 300`
nvram set ss_mode=0
dbus set dns2socks=0
nvram commit

# Different routers got different iptables syntax
case $(uname -m) in
  armv7l)
    MATCH_SET='--match-set'
    ;;
  mips)
    MATCH_SET='--set'
    ;;
esac


#--------------------------------------------------------------------------

restore_conf(){
	# restore dnsmasq conf file
	if [ -f /jffs/configs/dnsmasq.conf.add ]; then
		echo $(date): 恢复dnsmasq配置文件.
		rm -f /jffs/configs/dnsmasq.conf.add
	fi
	#--------------------------------------------------------------------------
	# delete dnsmasq postconf file
	if [ -f /jffs/scripts/dnsmasq.postconf ]; then
		echo $(date): 删除/jffs/scripts/dnsmasq.postconf
		rm -f /jffs/scripts/dnsmasq.postconf
	fi
	#--------------------------------------------------------------------------
	# delete custom.conf
	if [ -f /jffs/configs/dnsmasq.d/custom.conf ];then
		echo $(date): 删除 /jffs/configs/dnsmasq.d/custom.conf
		rm -rf /jffs/configs/dnsmasq.d/custom.conf
	fi	
}

bring_up_dnsmasq(){
	# Bring up dnsmasq
	echo $(date): 重启dnsmasq服务...
	service restart_dnsmasq >/dev/null 2>&1
}

restore_nat(){
	# flush iptables and destory REDSOCKS2 chain
	echo $(date): 删除SS相关的iptables设置，保证nat表干净...
	iptables -t nat -D PREROUTING -p tcp -m set $MATCH_SET gfwlist dst -j REDIRECT --to-port 3333 >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p udp -m set $MATCH_SET gfwlist dst -j REDIRECT --to-port 3333 >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p tcp -j REDSOCKS2 >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -D PREROUTING -j SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p tcp -j REDSOCKS2 >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -D PREROUTING -j SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -j SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -D OUTPUT -j SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m set $MATCH_SET router dst -j REDIRECT --to-ports 3333 >/dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m set $MATCH_SET router dst -j REDIRECT --to-ports 1089 >/dev/null 2>&1
	iptables -t nat -F OUTPUT  >/dev/null 2>&1
	iptables -t nat -D PREROUTING -s $lan_ipaddr/24 -p udp --dport 53 -j DNAT --to $lan_ipaddr >/dev/null 2>&1
	iptables -t nat -D PREROUTING -p udp --dport 53 -j DNAT --to $lan_ipaddr >/dev/null 2>&1
	iptables -t nat -F SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -X SHADOWSOCKS >/dev/null 2>&1
	iptables -t nat -F REDSOCKS2 >/dev/null 2>&1
	iptables -t nat -X REDSOCKS2 >/dev/null 2>&1
	ip route del local 0.0.0.0/0 dev lo table 300  >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -j SHADOWSOCKS2 >/dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp -j SHADOWSOCKS2 >/dev/null 2>&1
	iptables -t mangle -F SHADOWSOCKS2 >/dev/null 2>&1
	iptables -t mangle -X SHADOWSOCKS2 >/dev/null 2>&1
	
	if [ ! -z "ip_rule_exist" ];then
		until [ "$ip_rule_exist" = 0 ]
		do 
			ip rule del fwmark 0x01/0x01 table 300
			ip_rule_exist=`expr $ip_rule_exist - 1`
		done
	fi
	
}

destory_ipset(){
	# flush and destory ipset
	echo $(date): 清除所有SS相关ipset名单...
	ipset -F gfwlist >/dev/null 2>&1
	ipset -F router >/dev/null 2>&1
	ipset -F chnroute >/dev/null 2>&1
	ipset -X gfwlist >/dev/null 2>&1
	ipset -X router >/dev/null 2>&1
	ipset -X chnroute >/dev/null 2>&1
	ipset -F white_domain >/dev/null 2>&1
	ipset -F black_domain >/dev/null 2>&1
	ipset -X white_domain >/dev/null 2>&1
	ipset -X black_domain >/dev/null 2>&1
	ipset -F white_ip >/dev/null 2>&1
	ipset -F black_ip >/dev/null 2>&1
	ipset -X white_ip >/dev/null 2>&1
	ipset -X black_ip >/dev/null 2>&1
	#flush and destory white_cidr in chnmode mode
	ipset -F white_cidr >/dev/null 2>&1
	ipset -X white_cidr >/dev/null 2>&1
	#flush and destory black_cidr in gfwlist mode
	ipset -F black_cidr >/dev/null 2>&1
	ipset -X black_cidr >/dev/null 2>&1
}

restore_start_file(){
	echo $(date): 清除nat-start, wan-start中相关的SS启动命令...
	
	# restore nat-start file if any
	sed -i '/source/,/warning/d' /jffs/scripts/nat-start >/dev/null 2>&1
	sed -i '/nat-start/d' /jffs/scripts/nat-start >/dev/null 2>&1
	sed -i '/koolshare/d' /jffs/scripts/nat-start >/dev/null 2>&1
	sed -i '/sleep 5/d' /jffs/scripts/nat-start >/dev/null 2>&1
	
	# clear start up command line in wan-start
	sed -i '/start.sh/d' /jffs/scripts/wan-start >/dev/null 2>&1
	sed -i '/ssconfig/d' /jffs/scripts/wan-start >/dev/null 2>&1
	sed -i '/koolshare/d' /jffs/scripts/wan-start >/dev/null 2>&1
	sed -i '/sleep/d' /jffs/scripts/wan-start >/dev/null 2>&1
	sed -i '/sleep/d' /jffs/scripts/nat-start >/dev/null 2>&1	
}

kill_process(){
	#--------------------------------------------------------------------------
	# kill dnscrypt-proxy
	if [ ! -z "$dnscrypt" ]; then 
		echo $(date): 关闭dnscrypt-proxy进程...
		killall dnscrypt-proxy
	fi
	#--------------------------------------------------------------------------
	# kill redsocks2
	if [ ! -z "$redsocks2" ]; then 
		echo $(date): 关闭redsocks2进程...
		killall redsocks2
	fi
	#--------------------------------------------------------------------------
	# kill ss-redir
	if [ ! -z "$ssredir" ];then 
		echo $(date): 关闭ss-redir进程...
		killall ss-redir
	fi


	if [ ! -z "$rssredir" ];then 
		echo $(date): 关闭ssr-redir进程...
		killall rss-redir
	fi
	#--------------------------------------------------------------------------
	# kill ss-local
	sslocal=`ps | grep ss-local | grep -v "grep" | grep -w "23456" | awk '{print $1}'`
	if [ ! -z "$sslocal" ];then 
		echo $(date): 关闭ss-local进程:23456端口...
		kill $sslocal
	fi


	ssrlocal=`ps | grep rss-local | grep -v "grep" | grep -w "23456" | awk '{print $1}'`
	if [ ! -z "$ssrlocal" ];then 
		echo $(date): 关闭ssr-local进程:23456端口...
		kill -9 $ssrlocal
	fi

	#--------------------------------------------------------------------------
	# kill ss-tunnel
	if [ ! -z "$sstunnel" ];then 
		echo $(date): 关闭ss-tunnel进程...
		killall ss-tunnel
	fi
	
	if [ ! -z "$rsstunnel" ];then 
		echo $(date): 关闭rss-tunnel进程...
		killall rss-tunnel
	fi
	
	#--------------------------------------------------------------------------
	# kill pdnsd
	if [ ! -z "$pdnsd" ];then 
	echo $(date): 关闭pdnsd进程...
	killall pdnsd
	fi
	#--------------------------------------------------------------------------
	# kill Pcap_DNSProxy
	if [ ! -z "$Pcap_DNSProxy" ];then 
	echo $(date): 关闭Pcap_DNSProxy进程...
	killall dns.sh >/dev/null 2>&1
	killall Pcap_DNSProxy >/dev/null 2>&1
	fi
	#--------------------------------------------------------------------------
	# kill chinadns
	if [ ! -z "$chinadns" ];then 
		echo $(date): 关闭chinadns进程...
		killall chinadns
	fi
	#--------------------------------------------------------------------------
	# kill dns2socks
	if [ ! -z "$DNS2SOCK" ];then 
		echo $(date): 关闭dns2socks进程...
		killall dns2socks
	fi
	# kill all koolgame
	if [ ! -z "$koolgame" ];then 
		echo $(date): 关闭koolgame进程...
		killall koolgame >/dev/null 2>&1
	fi
	
	if [ ! -z "$client_linux_arm5" ];then 
		echo $(date): 关闭kcp协议进程...
		killall client_linux_arm5 >/dev/null 2>&1
	fi
}

kill_cron_job(){
	# kill crontab job
	echo $(date): 删除ss规则更新计划任务.
	sed -i '/ssupdate/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
}


remove_conf_and_settings(){
	echo $(date): 删除ss相关的名单配置文件.
	# remove conf under /jffs/configs/dnsmasq.d
	rm -rf /jffs/configs/dnsmasq.d/gfwlist.conf
	rm -rf /jffs/configs/dnsmasq.d/cdn.conf
	rm -rf /jffs/configs/dnsmasq.d/custom.conf
	rm -rf /jffs/configs/dnsmasq.d/wblist.conf
	rm -rf /tmp/sscdn.conf
	rm -rf /tmp/custom.conf
	rm -rf /tmp/cdn.conf
	rm -rf /tmp/wblist.conf
	rm -rf /jffs/configs/dnsmasq.conf.add

	# remove ss state
	dbus remove ss_basic_state_china
	dbus remove ss_basic_state_foreign
}

case $1 in
stop_all)
	#KCP_basic_action=0 应用所有设置
	echo $(date): =============== 梅林固件 - shadowsocks by sadoneli\&Xiaobao ===============
	echo $(date):
	echo $(date): -------------------------- 关闭Shadowsocks -------------------------------
	restore_conf
	bring_up_dnsmasq
	restore_nat
	destory_ipset
	restore_start_file
	kill_process
	kill_cron_job
	remove_conf_and_settings
	echo $(date): -------------------------- Shadowsocks已关闭 -----------------------------
	;;
stop_part)
	#KCP_basic_action=1 应用DNS设置
	echo $(date): ================ 梅林固件 - shadowsocks by sadoneli\&Xiaobao ==============
	echo $(date):
	echo $(date): ----------------------------- 停止上个SS模式 ------------------------------
	restore_conf
	#bring_up_dnsmasq
	restore_nat
	destory_ipset
	restore_start_file
	kill_process
	#kill_cron_job
	remove_conf_and_settings
	echo $(date):
	;;
*)
	echo "Usage: $0 (stop_all|stop_part)"
	exit 1
	;;
esac
