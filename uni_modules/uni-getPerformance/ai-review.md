# uni-getPerformance 代码质量分析报告

## 插件功能
实现获取应用性能数据的功能，仅 Android 平台支持。

## 代码位置
- 接口定义：`utssdk/interface.uts`
- Android 实现：`utssdk/app-android/index.uts`

## 发现的问题

### 1. 单例模式缺失（高优先级）

**位置**：`utssdk/app-android/index.uts:465-467`

**问题描述**：
`getPerformance` 函数每次调用都会创建一个新的 `PerformanceImpl` 实例，导致：
- 每次调用都创建新的事件监听器
- 性能数据无法共享
- 可能导致内存泄漏

```typescript
export const getPerformance: GetPerformance = function (): Performance {
    return new PerformanceImpl()  // 每次都创建新实例
}
```

**修复方案**：
```typescript
let performanceInstance: PerformanceImpl | null = null

export const getPerformance: GetPerformance = function (): Performance {
    if (performanceInstance == null) {
        performanceInstance = new PerformanceImpl()
    }
    return performanceInstance
}
```

### 2. 可能的内存泄漏（高优先级）

**位置**：`utssdk/app-android/index.uts:410-421`

**问题描述**：
在 `PerformanceImpl` 构造函数中注册了全局事件监听器，但没有提供清理机制。

```typescript
constructor() {
    this._allocate = new PerformanceAllocate(
        this._allEntryList,
        this._observerList,
    )

    onBeforeRoute((type: string) => {
        this._provider.onBefore(type)
    })
    onAfterRoute((type: string) => {
        this._provider.onAfter(type)
        if (type == NAVIGATE_BACK) {
            this.dispatchObserver()
        }
    })
    onPageReady((page: Page) => {
        this.dispatchObserver()
    })
}
```

**潜在风险**：
- 如果创建多个 `PerformanceImpl` 实例，事件监听器会累积
- 即使不再使用，监听器也不会被移除

**修复方案**：
添加销毁方法：

```typescript
private _beforeRouteUnregister: (() => void) | null = null
private _afterRouteUnregister: (() => void) | null = null
private _pageReadyUnregister: (() => void) | null = null

constructor() {
    this._allocate = new PerformanceAllocate(
        this._allEntryList,
        this._observerList,
    )

    this._beforeRouteUnregister = onBeforeRoute((type: string) => {
        this._provider.onBefore(type)
    })
    this._afterRouteUnregister = onAfterRoute((type: string) => {
        this._provider.onAfter(type)
        if (type == NAVIGATE_BACK) {
            this.dispatchObserver()
        }
    })
    this._pageReadyUnregister = onPageReady((page: Page) => {
        this.dispatchObserver()
    })
}

destroy() {
    // 移除事件监听器
    this._beforeRouteUnregister?.()
    this._afterRouteUnregister?.()
    this._pageReadyUnregister?.()

    // 清空 Observer 列表
    this._observerList.forEach(observer => {
        observer.disconnect()
    })
    this._observerList.length = 0

    // 清空数据
    this._allEntryList.clear()
    this._provider.removeAllStatus()
}
```

### 3. 数组操作线程安全问题（中优先级）

**位置**：`utssdk/app-android/index.uts:434-446`

**问题描述**：
`_observerList` 数组在多个地方被访问和修改，缺少并发控制。

```typescript
connect(observer: PerformanceObserverImpl) {
    const index = this._observerList.indexOf(observer)
    if (index < 0) {
        this._observerList.push(observer)
    }
}

disconnect(observer: PerformanceObserverImpl) {
    const index = this._observerList.indexOf(observer)
    if (index >= 0) {
        this._observerList.splice(index, 1)
    }
}
```

同时在 `pushObserverList` 中也会遍历这个数组（第382行）。

**潜在风险**：
- 在遍历过程中如果有 observer 被添加或删除，可能导致错误

**修复方案**：
在遍历时使用数组副本：

```typescript
pushObserverList(status: PerformanceEntryStatus[]) {
    // 创建副本以避免遍历时被修改
    const observersCopy = this._observerList.slice()

    observersCopy.forEach(observer => {
        const entryList = observer.entryList
        entryList.clear()

        status.forEach(entryStatus => {
            const entryData = entryStatus.entryData
            if (observer.entryTypes.includes(entryData.entryType)) {
                entryList.push(entryData)
            }
        })

        observer.dispatchCallback()
    })
}
```

