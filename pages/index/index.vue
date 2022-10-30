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
		<button @tap="testGetConnectedWifi">获取当前wifi信息</button>
	</view>
</template>

<script>

	export default {
		data() {
			return {
				title: 'Hello'
			}
		},
		onLoad() {

		},
		methods: {
			testGetConnectedWifi() {
				uni.getConnectedWifi({
					success(res) {
						console.log(res);
					}
				})
			},
			testonMemoryWarning() {
				uni.onMemoryWarning(function(res) {
					console.log(res);
				})
			},
			testoffMemoryWarning(){
				uni.offMemoryWarning(function(res) {
					console.log(res);
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
