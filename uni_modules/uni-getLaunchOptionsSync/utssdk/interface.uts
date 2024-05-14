export type OnLaunchOptions = {
    path: string
}

export type GetLaunchOptionsSync = () => OnLaunchOptions

export interface Uni {
    /**
     * 获取本次启动时的参数。返回值与App.onLaunch的回调参数一致
     *
     * @tutorial https://doc.dcloud.net.cn/uni-app-x/api/get-launch-options-sync.html
     * @uniPlatform {
     *  "app": {
     *    "android": {
     *      "osVer": "5.0",
     *      "uniVer": "√",
     *      "unixVer": "3.91"
     *    },
     *    "ios": {
     *      "osVer": "12.0",
     *      "uniVer": "√",
     *      "unixVer": "4.11"
     *    }
     *  },
     *  "mp": {
     *    "weixin": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *  },
     *  "web": {
     *    "uniVer": "√",
     *    "unixVer": "4.0"
     *  }
     * }
     */
    getLaunchOptionsSync(): OnLaunchOptions
}
