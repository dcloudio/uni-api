## chooseSystemMedia

chooseSystemMedia支持通过系统API选择图片，解决google play新政策要求[移除照片和视频访问权限权限](https://support.google.com/googleplay/android-developer/answer/14115180)。

### 引入插件

```
import {
	chooseSystemMedia
} from "@/uni_modules/uni-chooseSystemImage"
```

### 参数说明
|参数名称		|类型			|描述					|取值																	|默认值		|
|:--			|:--			|:--					|:--																	|:--		|
|count			|number			|最多可以选择的文件个数	|最多支持100个															|			|
|mediaType		|Array<string>	|支持的文件类型			|image:只能选择图片<br/>video:只能选择视频<br/>mix：可以同时选择图片和视频	|['image']	|
|pageOrientation|string			|图片选择的方向			|auto:跟随系统方向<br/>landscape:横向显示<br/>portrait:竖向显示			|portrait	|
|success		|function		|成功回调				|																		|			|
|fail			|function		|失败回调				|																		|			|
|complete		|function		|完成回调				|																		|			|

图片选择成功回调：

|参数名称	|类型			|描述			|
|:--		|:--			|:--			|
|filePaths	| Array<string>	|选择的文件列表	|


图片选择失败回调错误码

|错误码	|描述							|
|:--	|:--							|
|2101001|用户取消						|
|2101002|传入的参数异常					|
|2101005|权限申请失败						|
|2101010|其他异常，如果遇到可以评论反馈	|

### 调用APIK

```javascript
chooseSystemMedia({
	count: 2,
	mediaType: ['image'],
	pageOrientation:"portrait",
	success: (e) => {
		console.log(e.filePaths)
	},
	fail: (e) => {
		console.log(e)
	}
```

## chooseSystemImage

`chooseSystemImage`已废弃，后续不在维护，建议切换成`chooseSystemMedia`

### 引入插件

```
import {
	chooseSystemImage
} from "@/uni_modules/uni-chooseSystemImage"
```

### 调用API

```javascript
chooseSystemImage({
	count: 3,
	success: (e) => {
		console.log(e.filePaths)
	},
	fail: (e) => {
		console.log(e)
	}
})
```

注意：在Android 11及以上的系统中，调用的是系统的照片选择器。低于android 11的系统中会调用系统的文件选择器。

目前android系统的图片选择仅支持选择图片数量，如果需要针对图片压缩，可以使用[uni.compressImage](https://uniapp.dcloud.net.cn/api/media/image.html#compressimage)。

引入当前插件时同时需要将照片和视频权限移除。将下面内容拷贝到项目的manifest.json->Android/iOS权限配置->强制移除的权限。

```xml
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" ></uses-permission>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" ></uses-permission>
```