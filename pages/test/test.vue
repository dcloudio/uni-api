<template>
	<view class="content">


		<button @tap="testStartWifi" style="width: 100%;">初始化wifi模块</button>
		<button @tap="testGetWifiList" style="width: 100%;">获取当前wifi列表</button>
		<button @tap="testOffGetWifiList" style="width: 100%;">移除wifi列表监听</button>
		<button @tap="testGetConnnectWifi" style="width: 100%;">获取当前连接的wifi</button>
		<button @tap="testConnnectWifi" style="width: 100%;">链接wifi</button>
		<button @tap="testStopWifi" style="width: 100%;">关闭wifi模块</button>

		<button @tap="onGetWifiList2_assert0" style="width: 100%;">onGetWifiList2_assert0</button>

		<button @tap="testScreenShotListen">开启截屏监听</button>
		<button @tap="testScreenShotOff">关闭截屏监听</button>
		<button @tap="testSetUserCaptureScreen">{{setUserCaptureScreenText}}</button>

		<button @tap="testGetBatteryInfo">获取电池电量</button>
		<button @tap="testGetBatteryInfoSync">同步获取电池电量</button>
		<button @tap="testonMemoryWarning">开启内存不足告警监听</button>
		<button @tap="testoffMemoryWarning">关闭内存不足告警监听</button>
		<button @tap="getLocationTest" style="width: 100%;">获取定位</button>
		<button type="default" @click="handleInstallApk">安装apk</button>
    <button type="default" @click="handleShowNotificationProgress">显示通知栏下载进度</button>

	</view>
</template>

