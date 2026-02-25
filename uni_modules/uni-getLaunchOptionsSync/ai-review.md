# uni-getLaunchOptionsSync 代码质量分析报告

## 插件功能
获取应用首次启动的参数功能，返回值与 App.onLaunch 的回调参数一致。

## 代码位置
- 主要实现：`utssdk/index.uts`
- 接口定义：`utssdk/interface.uts`

## 发现的问题

### 1. 对象引用安全问题（高优先级）

**位置**：`utssdk/index.uts:15-17`

**问题描述**：
`getLaunchOptionsSync` 函数直接返回 `launchOptions` 对象的引用，而不是返回对象的副本。这会导致调用者可以修改返回的对象，进而影响后续所有调用的结果。

```typescript
export const getLaunchOptionsSync = defineSyncApi<GetLaunchOptionsSync>(
    'getLaunchOptionsSync',
    (): OnLaunchOptions => {
        return launchOptions  // 直接返回引用，存在安全隐患
    },
)
```

**潜在风险**：
- 调用者可以修改返回对象的属性值
- 多次调用可能得到被污染的数据
- 违反了只读数据的预期行为

**修复方案**：
返回对象的深拷贝，确保数据不可变性：

```typescript
export const getLaunchOptionsSync = defineSyncApi<GetLaunchOptionsSync>(
    'getLaunchOptionsSync',
    (): OnLaunchOptions => {
        // 返回深拷贝，防止外部修改
        return {
            path: launchOptions.path,
            appScheme: launchOptions.appScheme,
            appLink: launchOptions.appLink,
            query: launchOptions.query != null ? JSON.parse(JSON.stringify(launchOptions.query)) : null
        } as OnLaunchOptions
    },
)
```

### 2. 初始化数据不完整（中优先级）

**位置**：`utssdk/index.uts:4-7`

**问题描述**：
`launchOptions` 初始化时只设置了 `path` 和 `query` 两个字段，但根据 `interface.uts` 中的类型定义，还应该包含 `appScheme` 和 `appLink` 字段。

```typescript
let launchOptions = {
    path: __uniConfig.entryPagePath,
    query: {} as UTSJSONObject,
} as OnLaunchOptions
```

**潜在风险**：
- 在调用 `setLaunchOptionsSync` 之前调用 `getLaunchOptionsSync` 会返回不完整的数据
- TypeScript 类型断言可能隐藏运行时错误
- 与接口定义不一致

**修复方案**：
完整初始化所有字段：

```typescript
let launchOptions: OnLaunchOptions = {
    path: __uniConfig.entryPagePath,
    query: {} as UTSJSONObject,
    appScheme: null,
    appLink: null
}
```

### 3. 线程安全问题（中优先级）

**位置**：`utssdk/index.uts:4`

**问题描述**：
`launchOptions` 是一个模块级别的可变变量（使用 `let` 声明），在多线程环境下可能存在并发访问问题。虽然 `setLaunchOptionsSync` 通常只在应用启动时调用一次，但从代码设计角度看，缺少并发控制。

**潜在风险**：
- 在某些极端情况下，可能出现竞态条件
- 多线程同时读写可能导致数据不一致

**修复方案**：
考虑以下几种方案：

**方案 1**：使用不可变模式（推荐）
```typescript
let launchOptions: OnLaunchOptions = {
    path: __uniConfig.entryPagePath,
    query: {} as UTSJSONObject,
    appScheme: null,
    appLink: null
}

let isInitialized = false

export const setLaunchOptionsSync = function (options: OnLaunchOptions) {
    if (!isInitialized) {
        launchOptions = options
        isInitialized = true
    } else {
        console.warn('setLaunchOptionsSync should only be called once')
    }
}
```

**方案 2**：使用 Object.freeze（如果平台支持）
```typescript
let launchOptions: OnLaunchOptions = Object.freeze({
    path: __uniConfig.entryPagePath,
    query: {} as UTSJSONObject,
    appScheme: null,
    appLink: null
})

export const setLaunchOptionsSync = function (options: OnLaunchOptions) {
    launchOptions = Object.freeze(options)
}
```

