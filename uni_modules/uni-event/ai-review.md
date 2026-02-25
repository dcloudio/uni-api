# uni-event 插件代码质量与性能分析报告

## 概述
本报告对 uni-event 插件的代码进行了全面的质量和性能分析,涵盖了接口定义、协议定义、Android平台实现和Harmony平台实现四个主要文件。该插件实现了uni-app的事件总线机制,提供了$on、$off、$once、$emit四个核心API。

---

## 一、严重问题(高优先级)

### 1.1 潜在的内存泄漏 - emitterStore清理时机不明确

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 25-39
**严重程度**: 高

**问题描述**:
在Harmony平台实现中,使用Map存储多个小程序实例的Emitter对象。虽然在`beforeClose`事件中注册了清理逻辑,但如果`beforeClose`事件没有正常触发(如应用崩溃、强制关闭),会导致emitterStore中的Emitter实例无法被释放,造成内存泄漏。此外,每个Emitter内部可能持有大量的事件监听器引用,如果这些监听器没有被正确清理,也会导致严重的内存泄漏。

**当前代码**:
```typescript
const emitterStore = new Map<string, IUniEventEmitter>()

function getEmitter(): IUniEventEmitter {
    const mp = getCurrentMP()
    const id = mp.appId as string
    if (emitterStore.has(id)) {
        return emitterStore.get(id) as IUniEventEmitter
    }
    const emitter = new Emitter() as IUniEventEmitter
    emitterStore.set(id, emitter)
    mp.on('beforeClose', () => {
        emitterStore.delete(id)
    })
    return emitter
}
```

**修复建议**:
1. 在删除emitterStore条目之前,先清理Emitter内部的所有事件监听器
2. 添加弱引用或超时清理机制作为兜底方案
3. 考虑使用WeakMap替代Map,允许垃圾回收器自动清理未使用的实例

**优化后的代码**:
```typescript
const emitterStore = new Map<string, IUniEventEmitter>()
const emitterTimestamps = new Map<string, number>()
const EMITTER_TIMEOUT = 30 * 60 * 1000 // 30分钟超时

function cleanupEmitter(id: string): void {
    const emitter = emitterStore.get(id)
    if (emitter != null) {
        // 清理所有事件监听器(需要Emitter提供clear方法)
        // emitter.clear()
        emitterStore.delete(id)
        emitterTimestamps.delete(id)
    }
}

function cleanupStaleEmitters(): void {
    const now = Date.now()
    emitterTimestamps.forEach((timestamp, id) => {
        if (now - timestamp > EMITTER_TIMEOUT) {
            cleanupEmitter(id)
        }
    })
}

function getEmitter(): IUniEventEmitter {
    // 定期清理过期的emitter
    cleanupStaleEmitters()

    const mp = getCurrentMP()
    const id = mp.appId as string

    if (emitterStore.has(id)) {
        emitterTimestamps.set(id, Date.now())
        return emitterStore.get(id) as IUniEventEmitter
    }

    const emitter = new Emitter() as IUniEventEmitter
    emitterStore.set(id, emitter)
    emitterTimestamps.set(id, Date.now())

    mp.on('beforeClose', () => {
        cleanupEmitter(id)
    })

    return emitter
}
```

---

### 1.2 类型转换缺乏安全检查

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 28-31, 33
**严重程度**: 高

**问题描述**:
多处使用了强制类型断言(如`as string`、`as IUniEventEmitter`),没有进行null检查或类型验证。如果`getCurrentMP()`返回null,或者`mp.appId`为undefined,会导致程序崩溃。同样,`emitterStore.get(id)`可能返回undefined,强制转换为IUniEventEmitter可能导致运行时错误。

**当前代码**:
```typescript
function getEmitter(): IUniEventEmitter {
    const mp = getCurrentMP()
    const id = mp.appId as string
    if (emitterStore.has(id)) {
        return emitterStore.get(id) as IUniEventEmitter
    }
    const emitter = new Emitter() as IUniEventEmitter
    // ...
}
```

**修复建议**:
添加完善的null检查和类型验证,使用安全的类型转换。

**优化后的代码**:
```typescript
function getEmitter(): IUniEventEmitter {
    const mp = getCurrentMP()
    if (mp == null || mp.appId == null) {
        throw new Error('getEmitter: getCurrentMP returned null or appId is null')
    }

    const id = mp.appId as string
    if (typeof id !== 'string' || id.length === 0) {
        throw new Error('getEmitter: invalid appId')
    }

    if (emitterStore.has(id)) {
        const emitter = emitterStore.get(id)
        if (emitter == null) {
            throw new Error('getEmitter: emitterStore returned null for existing id')
        }
        return emitter
    }

    const emitter = new Emitter() as IUniEventEmitter
    if (emitter == null) {
        throw new Error('getEmitter: failed to create Emitter instance')
    }

    emitterStore.set(id, emitter)
    mp.on('beforeClose', () => {
        cleanupEmitter(id)
    })

    return emitter
}
```

