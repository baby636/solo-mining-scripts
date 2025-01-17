#!/bin/bash

basedir=/opt/phala
scriptdir=$basedir/scripts

source $scriptdir/utils.sh
source $scriptdir/config.sh
source $scriptdir/install_phala.sh
source $scriptdir/start.sh
source $scriptdir/stop.sh
source $scriptdir/update.sh
source $scriptdir/logs.sh
source $scriptdir/status.sh

help()
{
cat << EOF
Usage:
	help					展示帮助信息
	install {init|isgx|dcap}		安装Phala挖矿套件,默认无需输入IP地址、助记词
	uninstall				删除phala脚本
	start {node|pruntime|phost}{debug}	启动挖矿(debug参数允许输出挖矿套件日志信息)
	stop {node|pruntime|phost}		停止挖矿程序
	config					配置
	status					查看挖矿套件运行状态
	update {clean}				升级
	logs {node|pruntime|phost}		打印log信息
	sgx-test				运行挖矿测试程序
EOF
exit 0
}

sgx_test()
{
	docker -v
	if [ $? -ne 0 ]; then
		log_err "----------docker 没有安装----------" 
		exit 1
	fi

	local res_sgx=$(ls /dev | grep -w sgx)
	local res_isgx=$(ls /dev | grep -w isgx)
	if [ x"$res_sgx" == x"sgx" ] && [ x"$res_isgx" == x"" ]; then
		docker run -ti --rm --name phala-sgx_detect --device /dev/sgx/enclave --device /dev/sgx/provision swr.cn-east-3.myhuaweicloud.com/phala/phala-sgx_detect:latest
	elif [ x"$res_isgx" == x"isgx" ]; then
		docker run -ti --rm --name phala-sgx_detect --device /dev/isgx swr.cn-east-3.myhuaweicloud.com/phala/phala-sgx_detect:latest
	else
		log_err "----------sgx/dcap 驱动没有安装----------"
		exit 1
	fi
}

score_test()
{
	if [ $# != 1 ]; then
		log_err "---------请填写要使用的机器核心的数量！----------"
		exit 1
	fi

	docker -v
	if [ $? -ne 0 ]; then
		log_err "----------docker 没有安装----------" 
		install_depenencies
	fi

	local res_sgx=$(ls /dev | grep -w sgx)
	local res_isgx=$(ls /dev | grep -w isgx)
	if [ x"$res_sgx" == x"sgx" ] && [ x"$res_isgx" == x"" ] && [ -z $(docker ps -qf "name=phala-pruntime-bench") ]; then
		docker run -dti --rm --name phala-pruntime-bench -p 8001:8000 -v $HOME/data/phala-pruntime-data:/root/data -e EXTRA_OPTS="-c $1" --device /dev/sgx/enclave --device /dev/sgx/provision swr.cn-east-3.myhuaweicloud.com/phala/phala-dev-pruntime-bench
	elif [ x"$res_isgx" == x"isgx" ] && [ -z $(docker ps -qf "name=phala-pruntime-bench") ]; then
		docker run -dti --rm --name phala-pruntime-bench -p 8001:8000 -v $HOME/data/phala-pruntime-data:/root/data -e EXTRA_OPTS="-c $1" --device /dev/isgx swr.cn-east-3.myhuaweicloud.com/phala/phala-dev-pruntime-bench
	elif [ x"$res_sgx" == x"" ] && [ x"$res_isgx" == x"" ]; then
		log_err "----------sgx/dcap 驱动没有安装----------"
		exit 1
	fi

	echo -e "\033[31m 受各种环境因素影响，性能评分有可能产生一定程度的波动！此评分为预览版本，预备主网上线有变化的可能！ \033[0m"
	echo "评分更新中，请稍等！"
	sleep 30
	while true; do
		sleep 30
		score=$(curl -d '{"input": {}, "nonce": {}}' -H "Content-Type: application/json"  http://localhost:8001/get_info 2>/dev/null | jq -r .payload | jq .score)
		printf "\r您评分为: %d" $score
	done
}

case "$1" in
	install)
		install $2
		;;
	config)
		config $2
		;;
	start)
		shift 1
		start $@
		;;
	stop)
		stop $2
		;;
	status)
		status $@
		;;
	update)
		update $2
		;;
	logs)
		logs $2
		;;
	uninstall)
		$scriptdir/uninstall.sh
		;;
	score_test)
		score_test $2
		;;
	sgx-test)
		sgx_test
		;;
	help)
		help
		;;
	*)
		help
esac

exit 0
