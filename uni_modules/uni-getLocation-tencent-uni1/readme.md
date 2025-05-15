# uni-getlocation-tencent-uni1 腾讯定位插件使用文档

## Android 平台

1. 申请腾讯地图key

[申请网址](https://lbs.qq.com/mobile/androidMapSDK/developerGuide/getKey)

2. 配置key到插件中

修改项目根目录下 AndroidManifest.xml
`<meta-data android:name="TencentMapSDK" android:value="您申请的Key" />`

3. 制作自定义基座运行后生效

## iOS 平台

1.申请腾讯地图key

[申请网址](https://lbs.qq.com/mobile/androidMapSDK/developerGuide/getKey)

2.配置key到插件中

将申请的key配置到插件目录下 app-ios -> info.plist 中 TencentLBSAPIKey 对应的值

```xml
<key>TencentLBSAPIKey</key>
<string>您申请的Key</string>
```

3.配置访问位置权限描述信息

选中工程中的 manifest.json -> App权限配置 -> iOS隐私信息访问的许可描述，分别配置下列权限描述信息

- NSLocationAlwaysUsageDescription
- NSLocationWhenInUseUsageDescription
- NSLocationAlwaysAndWhenInUseUsageDescription

4.制作自定义基座运行后生效

## 相关开发文档

- [UTS 语法](https://uniapp.dcloud.net.cn/tutorial/syntax-uts.html)
- [UTS 原生插件](https://uniapp.dcloud.net.cn/plugin/uts-plugin.html)
