# uni-requestMerchantTransfer
### 开发文档
[UTS 语法](https://uniapp.dcloud.net.cn/tutorial/syntax-uts.html)
[UTS API插件](https://uniapp.dcloud.net.cn/plugin/uts-plugin.html)
[UTS uni-app兼容模式组件](https://uniapp.dcloud.net.cn/plugin/uts-component.html)
[UTS 标准模式组件](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-vue-component.html)
[Hello UTS](https://gitcode.net/dcloud/hello-uts)


注意：
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