### 4. 队列大小验证缺失（中优先级）

**位置**：`utssdk/app-android/index.uts:171-176`

**问题描述**：
`setBufferSize` 方法没有验证输入参数的有效性。

```typescript
set queueSize(value: number) {
    this._queueSize = value  // 没有验证 value 是否合法
    if (this.length > value) {
        this.dequeue(this.length - value)
    }
}
```

**潜在风险**：
- 负数或零可能导致异常行为
- 过大的值可能导致内存问题

**修复方案**：
```typescript
set queueSize(value: number) {
    // 验证参数有效性
    if (value < 1) {
        console.warn(`Invalid buffer size: ${value}, using minimum value 1`)
        value = 1
    }
    if (value > 1000) {
        console.warn(`Buffer size too large: ${value}, using maximum value 1000`)
        value = 1000
    }

    this._queueSize = value
    if (this.length > value) {
        this.dequeue(this.length - value)
    }
}
```

同时在 `Performance.setBufferSize` 中也应该添加验证：

```typescript
setBufferSize(size: number) {
    if (size < 1) {
        console.warn(`Invalid buffer size: ${size}`)
        return
    }
    this._allEntryList.bufferSize = size
}
```

### 5. null 检查不一致（低优先级）

**位置**：多处

**问题描述**：
代码中有些地方使用了 null 检查，有些地方使用了可选链，不够一致。

例如：
- 第73行：`if (page != null)`
- 第89行：`if (currentPage == null)`
- 第81行：`page.$nativePage!.pageId` （使用了非空断言）

**修复方案**：
统一使用可选链或 null 检查：

```typescript
executeBefore() {
    const page = getCurrentPage()
    if (page != null) {
        this._entryData.referrerPath = page.route
    }
}

executeAfter() {
    const page = getCurrentPage()
    if (page != null && page.$nativePage != null) {
        this._entryData.pageId = parseInt(page.$nativePage.pageId)
        this._entryData.path = page.route
    }
}
```

### 6. 性能优化建议（低优先级）

**位置**：`utssdk/app-android/index.uts:386-391`

**问题描述**：
在 `pushObserverList` 方法中，对每个 entry 都遍历所有 observer，时间复杂度为 O(n*m)。

```typescript
status.forEach(entryStatus => {
    const entryData = entryStatus.entryData
    if (observer.entryTypes.includes(entryData.entryType)) {
        entryList.push(entryData)
    }
})
```

**优化方案**：
可以考虑按 entryType 分组 observer，减少不必要的遍历。不过鉴于 observer 数量通常不多，这个优化可能不是必需的。

### 7. 缺少错误处理（中优先级）

**位置**：多处

**问题描述**：
在调用回调函数时没有错误处理，如果回调抛出异常可能会影响后续处理。

**修复方案**：
```typescript
dispatchCallback() {
    try {
        this._callback?.(this._entryList)
    } catch (e) {
        console.error('Performance observer callback error:', e)
    }
}
```

## 通用问题

### 1. 缺少文档注释
建议为关键类和方法添加文档注释，说明：
- 类的职责和使用场景
- 方法的参数和返回值
- 可能的异常情况

### 2. 缺少单元测试
建议添加单元测试覆盖：
- 队列的边界情况
- Observer 的注册和注销
- 性能数据的收集和分发

## 优先级总结

**高优先级（必须修复）**：
1. 单例模式缺失
2. 可能的内存泄漏

**中优先级（建议修复）**：
1. 数组操作线程安全问题
2. 队列大小验证缺失
3. 缺少错误处理

**低优先级（可选优化）**：
1. null 检查不一致
2. 性能优化建议

## 测试建议

修复后应进行以下测试：

1. **单例测试**：
   - 多次调用 `getPerformance()` 应返回同一实例
   - 验证性能数据在多次调用间共享

2. **内存测试**：
   - 长时间运行应用，监控内存使用
   - 验证不再使用的 observer 能被垃圾回收

3. **并发测试**：
   - 同时注册和注销多个 observer
   - 在回调执行期间注销 observer

4. **边界测试**：
   - 设置极小/极大的缓冲区大小
   - 快速产生大量性能数据

5. **功能测试**：
   - 验证各种路由类型的性能数据收集
   - 验证 observer 的过滤功能