---

### 1.3 事件监听器注册失败时无错误处理

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 35-37
**严重程度**: 高

**问题描述**:
在`getEmitter`函数中,调用`mp.on('beforeClose', callback)`注册清理监听器,但没有检查注册是否成功。如果`mp.on`方法不存在或注册失败,会导致资源无法正常清理,但程序不会报错,使问题难以发现。

**当前代码**:
```typescript
mp.on('beforeClose', () => {
    emitterStore.delete(id)
})
```

**修复建议**:
添加异常处理和日志记录,确保监听器注册成功。

**优化后的代码**:
```typescript
try {
    if (typeof mp.on === 'function') {
        mp.on('beforeClose', () => {
            cleanupEmitter(id)
        })
    } else {
        console.warn('getEmitter: mp.on is not a function, cleanup may not work properly')
    }
} catch (error) {
    console.error('getEmitter: failed to register beforeClose listener', error)
}
```

---

### 1.4 并发安全问题 - 无同步机制

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 27-39
**严重程度**: 高

**问题描述**:
`getEmitter`函数中对`emitterStore`的读写操作没有同步机制保护。在多线程环境下,如果多个线程同时调用`getEmitter`,可能导致竞态条件:
1. 两个线程同时检查`emitterStore.has(id)`都返回false
2. 两个线程都创建新的Emitter实例
3. 两个线程都调用`emitterStore.set(id, emitter)`,导致一个实例被覆盖
4. 被覆盖的实例无法被清理,造成内存泄漏

**当前代码**:
```typescript
function getEmitter(): IUniEventEmitter {
    const mp = getCurrentMP()
    const id = mp.appId as string
    if (emitterStore.has(id)) {
        return emitterStore.get(id) as IUniEventEmitter
    }
    const emitter = new Emitter() as IUniEventEmitter
    emitterStore.set(id, emitter)
    // ...
}
```

**修复建议**:
使用同步机制(如锁或原子操作)保护对共享资源的访问。

**优化后的代码**:
```typescript
// 在文件顶部添加锁机制
const emitterLock = new Map<string, boolean>()

function acquireLock(id: string): void {
    while (emitterLock.get(id) === true) {
        // 等待锁释放
    }
    emitterLock.set(id, true)
}

function releaseLock(id: string): void {
    emitterLock.set(id, false)
}

function getEmitter(): IUniEventEmitter {
    const mp = getCurrentMP()
    if (mp == null || mp.appId == null) {
        throw new Error('getEmitter: getCurrentMP returned null or appId is null')
    }

    const id = mp.appId as string

    // 获取锁
    acquireLock(id)

    try {
        if (emitterStore.has(id)) {
            const emitter = emitterStore.get(id)
            if (emitter == null) {
                throw new Error('getEmitter: emitterStore returned null for existing id')
            }
            return emitter
        }

        const emitter = new Emitter() as IUniEventEmitter
        emitterStore.set(id, emitter)
        emitterTimestamps.set(id, Date.now())

        try {
            if (typeof mp.on === 'function') {
                mp.on('beforeClose', () => {
                    cleanupEmitter(id)
                })
            }
        } catch (error) {
            console.error('getEmitter: failed to register beforeClose listener', error)
        }

        return emitter
    } finally {
        // 释放锁
        releaseLock(id)
    }
}

// 注意: UTS可能不支持上述的同步机制,实际实现需要根据平台特性调整
// 可以考虑使用UTS提供的线程安全API或在主线程中执行
```

---

## 二、中等问题(中优先级)

### 2.1 参数类型不一致

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 55-60
**严重程度**: 中

**问题描述**:
在`$off`函数的实现中,参数类型定义为`callback: Function`,但interface定义为`callback?: Function | null`,存在类型不匹配。这可能导致当传入null或undefined时,函数行为不符合预期。

**当前代码**:
```typescript
// interface定义
interface IUniEventEmitter {
    off: (eventName: string, callback?: Function | null) => void
}

// 实现
export const $off: $Off = defineSyncApi<void>(
    API_$_OFF,
    (eventName: string, callback: Function) => {
        getEmitter().off(eventName, callback)
    }
) as $Off
```

**修复建议**:
保持参数类型与interface定义一致。

**优化后的代码**:
```typescript
export const $off: $Off = defineSyncApi<void>(
    API_$_OFF,
    (eventName: string, callback?: Function | null) => {
        getEmitter().off(eventName, callback)
    }
) as $Off
```

