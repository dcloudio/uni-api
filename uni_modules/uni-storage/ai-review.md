# uni-storage 插件代码评审报告

## 插件概述
- **功能**: 实现本地数据存储功能,提供异步和同步两种API
- **支持平台**: Android、iOS、HarmonyOS
- **实现文件**:
  - Android: `utssdk/app-android/index.uts`
  - iOS: `utssdk/app-ios/index.uts`
  - HarmonyOS: `utssdk/app-harmony/index.uts`
  - 共通工具: `utssdk/uniStorageTool.uts`

---

## 代码质量问题

### 1. 非空断言使用不当
**位置**: Android平台多处

**问题示例** (index.uts:86, 90):
```typescript
let info = DCStorage.getDCStorage(UTSAndroid.getAppContext()!).performGetAllKeys(UTSAndroid.getAppId())
// @ts-expect-error
let keys = UTSArray.fromNative((info.v as ArrayList<String>));
```

**问题描述**:
1. `getAppContext()!` - 使用非空断言,如果返回null会崩溃
2. 强制类型转换`as ArrayList<String>`不安全
3. 使用`@ts-expect-error`忽略类型错误,降低代码安全性

**修复方案**:
```typescript
function includeKey(key: string): boolean {
  const appContext = UTSAndroid.getAppContext()
  if (appContext == null) {
    console.error('[includeKey] AppContext为null')
    return false
  }

  const dcStorage = DCStorage.getDCStorage(appContext)
  if (dcStorage == null) {
    return false
  }

  let info = dcStorage.performGetAllKeys(UTSAndroid.getAppId())
  if (info == null || info.v == null || info.code != DCStorage.SUCCESS) {
    return false
  }

  try {
    let keys = UTSArray.fromNative(info.v as ArrayList<String>)
    return keys.indexOf(key) > -1
  } catch (e) {
    console.error('[includeKey] 转换keys数组失败:', e)
    return false
  }
}
```

### 2. setTimeout(fn, 0)使用不当
**位置**: setStorage和getStorage函数

**Android代码** (index.uts:37-56):
```typescript
export const setStorage: SetStorage = function (options: SetStorageOptions) {
  setTimeout(function () {
    let dcStorage = DCStorage.getDCStorage(UTSAndroid.getAppContext());
    // ... 业务逻辑
  }, 0)
}
```

**问题描述**:
1. 使用`setTimeout(fn, 0)`将操作延迟到下一个事件循环
2. 目的可能是为了异步化,但这不是最佳实践
3. 如果在setTimeout回调执行前上下文变化,可能出现问题
4. 对性能有轻微影响

**修复方案**:
```typescript
// 方案1: 使用Promise
export const setStorage: SetStorage = function (options: SetStorageOptions) {
  Promise.resolve().then(() => {
    let dcStorage = DCStorage.getDCStorage(UTSAndroid.getAppContext());
    // ... 业务逻辑
  })
}

// 方案2: 如果需要真正的异步,使用线程池
export const setStorage: SetStorage = function (options: SetStorageOptions) {
  UTSAndroid.dispatchAsync('io', function() {
    let dcStorage = DCStorage.getDCStorage(UTSAndroid.getAppContext());
    // ... 业务逻辑
  }, null)
}
```

### 3. 错误处理不一致
**位置**: setStorage和getStorage函数

**setStorage** (index.uts:41-44):
```typescript
if (dcStorage == null) {
  let ret = new UniError("uni-setStorage", -1, "storage not found.")
  options.fail?.(ret)
  options.complete?.(ret)
  return
}
```

**getStorage** (index.uts:104):
```typescript
if (dcStorage == null) {
  let ret = new UniError("uni-setStorage", -1, "storage not found.") // 错误:subject应该是"uni-getStorage"
  options.fail?.(ret)
  options.complete?.(ret)
  return
}
```

**问题描述**:
getStorage的错误信息中使用了"uni-setStorage",应该是"uni-getStorage"。这会误导问题排查。

**修复方案**:
```typescript
// 创建错误常量
const ERROR_STORAGE_NOT_FOUND = -1
const ERROR_KEY_NOT_FOUND = -2

function createStorageError(subject: string, code: number, message: string): UniError {
  return new UniError(subject, code, message)
}

export const getStorage: GetStorage = function getStorage(options: GetStorageOptions) {
  let dcStorage = DCStorage.getDCStorage(UTSAndroid.getAppContext());

  if (dcStorage == null) {
    let ret = createStorageError("uni-getStorage", ERROR_STORAGE_NOT_FOUND, "storage not found")
    options.fail?.(ret)
    options.complete?.(ret)
    return
  }
  // ...
}
```

### 4. includeKey函数实现低效
**位置**: Android平台 (index.uts:84-96)

**问题描述**:
```typescript
function includeKey(key: string): boolean {
  let info = DCStorage.getDCStorage(UTSAndroid.getAppContext()!).performGetAllKeys(UTSAndroid.getAppId())
  if (info.v != null && info.code == DCStorage.SUCCESS) {
    let keys = UTSArray.fromNative((info.v as ArrayList<String>));
    if (keys.indexOf(key) > -1) {
      return true
    }
  }
  return false;
}
```

每次调用都获取所有keys,在keys数量多时性能差。更合理的做法是直接尝试读取该key的值。

