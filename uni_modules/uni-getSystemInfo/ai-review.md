# uni-getSystemInfo 代码审查报告

## 功能概述
获取系统信息相关功能，支持 Android、iOS、HarmonyOS 三个平台。

## 代码质量和性能问题

### Android 平台 (utssdk/app-android/index.uts)

#### 1. 严重代码重复问题
**位置**: index.uts:67-93 和 index.uts:207-234

**问题描述**:
`getSystemInfoSync` 和 `getWindowInfo` 函数中存在大量重复代码，关于计算 `androidThreeButtonNavigationTranslucent` 和 `safeAreaInsetsBottom` 的逻辑完全相同（约60行代码重复）。

**修复方案**:
```typescript
// 提取公共函数
function getSafeAreaBottomInsets(activity: Activity, navigationMode: string, pixelRatio: number): number {
    let safeAreaInsetsBottom = 0;
    let androidThreeButtonNavigationTranslucent = false;

    const pages = getCurrentPages();
    if (pages.length > 0) {
        const currentPage = pages[pages.length - 1];
        androidThreeButtonNavigationTranslucent = (currentPage.getPageStyle()["androidThreeButtonNavigationTranslucent"] as boolean | null) ?? false;

        // 处理 dialogPages 逻辑...
    }

    if ((androidThreeButtonNavigationTranslucent && navigationMode == "button" || navigationMode == "gesture_indicator")
        && (!DeviceUtil.isInMultiWindowMode(activity) || DeviceUtil.getSplitScreenPosition(activity) != 'top')) {
        safeAreaInsetsBottom = DeviceUtil.getNavigationBarHeight(activity);
    }

    return safeAreaInsetsBottom;
}
```

**影响**: 可维护性差，修改逻辑需要同步两处，容易出错。

---

#### 2. 性能问题 - 重复计算
**位置**: index.uts:40-41, 47

**问题描述**:
```typescript
const devicePixelRatio = DeviceUtil.getScaledDensity(activity);  // 第40行
const pixelRatio = DeviceUtil.getScaledDensity(activity)         // 第47行
```
相同的值被计算了两次，`getScaledDensity` 涉及系统服务调用，有性能开销。

**修复方案**:
```typescript
const pixelRatio = DeviceUtil.getScaledDensity(activity);
const devicePixelRatio = pixelRatio;  // 直接引用
```

---

#### 3. 线程安全和潜在死锁风险
**位置**: index.uts:176-189

**问题描述**:
使用 CountDownLatch 实现线程同步，但如果主线程执行时间过长或出现异常，可能导致死锁。

**修复方案**:
```typescript
// 添加超时机制
if (!Looper.myLooper() == Looper.getMainLooper()) {
    const latch = new CountDownLatch(1);
    new RunnableTask(Looper.getMainLooper(), () => {
        result = runnable();
        latch.countDown();
    }).execute();

    // 添加超时等待，避免永久阻塞
    if (!latch.await(5000, TimeUnit.MILLISECONDS)) {
        // 超时处理
        throw new Exception("获取系统信息超时");
    }
}
```

---

#### 4. 异常处理不当
**位置**: index.uts:171-173, 188

**问题描述**:
```typescript
} catch (e : Exception) {
    return null;
}
// ...
return result!!;  // 强制解包，如果 result 为 null 会崩溃
```

**修复方案**:
```typescript
if (result == null) {
    // 返回默认值或抛出更明确的异常
    throw new Exception("无法获取系统信息");
}
return result;
```

---

#### 5. Activity 获取逻辑冗余
**位置**: index.uts:23-26, 193-196

**问题描述**:
相同的 Activity 获取逻辑重复出现。

**修复方案**:
```typescript
// 提取为工具函数
private function getActivitySafely(): Activity {
    let activity = UTSAndroid.getTopPageActivity();
    if (activity == null) {
        activity = UTSAndroid.getUniActivity()!!
    }
    return activity;
}
```

---