---

### 2.2 缺少参数验证

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-android\index.uts`
**行号**: 6-21
**严重程度**: 中

**问题描述**:
所有API函数($on、$off、$once、$emit)都没有对输入参数进行验证,如eventName是否为空字符串、callback是否为有效函数等。这可能导致:
1. eventName为空字符串时,所有事件都绑定到同一个key
2. callback不是函数时,触发事件会报错
3. args参数包含不支持的类型时,可能导致序列化错误

**当前代码**:
```typescript
export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    // TODO EventStopHandler
    return emitter.on(eventName, callback)
})
```

**修复建议**:
添加输入参数验证,提供有意义的错误提示。

**优化后的代码**:
```typescript
export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    // 参数验证
    if (typeof eventName !== 'string' || eventName.length === 0) {
        console.error('$on: eventName must be a non-empty string')
        return -1
    }

    if (typeof callback !== 'function') {
        console.error('$on: callback must be a function')
        return -1
    }

    // TODO EventStopHandler
    return emitter.on(eventName, callback)
})

export const $off = defineSyncApi<$Off>('$off', (eventName, callback) => {
    if (typeof eventName !== 'string' || eventName.length === 0) {
        console.error('$off: eventName must be a non-empty string')
        return
    }

    if (callback !== null && callback !== undefined && typeof callback !== 'function' && typeof callback !== 'number') {
        console.error('$off: callback must be a function, number, null or undefined')
        return
    }

    emitter.off(eventName, callback)
})

export const $once = defineSyncApi<$Once>('$once', (eventName, callback): number => {
    if (typeof eventName !== 'string' || eventName.length === 0) {
        console.error('$once: eventName must be a non-empty string')
        return -1
    }

    if (typeof callback !== 'function') {
        console.error('$once: callback must be a function')
        return -1
    }

    return emitter.once(eventName, callback)
})

export function $emit(eventName: string, ...args: Array<any | null>): void {
    if (typeof eventName !== 'string' || eventName.length === 0) {
        console.error('$emit: eventName must be a non-empty string')
        return
    }

    emitter.emit(eventName, ...args)
}
```

---

### 2.3 返回值类型不一致

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 41-46
**严重程度**: 中

**问题描述**:
`$on`和`$once`函数的返回值类型在interface中定义为number,但`getEmitter().on()`和`getEmitter().once()`的返回值类型不明确。如果底层Emitter的on/once方法返回void或其他类型,会导致类型不匹配。

**当前代码**:
```typescript
// interface定义
interface IUniEventEmitter {
    on: (eventName: string, callback: Function) => void
}

// 使用
export const $on: $On = defineSyncApi<number>(
    API_$_ON,
    (eventName: string, callback: Function) => {
        return getEmitter().on(eventName, callback) // on返回void,但期望返回number
    }
) as $On
```

**修复建议**:
修改IUniEventEmitter接口,使返回值类型与API定义一致。

**优化后的代码**:
```typescript
interface IUniEventEmitter {
    on: (eventName: string, callback: Function) => number
    once: (eventName: string, callback: Function) => number
    off: (eventName: string, callback?: Function | null) => void
    emit: (eventName: string, ...args: (Object | undefined | null)[]) => void
}
```

---

### 2.4 缺少错误边界处理

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-android\index.uts`
**行号**: 19-21
**严重程度**: 中

**问题描述**:
`$emit`函数在调用`emitter.emit`时,如果事件监听器内部抛出异常,可能导致整个事件分发链中断,后续监听器无法执行。

**当前代码**:
```typescript
export function $emit(eventName: string, ...args: Array<any | null>): void {
    emitter.emit(eventName, ...args)
}
```

**修复建议**:
添加异常处理,确保单个监听器的异常不会影响其他监听器。(注意:这个优化可能需要在Emitter内部实现)

**优化后的代码**:
```typescript
export function $emit(eventName: string, ...args: Array<any | null>): void {
    try {
        emitter.emit(eventName, ...args)
    } catch (error) {
        console.error(`$emit: error occurred while emitting event "${eventName}"`, error)
    }
}

// 更好的方式是在Emitter内部处理,确保每个listener都被try-catch包裹
```

---

### 2.5 性能问题 - 频繁的Map操作

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 27-39
**严重程度**: 中

**问题描述**:
每次调用`$on`、`$off`、`$once`、`$emit`时都会调用`getEmitter()`,进而访问Map进行查找。在高频事件场景下,这会带来不必要的性能开销。

**当前代码**:
```typescript
export const $on: $On = defineSyncApi<number>(
    API_$_ON,
    (eventName: string, callback: Function) => {
        return getEmitter().on(eventName, callback) // 每次都查找Map
    }
) as $On
```

