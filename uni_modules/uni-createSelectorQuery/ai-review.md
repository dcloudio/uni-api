# uni-createSelectorQuery 代码质量与性能分析报告

## 概述
本报告对 `uni-createSelectorQuery` 插件进行了全面的代码质量和性能分析，涵盖了 Android 和 HarmonyOS 平台的实现。插件主要用于实现组件选择器功能，支持查询节点信息、布局位置、滚动偏移等。

分析的文件包括：
- `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-createSelectorQuery\utssdk\interface.uts`
- `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-createSelectorQuery\utssdk\app-android\index.uts`
- `D:\DCloud\GIT\uni-app-x\uni-app\api\uni-createSelectorQuery\utssdk\app-harmony\index.uts`

## 问题汇总

### 严重程度统计
- 高危问题：5 个
- 中危问题：8 个
- 低危问题：6 个

---

## 高危问题

### 1. 空指针异常风险

**问题描述**：
在 Android 实现中，多处使用了强制非空断言（`!`）而没有进行充分的空值检查，可能导致运行时崩溃。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：139, 148, 159, 168, 391

**严重程度**：高

**代码片段**：
```typescript
// 行 139
this._component?.$?.$waitNativeRender(() => {

// 行 391
return new SelectorQueryImpl(getCurrentPage()!)
```

**问题分析**：
1. `getCurrentPage()!` 强制断言不为空，但 `getCurrentPage()` 可能返回 null
2. `this._component?.$?.$waitNativeRender` 使用了可选链，但内部回调没有处理 component 为 null 的情况
3. 在 HarmonyOS 实现的 219-224 行也存在类似问题

**修复建议**：
增加空值检查和错误处理机制，避免强制非空断言。

**优化后的代码**：
```typescript
// app-android/index.uts 行 391
export const createSelectorQuery: CreateSelectorQuery =
    function (): SelectorQuery {
        const currentPage = getCurrentPage()
        if (currentPage == null) {
            console.error('[createSelectorQuery] getCurrentPage returned null')
            // 返回一个空操作的 SelectorQuery 或抛出异常
            throw new Error('Cannot create SelectorQuery: current page is null')
        }
        return new SelectorQueryImpl(currentPage)
    }

// app-harmony/index.uts 行 219-224
export const createSelectorQuery = defineSyncApi<SelectorQuery>('createSelectorQuery', (context?: ComponentInternalInstance | ComponentPublicInstance) => {
  context = resolveComponentInstance(context)
  if (context && !getPageIdByVm(context)) {
    context = null
  }
  const currentPageVm = context || getCurrentPageVm()
  if (currentPageVm == null) {
    console.error('[createSelectorQuery] No valid page context available')
    throw new Error('Cannot create SelectorQuery: no valid page context')
  }
  return new SelectorQueryImpl(currentPageVm) as SelectorQuery
}) as CreateSelectorQuery
```

---

### 2. 潜在的内存泄漏风险

**问题描述**：
在 `SelectorQueryImpl` 类中，`_queue` 和 `_queueCb` 数组在每次调用 `_push` 时不断累积，但没有清理机制。如果 `exec()` 没有被调用或调用失败，这些数组会一直占用内存。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：127-135, 209-223

**严重程度**：高

**代码片段**：
```typescript
class SelectorQueryImpl implements SelectorQuery {
    private _queue: Array<SelectorQueryRequest>
    private _queueCb: Array<SelectorQueryNodeInfoCallback | null>

    constructor(component: ComponentPublicInstance) {
        this._component = component
        this._queue = []
        this._queueCb = []
    }

    _push(
        selector: string,
        component: ComponentPublicInstance | null,
        single: boolean,
        fields: NodeField,
        callback: SelectorQueryNodeInfoCallback | null,
    ) {
        this._queue.push({
            component,
            selector,
            single,
            fields,
        } as SelectorQueryRequest)
        this._queueCb.push(callback)
    }
}
```

**问题分析**：
1. 每次调用选择器方法（select、selectAll 等）都会向队列中添加请求
2. 如果开发者忘记调用 `exec()`，队列会一直增长
3. 如果同一个 SelectorQuery 实例被重复使用，队列不会被清空
4. HarmonyOS 实现也存在相同问题（136-146, 202-216 行）

**修复建议**：
1. 在 `exec()` 方法执行完成后清空队列
2. 添加队列大小限制
3. 考虑实现类似 WeakMap 的自动清理机制

