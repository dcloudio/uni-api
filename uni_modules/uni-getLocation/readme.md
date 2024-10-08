# uts-location
### 开发文档
[UTS 语法](https://uniapp.dcloud.net.cn/tutorial/syntax-uts.html)
[UTS API插件](https://uniapp.dcloud.net.cn/plugin/uts-plugin.html)
[UTS 组件插件](https://uniapp.dcloud.net.cn/plugin/uts-component.html)
[Hello UTS](https://gitcode.net/dcloud/hello-uts)

Notes:
1. plist 文件中的YourPurposeKey、NSLocationWhenInUseUsageDescription、NSLocationAlwaysUsageDescription、NSLocationAlwaysAndWhenInUseUsageDescription需要按照自己项目需要配置不同的描述
2. NSLocationTemporaryUsageDescriptionDictionary 这个Dictionary是在iOS14.0+上设置高精度必须配置的key，可以添加若干个YourPurposeKey，结合项目需求在不同的高精度权限申请授权的地方配置不同的PurposeKey和描述（和代码中的PurposeKey是一一对应的关系）