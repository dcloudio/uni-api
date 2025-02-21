# uni-requestMerchantTransfer
### 开发文档
[UTS 语法](https://uniapp.dcloud.net.cn/tutorial/syntax-uts.html)
[UTS API插件](https://uniapp.dcloud.net.cn/plugin/uts-plugin.html)
[UTS uni-app兼容模式组件](https://uniapp.dcloud.net.cn/plugin/uts-component.html)
[UTS 标准模式组件](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-vue-component.html)
[Hello UTS](https://gitcode.net/dcloud/hello-uts)


API：uni.requestMerchantTransfer(options: RequestMerchantTransferOption)

功能描述：商家转账用户确认模式下，在移动端应用APP中集成开放SDK调起微信请求用户确认收款。

# RequestMerchantTransferOption参数介绍：

| 名称      | 类型     | 必备 | 描述                                                         |
|-----------|:---------:|:---------:|--------------------------------------------------------------|
| mchId     | string   | 是   | 商户号                                                       |
| subMchId  | string   | 否   | 子商户号，服务商模式下必填                                   |
| package   | string   | 是   | 商家转账付款单跳转收款页 pkg 信息,商家转账付款单受理成功时返回给商户 |
| appId     | string   | 否   | 商户 appId（微信平台appid），普通模式下必填，服务商模式下，appId 和 subAppId 二选一填写 |
| subAppId  | string   | 否   | 子商户 appId（微信平台子appid)，服务商模式下，appId 和 subAppId 二选一填写      |
| openId    | string   | 否   | 收款用户 openId， 对应传入的商户 appId 下，某用户的 openId    |
| success   | function | 否   | 接口调用成功的回调函数                                        |
| fail      | function | 否   | 接口调用失败的回调函数                                        |
| complete  | function | 否   | 接口调用结束的回调函数（调用成功、失败都会执行）              |

# 使用示例：
对应参考：[微信小程序API规范](https://developers.weixin.qq.com/miniprogram/dev/api/payment/wx.requestMerchantTransfer.html)
```javascript
uni.requestMerchantTransfer({
	"mchId": "mchId",
	"appId": "微信开发者平台对应app的APPID",
	"package": "package",
	success: (res) => {
		console.log(res)
	},
	fail: (res) => {
		console.log(res.errMsg)
	},
	complete: (res) => {
		console.log(res.errMsg)
	}
})
```

# iOS注意：在提交云端打包之前必须配置对应的Info.plist文件
1. 需要在项目根目录下添加 Info.plist 文件 (https://uniapp.dcloud.net.cn/tutorial/app-nativeresource-ios.html#infoplist)
2. plist中添加 uni-requestMerchantTransfer 插件需要的key：（如下）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>WeChat</key>
		<dict>
			<key>appid</key>
			<string>请填写微信开发者平台对应app的APPID</string>
			<key>universalLink</key>
			<string>请填写能唤起当前应用的Universal Links路径</string>
		</dict>

		<key>LSApplicationQueriesSchemes</key>
		<array>
			<string>weixin</string>
			<string>weixinULAPI</string>
			<string>weixinURLParamsAPI</string>
		</array>

		<key>CFBundleURLTypes</key>
		<array>
			<dict>
				<key>CFBundleTypeRole</key>
				<string>Editor</string>
				<key>CFBundleURLName</key>
				<string>WeChat</string>
				<key>CFBundleURLSchemes</key>
				<array>
					<string>请填写微信开发者平台对应app的APPID</string>
				</array>
			</dict>
		</array>
	</dict>
</plist>
```
