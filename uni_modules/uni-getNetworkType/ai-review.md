# uni-getNetworkType 代码质量分析报告

## 插件功能
实现获取网络类型、监听网络状态变化等功能，支持 Android、iOS 和鸿蒙平台。

## 代码位置
- 接口定义：`utssdk/interface.uts`
- Android 实现：`utssdk/app-android/index.uts`
- iOS 实现：`utssdk/app-ios/index.uts`
- 鸿蒙实现：`utssdk/app-harmony/index.uts`

## Android 平台问题分析

### 1. 使用已废弃的 API（高优先级）

**位置**：`utssdk/app-android/index.uts:28`、`175`、`198`、`203`、`211`

**问题描述**：
`ConnectivityManager.getActiveNetworkInfo()` 在 Android 10 (API 29) 中已被废弃，应该使用新的 API。

```typescript
const activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
```

**潜在风险**：
- 在 Android 10+ 设备上可能返回 null
- 未来版本可能完全移除此 API
- 无法准确获取网络状态

**修复方案**：
使用 `getNetworkCapabilities()` 替代：

```typescript
export const getNetworkType : GetNetworkType = function (options : GetNetworkTypeOptions) {
    const context = UTSAndroid.getUniActivity()!!;
    const connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager;

    if (connectivityManager != null) {
        if (Build.VERSION.SDK_INT >= 23) {
            const permissions = ["android.permission.ACCESS_NETWORK_STATE"];
            if (!UTSAndroid.checkSystemPermissionGranted(context, permissions)) {
                const result : GetNetworkTypeSuccess = {
                    networkType: "none"
                }
                options?.success?.(result);
                options?.complete?.(result);
                return
            }
        }

        let networkType = "none"

        // Android M (API 23) 及以上使用新 API
        if (Build.VERSION.SDK_INT >= 23) {
            const network = connectivityManager.getActiveNetwork();
            if (network != null) {
                const capabilities = connectivityManager.getNetworkCapabilities(network);
                if (capabilities != null) {
                    if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                        networkType = "wifi"
                    } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                        // 获取移动网络类型
                        const telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                        if (Build.VERSION.SDK_INT >= 24) {
                            networkType = getRealTypeById(telephonyManager.dataNetworkType)
                        } else {
                            networkType = getRealTypeById(telephonyManager.networkType)
                        }
                    } else {
                        networkType = "unknown"
                    }
                }
            }
        } else {
            // 兼容低版本
            const activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
            networkType = getRealNetworkType(activeNetworkInfo)
        }

        const result : GetNetworkTypeSuccess = {
            networkType: networkType
        }
        options?.success?.(result);
        options?.complete?.(result);
    } else {
        const result : GetNetworkTypeSuccess = {
            networkType: "none"
        }
        options?.success?.(result);
        options?.complete?.(result);
    }
};
```

### 2. UniNetworkCallback 中重复使用废弃 API（高优先级）

**位置**：`utssdk/app-android/index.uts:174-194`

**问题描述**：
在 `getDetailedNetworkType` 方法中仍然使用 `getActiveNetworkInfo()`，应该使用传入的 `Network` 对象获取信息。

```typescript
getDetailedNetworkType(network : Network) : string {
    var activeNetworkInfo = this.manager.getActiveNetworkInfo();  // 废弃 API
    // ...
}
```

**修复方案**：
```typescript
getDetailedNetworkType(network : Network) : string {
    if (Build.VERSION.SDK_INT >= 23) {
        const capabilities = this.manager.getNetworkCapabilities(network);
        if (capabilities != null) {
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                return "wifi"
            } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                var type = 0
                if (Build.VERSION.SDK_INT >= 24) {
                    type = this.telephonyManager.dataNetworkType
                } else {
                    type = this.telephonyManager.networkType
                }
                return getRealTypeById(type)
            } else {
                return "unknown"
            }
        }
    } else {
        // 低版本兼容
        var activeNetworkInfo = this.manager.getActiveNetworkInfo();
        if (activeNetworkInfo != null) {
            if (activeNetworkInfo.getType() == ConnectivityManager.TYPE_WIFI) {
                return "wifi"
            } else if (activeNetworkInfo.getType() == ConnectivityManager.TYPE_MOBILE) {
                var type = 0
                if (Build.VERSION.SDK_INT >= 24) {
                    type = this.telephonyManager.dataNetworkType
                } else {
                    type = this.telephonyManager.networkType
                }
                return getRealTypeById(type)
            }
        }
    }
    return "unknown"
}
```