**优化后的代码**：
```typescript
class SelectorQueryImpl implements SelectorQuery {
    private _queue: Array<SelectorQueryRequest>
    private _queueCb: Array<SelectorQueryNodeInfoCallback | null>
    private _component: ComponentPublicInstance | null = null
    private _nodesRef!: NodesRef
    private readonly MAX_QUEUE_SIZE = 100 // 设置队列最大容量

    constructor(component: ComponentPublicInstance) {
        this._component = component
        this._queue = []
        this._queueCb = []
    }

    // 添加清理方法
    private _clearQueue() {
        this._queue.length = 0
        this._queueCb.length = 0
    }

    exec(callback?: (result: Array<any>) => void | null): NodesRef | null {
        // 保存当前队列的引用
        const currentQueue = [...this._queue]
        const currentQueueCb = [...this._queueCb]

        // 立即清空队列，防止重复执行
        this._clearQueue()

        this._component?.$?.$waitNativeRender(() => {
            requestComponentInfo(
                this._component,
                currentQueue,
                (res: Array<any>) => {
                    res.forEach((info: any, _index) => {
                        const queueCb = currentQueueCb[_index]
                        if (isFunction(queueCb)) {
                            queueCb!(info)
                        }
                    })
                    if (isFunction(callback)) {
                        callback(res)
                    }
                },
            )
        })
        return this._nodesRef
    }

    _push(
        selector: string,
        component: ComponentPublicInstance | null,
        single: boolean,
        fields: NodeField,
        callback: SelectorQueryNodeInfoCallback | null,
    ) {
        // 检查队列大小
        if (this._queue.length >= this.MAX_QUEUE_SIZE) {
            console.warn('[SelectorQuery] Queue size exceeded maximum limit, clearing oldest requests')
            this._queue.shift()
            this._queueCb.shift()
        }

        this._queue.push({
            component,
            selector,
            single,
            fields,
        } as SelectorQueryRequest)
        this._queueCb.push(callback)
    }
}
```

---

### 3. 类型安全问题 - any 类型滥用

**问题描述**：
代码中大量使用 `any` 类型，削弱了 TypeScript 的类型检查能力，容易引入运行时错误。

**问题位置**：
- 文件：`interface.uts`, `app-android/index.uts`, `app-harmony/index.uts`
- 行号：interface.uts (3, 11, 14, 57, 60, 122, 442, 469), app-android/index.uts (19, 143, 145, 163, 165, 240, 244, 263, 274, 276), app-harmony/index.uts (152, 154, 161, 166)

**严重程度**：高

**代码片段**：
```typescript
// interface.uts
export type SelectorQueryNodeInfoCallback = (result: any) => void

export type NodeInfo = {
    dataset: any | null
    node: any | null
    context: any | null
}

// app-android/index.uts
type RequestComponentInfoCallback = (result: Array<any>) => void

query(selector: string, all: boolean): any | null {
    // ...
}
```

**问题分析**：
1. `any` 类型让编译器无法进行类型检查
2. 容易导致运行时类型错误
3. 降低代码可维护性和可读性
4. IDE 无法提供准确的代码提示

**修复建议**：
定义具体的类型接口，替换 `any` 类型。

**优化后的代码**：
```typescript
// interface.uts
// 定义具体的数据集类型
export type DatasetValue = string | number | boolean | null
export type Dataset = Record<string, DatasetValue>

// 定义回调结果类型
export type SelectorQueryResult = NodeInfo | NodeInfo[] | null

export type SelectorQueryNodeInfoCallback = (result: SelectorQueryResult) => void

export type NodeInfo = {
    id: string | null
    dataset: Dataset | null
    left: number | null
    right: number | null
    top: number | null
    bottom: number | null
    width: number | null
    height: number | null
    scrollLeft: number | null
    scrollTop: number | null
    scrollHeight: number | null
    scrollWidth: number | null
    node: Element | null // 改为具体的 Element 类型
    context: CanvasContext | MapContext | VideoContext | EditorContext | null
}

// app-android/index.uts
type RequestComponentInfoCallback = (result: Array<SelectorQueryResult>) => void

// 为 query 方法定义返回类型
query(selector: string, all: boolean): NodeInfo | NodeInfo[] | null {
    if (this._element.nodeName == '#comment') {
        return this.queryFragment(this._element, selector, all)
    } else {
        return all
            ? this.querySelectorAll(this._element, selector)
            : this.querySelector(this._element, selector)
    }
}
```

---

### 4. 异步处理缺少错误捕获

**问题描述**：
`exec()` 方法中的异步回调没有 try-catch 保护，如果回调函数抛出异常，会导致整个查询流程中断且无法追踪错误。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：139-153, 159-176

**严重程度**：高

**代码片段**：
```typescript
exec(): NodesRef | null {
    this._component?.$?.$waitNativeRender(() => {
        requestComponentInfo(
            this._component,
            this._queue,
            (res: Array<any>) => {
                const queueCbs = this._queueCb
                res.forEach((info: any, _index) => {
                    const queueCb = queueCbs[_index]
                    if (isFunction(queueCb)) {
                        queueCb!(info)  // 可能抛出异常
                    }
                })
            },
        )
    })
    return this._nodesRef
}
```

**问题分析**：
1. 用户提供的回调函数可能抛出异常
2. 没有错误处理机制，异常会向上传播
3. 可能导致后续回调无法执行
4. 难以定位问题源

**修复建议**：
添加 try-catch 块保护回调执行，确保单个回调失败不影响其他回调。

**优化后的代码**：
```typescript
exec(callback?: (result: Array<any>) => void | null): NodesRef | null {
    if (this._component == null) {
        console.error('[SelectorQuery.exec] Component is null')
        return this._nodesRef
    }

    const currentQueue = [...this._queue]
    const currentQueueCb = [...this._queueCb]
    this._clearQueue()

    this._component.$?.$waitNativeRender(() => {
        try {
            requestComponentInfo(
                this._component,
                currentQueue,
                (res: Array<any>) => {
                    const queueCbs = currentQueueCb
                    res.forEach((info: any, _index) => {
                        const queueCb = queueCbs[_index]
                        if (isFunction(queueCb)) {
                            try {
                                queueCb!(info)
                            } catch (error) {
                                console.error(`[SelectorQuery] Callback error at index ${_index}:`, error)
                            }
                        }
                    })

                    if (isFunction(callback)) {
                        try {
                            callback(res)
                        } catch (error) {
                            console.error('[SelectorQuery] Main callback error:', error)
                        }
                    }
                },
            )
        } catch (error) {
            console.error('[SelectorQuery] requestComponentInfo error:', error)
        }
    })

    return this._nodesRef
}
```

