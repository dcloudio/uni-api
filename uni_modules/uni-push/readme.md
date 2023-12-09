# uni-push

`uni-push` 工程，是基于 DCloud-UTS 架构之上的封装个推消息推送 `SDK` 的插件工程，使用此模块可轻松实现服务端向客户端推送通知和透传消息的功能。

### 插件使用说明

#### 导入插件
```uts
import * as GTPlugin from "../../uni_modules/uni-push"
```

#### 初始化

```typescript
//初始化个推推送
GTPlugin.initPush();
```

#### 推送消息事件

> 添加透传消息回调，对应的GTPlugin.offPushMessage()可移除对应监听callback（传入null，可移除所有监听callback）

```typescript
GTPlugin.onPushMessage((res) => {
    console.log("onPushMessage => " + JSON.stringify(res))
})
```

| 名称   | 类型            | 描述                                                          |
| ---- | ------------- | ----------------------------------------------------------- |
| type | String        | 事件类型，"click"-从系统推送服务点击消息启动应用事件；"receive"-应用从推送服务器接收到推送消息事件。 |
| data | String、Object | 消息内容                                                        |



#### 日志

开发阶段，需要使用到日志辅助。

```typescript
//设置日志回调，可以在控制台看到[GT-PUSH]的日志
GTPlugin.setDebugLogger(function(res) {
    console.log(res)
});
```

当插件正常初始化会出现以下日志：

```uts
16:47:53.254 [GT-PUSH] [LogController] Sdk version = 3.3.0.0 at pages/index/index.vue:25
16:47:54.052 [GT-PUSH] [ServiceManager] ServiceManager start from initialize... at pages/index/index.vue:25
16:47:54.073 [GT-PUSH] PushCore started at pages/index/index.vue:25
16:47:54.274 [GT-PUSH] onHandleIntent() = get sdk service pid  at pages/index/index.vue:25
16:47:54.292 [GT-PUSH] onHandleIntent() areNotificationsEnabled at pages/index/index.vue:25
16:47:54.353 [GT-PUSH] [LoginInteractor] Start login appid = nU*******wzf at pages/index/index.vue:25
16:47:54.571 收到 cid onReceiveClientId : 3061f********ce7578eb24 at pages/index/index.vue:29
16:47:54.592 [GT-PUSH] onHandleIntent() = received client id  at pages/index/index.vue:25
16:47:54.593 [GT-PUSH] [LoginResult] Login successed with cid = 3061f********ce7578eb24 at pages/index/index.vue:25
```

#### 推送相关动作

> 设置推送相关动作回调，更多可查看`app-android/index.uts`下面的 `UserPushAction`类

```typescript
GTPlugin.setPushAction({
    onReceiveClientId: function(cid) {
        console.log("收到 cid onReceiveClientId : " + cid)
    }
});
```



#### 唯一的推送标识

获取客户端唯一的推送标识

```typescript
GTPlugin.getPushClientId({
	success: (res) => {
		console.log("getPushClientId success => " + JSON.stringify(res));
	},
	fail: (res) => {
		console.log("getPushClientId fail => " + JSON.stringify(res));
	},
	complete: (res) => {
		console.log("getPushClientId complete => " + JSON.stringify(res));
	}
});
```

**OBJECT 参数说明**

| 参数名      | 类型       | 必填  | 说明                       |
| -------- | -------- | --- | ------------------------ |
| success  | Function | 是   | 接口调用的回调函数，详见返回参数说明       |
| fail     | Function | 否   | 接口调用失败的回调函数              |
| complete | Function | 否   | 接口调用结束的回调函数（调用成功、失败都会执行） |

**success 返回参数说明**

| 参数     | 类型     | 说明                                       |
| ------ | ------ | ---------------------------------------- |
| cid    | String | 个推客户端推送id，对应uni-id-device表的push_clientid |
| errMsg | String | 错误描述                                     |

**fail 返回参数说明**

| 参数     | 类型     | 说明   |
| ------ | ------ | ---- |
| errMsg | String | 错误描述 |



### APP_ID申请

可登录[个推官网](https://dev.getui.com/)注册申请应用，获取APP相关信息。



### 多厂商

多厂商渠道可以参考[[厂商应用开通指南-个推文档中心](https://docs.getui.com/getui/mobile/vendor/vendor_open/) 和 [厂商 SDK 集成指南-个推文档中心](https://docs.getui.com/getui/mobile/vendor/androidstudio/)

> 注意：华为厂商需要把`agconnect-services.json` 放到${工程根目录}/nativeResources/android/ 目录下

### 开发文档

[个推推送SDK](https://docs.getui.com/getui/start/accessGuide/)
[多厂商接入](https://docs.getui.com/getui/mobile/vendor/vendor_open/)



### 注意事项

在`AndroidManifest.xml`中，必须声明插件`flag`

```xml
		<!-- 标识dcloud -->
		<meta-data android:name="GETUI_PLUGIN_FLAG" android:value="dcloud"/>
```