**修复建议**:
考虑缓存当前小程序的Emitter实例,减少Map查找次数。

**优化后的代码**:
```typescript
let cachedEmitter: IUniEventEmitter | null = null
let cachedAppId: string | null = null

function getEmitter(): IUniEventEmitter {
    const mp = getCurrentMP()
    if (mp == null || mp.appId == null) {
        throw new Error('getEmitter: getCurrentMP returned null or appId is null')
    }

    const id = mp.appId as string

    // 使用缓存
    if (cachedAppId === id && cachedEmitter != null) {
        emitterTimestamps.set(id, Date.now())
        return cachedEmitter
    }

    if (emitterStore.has(id)) {
        const emitter = emitterStore.get(id)
        if (emitter == null) {
            throw new Error('getEmitter: emitterStore returned null for existing id')
        }
        cachedAppId = id
        cachedEmitter = emitter
        emitterTimestamps.set(id, Date.now())
        return emitter
    }

    const emitter = new Emitter() as IUniEventEmitter
    emitterStore.set(id, emitter)
    emitterTimestamps.set(id, Date.now())
    cachedAppId = id
    cachedEmitter = emitter

    try {
        if (typeof mp.on === 'function') {
            mp.on('beforeClose', () => {
                cleanupEmitter(id)
                if (cachedAppId === id) {
                    cachedAppId = null
                    cachedEmitter = null
                }
            })
        }
    } catch (error) {
        console.error('getEmitter: failed to register beforeClose listener', error)
    }

    return emitter
}
```

---

## 三、轻微问题(低优先级)

### 3.1 TODO注释未实现

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-android\index.uts`
**行号**: 7
**严重程度**: 低

**问题描述**:
代码中存在TODO注释"TODO EventStopHandler",但没有说明具体需要实现什么功能,也没有跟踪issue或计划。

**当前代码**:
```typescript
export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    // TODO EventStopHandler
    return emitter.on(eventName, callback)
})
```

**修复建议**:
要么实现该功能,要么添加详细的注释说明为什么需要这个功能以及计划何时实现。

**优化后的代码**:
```typescript
export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    // TODO: EventStopHandler - 添加事件停止传播机制
    // 允许监听器通过返回false或调用stopPropagation()来阻止后续监听器执行
    // 计划在版本4.40中实现
    // 相关issue: #XXXX
    return emitter.on(eventName, callback)
})
```

---

### 3.2 缺少JSDoc注释

**文件位置**: 所有实现文件
**严重程度**: 低

**问题描述**:
所有函数都缺少JSDoc注释,虽然interface.uts中有详细的文档,但实现文件中没有说明具体的实现细节、边界情况处理等。

**修复建议**:
为关键函数添加JSDoc注释,说明实现细节。

**优化示例**:
```typescript
/**
 * 获取当前小程序实例的Emitter对象
 * @description
 * - 首次调用时创建新的Emitter实例并缓存
 * - 后续调用返回缓存的实例
 * - 在小程序关闭时自动清理
 * @returns IUniEventEmitter 事件发射器实例
 * @throws Error 当getCurrentMP()返回null时抛出异常
 */
function getEmitter(): IUniEventEmitter {
    // ...
}

/**
 * 监听自定义事件
 * @param eventName 事件名称,不能为空字符串
 * @param callback 事件回调函数
 * @returns 事件监听器ID,用于后续的off操作
 */
export const $on: $On = defineSyncApi<number>(
    API_$_ON,
    (eventName: string, callback: Function) => {
        return getEmitter().on(eventName, callback)
    }
) as $On
```

---

### 3.3 类型定义可以更精确

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\interface.uts`
**行号**: 1, 4, 7
**严重程度**: 低

**问题描述**:
`$OnCallback`、`$OnceCallback`定义为`Function`类型过于宽泛,应该定义更具体的函数签名。`$Off`的callback参数类型为`any | null`,也不够精确。

**当前代码**:
```typescript
type $OnCallback = Function
export type $On = (eventName: string, callback: $OnCallback) => number

type $OnceCallback = Function
export type $Once = (eventName: string, callback: $OnceCallback) => number

export type $Off = (eventName: string, callback?: any | null) => void
```

**修复建议**:
使用更精确的类型定义。

**优化后的代码**:
```typescript
// 定义事件回调的通用类型
type EventCallback = (...args: any[]) => void | boolean

type $OnCallback = EventCallback
export type $On = (eventName: string, callback: $OnCallback) => number

type $OnceCallback = EventCallback
export type $Once = (eventName: string, callback: $OnceCallback) => number

// callback可以是函数、监听器ID(number)或null
export type $Off = (eventName: string, callback?: EventCallback | number | null) => void
```