---

### 5. 潜在的无限循环风险

**问题描述**：
在 `QuerySelectorHelper.queryFragment()` 方法中，while 循环的终止条件可能不满足，导致无限循环。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：254-290

**严重程度**：高

**代码片段**：
```typescript
queryFragment(el: Element, selector: string, all: boolean): any | null {
    const startNodeId = parseInt(el.getNodeId())
    const endNodeId = (startNodeId + 1).toString()
    let current = el.nextSibling
    if (current == null) {
        return null
    }

    if (all) {
        const result1: Array<any> = []
        while (true) {  // 无限循环风险
            const queryResult = this.querySelectorAll(current!, selector)
            if (queryResult != null) {
                result1.push(...queryResult)
            }
            current = current.nextSibling
            if (current == null || current.getNodeId() == endNodeId) {
                break
            }
        }
        return result1
    } else {
        let result2: any | null = null
        while (true) {  // 无限循环风险
            result2 = this.querySelector(current!, selector)
            current = current.nextSibling
            if (
                result2 != null ||
                current == null ||
                current.getNodeId() == endNodeId
            ) {
                break
            }
        }
        return result2
    }
}
```

**问题分析**：
1. 依赖于 DOM 结构的正确性
2. 如果 DOM 结构异常（如循环引用），可能导致无限循环
3. 没有迭代次数限制
4. `getNodeId()` 返回值的格式假设可能不成立

**修复建议**：
添加迭代次数限制和更安全的循环终止条件。

**优化后的代码**：
```typescript
queryFragment(el: Element, selector: string, all: boolean): any | null {
    const startNodeId = parseInt(el.getNodeId())
    const endNodeId = (startNodeId + 1).toString()
    let current = el.nextSibling
    if (current == null) {
        return null
    }

    const MAX_ITERATIONS = 1000 // 设置最大迭代次数
    let iterationCount = 0

    if (all) {
        const result1: Array<any> = []
        while (current != null && iterationCount < MAX_ITERATIONS) {
            iterationCount++

            // 先检查是否到达结束节点
            if (current.getNodeId() == endNodeId) {
                break
            }

            const queryResult = this.querySelectorAll(current, selector)
            if (queryResult != null) {
                result1.push(...queryResult)
            }

            current = current.nextSibling
        }

        if (iterationCount >= MAX_ITERATIONS) {
            console.warn('[QuerySelectorHelper] Max iterations reached in queryFragment')
        }

        return result1
    } else {
        let result2: any | null = null
        while (current != null && iterationCount < MAX_ITERATIONS) {
            iterationCount++

            // 先检查是否到达结束节点
            if (current.getNodeId() == endNodeId) {
                break
            }

            result2 = this.querySelector(current, selector)
            if (result2 != null) {
                break
            }

            current = current.nextSibling
        }

        if (iterationCount >= MAX_ITERATIONS) {
            console.warn('[QuerySelectorHelper] Max iterations reached in queryFragment')
        }

        return result2
    }
}
```

---

## 中危问题

### 6. 代码重复 - exec 方法重载

**问题描述**：
Android 实现中的 `exec()` 方法存在两个重载版本，代码逻辑几乎完全相同，违反了 DRY（Don't Repeat Yourself）原则。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：137-156, 157-179

**严重程度**：中

**代码片段**：
```typescript
// @ts-expect-error
exec(): NodesRef | null {
    this._component?.$?.$waitNativeRender(() => {
        requestComponentInfo(
            this._component,
            this._queue,
            (res: Array<any>) => {
                const queueCbs = this._queueCb
                res.forEach((info: any, _index) => {
                    const queueCb = queueCbs[_index]
                    if (isFunction(queueCb)) {
                        queueCb!(info)
                    }
                })
            },
        )
    })
    return this._nodesRef
}

// @ts-expect-error
exec(callback: (result: Array<any>) => void | null): NodesRef | null {
    this._component?.$?.$waitNativeRender(() => {
        requestComponentInfo(
            this._component,
            this._queue,
            (res: Array<any>) => {
                const queueCbs = this._queueCb
                res.forEach((info: any, _index) => {
                    const queueCb = queueCbs[_index]
                    if (isFunction(queueCb)) {
                        queueCb!(info)
                    }
                })
                if (isFunction(callback)) {
                    callback(res)
                }
            },
        )
    })
    return this._nodesRef
}
```

**问题分析**：
1. 重复代码增加维护成本
2. 修改一处容易遗漏另一处
3. 代码体积增大

**修复建议**：
合并两个方法，使用可选参数。