### 3. 回调注销时可能的并发问题（中优先级）

**位置**：`utssdk/app-android/index.uts:128-147`

**问题描述**：
`offNetworkStatusChange` 在遍历 Map 时可能会修改 Map，导致并发问题。

```typescript
StatusChangeCallbacks.forEach((value : OnNetworkStatusChangeCallback, key : number, map : Map<number, OnNetworkStatusChangeCallback>) => {
    if (listener == value) {
        StatusChangeCallbacks.delete(key)  // 在 forEach 中删除可能有问题
        unregisterNetworkChange()
    }
    return
})
```

**修复方案**：
```typescript
export const offNetworkStatusChange : OffNetworkStatusChange = function (listener ?: number | OnNetworkStatusChangeCallback | null) {
    if (listener == null) {
        StatusChangeCallbacks.clear()
        unregisterNetworkChange()
        return
    } else {
        if (typeof listener == "number") {
            StatusChangeCallbacks.delete(listener)
            unregisterNetworkChange()
        } else if (typeof listener == "function") {
            // 先找到需要删除的 key，然后再删除
            const keysToDelete : number[] = []
            StatusChangeCallbacks.forEach((value : OnNetworkStatusChangeCallback, key : number) => {
                if (listener == value) {
                    keysToDelete.push(key)
                }
            })

            keysToDelete.forEach((key : number) => {
                StatusChangeCallbacks.delete(key)
            })

            if (keysToDelete.length > 0) {
                unregisterNetworkChange()
            }
        }
    }
}
```

### 4. 网络回调触发缺少线程安全保护（中优先级）

**位置**：`utssdk/app-android/index.uts:216-224`

**问题描述**：
`triggerCallback` 方法在遍历回调时没有同步保护，可能在遍历过程中有新的回调被添加或删除。

```typescript
triggerCallback() {
    var callback : OnNetworkStatusChangeCallbackResult = {
        isConnected: this.isConnect,
        networkType: this.networkType
    }
    this.callbacks.forEach((value : OnNetworkStatusChangeCallback) => {
        value(callback)
    })
}
```

**修复方案**：
```typescript
triggerCallback() {
    var callback : OnNetworkStatusChangeCallbackResult = {
        isConnected: this.isConnect,
        networkType: this.networkType
    }

    // 创建回调列表的副本，避免遍历时被修改
    const callbacksCopy : Array<OnNetworkStatusChangeCallback> = []
    this.callbacks.forEach((value : OnNetworkStatusChangeCallback) => {
        callbacksCopy.push(value)
    })

    // 在副本上调用回调
    callbacksCopy.forEach((callback) => {
        try {
            callback(callback)
        } catch (e : Exception) {
            console.error("Network callback error: ", e)
        }
    })
}
```

### 5. 缺少魔法数字的常量定义（低优先级）

**位置**：`utssdk/app-android/index.uts:64-94`

**问题描述**：
使用了大量魔法数字（如 7、12、14、17、18 等）来判断网络类型，缺少说明和常量定义。

```typescript
case 7://电信2g 努比亚
    type = "2g";
    break;
```

**修复方案**：
在文件顶部定义常量：

```typescript
// 网络类型常量定义（针对特定设备的兼容性处理）
const NETWORK_TYPE_EVDO_B = 12  // API Level 9+
const NETWORK_TYPE_EHRPD = 14   // 电信特定类型
const NETWORK_TYPE_HSPAP = 15   // API Level 13+
const NETWORK_TYPE_TD_SCDMA = 17  // 移动3G
const NETWORK_TYPE_IWLAN = 18     // 华为3G

function getRealTypeById(subtype : number) : string {
    let type = "unknown";
    switch (subtype) {
        case TelephonyManager.NETWORK_TYPE_CDMA:
        case TelephonyManager.NETWORK_TYPE_EDGE:
        case TelephonyManager.NETWORK_TYPE_GPRS:
        case 7: // 电信2G 努比亚特定
            type = "2g";
            break;
        case TelephonyManager.NETWORK_TYPE_EVDO_0:
        case TelephonyManager.NETWORK_TYPE_EVDO_A:
        case NETWORK_TYPE_EVDO_B:
        case NETWORK_TYPE_EHRPD:
            type = "3g";
            break;
        // ... 其他case
    }
    return type
}
```

## iOS 平台问题分析

### 1. 5G 网络检测逻辑错误（高优先级）

**位置**：`utssdk/app-ios/index.uts:164`