---

### 3.4 魔法值 - 事件监听器ID初始值

**文件位置**: 所有实现文件
**严重程度**: 低

**问题描述**:
虽然代码中返回了监听器ID,但没有明确说明ID的生成规则、范围、是否会重复等。如果返回-1表示失败,应该定义为常量。

**修复建议**:
定义常量表示特殊的返回值。

**优化后的代码**:
```typescript
// 在protocol.uts中添加常量定义
export const LISTENER_ID_INVALID = -1
export const LISTENER_ID_MIN = 0

// 在实现中使用
export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    if (typeof eventName !== 'string' || eventName.length === 0) {
        console.error('$on: eventName must be a non-empty string')
        return LISTENER_ID_INVALID
    }

    if (typeof callback !== 'function') {
        console.error('$on: callback must be a function')
        return LISTENER_ID_INVALID
    }

    return emitter.on(eventName, callback)
})
```

---

### 3.5 代码重复

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 41-67
**严重程度**: 低

**问题描述**:
四个导出函数($on、$once、$off、$emit)都使用了相同的模式调用`getEmitter()`,可以考虑提取公共逻辑减少重复代码。

**当前代码**:
```typescript
export const $on: $On = defineSyncApi<number>(
    API_$_ON,
    (eventName: string, callback: Function) => {
        return getEmitter().on(eventName, callback)
    }
) as $On

export const $once: $Once = defineSyncApi<number>(
    API_$_ONCE,
    (eventName: string, callback: Function) => {
        return getEmitter().once(eventName, callback)
    }
) as $Once
// ...
```

**修复建议**:
虽然可以提取公共逻辑,但考虑到代码简洁性和可读性,当前实现已经足够清晰,不需要过度优化。如果确实需要添加更多公共逻辑(如参数验证、日志记录),可以考虑提取辅助函数。

**优化后的代码**:
```typescript
// 如果需要添加公共逻辑,可以这样实现
function validateEventName(apiName: string, eventName: string): boolean {
    if (typeof eventName !== 'string' || eventName.length === 0) {
        console.error(`${apiName}: eventName must be a non-empty string`)
        return false
    }
    return true
}

function validateCallback(apiName: string, callback: any): boolean {
    if (typeof callback !== 'function') {
        console.error(`${apiName}: callback must be a function`)
        return false
    }
    return true
}

export const $on: $On = defineSyncApi<number>(
    API_$_ON,
    (eventName: string, callback: Function) => {
        if (!validateEventName(API_$_ON, eventName) || !validateCallback(API_$_ON, callback)) {
            return LISTENER_ID_INVALID
        }
        return getEmitter().on(eventName, callback)
    }
) as $On
```

---

### 3.6 接口与实现的类型不匹配

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**行号**: 18-23, 62-67
**严重程度**: 低

**问题描述**:
`IUniEventEmitter`接口的`emit`方法参数类型为`(Object | undefined | null)[]`,而`$Emit`类型定义的参数为`Array<any | null>`,存在细微差异。虽然实际使用中可能不会有问题,但类型定义应该保持一致。

**当前代码**:
```typescript
interface IUniEventEmitter {
    emit: (eventName: string, ...args: (Object | undefined | null)[]) => void
}

export const $emit: $Emit = defineSyncApi<void>(
    API_$_EMIT,
    (eventName: string, ...args: (Object | undefined | null)[]) => {
        getEmitter().emit(eventName, ...args)
    }
) as $Emit
```

**修复建议**:
统一参数类型定义。

**优化后的代码**:
```typescript
// 在interface.uts中添加类型别名
export type EventArgs = Array<any | null>

// 更新接口定义
interface IUniEventEmitter {
    on: (eventName: string, callback: Function) => number
    once: (eventName: string, callback: Function) => number
    off: (eventName: string, callback?: Function | null) => void
    emit: (eventName: string, ...args: any[]) => void
}

// 更新$Emit类型
export type $Emit = (eventName: string, ...args: any[]) => void
```

---

## 四、平台差异问题

### 4.1 iOS平台实现缺失

**文件位置**: `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-ios\index.uts`
**严重程度**: 高

**问题描述**:
iOS平台的实现文件为空(0字节),这意味着iOS平台可能使用了默认实现或者依赖于运行时提供的实现。如果是后者,应该添加注释说明;如果是前者,应该提供完整的实现。

**修复建议**:
1. 如果iOS使用与Android相同的实现,应该从app-android目录导出
2. 如果iOS有特殊实现,应该补充完整代码
3. 如果iOS依赖运行时,应该添加注释说明