**优化后的代码**：
```typescript
exec(callback?: (result: Array<any>) => void | null): NodesRef | null {
    if (this._component == null) {
        console.error('[SelectorQuery.exec] Component is null')
        return this._nodesRef
    }

    const currentQueue = [...this._queue]
    const currentQueueCb = [...this._queueCb]
    this._clearQueue()

    this._component.$?.$waitNativeRender(() => {
        try {
            requestComponentInfo(
                this._component,
                currentQueue,
                (res: Array<any>) => {
                    res.forEach((info: any, _index) => {
                        const queueCb = currentQueueCb[_index]
                        if (isFunction(queueCb)) {
                            try {
                                queueCb!(info)
                            } catch (error) {
                                console.error(`[SelectorQuery] Callback error at index ${_index}:`, error)
                            }
                        }
                    })

                    // 只有在传入了 callback 且为函数时才执行
                    if (callback != null && isFunction(callback)) {
                        try {
                            callback(res)
                        } catch (error) {
                            console.error('[SelectorQuery] Main callback error:', error)
                        }
                    }
                },
            )
        } catch (error) {
            console.error('[SelectorQuery] requestComponentInfo error:', error)
        }
    })

    return this._nodesRef
}
```

---

### 7. 不必要的 @ts-expect-error 注释

**问题描述**：
代码中存在多处 `@ts-expect-error` 注释，表明存在类型错误被强制忽略，这是代码异味的信号。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：45, 46, 47, 51, 137, 157, 182, 183

**严重程度**：中

**代码片段**：
```typescript
// @ts-expect-error
boundingClientRect(): SelectorQuery {
    // @ts-expect-error
    return this.boundingClientRect(null)
}

// @ts-expect-error
boundingClientRect(
    callback: SelectorQueryNodeInfoCallback | null,
): SelectorQuery {
    // ...
}
```

**问题分析**：
1. 表明类型定义不准确
2. 掩盖潜在的类型安全问题
3. 降低代码可维护性

**修复建议**：
修正类型定义，移除不必要的类型错误抑制。

**优化后的代码**：
```typescript
// 修改接口定义，支持可选参数
interface NodesRef {
    boundingClientRect(callback?: SelectorQueryNodeInfoCallback | null): SelectorQuery
    // ... 其他方法
}

// 实现时使用可选参数
boundingClientRect(callback?: SelectorQueryNodeInfoCallback | null): SelectorQuery {
    this._selectorQuery._push(
        this._selector,
        this._component,
        this._single,
        {
            id: true,
            dataset: true,
            rect: true,
            size: true,
        } as NodeField,
        callback ?? null,
    )
    return this._selectorQuery
}

// 修改 in 方法的类型检查
in(component: any | null): SelectorQuery {
    // 使用类型守卫而不是 instanceof（UTS 可能不支持）
    if (component != null && typeof component === 'object' && '$' in component) {
        this._component = component as ComponentPublicInstance
    }
    return this
}
```

---

### 8. NodesRefImpl 每次调用都创建新实例

**问题描述**：
在 `SelectorQueryImpl` 中，每次调用 `select()`、`selectAll()` 或 `selectViewport()` 都会创建新的 `NodesRefImpl` 实例并覆盖 `_nodesRef` 属性，可能导致内存浪费。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：189-207

**严重程度**：中

**代码片段**：
```typescript
select(selector: string): NodesRef {
    this._nodesRef = new NodesRefImpl(this, this._component, selector, true)
    return this._nodesRef
}

selectAll(selector: string): NodesRef {
    this._nodesRef = new NodesRefImpl(
        this,
        this._component,
        selector,
        false,
    )
    return this._nodesRef
}

selectViewport(): NodesRef {
    this._nodesRef = new NodesRefImpl(this, null, '', true)
    return this._nodesRef
}
```

**问题分析**：
1. 每次调用都覆盖之前的 `_nodesRef`，旧实例可能还未被使用就被丢弃
2. 不支持链式调用多个不同的选择器
3. 实际上 `_nodesRef` 的存储意义不大，因为总是返回新实例

**修复建议**：
直接返回新实例，不需要存储在 `_nodesRef` 属性中。

**优化后的代码**：
```typescript
class SelectorQueryImpl implements SelectorQuery {
    private _page: ComponentPublicInstance
    private _queue: Array<SelectorQueryRequest>
    private _component: ComponentPublicInstance | null = null
    private _queueCb: Array<SelectorQueryNodeInfoCallback | null>
    // 移除 _nodesRef 属性

    constructor(component: ComponentPublicInstance) {
        this._component = component
        this._queue = []
        this._queueCb = []
    }

    select(selector: string): NodesRef {
        // 直接返回新实例，不需要存储
        return new NodesRefImpl(this, this._component, selector, true)
    }

    selectAll(selector: string): NodesRef {
        return new NodesRefImpl(this, this._component, selector, false)
    }

    selectViewport(): NodesRef {
        return new NodesRefImpl(this, null, '', true)
    }

    exec(callback?: (result: Array<any>) => void | null): NodesRef | null {
        // ... 执行逻辑
        // 返回 null 或者最后一次的查询结果（如果需要的话）
        return null
    }
}
```

---

### 9. requestComponentInfo 缺少参数验证

**问题描述**：
`requestComponentInfo` 函数没有对输入参数进行验证，可能导致不必要的执行或错误。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：366-387

**严重程度**：中