### 4. 性能优化建议（低优先级）

**问题描述**：
每次调用 `getLaunchOptionsSync` 时，如果采用深拷贝方案，会产生新的对象创建开销。虽然这个 API 通常不会被频繁调用，但仍可以优化。

**优化方案**：
使用缓存机制，只在数据变更时重新创建副本：

```typescript
let launchOptions: OnLaunchOptions = {
    path: __uniConfig.entryPagePath,
    query: {} as UTSJSONObject,
    appScheme: null,
    appLink: null
}

let cachedCopy: OnLaunchOptions | null = null

export const setLaunchOptionsSync = function (options: OnLaunchOptions) {
    launchOptions = options
    cachedCopy = null  // 清除缓存，强制重新创建副本
}

export const getLaunchOptionsSync = defineSyncApi<GetLaunchOptionsSync>(
    'getLaunchOptionsSync',
    (): OnLaunchOptions => {
        if (cachedCopy === null) {
            cachedCopy = {
                path: launchOptions.path,
                appScheme: launchOptions.appScheme,
                appLink: launchOptions.appLink,
                query: launchOptions.query != null ? JSON.parse(JSON.stringify(launchOptions.query)) : null
            } as OnLaunchOptions
        }
        return cachedCopy
    },
)
```

### 5. 类型安全改进建议（低优先级）

**位置**：`utssdk/index.uts:7`

**问题描述**：
使用了类型断言 `as OnLaunchOptions`，这可能会绕过类型检查。

**修复方案**：
明确声明变量类型：

```typescript
let launchOptions: OnLaunchOptions = {
    path: __uniConfig.entryPagePath,
    query: {} as UTSJSONObject,
    appScheme: null,
    appLink: null
}
```

## 综合修复方案

综合考虑以上所有问题，推荐的完整修复代码如下：

```typescript
import { __uniConfig } from '@dcloudio/uni-runtime'
import { GetLaunchOptionsSync, OnLaunchOptions } from './interface.uts'

// 使用明确的类型声明，而非类型断言
let launchOptions: OnLaunchOptions = {
    path: __uniConfig.entryPagePath,
    query: {} as UTSJSONObject,
    appScheme: null,
    appLink: null
}

// 标记是否已初始化，防止重复设置
let isInitialized = false

export const setLaunchOptionsSync = function (options: OnLaunchOptions) {
    if (!isInitialized) {
        launchOptions = options
        isInitialized = true
    } else {
        console.warn('setLaunchOptionsSync should only be called once during app launch')
    }
}

export const getLaunchOptionsSync = defineSyncApi<GetLaunchOptionsSync>(
    'getLaunchOptionsSync',
    (): OnLaunchOptions => {
        // 返回深拷贝，防止外部修改原始数据
        return {
            path: launchOptions.path,
            appScheme: launchOptions.appScheme,
            appLink: launchOptions.appLink,
            query: launchOptions.query != null ? JSON.parse(JSON.stringify(launchOptions.query)) : null
        } as OnLaunchOptions
    },
)
```

## 优先级总结

1. **高优先级**：对象引用安全问题 - 必须修复
2. **中优先级**：初始化数据不完整、线程安全问题 - 建议修复
3. **低优先级**：性能优化、类型安全改进 - 可选优化

## 测试建议

修复后应进行以下测试：

1. **数据隔离测试**：
   ```typescript
   const options1 = uni.getLaunchOptionsSync()
   options1.path = 'modified'
   const options2 = uni.getLaunchOptionsSync()
   // options2.path 应该保持原值，不受 options1 修改的影响
   ```

2. **初始化测试**：
   在 `setLaunchOptionsSync` 调用前后分别获取启动参数，验证数据完整性

3. **并发测试**：
   模拟多线程同时调用 `getLaunchOptionsSync`，验证数据一致性

4. **性能测试**：
   测试在频繁调用场景下的性能表现