**建议的代码**:
```typescript
// 选项1: 如果与Android实现相同
export * from '../app-android/index.uts'

// 选项2: 如果有iOS特定实现
import { Emitter } from '@dcloudio/uni-runtime'
import { $Off, $On, $Once } from '../interface.uts'

const emitter = new Emitter()

export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    // iOS特定实现
    return emitter.on(eventName, callback)
})

// ... 其他函数

// 选项3: 如果依赖运行时
// iOS平台的事件总线由uni-app运行时提供,无需UTS插件实现
// 此文件保持为空
```

---

### 4.2 Android和Harmony实现不一致

**文件位置**:
- `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-android\index.uts`
- `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-event\utssdk\app-harmony\index.uts`
**严重程度**: 中

**问题描述**:
Android平台使用单例Emitter,而Harmony平台使用Map管理多个Emitter实例。这种实现差异可能导致跨平台行为不一致:
1. Android平台上,所有小程序实例共享同一个事件总线
2. Harmony平台上,每个小程序实例有独立的事件总线

**当前代码**:
```typescript
// Android实现
const emitter = new Emitter() // 全局单例

// Harmony实现
const emitterStore = new Map<string, IUniEventEmitter>() // 每个appId一个实例
```

**修复建议**:
1. 统一两个平台的实现逻辑
2. 如果确实需要不同的实现,应该在文档中明确说明差异
3. 建议Android也采用Harmony的多实例模式,以支持多小程序场景

**优化后的代码**:
```typescript
// 建议Android也采用多实例模式
import { Emitter, getCurrentMP } from '@dcloudio/uni-runtime'
import { $Off, $On, $Once } from '../interface.uts'

interface IUniEventEmitter {
    on: (eventName: string, callback: Function) => number
    once: (eventName: string, callback: Function) => number
    off: (eventName: string, callback?: Function | null) => void
    emit: (eventName: string, ...args: any[]) => void
}

const emitterStore = new Map<string, IUniEventEmitter>()

function getEmitter(): IUniEventEmitter {
    // 与Harmony平台保持一致的实现
    // ...
}

export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    return getEmitter().on(eventName, callback)
})

// ... 其他函数
```

---

## 五、性能优化建议

### 5.1 事件名称索引优化

**严重程度**: 低

**问题描述**:
虽然Emitter的内部实现不在此插件中,但事件总线通常使用Map或对象存储事件监听器。在有大量不同事件的场景下,应该确保事件名称的查找效率。

**优化建议**:
1. 确保Emitter内部使用Map而非普通对象存储监听器
2. 考虑对高频事件进行缓存
3. 定期清理已无监听器的事件键

---

### 5.2 监听器数量限制

**严重程度**: 中

**问题描述**:
当前实现没有限制单个事件可以注册的监听器数量。恶意代码或bug可能导致注册大量监听器,造成内存占用过高和性能下降。

**优化建议**:
添加监听器数量限制和警告机制。

**优化后的代码**:
```typescript
const MAX_LISTENERS_PER_EVENT = 100
const MAX_LISTENERS_WARNING_THRESHOLD = 50

export const $on = defineSyncApi<$On>('$on', (eventName, callback): number => {
    if (!validateEventName(API_$_ON, eventName) || !validateCallback(API_$_ON, callback)) {
        return LISTENER_ID_INVALID
    }

    const emitter = getEmitter()

    // 检查监听器数量(需要Emitter提供getListenerCount方法)
    // const count = emitter.getListenerCount(eventName)
    // if (count >= MAX_LISTENERS_PER_EVENT) {
    //     console.error(`$on: too many listeners for event "${eventName}" (max: ${MAX_LISTENERS_PER_EVENT})`)
    //     return LISTENER_ID_INVALID
    // }
    // if (count >= MAX_LISTENERS_WARNING_THRESHOLD) {
    //     console.warn(`$on: event "${eventName}" has ${count} listeners`)
    // }

    return emitter.on(eventName, callback)
})
```

---

### 5.3 减少函数调用开销

**严重程度**: 低

**问题描述**:
在Harmony平台实现中,每次API调用都会经过`defineSyncApi` -> `getEmitter()` -> `Map查找`的调用链,在高频场景下有一定的性能开销。

**优化建议**:
前面已提出的缓存方案可以有效减少这个开销。

---

## 六、安全性问题

### 6.1 事件名称冲突风险

**严重程度**: 中

**问题描述**:
当前实现没有对事件名称进行命名空间隔离,不同模块可能使用相同的事件名称导致冲突。特别是在多个第三方插件同时使用事件总线时,容易产生意外的事件触发。

**修复建议**:
1. 建议在文档中说明事件命名规范(如使用模块名作为前缀)
2. 考虑提供命名空间API
3. 添加事件名称冲突检测和警告