**代码片段**：
```typescript
function requestComponentInfo(
    vueComponent: ComponentPublicInstance | null,
    queue: Array<SelectorQueryRequest>,
    callback: RequestComponentInfoCallback,
) {
    const result: Array<any> = []
    const el = vueComponent?.$el
    if (el != null) {
        queue.forEach((item: SelectorQueryRequest) => {
            const queryResult = QuerySelectorHelper.queryElement(
                el,
                item.selector,
                !item.single,
                item.fields,
            )
            if (queryResult != null) {
                result.push(queryResult)
            }
        })
    }
    callback(result)
}
```

**问题分析**：
1. 没有检查 queue 是否为空
2. 没有检查 callback 是否为函数
3. el 为 null 时仍会调用 callback，返回空数组
4. 缺少错误处理

**修复建议**：
添加参数验证和错误处理。

**优化后的代码**：
```typescript
function requestComponentInfo(
    vueComponent: ComponentPublicInstance | null,
    queue: Array<SelectorQueryRequest>,
    callback: RequestComponentInfoCallback,
) {
    // 参数验证
    if (!isFunction(callback)) {
        console.error('[requestComponentInfo] callback is not a function')
        return
    }

    if (queue.length === 0) {
        console.warn('[requestComponentInfo] queue is empty')
        callback([])
        return
    }

    const result: Array<any> = []
    const el = vueComponent?.$el

    if (el == null) {
        console.warn('[requestComponentInfo] vueComponent.$el is null')
        callback(result)
        return
    }

    try {
        queue.forEach((item: SelectorQueryRequest) => {
            if (item == null) {
                console.warn('[requestComponentInfo] Skipping null queue item')
                return
            }

            try {
                const queryResult = QuerySelectorHelper.queryElement(
                    el,
                    item.selector,
                    !item.single,
                    item.fields,
                )
                if (queryResult != null) {
                    result.push(queryResult)
                } else {
                    // 即使查询结果为空，也应该添加 null 保持索引对应
                    result.push(null)
                }
            } catch (error) {
                console.error(`[requestComponentInfo] Query error for selector "${item.selector}":`, error)
                result.push(null)
            }
        })
    } catch (error) {
        console.error('[requestComponentInfo] Fatal error during query processing:', error)
    }

    callback(result)
}
```

---

### 10. querySelf 方法选择器解析不完整

**问题描述**：
`querySelf` 方法只支持简单的类选择器、ID 选择器和标签选择器，不支持复杂选择器（如属性选择器、伪类等）。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：319-337

**严重程度**：中

**代码片段**：
```typescript
querySelf(element: Element | null, selector: string): Element | null {
    if (element == null || selector.length < 2) {
        return null
    }

    const selectorType = selector.charAt(0)
    const selectorName = selector.slice(1)
    if (selectorType == '.' && element.classList.includes(selectorName)) {
        return element
    }
    if (selectorType == '#' && element.getAttribute('id') == selectorName) {
        return element
    }
    if (selector.toUpperCase() == element.nodeName.toUpperCase()) {
        return element
    }

    return null
}
```

**问题分析**：
1. 只处理最简单的选择器格式
2. 不支持复合选择器（如 `.class1.class2`）
3. 不支持属性选择器（如 `[data-id="123"]`）
4. 可能与标准 querySelector 行为不一致
5. `selector.length < 2` 的判断对标签选择器（如 `a`）会误判

**修复建议**：
改进选择器匹配逻辑，或者移除 `querySelf` 直接使用原生 `matches()` 方法。

**优化后的代码**：
```typescript
querySelf(element: Element | null, selector: string): Element | null {
    if (element == null || selector.length === 0) {
        return null
    }

    // 对于单字符选择器（标签名），直接比较
    if (selector.length === 1) {
        if (selector.toUpperCase() == element.nodeName.toUpperCase()) {
            return element
        }
        return null
    }

    try {
        // 优先使用原生 matches 方法（如果支持）
        if (element.matches && element.matches(selector)) {
            return element
        }

        // 降级方案：手动匹配简单选择器
        const selectorType = selector.charAt(0)
        const selectorName = selector.slice(1)

        switch (selectorType) {
            case '.':
                // 类选择器 - 支持多个类名
                const classes = selectorName.split('.')
                const hasAllClasses = classes.every(cls =>
                    cls.length > 0 && element.classList.includes(cls)
                )
                if (hasAllClasses) {
                    return element
                }
                break

            case '#':
                // ID 选择器
                if (element.getAttribute('id') == selectorName) {
                    return element
                }
                break

            default:
                // 标签选择器
                if (selector.toUpperCase() == element.nodeName.toUpperCase()) {
                    return element
                }
                break
        }
    } catch (error) {
        console.warn(`[querySelf] Error matching selector "${selector}":`, error)
    }

    return null
}
```

---

### 11. getNodeInfo 方法性能优化不足

**问题描述**：
`getNodeInfo` 方法对于不需要完整信息的情况仍然创建了完整的 NodeInfo 对象，没有根据 fields 参数进行优化。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：339-363

**严重程度**：中

**代码片段**：
```typescript
getNodeInfo(element: Element): NodeInfo {
    if (this._fields.node == true) {
        const nodeInfo = {
            node: element
        } as NodeInfo
        if (this._fields.size == true) {
            const rect = element.getBoundingClientRect()
            nodeInfo.width = rect.width
            nodeInfo.height = rect.height
        }
        return nodeInfo
    }
    const rect = element.getBoundingClientRect()
    const nodeInfo = {
        id: element.getAttribute('id')?.toString(),
        dataset: null,
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom,
        width: rect.width,
        height: rect.height,
    } as NodeInfo
    return nodeInfo
}
```