**修复方案**:
```typescript
// 直接检查key是否存在,而不是获取所有keys
function includeKey(key: string): boolean {
  const appContext = UTSAndroid.getAppContext()
  if (appContext == null) {
    return false
  }

  let dcStorage = DCStorage.getDCStorage(appContext)
  if (dcStorage == null) {
    return false
  }

  // 直接尝试获取该key
  let info = dcStorage.performGetItem(UTSAndroid.getAppId(), key)
  return info != null && info.code == DCStorage.SUCCESS && info.v != null
}
```

### 5. 代码重复 - getStorage中的逻辑
**位置**: Android平台 (index.uts:122-147)

**问题描述**:
```typescript
let list: String[] = []
let info = dcStorage.performGetAllKeys(UTSAndroid.getAppId())
if (info.code == DCStorage.SUCCESS && info.v != null) {
  let arrayKeys: String[] = []
  ;(info.v as List<string>).forEach((perKey: string) => {
    arrayKeys.push(perKey)
  });
  list = arrayKeys
}

if (list != null) {
  let item = list!.find((value): boolean => {
    if (typeof value == "string") {
      return (value as string) == key;
    }
    return false;
  })
  return (item != null);
}
```

这段逻辑与includeKey函数几乎相同,可以直接调用includeKey。

**修复方案**:
```typescript
// 在uni_getStorageAsync的第三个参数中直接使用includeKey
uni_getStorageAsync(options, function (itemKey: string): string | null {
  // ... 获取逻辑
}, includeKey) // 直接使用includeKey函数
```

### 6. 条件编译使用混乱
**位置**: Android平台 (index.uts:14-19)

**问题描述**:
```typescript
// @ts-expect-error
// #ifdef UNI-APP-X
import DCStorage from "io.dcloud.common.unix.util.db.DCStorage";
// #endif
// #ifndef UNI-APP-X
import DCStorage from "io.dcloud.common.util.db.DCStorage";
// #endif
```

同一个符号DCStorage在不同条件下从不同路径导入,但使用`@ts-expect-error`忽略了类型检查。

**修复方案**:
```typescript
// 使用类型声明而不是@ts-expect-error
declare class DCStorage {
  static getDCStorage(context: any): DCStorage | null
  performSetItem(context: any, appId: string, key: string, value: string): void
  performGetItem(appId: string, key: string): any
  // ... 其他方法
}

// #ifdef UNI-APP-X
import DCStorage from "io.dcloud.common.unix.util.db.DCStorage";
// #endif
// #ifndef UNI-APP-X
import DCStorage from "io.dcloud.common.util.db.DCStorage";
// #endif
```

---

## 性能问题

### 1. performGetAllKeys在每次检查key存在时都被调用
**位置**: includeKey函数和getStorage中的key检查

**问题描述**:
- performGetAllKeys可能是一个昂贵的操作,特别是当存储的keys很多时
- 每次调用都遍历所有keys
- 如果用户频繁调用getStorage,性能影响会累积

**影响范围**:
- 当存储项超过100个时,性能下降明显
- 频繁调用getStorage时CPU占用高

**修复方案**:
已在代码质量问题中说明,使用performGetItem直接检查key是否存在。

### 2. setTimeout延迟影响响应速度
**位置**: setStorage和getStorage

**问题描述**:
虽然setTimeout(fn, 0)延迟很小,但仍会影响响应速度:
- 增加事件循环队列长度
- 在高并发场景下累积延迟

**修复方案**:
如前所述,考虑使用Promise或真正的异步线程。

---

## 功能完整性问题

### 1. 缺少存储大小限制
**问题描述**:
代码中没有检查:
- 单个存储项的大小限制
- 总存储空间限制
- 存储key的数量限制

**影响**:
- 恶意代码可能存储大量数据导致应用卡顿
- 用户数据可能占满存储空间

**建议**:
```typescript
const MAX_STORAGE_SIZE = 10 * 1024 * 1024 // 10MB
const MAX_ITEM_SIZE = 2 * 1024 * 1024 // 2MB
const MAX_KEY_COUNT = 1000

function validateStorageSize(newItemSize: number): boolean {
  let info = getStorageInfo()
  if (info.currentSize + newItemSize > MAX_STORAGE_SIZE) {
    return false
  }
  if (info.keys.length >= MAX_KEY_COUNT) {
    return false
  }
  return true
}
```

### 2. 缺少数据加密
**问题描述**:
敏感数据(如token、用户信息)直接以明文存储,存在安全风险。

**建议**:
1. 在文档中说明哪些数据适合存储
2. 建议敏感数据使用加密存储
3. 提供加密存储的示例或工具函数

---

## 总结

### 优先级分类

**高优先级（建议立即修复）**:
1. 修复getStorage中的错误信息(使用了错误的subject)
2. 移除非空断言,添加null检查
3. 优化includeKey实现,避免获取所有keys

**中优先级（建议近期修复）**:
1. 统一错误处理,创建错误常量
2. 重构setTimeout为更合适的异步方案
3. 消除代码重复
4. 添加存储大小限制

**低优先级（可选优化）**:
1. 完善类型声明,移除@ts-expect-error
2. 添加数据加密功能或文档说明
3. 性能监控和优化

### 整体评价
uni-storage插件提供了完整的本地存储功能,代码结构清晰。主要问题:
1. 性能优化空间大,特别是includeKey的实现
2. 错误处理不够严谨,存在拼写错误
3. 缺少存储限制可能导致资源滥用
4. 过度使用非空断言和类型转换降低了代码安全性

建议优先修复错误信息和性能问题,然后完善错误处理和类型安全。