#### 6. 窗口宽度计算可能不准确
**位置**: index.uts:61, 201

**问题描述**:
```typescript
const windowWidth = Math.ceil(UTSAndroid.getUniActivity()!!.findViewById<ViewGroup>(android.R.id.content).width / pixelRatio)
```
使用 `Math.ceil` 向上取整可能导致宽度不准确，应该使用 `Math.round`。

**修复方案**:
```typescript
const windowWidth = Math.round(UTSAndroid.getUniActivity()!!.findViewById<ViewGroup>(android.R.id.content).width / pixelRatio)
```

---

### Android DeviceUtil (utssdk/app-android/device/SystemInfoDeviceUtil.uts)

#### 7. 字符串替换 Bug
**位置**: SystemInfoDeviceUtil.uts:318

**问题描述**:
```typescript
return str!.replace(" ", "").toUpperCase();
```
`replace` 只会替换第一个空格，如果字符串中有多个空格则无法完全删除。

**修复方案**:
```typescript
return str!.replaceAll(" ", "").toUpperCase();
// 或者使用正则
return str!.replace(/ /g, "").toUpperCase();
```

---

#### 8. 反射性能问题
**位置**: SystemInfoDeviceUtil.uts:293-302, 321-334

**问题描述**:
- `isHarmonyOS()` 每次调用都使用反射检查
- `getSystemPropertyValue()` 每次都通过反射访问系统属性

**修复方案**:
```typescript
// 缓存反射结果
private static isHarmonyOSCache: boolean | null = null;

private static isHarmonyOS(): boolean {
    if (DeviceUtil.isHarmonyOSCache != null) {
        return DeviceUtil.isHarmonyOSCache!!;
    }

    try {
        let classType = Class.forName("com.huawei.system.BuildEx");
        let getMethod = classType.getMethod("getOsBrand");
        let value = getMethod.invoke(classType) as string;
        DeviceUtil.isHarmonyOSCache = !TextUtils.isEmpty(value);
        return DeviceUtil.isHarmonyOSCache!!;
    } catch (e : Exception) {
        DeviceUtil.isHarmonyOSCache = false;
        return false;
    }
}

// 对于 getSystemPropertyValue，可以缓存常用的系统属性
private static systemPropertiesCache: Map<string, string | null> = new Map();

private static getSystemPropertyValue(propName: string): string | null {
    if (DeviceUtil.systemPropertiesCache.has(propName)) {
        return DeviceUtil.systemPropertiesCache.get(propName)!!;
    }

    // 原有反射逻辑...

    DeviceUtil.systemPropertiesCache.set(propName, value);
    return value;
}
```

---

#### 9. ROM 版本缓存机制不完善
**位置**: SystemInfoDeviceUtil.uts:24-25, 136-143

**问题描述**:
静态变量 `customOS` 和 `customOSVersion` 缓存后永不更新，但每次调用 `getRomName()` 和 `getRomVersion()` 都会执行 `setCustomInfo()`。

**修复方案**:
```typescript
public static getRomName(): string {
    if (DeviceUtil.customOS == null) {
        DeviceUtil.setCustomInfo(Build.MANUFACTURER);
    }
    return DeviceUtil.customOS ?? "";
}

public static getRomVersion(): string {
    if (DeviceUtil.customOSVersion == null) {
        DeviceUtil.setCustomInfo(Build.MANUFACTURER);
    }
    return DeviceUtil.customOSVersion ?? "";
}
```

---

#### 10. 多窗口模式检测品牌特殊处理
**位置**: SystemInfoDeviceUtil.uts:345-361

**问题描述**:
OPPO 品牌使用特殊逻辑，其他品牌使用标准 API。这种品牌判断不够健壮。

**建议**: 添加更多品牌适配或使用更通用的检测方案。

---

### iOS 平台 (utssdk/app-ios/index.uts)

#### 11. 版本号转换逻辑可优化
**位置**: index.uts:76-86