**问题分析**：
1. 当 `fields.node != true` 时，总是调用 `getBoundingClientRect()`，即使不需要尺寸信息
2. 没有根据 `fields` 的其他属性（id, dataset, rect, size, scrollOffset）按需获取信息
3. `getBoundingClientRect()` 是性能开销较大的操作，应该避免不必要的调用

**修复建议**：
根据 fields 参数按需获取信息。

**优化后的代码**：
```typescript
getNodeInfo(element: Element): NodeInfo {
    const nodeInfo: NodeInfo = {} as NodeInfo

    // 如果只需要 node 本身
    if (this._fields.node == true) {
        nodeInfo.node = element

        // 如果还需要 size，才调用 getBoundingClientRect
        if (this._fields.size == true) {
            const rect = element.getBoundingClientRect()
            nodeInfo.width = rect.width
            nodeInfo.height = rect.height
        }

        return nodeInfo
    }

    // 按需获取各项信息
    if (this._fields.id == true) {
        nodeInfo.id = element.getAttribute('id')?.toString() ?? null
    }

    if (this._fields.dataset == true) {
        // 实现 dataset 获取逻辑
        nodeInfo.dataset = this._getDataset(element)
    }

    // 只有在需要位置或尺寸信息时才调用 getBoundingClientRect
    if (this._fields.rect == true || this._fields.size == true) {
        const rect = element.getBoundingClientRect()

        if (this._fields.rect == true) {
            nodeInfo.left = rect.left
            nodeInfo.top = rect.top
            nodeInfo.right = rect.right
            nodeInfo.bottom = rect.bottom
        }

        if (this._fields.size == true) {
            nodeInfo.width = rect.width
            nodeInfo.height = rect.height
        }
    }

    if (this._fields.scrollOffset == true) {
        nodeInfo.scrollLeft = element.scrollLeft
        nodeInfo.scrollTop = element.scrollTop
        nodeInfo.scrollWidth = element.scrollWidth
        nodeInfo.scrollHeight = element.scrollHeight
    }

    if (this._fields.context == true) {
        // 实现 context 获取逻辑
        nodeInfo.context = this._getContext(element)
    }

    return nodeInfo
}

// 添加辅助方法
private _getDataset(element: Element): any | null {
    // 获取所有 data-* 属性
    const dataset: Record<string, any> = {}
    const attributes = element.attributes
    let hasData = false

    for (let i = 0; i < attributes.length; i++) {
        const attr = attributes[i]
        if (attr.name.startsWith('data-')) {
            const key = attr.name.slice(5) // 去掉 'data-' 前缀
            dataset[key] = attr.value
            hasData = true
        }
    }

    return hasData ? dataset : null
}

private _getContext(element: Element): any | null {
    // 根据元素类型返回对应的 Context
    // 这部分需要根据实际实现补充
    return null
}
```

---

### 12. HarmonyOS 实现中的数组操作性能问题

**问题描述**：
在 HarmonyOS 实现中，`_push` 方法使用了 `callback && this._queueCb.push(callback)` 的短路写法，这会导致 `_queue` 和 `_queueCb` 数组长度不一致。

**问题位置**：
- 文件：`app-harmony/index.uts`
- 行号：202-216

**严重程度**：中

**代码片段**：
```typescript
_push(
    selector: string,
    component: ComponentPublicInstance | undefined | null,
    single: boolean,
    fields: NodeField,
    callback?: SelectorQueryNodeInfoCallback | null
) {
    this._queue.push({
        component,
        selector,
        single,
        fields,
    } as SelectorQueryRequest)
    callback && this._queueCb.push(callback)  // 条件性添加
}
```

**问题分析**：
1. 当 callback 为 null/undefined 时，不会添加到 `_queueCb`
2. 导致 `_queue` 和 `_queueCb` 长度不一致
3. 在 `exec()` 方法中通过索引访问可能出错

**修复建议**：
始终保持两个数组长度一致。

**优化后的代码**：
```typescript
_push(
    selector: string,
    component: ComponentPublicInstance | undefined | null,
    single: boolean,
    fields: NodeField,
    callback?: SelectorQueryNodeInfoCallback | null
) {
    if (this._queue.length >= this.MAX_QUEUE_SIZE) {
        console.warn('[SelectorQuery] Queue size exceeded maximum limit')
        this._queue.shift()
        this._queueCb.shift()
    }

    this._queue.push({
        component,
        selector,
        single,
        fields,
    } as SelectorQueryRequest)

    // 始终添加到 _queueCb，保持数组长度一致
    this._queueCb.push(callback ?? null)
}
```

---

### 13. fields 方法参数验证缺失

**问题描述**：
`fields` 方法没有验证 `NodeField` 参数的有效性，可能传入空对象或无效字段。

**问题位置**：
- 文件：`app-android/index.uts`, `app-harmony/index.uts`
- 行号：app-android (70-82), app-harmony (83-92)

**严重程度**：中

