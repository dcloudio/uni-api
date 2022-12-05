## 使用说明  

Wi-Fi功能模块


### App-iOS平台注意事项  
- iOS平台App获取Wi-Fi信息需要开启“Access WiFi information”能力  
  登录苹果开发者网站，在“Certificates, Identifiers & Profiles”页面选择“Identifiers”中选择对应的App ID，确保开启“Access WiFi information”，保存后重新生成profile文件  
- iOS13及以上系统，获取当前连接的Wi-Fi信息需要先获取系统定位权限，因此在iOS13及以上系统使用此接口时，会触发定位权限申请的弹窗  

### App-Android平台注意事项  
- 如果是自定义基座，需要具备下面的权限

```
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```


### 公共错误代码


|错误码	|错误信息					|说明																|
|---	|----						|------																|
|0		|ok							|正常																|
|12000	|not init					|未先调用 startWifi 接口											|
|12001	|system not support			|当前系统不支持相关能力												|
|12002	|password error Wi-Fi		|密码错误															|
|12005	|wifi not turned on			|Android 特有，未打开 Wi-Fi 开关									|
|12013	|wifi config may be expired	|系统保存的 Wi-Fi 配置过期，建议忘记 Wi-Fi 后重试，仅 Android 支持	|




### uni.startWifi

初始化Wi-Fi模块。


#### 参数

Object object

|属性|类型|默认值|必填|说明|
|---|----|------|----|---|
|success|function|否|接口调用成功的回调函数|
|fail|function|否|接口调用失败的回调函数|
|complete|function|否|接口调用结束的回调函数（调用成功、失败都会执行）|




### uni.stopWifi

关闭 Wi-Fi 模块。


#### 参数

Object object

|属性|类型|默认值|必填|说明|
|---|----|------|----|---|
|success|function|否|接口调用成功的回调函数|
|fail|function|否|接口调用失败的回调函数|
|complete|function|否|接口调用结束的回调函数（调用成功、失败都会执行）|



### uni.getConnectedWifi

获取已连接的 Wi-Fi 信息。

#### 参数

Object object

|属性		|类型		|默认值	|必填												|说明						|
|---		|----		|------	|----												|---						|
|partialInfo|boolean	|false	|否													|是否需要返回部分 Wi-Fi 信息|
|success	|function	|		|否													|接口调用成功的回调函数		|
|fail		|function	|		|否													|接口调用失败的回调函数		|
|complete	|function	|		|否													|接口调用结束的回调函数（调用成功、失败都会执行）|




### uni.getWifiList

请求获取 Wi-Fi 列表。wifiList 数据会在 onGetWifiList 注册的回调中返回。



#### 参数

Object object

|属性|类型|默认值|必填|说明|
|---|----|------|----|---|
|success|function||否|接口调用成功的回调函数|
|fail|function||否|接口调用失败的回调函数|
|complete|function||否|接口调用结束的回调函数（调用成功、失败都会执行）|




**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.onGetWifiList

监听获取到 Wi-Fi 列表数据事件。

#### 参数

function listener

获取到 Wi-Fi 列表数据事件的监听函数


#### 参数

Object res

|属性		|类型				|说明			|
|--			|---				|--				|
|wifiList	|Array<WifiInfo>	|Wi-Fi 列表数据	|



**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.offGetWifiList

移除获取到 Wi-Fi 列表数据事件的监听函数。

#### 参数

function listener

onGetWifiList 传入的监听函数。不传此参数则移除所有监听函数。


**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.connectWifi

连接 Wi-Fi。若已知 Wi-Fi 信息，可以直接利用该接口连接。

#### 参数

Object object

|属性	|类型		|默认值		|必填	|说明	|最低版本											|
|---	|---		|---		|---	|---	|-----												|
|SSID	|string		|			|是		|Wi-Fi 设备 SSID|													|
|BSSID	|string		|			|否		|Wi-Fi 设备 BSSID|													|
|password	|string		|			|是		|Wi-Fi 设备密码|													|
|maunal	|boolean	|false		|否		|跳转到系统设置页进行连接|2.12.0												|
|partialInfo	|boolean	|false		|否		|是否需要返回部分 Wi-Fi 信息，仅安卓生效|2.22.0												|
|success	|function	|			|否		|接口调用成功的回调函数|													|
|fail	|function	|			|否		|接口调用失败的回调函数|													|
|complete	|function	|		|否		|接口调用结束的回调函数（调用成功、失败都会执行）	|

**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.onWifiConnected


监听连接上 Wi-Fi 的事件。

#### 参数

function listener

连接上 Wi-Fi 的事件的监听函数

#### 参数

Object res


|属性	|类型		|说明		|
|---	|---		|---		|
|wifi	|WifiInfo	|Wi-Fi 信息	|


**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.offWifiConnected

移除连接上wifi的事件的监听函数，不传此参数则移除所有监听函数。


#### 参数

function listener

onWifiConnected 传入的监听函数。不传此参数则移除所有监听函数。


**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|


### uni.onWifiConnectedWithPartialInfo

监听连接上 Wi-Fi 的事件， wifiInfo仅包含SSID。

#### 参数

function listener

onWifiConnectedWithPartialInfo 传入的监听函数。不传此参数则移除所有监听函数。


**平台差异说明**

|App-Android|App-iOS|
|:-:|:-:|
|√|x|



### WifiInfo

Wifi 信息

#### 属性

+ string SSID

Wi-Fi 的 SSID

+ string BSSID

Wi-Fi 的 BSSID

+ boolean secure

Wi-Fi 是否安全

+ number signalStrength

Wi-Fi 信号强度, 安卓取值 0 ～ 100 

+ number frequency

Wi-Fi 频段单位 MHz