**问题描述**：
5G 网络检测的逻辑有误，使用了错误的逻辑运算符。

```typescript
if (carrierTypeName != CTRadioAccessTechnologyNRNSA || carrierTypeName != CTRadioAccessTechnologyNR) {
    status = "5g"
}
```

这个条件永远为真，因为 `carrierTypeName` 不可能同时等于两个不同的值。

**修复方案**：
```typescript
if (UTSiOS.available("iOS 14.1, *")) {
    if (carrierTypeName == CTRadioAccessTechnologyNRNSA || carrierTypeName == CTRadioAccessTechnologyNR) {
        status = "5g"
    }
}
```

### 2. 信号量使用不够完善（中优先级）

**位置**：`utssdk/app-ios/index.uts:34-40`

**问题描述**：
虽然使用了信号量保护 `onNetworkStatusChangeIndex` 的递增，但是后续对 `onNetworkStatusChangeCallbacks` 的操作没有保护。

```typescript
export const onNetworkStatusChange : OnNetworkStatusChange = function (listener : OnNetworkStatusChangeCallback) : number {
    semaphore.wait()
    onNetworkStatusChangeIndex++
    semaphore.signal()
    onNetworkStatusChangeCallbacks[onNetworkStatusChangeIndex] = listener  // 这里没有保护
    // ...
}
```

**修复方案**：
```typescript
export const onNetworkStatusChange : OnNetworkStatusChange = function (listener : OnNetworkStatusChangeCallback) : number {
    semaphore.wait()
    onNetworkStatusChangeIndex++
    const currentIndex = onNetworkStatusChangeIndex
    onNetworkStatusChangeCallbacks[currentIndex] = listener
    semaphore.signal()

    // ... 其他代码

    return currentIndex
}
```

### 3. 回调未能及时清理可能导致内存泄漏（中优先级）

**位置**：`utssdk/app-ios/index.uts:90-101`

**问题描述**：
在 `offNetworkStatusChange` 中，只有当传入的 listener 为 null 时才会清空所有回调并停止监听，但如果只删除单个回调，仍然会继续监听网络状态。

```typescript
export const offNetworkStatusChange : OffNetworkStatusChange = function (listener ?: number | OnNetworkStatusChangeCallback | null) {
    if (listener != null && typeof listener! == "number") {
        const id = listener as number
        onNetworkStatusChangeCallbacks.delete(id)
    } else {
        onNetworkStatusChangeCallbacks.clear()
    }
    UniNetWorkManager.shared.stopNetworkTypeMonitoring()  // 总是停止监听
    UniNetWorkManager.shared.stopNetworkPermissionMonitoring()
    UniNetWorkManager.shared.clearNetworkHistory()
    UniNetWorkManager.shared.clearAllCallbacks()
}
```

**修复方案**：
只有在所有回调都被移除后才停止监听：

```typescript
export const offNetworkStatusChange : OffNetworkStatusChange = function (listener ?: number | OnNetworkStatusChangeCallback | null) {
    if (listener != null && typeof listener! == "number") {
        const id = listener as number
        onNetworkStatusChangeCallbacks.delete(id)
    } else {
        onNetworkStatusChangeCallbacks.clear()
    }

    // 只有当所有回调都被移除后才停止监听
    if (onNetworkStatusChangeCallbacks.size == 0) {
        UniNetWorkManager.shared.stopNetworkTypeMonitoring()
        UniNetWorkManager.shared.stopNetworkPermissionMonitoring()
        UniNetWorkManager.shared.clearNetworkHistory()
        UniNetWorkManager.shared.clearAllCallbacks()
    }
}
```

### 4. onNetworkStatusChange 注册时触发所有回调（低优先级）

**位置**：`utssdk/app-ios/index.uts:43-62`

**问题描述**：
在注册新的网络状态监听时，会触发所有已注册的回调。这可能不是预期行为。

```typescript
getNetworkType({
    success: (res : GetNetworkTypeSuccess) => {
        let result : OnNetworkStatusChangeCallbackResult = {
            isConnected: res.networkType != 'none',
            networkType: res.networkType
        }
        onNetworkStatusChangeCallbacks.forEach((value : OnNetworkStatusChangeCallback, key : number) => {
            value(result)  // 触发所有回调，包括刚注册的和之前注册的
        })
    },
    // ...
})
```

**修复方案**：
只触发当前注册的回调：

