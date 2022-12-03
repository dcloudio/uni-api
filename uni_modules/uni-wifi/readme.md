## 使用说明  

Wi-Fi功能模块


### App-iOS平台注意事项  
- iOS平台App获取Wi-Fi信息需要开启“Access WiFi information”能力  
  登录苹果开发者网站，在“Certificates, Identifiers & Profiles”页面选择“Identifiers”中选择对应的App ID，确保开启“Access WiFi information”，保存后重新生成profile文件  
- iOS13及以上系统，获取当前连接的Wi-Fi信息需要先获取系统定位权限，因此在iOS13及以上系统使用此接口时，会触发定位权限申请的弹窗  


### uni.startWifi

初始化Wi-Fi模块。


### uni.stopWifi

关闭 Wi-Fi 模块。


### uni.getConnectedWifi

获取已连接的 Wi-Fi 信息。


### uni.getWifiList

请求获取 Wi-Fi 列表。wifiList 数据会在 onGetWifiList 注册的回调中返回。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.onGetWifiList

监听获取到 Wi-Fi 列表数据事件。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.offGetWifiList

移除获取到 Wi-Fi 列表数据事件的监听函数。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.connectWifi

连接 Wi-Fi。若已知 Wi-Fi 信息，可以直接利用该接口连接。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.onWifiConnected

监听连接上 Wi-Fi 的事件。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.offWifiConnected

移除连接上wifi的事件的监听函数，不传此参数则移除所有监听函数。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.onWifiConnectedWithPartialInfo

监听连接上 Wi-Fi 的事件， wifiInfo仅包含SSID。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.onOffWifiConnectedWithPartialInfo

移除连接上 Wi-Fi 的事件的监听函数，不传参数则移除所有监听函数。

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