**问题描述**:
```typescript
const systemInfoConvertVersionCode = function(version: string): number {
    if (version.length > 0){
        const components = version.components(separatedBy= '.')
        var resultString = ""
        for (let i = 0; i < components.length; i++) {
            resultString = (i == 0) ? (resultString + components[i] + '.') : (resultString + components[i])
        }
        return parseFloat(resultString)
    }
    return 0
}
```

**问题**:
1. 只处理前两段版本号（如 3.1.5 变成 3.15），丢失了后续信息
2. 逻辑不够清晰

**修复方案**:
```typescript
const systemInfoConvertVersionCode = function(version: string): number {
    if (version.length == 0) {
        return 0;
    }

    const components = version.components(separatedBy= '.')
    if (components.length == 0) {
        return 0;
    }

    // 取前两段版本号：major.minor
    const major = components[0]
    const minor = components.length > 1 ? components[1] : "0"
    return parseFloat(major + '.' + minor)
}
```

---

#### 12. getWindowInfo 重复调用
**位置**: index.uts:13, 149-151

**问题描述**:
`getSystemInfoSync` 内部调用 `getWindowInfoResult()`，而导出的 `getWindowInfo` 也调用同一函数。如果用户同时调用这两个 API，会重复计算。

**建议**: 考虑添加短期缓存（100-200ms），避免连续调用时的重复计算。

---

### HarmonyOS 平台 (utssdk/app-harmony/index.uts)

#### 13. 设备方向写死
**位置**: index.uts:99

**问题描述**:
```typescript
deviceOrientation: 'portrait', // 暂未找到同步获取方法，可能需要监听窗口变化
```

**建议**:
- 优先级低，但应该在 TODO 列表中跟进
- 可以考虑在插件初始化时监听窗口变化事件并缓存当前方向

---

#### 14. romName 回退值处理
**位置**: index.uts:106

**问题描述**:
```typescript
romName: deviceInfo.distributionOSName || 'HarmonyOS NEXT', // TODO 应为deviceInfo.distributionOSName，但实际上是空字符串，待确认
```

**建议**:
- 与华为确认 API 行为
- 考虑使用更可靠的回退方案

---

## 通用问题

#### 15. 缺少单元测试
所有平台都缺少单元测试，建议为关键函数添加测试用例。

#### 16. 缺少性能测试
系统信息获取是高频调用的 API，建议添加性能基准测试。

#### 17. 文档不完善
- 缺少各字段的详细说明
- 缺少平台差异说明
- 缺少最佳实践指南

---

## 优先级建议

### P0 (必须修复):
1. Android 异常处理不当 (问题4)
2. Android 字符串替换 Bug (问题7)

### P1 (高优先级):
1. Android 代码重复 (问题1)
2. Android 性能问题 - 重复计算 (问题2)
3. Android 反射性能问题 (问题8)
4. Android ROM 版本缓存机制 (问题9)

### P2 (中优先级):
1. Android 线程安全问题 (问题3)
2. Android Activity 获取逻辑 (问题5)
3. Android 窗口宽度计算 (问题6)
4. iOS 版本号转换 (问题11)

### P3 (低优先级):
1. Android 多窗口模式检测 (问题10)
2. iOS getWindowInfo 重复调用 (问题12)
3. HarmonyOS 设备方向 (问题13)
4. HarmonyOS romName (问题14)
5. 缺少测试和文档 (问题15-17)

---

## 总体评价

**代码质量**: ⭐⭐⭐ (3/5)
- Android 平台代码重复严重，需要重构
- iOS 平台相对简洁
- HarmonyOS 平台较为规范

**性能**: ⭐⭐⭐ (3/5)
- 存在多处不必要的重复计算
- 反射调用过多影响性能
- 缺少缓存机制

**健壮性**: ⭐⭐⭐ (3/5)
- 异常处理不够完善
- 线程安全存在隐患
- 部分边界情况未处理

**可维护性**: ⭐⭐ (2/5)
- 代码重复严重降低可维护性
- 缺少注释和文档
- 需要重构提取公共逻辑