**优化建议**:
```typescript
// 建议的命名规范
// 系统事件: uni:* (如 uni:pageShow, uni:pageHide)
// 用户事件: app:* (如 app:userLogin, app:dataUpdate)
// 插件事件: plugin:pluginName:* (如 plugin:share:success)

// 可以提供辅助函数
export function createNamespacedEventBus(namespace: string) {
    return {
        on(eventName: string, callback: Function): number {
            return uni.$on(`${namespace}:${eventName}`, callback)
        },
        off(eventName: string, callback?: Function | null): void {
            uni.$off(`${namespace}:${eventName}`, callback)
        },
        once(eventName: string, callback: Function): number {
            return uni.$once(`${namespace}:${eventName}`, callback)
        },
        emit(eventName: string, ...args: any[]): void {
            uni.$emit(`${namespace}:${eventName}`, ...args)
        }
    }
}

// 使用示例
const myBus = createNamespacedEventBus('myPlugin')
myBus.on('dataReady', (data) => {
    console.log(data)
})
myBus.emit('dataReady', { value: 123 })
```

---

### 6.2 内存占用监控

**严重程度**: 低

**问题描述**:
当前实现没有提供监控事件总线内存占用的能力,难以发现内存泄漏问题。

**优化建议**:
提供调试API查看事件总线状态。

**优化后的代码**:
```typescript
// 仅在开发模式下提供
// #ifdef DEV_ENV
export function getEventBusStats() {
    const emitter = getEmitter()
    return {
        // 需要Emitter提供以下方法
        // eventCount: emitter.getEventCount(),
        // listenerCount: emitter.getTotalListenerCount(),
        // events: emitter.getEventNames()
    }
}

export function clearAllListeners() {
    const emitter = getEmitter()
    // emitter.clearAll()
}
// #endif
```

---

## 七、文档和测试问题

### 7.1 缺少单元测试

**严重程度**: 中

**问题描述**:
当前插件没有单元测试,无法验证各种边界情况的处理是否正确,如:
1. 事件名称为空字符串
2. callback为null/undefined
3. 重复注册同一个callback
4. off一个不存在的事件
5. emit一个没有监听器的事件
6. 在监听器中off自己
7. 在监听器中修改监听器列表

**修复建议**:
添加完整的单元测试覆盖。

**测试用例示例**:
```typescript
// 测试框架示例
describe('uni.$on', () => {
    it('should register event listener and return listener id', () => {
        const id = uni.$on('test', () => {})
        expect(typeof id).toBe('number')
        expect(id).toBeGreaterThanOrEqual(0)
    })

    it('should return -1 when eventName is empty', () => {
        const id = uni.$on('', () => {})
        expect(id).toBe(-1)
    })

    it('should return -1 when callback is not a function', () => {
        const id = uni.$on('test', null as any)
        expect(id).toBe(-1)
    })
})

describe('uni.$emit', () => {
    it('should trigger all registered listeners', () => {
        let count = 0
        uni.$on('test', () => count++)
        uni.$on('test', () => count++)
        uni.$emit('test')
        expect(count).toBe(2)
    })

    it('should pass arguments to listeners', () => {
        let receivedArgs: any[] = []
        uni.$on('test', (...args) => { receivedArgs = args })
        uni.$emit('test', 1, 'hello', { key: 'value' })
        expect(receivedArgs).toEqual([1, 'hello', { key: 'value' }])
    })
})

describe('uni.$off', () => {
    it('should remove specific listener by callback', () => {
        let count = 0
        const callback = () => count++
        uni.$on('test', callback)
        uni.$emit('test')
        expect(count).toBe(1)

        uni.$off('test', callback)
        uni.$emit('test')
        expect(count).toBe(1) // still 1, not 2
    })

    it('should remove specific listener by id', () => {
        let count = 0
        const id = uni.$on('test', () => count++)
        uni.$emit('test')
        expect(count).toBe(1)

        uni.$off('test', id)
        uni.$emit('test')
        expect(count).toBe(1)
    })

    it('should remove all listeners when callback is null', () => {
        let count1 = 0, count2 = 0
        uni.$on('test', () => count1++)
        uni.$on('test', () => count2++)
        uni.$emit('test')
        expect(count1).toBe(1)
        expect(count2).toBe(1)

        uni.$off('test', null)
        uni.$emit('test')
        expect(count1).toBe(1)
        expect(count2).toBe(1)
    })
})

describe('uni.$once', () => {
    it('should trigger listener only once', () => {
        let count = 0
        uni.$once('test', () => count++)
        uni.$emit('test')
        uni.$emit('test')
        uni.$emit('test')
        expect(count).toBe(1)
    })

    it('should auto-remove listener after first trigger', () => {
        let triggered = false
        const id = uni.$once('test', () => { triggered = true })
        uni.$emit('test')
        expect(triggered).toBe(true)

        // 验证监听器已被移除
        // 这需要Emitter提供hasListener方法
    })
})

describe('Memory leak tests', () => {
    it('should not leak memory when registering and removing many listeners', () => {
        for (let i = 0; i < 10000; i++) {
            const id = uni.$on('test', () => {})
            uni.$off('test', id)
        }
        // 验证内存占用正常
    })
})

describe('Concurrent tests', () => {
    it('should handle concurrent on/off/emit operations', async () => {
        // 模拟并发场景
        const promises = []
        for (let i = 0; i < 100; i++) {
            promises.push(
                new Promise<void>((resolve) => {
                    const id = uni.$on('test', () => {})
                    setTimeout(() => {
                        uni.$off('test', id)
                        resolve()
                    }, Math.random() * 100)
                })
            )
        }
        await Promise.all(promises)
    })
})
```