<script>
	import {
		installApk
	} from "@/uni_modules/uni-installApk"


	let pre = 0
	let speed = 1
	let preTime = 0
	let isBegin = false

	export default {
		data() {
			return {
				memListener: null,
				setUserCaptureScreenFlag: false,
				setUserCaptureScreenText: '禁止截屏',
				permissionGranted: false,
				id: 0
			}
		},
		onLoad() {

		},
		methods: {
			onMemoryWarning: function(res) {
				console.log(res);
			},
			fn: function(res) {
				console.log(res)
			},
			getLocationTest() {
				console.log(" ------- getLocationTest: ");
				uni.getLocation({
					type: 'gcj02 ',
					success(res) {
						console.log(" success ", res);
					},
					fail(res) {
						console.log(" fail ", res);
					}
				})
			},
			onGetWifiList2_assert0() {
				console.log(" ------- onGetWifiList2_assert0: ", this.id);
				const fn = res => console.log('onGetWifiList res', res)
				uni.startWifi({
					success() {
						uni.onGetWifiList(fn)
						uni.getWifiList({
							success() {
								console.log('getWifiList success');
								uni.offGetWifiList(fn)
								uni.stopWifi({
									success() {},
									fail(e) {
										console.log("stopWifi fail: ", e);
									}
								})
							}
						})
					}
				})
				this.id++
			},

			testConnnectWifi() {

				uni.startWifi({
					success: (res) => {
						console.log("success: " + JSON.stringify(res));
						// uni.connectWifi({
						// 	maunal:false,
						// 	SSID:"Xiaomi_20D0",
						// 	password:"BBB111",
						// 	complete:(res)=>{
						// 		console.log(res);
						// 	}
						// });
					},
					fail: (res) => {
						console.log("fail: " + JSON.stringify(res));
					},
					complete: (res) => {
						console.log("complete: " + JSON.stringify(res));
					}
				})



			},
			testGetConnnectWifi() {
				uni.getConnectedWifi({
					partialInfo: false,
					complete: (res) => {
						console.log(res);
						if (res.errCode == 0) {
							uni.showToast({
								icon: 'none',
								title: res.wifi.SSID
							})
						} else {
							uni.showToast({
								icon: 'none',
								title: res.errMsg
							})
						}

					}
				});
			},
			testStartWifi() {
				uni.startWifi({
					success: (res) => {
						console.log("success: " + JSON.stringify(res));
						// wifi 开启成功后，注册wifi链接状态监听和wifi列表获取监听
						uni.onGetWifiList(function(res) {
							console.log("onGetWifiList");
							console.log(res);
						});
						uni.onWifiConnected(function(res) {
							console.log("onWifiConnected");
							console.log(res);
						});
						uni.onWifiConnectedWithPartialInfo(function(res) {
							console.log("onWifiConnectedWithPartialInfo");
							console.log(res);
						});

					},
					fail: (res) => {
						console.log("fail: " + JSON.stringify(res));
					},
					complete: (res) => {
						console.log("complete: " + JSON.stringify(res));
					}
				})
			},
			testStopWifi() {
				uni.offWifiConnected()
				uni.offWifiConnectedWithPartialInfo()

				uni.stopWifi({
					success: (res) => {
						console.log("success: " + JSON.stringify(res));
					},
					fail: (res) => {
						console.log("fail: " + JSON.stringify(res));
					},
					complete: (res) => {
						console.log("complete: " + JSON.stringify(res));
					}
				})

			},
			testGetWifiList() {
				uni.getWifiList({
					success: (res) => {
						console.log("success: " + JSON.stringify(res));
					},
					fail: (res) => {
						console.log("fail: " + JSON.stringify(res));
					},
					complete: (res) => {
						console.log("complete: " + JSON.stringify(res));
					}
				})

			},

			testOffGetWifiList() {
				uni.offGetWifiList()
			},



			testonMemoryWarning() {
				uni.onMemoryWarning(this.onMemoryWarning)
				uni.showToast({
					icon: 'none',
					title: '已监听，注意控制台输出'
				})
			},
			testoffMemoryWarning() {
				uni.offMemoryWarning(this.onMemoryWarning)
				uni.showToast({
					icon: 'none',
					title: '监听已移除'
				})
			},
			testScreenShotListen() {
				var that = this;
				uni.onUserCaptureScreen(function(res) {
					console.log(res);
					uni.showToast({
						icon: "none",
						title: '捕获截屏事件'
					})
					that.screenImage = res.path
				});

				if (uni.getSystemInfoSync().platform != "android" || that.permissionGranted) {
					// 除android 之外的平台，直接提示监听已开启
					uni.showToast({
						icon: "none",
						title: '截屏监听已开启'
					})
				}
			},
			testScreenShotOff() {
				uni.offUserCaptureScreen(function(res) {
					console.log(res);
				});
				// 提示已经开始监听,注意观察
				uni.showToast({
					icon: "none",
					title: '截屏监听已关闭'
				})
			},
			testGetBatteryInfo() {
				uni.getBatteryInfo({
					success(res) {
						console.log(res);
						uni.showToast({
							title: "当前电量：" + res.level + '%',
							icon: 'none'
						});
					}
				})
			},

			testGetBatteryInfoSync() {
				let ret = uni.getBatteryInfoSync()
				console.log(ret)
			},

			testSetUserCaptureScreen() {
				let flag = this.setUserCaptureScreenFlag;
				uni.setUserCaptureScreen({
					enable: flag,
					success: (res) => {
						console.log("setUserCaptureScreen enable: " + flag + " success: " + JSON.stringify(
							res));
					},
					fail: (res) => {
						console.log("setUserCaptureScreen enable: " + flag + " fail: " + JSON.stringify(res));
					},
					complete: (res) => {
						console.log("setUserCaptureScreen enable: " + flag + " complete: " + JSON.stringify(
							res));
					}
				});
				uni.showToast({
					icon: "none",
					title: this.setUserCaptureScreenText
				});
				this.setUserCaptureScreenFlag = !this.setUserCaptureScreenFlag;
				if (this.setUserCaptureScreenFlag) {
					this.setUserCaptureScreenText = '允许截屏';
				} else {
					this.setUserCaptureScreenText = '禁止截屏';
				}
			},
			handleInstallApk() {
				installApk({
					// filePath: "/sdcard/Android/data/io.dcloud.HBuilder/apps/HBuilder/doc/ddd.apk",
					filePath:"/static/test.apk",
					complete(res) {
						console.log(res);
					}
				})
			},
      handleShowNotificationProgress(){
        const task = uni.downloadFile({
        	url: "http://192.168.213.108:8080/test.apk",
        	success(e) {
        		console.log("success111 :", e);
        		uni.finishNotificationProgress({
        			title: "安装升级包",
        			content: "下载完成。",
        			callback: () => {
        				uni.installApk({
        					filePath: e.tempFilePath,
        					complete(res) {
        						console.log(res);
        					}
        				})
        			}
        		})
        	},
        	fail(e) {
        		console.log("fail : ", e);
        	}
        });

        task.onProgressUpdate((res) => {
        	const sd = this.calculateSpeed(res.totalBytesWritten)
        	const remian = ((res.totalBytesExpectedToWrite - res.totalBytesWritten) / sd).toFixed(0)
        	const remianStr = sd != 1 ? "剩余时间 " + remian + "秒" : "正在计算"

        	uni.createNotificationProgress({
        		title: "正在下载升级包",
        		content: remianStr,
        		progress: res.progress
        	})

        	if (res.progress == 100) {
        		pre = 0
        		speed = 1
        		preTime = Date.now()
        		isBegin = false
        	}
        })
      },
      calculateSpeed(current) {
      	//简略的计算下载速度
      	if (!isBegin) {
      		preTime = Date.now()
      		isBegin = true
      		return speed
      	}
      	const currentTime = Date.now()
      	if (currentTime - preTime > 1000) {
      		speed = current - pre
      		pre = current
      		preTime = currentTime
      	}
      	return speed
      }
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