**代码片段**：
```typescript
fields(
    fields: NodeField,
    callback: SelectorQueryNodeInfoCallback | null,
): SelectorQuery {
    this._selectorQuery._push(
        this._selector,
        this._component,
        this._single,
        fields,
        callback,
    )
    return this._selectorQuery
}
```

**问题分析**：
1. 没有检查 fields 是否为空对象
2. 没有检查 fields 中是否至少有一个有效字段
3. 空 fields 会导致无意义的查询

**修复建议**：
添加参数验证。

**优化后的代码**：
```typescript
fields(
    fields: NodeField,
    callback: SelectorQueryNodeInfoCallback | null,
): SelectorQuery {
    // 验证 fields 参数
    if (fields == null || typeof fields !== 'object') {
        console.error('[NodesRef.fields] Invalid fields parameter')
        return this._selectorQuery
    }

    // 检查是否至少有一个有效字段
    const hasValidField = (
        fields.id === true ||
        fields.dataset === true ||
        fields.rect === true ||
        fields.size === true ||
        fields.scrollOffset === true ||
        fields.context === true ||
        fields.node === true ||
        (fields.properties != null && fields.properties.length > 0) ||
        (fields.computedStyle != null && fields.computedStyle.length > 0)
    )

    if (!hasValidField) {
        console.warn('[NodesRef.fields] No valid fields specified, query will return empty result')
    }

    this._selectorQuery._push(
        this._selector,
        this._component,
        this._single,
        fields,
        callback,
    )
    return this._selectorQuery
}
```

---

## 低危问题

### 14. TODO 注释未处理

**问题描述**：
代码中存在多处 TODO 注释，表示功能未完成或需要改进。

**问题位置**：
- 文件：`app-android/index.uts`, `app-harmony/index.uts`
- 行号：app-android (11-17, 154, 177), app-harmony (25-39, 155, 171)

**严重程度**：低

**代码片段**：
```typescript
// TODO
// const ContextClasss = {
//   canvas: CanvasContext,
//   map: MapContext,
//   video: VideoContext,
//   editor: EditorContext,
// }

// TODO
return this._nodesRef
```

**问题分析**：
1. Context 类型转换功能未实现
2. exec() 返回值的意义不明确
3. 可能影响某些高级功能

**修复建议**：
1. 完成 Context 类型转换功能
2. 明确 exec() 的返回值用途或改为返回 SelectorQuery 本身支持链式调用
3. 添加功能追踪 issue

---

### 15. 缺少日志和调试信息

**问题描述**：
代码中几乎没有日志输出，不利于问题排查和调试。

**问题位置**：
全部文件

**严重程度**：低

**问题分析**：
1. 缺少关键操作的日志
2. 错误情况没有日志输出
3. 不利于生产环境问题排查

**修复建议**：
添加适当的日志输出，特别是错误和警告场景。

---

### 16. 缺少单元测试

**问题描述**：
没有找到单元测试文件，代码质量难以保证。

**问题位置**：
整个项目

**严重程度**：低

**修复建议**：
添加单元测试覆盖主要功能。

---

### 17. 选择器字符串未进行安全检查

**问题描述**：
选择器字符串直接传递给 DOM 查询方法，可能导致查询失败或异常。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：292-301, 303-316

**严重程度**：低

**代码片段**：
```typescript
querySelector(element: Element, selector: string): NodeInfo | null {
    let element2 = this.querySelf(element, selector)
    if (element2 == null) {
        element2 = element.querySelector(selector)  // 可能抛出异常
    }
    if (element2 != null) {
        return this.getNodeInfo(element2)
    }
    return null
}
```

**问题分析**：
1. 无效的选择器字符串会导致 querySelector 抛出异常
2. 没有 try-catch 保护
3. 可能导致整个查询流程中断

**修复建议**：
添加异常处理。

**优化后的代码**：
```typescript
querySelector(element: Element, selector: string): NodeInfo | null {
    if (selector == null || selector.trim().length === 0) {
        console.warn('[querySelector] Empty or invalid selector')
        return null
    }

    try {
        let element2 = this.querySelf(element, selector)
        if (element2 == null) {
            element2 = element.querySelector(selector)
        }
        if (element2 != null) {
            return this.getNodeInfo(element2)
        }
    } catch (error) {
        console.error(`[querySelector] Query failed for selector "${selector}":`, error)
    }

    return null
}

querySelectorAll(
    element: Element,
    selector: string,
): Array<NodeInfo> | null {
    if (selector == null || selector.trim().length === 0) {
        console.warn('[querySelectorAll] Empty or invalid selector')
        return null
    }

    const nodesInfoArray: Array<NodeInfo> = []

    try {
        const element2 = this.querySelf(element, selector)
        if (element2 != null) {
            nodesInfoArray.push(this.getNodeInfo(element))
        }

        const findNodes = element.querySelectorAll(selector)
        findNodes?.forEach((el: Element) => {
            nodesInfoArray.push(this.getNodeInfo(el))
        })
    } catch (error) {
        console.error(`[querySelectorAll] Query failed for selector "${selector}":`, error)
        return null
    }

    return nodesInfoArray
}
```

---

### 18. 代码注释不足

**问题描述**：
代码中缺少必要的注释说明，特别是复杂逻辑部分。

**问题位置**：
全部文件

**严重程度**：低

