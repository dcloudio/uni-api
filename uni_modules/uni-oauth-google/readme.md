# uni-oauth-google

## 使用说明

#### 创建 google cloud 应用

在[google云管理后台](https://console.cloud.google.com/)，创建新的应用，并创建`OAuth 客户端 ID`,重点确保填写正确的包名和证书签名

#### 配置资源文件

在 res/values/strings.xml 中添加你的客户端 ID：

```xml
<string name="default_web_client_id">YOUR_WEB_CLIENT_ID.apps.googleusercontent.com</string>
```

#### 调用代码

以正确的包名和证书自定义基座后，可以使用下面的代码进行调用

uvue:

```vue
<template>
	<view>
		<button @tap="loginClick" >google登录</button>
		<button @tap="logoutClick" >google登出</button>
	</view>
</template>

<script>
	import { googleLogin, GoogleLoginOptions } from "@/uni_modules/uni-oauth-google"
	import { googleLogout, GoogleLogoutOptions } from "@/uni_modules/uni-oauth-google"

	export default {
		data() {
			return {
			}
		},
		methods: {
			loginClick:()=>{
				console.log("loginClick")
				let options = {
					success: (res : any) => {
					  console.log("success",res)
					},
					fail: (res : any) => {
					  console.log("fail",res)
					},
					complete: (res : any) => {
						console.log("complete",res)
					}
				} as GoogleLoginOptions;
				googleLogin(options);
			},
			logoutClick:()=>{
				console.log("logoutClick")
				let options = {
				  success: (res : any) => {
				    console.log("success",res)
				  },
				  fail: (res : any) => {
				    console.log("fail",res)
				  },
				  complete: (res : any|null) => {
				  	console.log("complete",res)
				  }
				} as GoogleLogoutOptions;
				try{
					googleLogout(options);
				}catch(e:Exception){
					console.log(e)
				}

			},
		}
	}
</script>

<style>

</style>

```

vue:

```vue
<template>
	<view>
		<button @tap="loginClick" >google登录</button>
		<button @tap="logoutClick" >google登出</button>
	</view>
</template>

<script>
	import { googleLogin } from "@/uni_modules/uni-oauth-google"
	import { googleLogout } from "@/uni_modules/uni-oauth-google"


	export default {
		data() {
			return {
			}
		},
		methods: {
			loginClick:()=>{
				let options = {
					success: (res) => {
					  console.log("success",res)
					},
					fail: (res) => {
					  console.log("fail",res)
					},
					complete: (res) => {
						console.log("complete",res)
					}
				}
				googleLogin(options);
			},
			logoutClick:()=>{
				let options = {
				  success: () => {
				    console.log("success")
				  },
				  fail: (res) => {
				    console.log("fail",res)
				  },
				  complete: (res) => {
				  	console.log("complete",res)
				  }
				}
				googleLogout(options);
			},
		}
	}
</script>

<style>

</style>

```
