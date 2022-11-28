# uni-wifi

WiFi信息相关


### uni.getConnectedWifi

获取当前设备连接的WiFi信息。

> iOS使用此接口注意事项：
> 1.iOS使用此接口需要添加Access WiFi information的Capabilities, 此能力不需要开发者手动配置，但是需要在苹果开发者后台，对开发及发布证书勾选相应能力，再生成podfile文件。
> 2.在iOS13及以上系统，获取当前连接的WiFi信息需要先获取系统定位权限，因此在iOS13及以上系统使用此接口时，会触发定位权限申请的弹窗。


### uni.startWifi

初始化WiFi模块。

**注意平台差异：iOS暂不支持此接口**

### uni.stopWifi

停止WiFi模块。

**注意平台差异：iOS暂不支持此接口**


### uni.getWifiList

获取WiFi列表。

**注意平台差异：iOS暂不支持此接口**

### uni.onGetWifiList

获取WiFi列表的回调。

**注意平台差异：iOS暂不支持此接口**

### uni.offGetWifiList

注销获取WiFi列表的回调。

**注意平台差异：iOS暂不支持此接口**

### uni.connectWifi

连接指定WiFi。

**注意平台差异：iOS暂不支持此接口**

### uni.onWifiConnected

连上wifi事件的监听函数。

**注意平台差异：iOS暂不支持此接口**

### uni.onWifiConnectedWithPartialInfo

连上wifi事件的监听函数， wifiInfo仅包含SSID。

**注意平台差异：iOS暂不支持此接口**

### uni.offWifiConnected

移除连接上wifi的事件的监听函数，不传此参数则移除所有监听函数。

**注意平台差异：iOS暂不支持此接口**


### uni.onOffWifiConnectedWithPartialInfo

移除连接上wifi的事件的监听函数，不传参数则移除所有监听函数。

**注意平台差异：iOS暂不支持此接口**


### uni.setWifiList

设置 wifiList 中 AP 的相关信息。在 onGetWifiList 回调后调用，iOS特有接口。

**注意平台差异：iOS特有接口，目前暂未支持**