**修复建议**：
为关键方法和复杂逻辑添加注释。

---

### 19. 常量使用魔法数字

**问题描述**：
代码中存在魔法数字和字符串，应该提取为常量。

**问题位置**：
- 文件：`app-android/index.uts`
- 行号：245, 255-256, 320, 324-326, 329-330, 332-333

**严重程度**：低

**代码片段**：
```typescript
if (this._element.nodeName == '#comment') {
    // ...
}

const selectorType = selector.charAt(0)
if (selectorType == '.') {
    // ...
}
if (selectorType == '#') {
    // ...
}
```

**修复建议**：
提取常量。

**优化后的代码**：
```typescript
// 在文件顶部定义常量
const NODE_TYPE_COMMENT = '#comment'
const SELECTOR_TYPE_CLASS = '.'
const SELECTOR_TYPE_ID = '#'
const MIN_SELECTOR_LENGTH = 2

class QuerySelectorHelper {
    // ...

    query(selector: string, all: boolean): any | null {
        if (this._element.nodeName == NODE_TYPE_COMMENT) {
            return this.queryFragment(this._element, selector, all)
        } else {
            return all
                ? this.querySelectorAll(this._element, selector)
                : this.querySelector(this._element, selector)
        }
    }

    querySelf(element: Element | null, selector: string): Element | null {
        if (element == null || selector.length === 0) {
            return null
        }

        const selectorType = selector.charAt(0)
        const selectorName = selector.slice(1)

        if (selectorType == SELECTOR_TYPE_CLASS && element.classList.includes(selectorName)) {
            return element
        }
        if (selectorType == SELECTOR_TYPE_ID && element.getAttribute('id') == selectorName) {
            return element
        }
        if (selector.toUpperCase() == element.nodeName.toUpperCase()) {
            return element
        }

        return null
    }
}
```

---

## 性能优化建议

### 1. 批量查询优化

**建议**：
当有多个查询请求时，可以考虑合并选择器，减少 DOM 遍历次数。

**示例**：
```typescript
// 当前实现：每个选择器单独查询
queue.forEach((item: SelectorQueryRequest) => {
    const queryResult = QuerySelectorHelper.queryElement(el, item.selector, !item.single, item.fields)
    if (queryResult != null) {
        result.push(queryResult)
    }
})

// 优化方案：分析是否可以合并选择器
// 例如：多个 select() 可以合并为一个 selectAll()
```

### 2. 缓存 getBoundingClientRect 结果

**建议**：
对于同一元素的多次查询，可以缓存 rect 结果，避免重复计算。

### 3. 使用 IntersectionObserver 优化性能

**建议**：
对于频繁查询的场景，可以考虑使用 IntersectionObserver 来监听元素变化，而不是每次都主动查询。

---

## 代码规范问题

### 1. 命名不一致

**问题**：
- Android 实现使用 `_nodesRef!: NodesRef`（非空断言）
- HarmonyOS 实现使用 `_nodesRef?: NodesRef`（可选属性）

**建议**：统一使用可选属性，更安全。

### 2. 类型导出不一致

**问题**：
HarmonyOS 实现重新导出了类型，而 Android 实现没有。

**建议**：统一导出策略。

---

## 兼容性问题

### 1. Element 类型在不同平台的差异

**问题**：
Android 和 HarmonyOS 平台的 Element 实现可能不完全相同，需要注意 API 差异。

**建议**：
为每个平台的特殊方法添加条件编译或运行时检查。

---

## 总结

### 优先修复项（高危问题）

1. **空指针异常风险**：添加完善的空值检查
2. **内存泄漏风险**：实现队列清理机制
3. **类型安全问题**：替换 any 类型为具体类型
4. **异步错误捕获**：添加 try-catch 保护
5. **无限循环风险**：添加迭代次数限制

### 性能优化重点

1. 实现队列清理机制，防止内存泄漏
2. 按需获取节点信息，避免不必要的 getBoundingClientRect 调用
3. 批量查询优化
4. 添加结果缓存机制

### 代码质量提升

1. 移除不必要的 @ts-expect-error 注释
2. 消除代码重复（合并 exec 方法重载）
3. 添加完善的错误处理和日志
4. 补充单元测试
5. 完善注释文档

### 建议的开发流程改进

1. 引入 ESLint/TSLint 进行代码规范检查
2. 添加 CI/CD 流程，包含单元测试和代码质量检查
3. 使用静态分析工具检测潜在问题
4. 建立代码审查机制

---

## 附录：快速修复检查清单

- [ ] 修复 getCurrentPage() 空指针问题
- [ ] 实现队列清理机制
- [ ] 替换所有 any 类型
- [ ] 为所有回调添加 try-catch
- [ ] 为 while 循环添加迭代限制
- [ ] 合并重复的 exec 方法
- [ ] 修复 querySelf 的选择器长度判断
- [ ] 优化 getNodeInfo 按需获取信息
- [ ] 修复 _push 方法的数组长度一致性
- [ ] 为所有 DOM 查询添加异常处理
- [ ] 添加参数验证
- [ ] 提取魔法数字为常量
- [ ] 添加必要的日志输出
- [ ] 编写单元测试
- [ ] 完成 TODO 项或移除过时的注释

---

**生成时间**：2025-12-04
**分析工具**：AI Code Review
**分析版本**：1.0