---

### 7.2 文档不完整

**严重程度**: 低

**问题描述**:
虽然interface.uts中有基本的API文档,但缺少以下内容:
1. 监听器ID的说明(什么时候返回-1,ID是否唯一,ID的生命周期)
2. $off的三种调用方式说明(传callback、传id、传null)
3. 跨平台差异说明
4. 最佳实践和注意事项
5. 常见问题和错误处理

**修复建议**:
补充完整的文档,特别是边界情况和最佳实践。

---

## 八、总结与建议

### 8.1 总体评价

uni-event插件实现了基本的事件总线功能,代码结构清晰,但在健壮性、平台一致性和性能优化方面存在一些问题。主要的关注点包括:

1. 内存管理: Harmony平台的emitterStore清理机制不够可靠
2. 类型安全: 多处使用强制类型转换,缺少null检查
3. 错误处理: 缺少参数验证和异常处理
4. 平台一致性: Android和Harmony实现不一致,iOS实现缺失
5. 性能优化: 高频操作的性能开销需要优化

### 8.2 优先修复项

1. **修复内存泄漏风险**(问题1.1) - 添加可靠的清理机制
2. **添加类型安全检查**(问题1.2) - 避免运行时崩溃
3. **统一平台实现**(问题4.2) - 确保跨平台行为一致
4. **补充iOS实现**(问题4.1) - 完善平台支持
5. **添加参数验证**(问题2.2) - 提高API健壮性
6. **添加单元测试**(问题7.1) - 确保代码质量

### 8.3 性能优化建议

1. 使用缓存减少Map查找次数(问题2.5)
2. 添加监听器数量限制(优化5.2)
3. 优化事件分发链,确保单个监听器异常不影响其他监听器(问题2.4)

### 8.4 代码质量提升

1. 添加完善的JSDoc注释(问题3.2)
2. 使用更精确的类型定义(问题3.3)
3. 定义常量替代魔法值(问题3.4)
4. 实现或删除TODO注释(问题3.1)

### 8.5 安全性增强

1. 提供命名空间机制避免事件名称冲突(问题6.1)
2. 添加内存监控和调试工具(问题6.2)
3. 限制单个事件的监听器数量,防止滥用

---

## 九、修复优先级总结

| 优先级 | 问题数量 | 关键问题 |
|--------|----------|----------|
| 高 | 5 | 内存泄漏、类型安全、错误处理、并发安全、平台实现缺失 |
| 中 | 8 | 参数验证、类型不一致、平台差异、监听器限制、单元测试 |
| 低 | 7 | TODO注释、JSDoc、类型精确度、代码重复、文档完善 |

**预计修复时间**:
- 高优先级问题: 6-8 小时
- 中优先级问题: 8-12 小时
- 低优先级问题: 4-6 小时
- 单元测试编写: 8-10 小时

**总计**: 约 26-36 小时的工作量

---

## 十、代码改进行动计划

### 第一阶段: 紧急修复(1-2天)
1. 修复Harmony平台的内存泄漏风险
2. 添加完整的null检查和类型验证
3. 补充iOS平台实现或添加说明
4. 统一Android和Harmony平台的实现逻辑

### 第二阶段: 质量提升(3-5天)
1. 为所有API添加参数验证
2. 实现错误边界处理
3. 添加完整的单元测试套件
4. 优化性能(缓存、监听器限制)

### 第三阶段: 文档和工具(2-3天)
1. 补充完整的JSDoc注释
2. 编写详细的使用文档
3. 添加调试和监控工具
4. 提供最佳实践指南

### 第四阶段: 长期优化(持续)
1. 收集用户反馈
2. 性能监控和优化
3. 跟进新版本的特性需求
4. 维护和更新测试用例
