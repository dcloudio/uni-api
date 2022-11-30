<template>
	<view class="content">
		<image class="logo" src="/static/logo.png"></image>
		<view class="text-area">
			<text class="title">{{title}}</text>
		</view>
		<button @tap="testScreenShotListen">开启截屏监听</button>
		<button @tap="testScreenShotOff">关闭截屏监听</button>
		<button @tap="testGetBatteryInfo">获取电池电量</button>
		<button @tap="testonMemoryWarning">开启内存不足告警监听</button>
		<button @tap="testoffMemoryWarning">关闭内存不足告警监听</button>
		
		<button @tap="testStartWifi">初始化wifi模块</button>
		<button @tap="testGetWifiList">获取当前wifi列表</button>
		<button @tap="testGetConnnectWifi">获取当前连接的wifi</button>
		<button @tap="testConnnectWifi">链接wifi</button>
		<button @tap="testStopWifi">关闭wifi模块</button>
	</view>
</template>

<script>

	export default {
		data() {
			return {
				title: 'Hello',
				memListener:null,
			}
		},
		onLoad() {

		},
		methods: {
			onMemoryWarning:function(res){
				console.log(res);
			},
			testConnnectWifi(){

				uni.connectWifi({
					maunal:false,
					SSID:"Xiaomi_20D0",
					password:"BBBB",
					complete:(res)=>{
						console.log(res);
					}
				});
			},
			testGetConnnectWifi(){
				uni.getConnectedWifi({
					partialInfo:false,
					complete:(res)=>{
						console.log(res);
						if (res.errCode == 0) {
							uni.showToast({
								icon:'none',
								title:res.wifi.SSID
							})
						} else{
							uni.showToast({
								icon:'none',
								title:res.errMsg
							})
						}
						
					}
				});
			},
			testStartWifi(){
				uni.startWifi({
					success:(res)=> {
						console.log("success: " + JSON.stringify(res));
						// wifi 开启成功后，注册wifi链接状态监听和wifi列表获取监听
						uni.onGetWifiList(function(res){
							console.log("onGetWifiList");
							console.log(res);
						});
						uni.onWifiConnected(function(res){
							console.log("onWifiConnected");
							console.log(res);
						});
						
					},fail:(res)=>{
						console.log("fail: " + JSON.stringify(res));
					},complete:(res)=>{
						console.log("complete: " + JSON.stringify(res));
					}
				})
			},
			testStopWifi() {
				uni.stopWifi({
					success:(res)=> {
						console.log("success: " + JSON.stringify(res));
					},fail:(res)=>{
						console.log("fail: " + JSON.stringify(res));
					},complete:(res)=>{
						console.log("complete: " + JSON.stringify(res));
					}
				})
				
			},
			testGetWifiList() {
				uni.getWifiList({
					success:(res)=> {
						console.log("success: " + JSON.stringify(res));
					},fail:(res)=>{
						console.log("fail: " + JSON.stringify(res));
					},complete:(res)=>{
						console.log("complete: " + JSON.stringify(res));
					}
				})
				
			},
			testonMemoryWarning() {
				uni.onMemoryWarning(this.onMemoryWarning)
				uni.showToast({
					icon:'none',
					title:'已监听，注意控制台输出'
				})
			},
			testoffMemoryWarning(){
				uni.offMemoryWarning(this.onMemoryWarning)
				uni.showToast({
					icon:'none',
					title:'监听已移除'
				})
			},
			testScreenShotListen() {
				var that = this;
				uni.onUserCaptureScreen(function(res) {
						console.log(res);
						
						if (uni.getSystemInfoSync().platform == "android") {
							// 除android 之外的平台，不需要判断返回状态码
							if(res.errCode == -1){
								// 启动失败
								return ;
							}else if(res.errCode == 0){
								uni.showToast({
									icon:"none",
									title:'截屏监听已开启'
								})
							}else {
								uni.showToast({
									icon:"none",
									title:'捕获截屏事件'
								})
								that.screenImage = res.image
							}
						}else{
							// 除android 之外的平台，不需要判断返回状态码
							uni.showToast({
								icon:"none",
								title:'捕获截屏事件'
							})
						}
						
					});
					
					if (uni.getSystemInfoSync().platform != "android") {
						// 除android 之外的平台，直接提示监听已开启
						uni.showToast({
							icon:"none",
							title:'截屏监听已开启'
						})
					}
			},
			testScreenShotOff() {
				uni.offUserCaptureScreen(function(res) {
						console.log(res);
				});
				// 提示已经开始监听,注意观察
				uni.showToast({
					icon:"none",
					title:'截屏监听已关闭'
				})
			},
			testGetBatteryInfo() {
				uni.getBatteryInfo({
					success(res) {
						uni.showToast({
							title: "当前电量：" + res.level + '%',
							icon: 'none'
						});
					}
				})
			},
		}
	}
</script>

<style>
	.content {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}

	.logo {
		height: 200rpx;
		width: 200rpx;
		margin-top: 200rpx;
		margin-left: auto;
		margin-right: auto;
		margin-bottom: 50rpx;
	}

	.text-area {
		display: flex;
		justify-content: center;
	}

	.title {
		font-size: 36rpx;
		color: #8f8f94;
	}
</style>