```typescript
export const onNetworkStatusChange : OnNetworkStatusChange = function (listener : OnNetworkStatusChangeCallback) : number {
    semaphore.wait()
    onNetworkStatusChangeIndex++
    const currentIndex = onNetworkStatusChangeIndex
    onNetworkStatusChangeCallbacks[currentIndex] = listener
    semaphore.signal()

    // 如果是第一个监听器，开始监听
    if (onNetworkStatusChangeCallbacks.size == 1) {
        UniNetWorkManager.shared.startNetworkTypeMonitoring()
        UniNetWorkManager.shared.startNetworkPermissionMonitoring()

        // 设置回调
        UniNetWorkManager.shared.onNetworkPermissionChange((permission : boolean) : void => {
            let res : OnNetworkStatusChangeCallbackResult = {
                isConnected: permission && UniNetWorkManager.shared.isNetworkAvailable,
                networkType: permission ? UniNetWorkManager.shared.currentNetworkType.description() : UniNetConnectionType.unknown.description()
            }
            onNetworkStatusChangeCallbacks.forEach((value : OnNetworkStatusChangeCallback, key : number) => {
                value(res)
            })
        })

        UniNetWorkManager.shared.onNetworkTypeChanged = (oldType : UniNetConnectionType, newType : UniNetConnectionType) => {
            let res : OnNetworkStatusChangeCallbackResult = {
                isConnected: UniNetWorkManager.shared.isNetworkAvailable,
                networkType: newType.description()
            }
            onNetworkStatusChangeCallbacks.forEach((value : OnNetworkStatusChangeCallback, key : number) => {
                value(res)
            })
        }
    }

    // 只给当前注册的监听器发送初始状态
    getNetworkType({
        success: (res : GetNetworkTypeSuccess) => {
            let result : OnNetworkStatusChangeCallbackResult = {
                isConnected: res.networkType != 'none',
                networkType: res.networkType
            }
            listener(result)  // 只触发当前回调
        },
        fail: (err : UniError) => {
            let result : OnNetworkStatusChangeCallbackResult = {
                isConnected: false,
                networkType: 'unknown'
            }
            listener(result)  // 只触发当前回调
        }
    })

    return currentIndex
}
```

### 5. 类型检查可以优化（低优先级）

**位置**：`utssdk/app-ios/index.uts:91`

**问题描述**：
类型检查使用了 `typeof listener! == "number"`，不够直观。

```typescript
if (listener != null && typeof listener! == "number") {
```

**修复方案**：
```typescript
if (typeof listener == "number") {
    const id = listener as number
    onNetworkStatusChangeCallbacks.delete(id)
} else if (listener == null) {
    onNetworkStatusChangeCallbacks.clear()
}
```

## 通用问题

### 1. 缺少错误处理
建议在以下场景添加错误处理：
- 系统服务获取失败
- 权限获取失败
- 网络状态获取异常

### 2. 缺少日志记录
建议添加调试日志，便于问题排查：
- 网络类型变化
- 回调注册/注销
- 错误情况

### 3. 性能优化建议
- 考虑缓存网络类型，避免频繁查询
- 对于 Android，可以优化网络监听的注册时机

## 优先级总结

**高优先级（必须修复）**：
1. Android：使用已废弃的 API（getActiveNetworkInfo）
2. iOS：5G 网络检测逻辑错误

**中优先级（建议修复）**：
1. Android：回调注销时可能的并发问题
2. Android：网络回调触发缺少线程安全保护
3. iOS：信号量使用不够完善
4. iOS：回调未能及时清理可能导致内存泄漏

**低优先级（可选优化）**：
1. Android：缺少魔法数字的常量定义
2. iOS：onNetworkStatusChange 注册时触发所有回调
3. iOS：类型检查优化

## 测试建议

修复后应进行以下测试：

1. **网络类型测试**：
   - WiFi 网络
   - 2G/3G/4G/5G 移动网络
   - 无网络连接

2. **网络切换测试**：
   - WiFi 切换到移动网络
   - 移动网络切换到 WiFi
   - 网络断开和恢复

3. **权限测试**：
   - 拒绝网络权限
   - 授予网络权限后的行为

4. **多监听器测试**：
   - 同时注册多个监听器
   - 部分注销监听器
   - 全部注销监听器

5. **边界情况测试**：
   - 飞行模式切换
   - 系统服务不可用
   - 快速连续调用 API

6. **兼容性测试**：
   - Android 5.0 - Android 14
   - iOS 12.0 - iOS 17
   - 不同设备厂商（华为、小米、OPPO 等）

7. **内存泄漏测试**：
   - 长时间运行监听网络状态
   - 频繁注册和注销监听器
