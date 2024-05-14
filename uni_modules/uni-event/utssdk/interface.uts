type $OnCallback = Function
export type $On = (eventName: string, callback: $OnCallback) => void

type $OnceCallback = Function
export type $Once = (eventName: string, callback: $OnceCallback) => void

type $OffCallback = Function
export type $Off = (eventName: string, callback?: $OffCallback | null) => void

export type $Emit = (eventName: string, args: any | null) => void

export interface Uni {
    /**
     * 监听自定义事件。事件可以由 uni.$emit 触发。回调函数会接收 uni.$emit 传递的参数。
     *
     * @tutorial https://doc.dcloud.net.cn/uni-app-x/api/event-bus.html#on
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
     *    "alipay": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "baidu": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "toutiao": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "lark": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "qq": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "kuaishou": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "jd": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    }
     *  },
     *  "web": {
     *    "uniVer": "√",
     *    "unixVer": "4.0"
     *  }
     * }
     */
    $on(eventName: string, callback: $OnCallback): void
    /**
     * 移除自定义事件监听器。如果提供了事件名和回调，则只移除这个回调的监听器。
     * 4.13+ 开始支持第二个参数为可选，如果仅提供事件名，则移除该事件的所有监听器。
     * @tutorial https://doc.dcloud.net.cn/uni-app-x/api/event-bus.html#off
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
     *    "alipay": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "baidu": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "toutiao": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "lark": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "qq": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "kuaishou": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "jd": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    }
     *  },
     *  "web": {
     *    "uniVer": "√",
     *    "unixVer": "4.0"
     *  }
     * }
     */
    $off(eventName: string, callback?: $OffCallback | null): void
    /**
     * 监听一个自定义事件。事件只触发一次，在第一次触发之后移除事件监听器。
     *
     * @tutorial https://doc.dcloud.net.cn/uni-app-x/api/event-bus.html#once
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
     *    "alipay": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "baidu": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "toutiao": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "lark": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "qq": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "kuaishou": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "jd": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    }
     *  },
     *  "web": {
     *    "uniVer": "√",
     *    "unixVer": "4.0"
     *  }
     * }
     */
    $once(eventName: string, callback: $OnceCallback): void
    /**
     * 触发自定义事件，附加的参数会传递给事件监听器。
     *
     * @tutorial https://doc.dcloud.net.cn/uni-app-x/api/event-bus.html#emit
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
     *    "alipay": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "baidu": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "toutiao": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "lark": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "qq": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "kuaishou": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    },
     *    "jd": {
     *      "hostVer": "√",
     *      "uniVer": "√",
     *      "unixVer": "x"
     *    }
     *  },
     *  "web": {
     *    "uniVer": "√",
     *    "unixVer": "4.0"
     *  }
     * }
     */
    $emit(eventName: string, args: any | null): void
}
