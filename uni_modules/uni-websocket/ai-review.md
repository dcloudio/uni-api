# uni-websocket 插件代码评审报告

## 插件概述
- **功能**: 实现WebSocket连接和通信功能
- **支持平台**: Android、iOS、HarmonyOS
- **实现方式**: 使用单例WebSocketManager管理所有WebSocket连接
- **实现文件**:
  - Android: `utssdk/app-android/index.uts` + `websocket/WebSocketManager.uts`
  - iOS: `utssdk/app-ios/index.uts`
  - HarmonyOS: `utssdk/app-harmony/index.uts`

---

## 架构设计问题

### 1. 单例模式的状态管理风险
**位置**: index.uts全部函数

**代码示例**:
```typescript
export const connectSocket : ConnectSocket = (options : ConnectSocketOptions) : SocketTask => {
	return WebSocketManager.getInstance().connectSocket(options);
}

export const sendSocketMessage : SendSocketMessage = (options : SendSocketMessageOptions) : void => {
	return WebSocketManager.getInstance().sendSocketMessage(options);
}
```

**问题描述**:
1. 所有WebSocket操作都通过单例WebSocketManager处理
2. 全局的onSocketOpen/onSocketMessage等回调可能与多个连接冲突
3. 如果用户同时建立多个WebSocket连接,全局回调会覆盖

**潜在风险**:
```typescript
// 用户代码
uni.onSocketOpen(() => {
  console.log('连接1打开')
})

let socket1 = uni.connectSocket({url: 'ws://server1'})

uni.onSocketOpen(() => {
  console.log('连接2打开') // 覆盖了前面的回调!
})

let socket2 = uni.connectSocket({url: 'ws://server2'})
```

**修复方案**:
1. 让connectSocket返回的SocketTask对象持有独立的回调
2. 弃用全局onSocketOpen等方法,改为SocketTask的实例方法
3. 或在文档中明确说明只支持单个WebSocket连接

### 2. API设计不一致
**位置**: 全局函数vs SocketTask方法

**问题描述**:
- `sendSocketMessage`和`closeSocket`是全局函数,但需要操作特定连接
- 没有提供socketTask参数,无法指定操作哪个连接
- 与connectSocket返回SocketTask的设计不一致

**正确的API设计应该是**:
```typescript
let task = uni.connectSocket({url: 'ws://...'})

// 方式1: 使用SocketTask的方法
task.send({data: 'hello'})
task.close()
task.onOpen(() => {})
task.onMessage((res) => {})

// 方式2: 全局方法接受task参数
uni.sendSocketMessage({socketTask: task, data: 'hello'})
```

---

## 代码质量问题

### 1. 缺少输入参数验证
**位置**: 所有导出函数

**问题描述**:
```typescript
export const connectSocket : ConnectSocket = (options : ConnectSocketOptions) : SocketTask => {
	return WebSocketManager.getInstance().connectSocket(options);
}
```

没有验证:
- options是否为null
- options.url是否有效
- options.url是否是合法的WebSocket URL(ws://或wss://)

**修复方案**:
```typescript
export const connectSocket : ConnectSocket = (options : ConnectSocketOptions) : SocketTask => {
	if (options == null) {
		console.error('[connectSocket] options不能为空')
		throw new Error('options不能为空')
	}

	if (options.url == null || options.url.trim().length == 0) {
		console.error('[connectSocket] url不能为空')
		throw new Error('url不能为空')
	}

	if (!options.url.startsWith('ws://') && !options.url.startsWith('wss://')) {
		console.error('[connectSocket] url必须以ws://或wss://开头')
		throw new Error('url格式错误')
	}

	return WebSocketManager.getInstance().connectSocket(options);
}
```

### 2. 缺少错误处理
**位置**: 所有函数

**问题描述**:
函数直接调用WebSocketManager的方法,没有try-catch包裹,如果出错会直接抛异常。

**修复方案**:
```typescript
export const connectSocket : ConnectSocket = (options : ConnectSocketOptions) : SocketTask => {
	try {
		// 参数验证...
		return WebSocketManager.getInstance().connectSocket(options);
	} catch (e) {
		console.error('[connectSocket] 创建连接失败:', e)
		// 返回一个错误状态的SocketTask或触发fail回调
		options.fail?.({
			errMsg: `connectSocket:fail ${e.message}`
		})
		throw e
	}
}
```

### 3. 缺少日志记录
**位置**: 整个文件

**问题描述**:
没有任何日志输出,不利于调试和问题排查。

**修复方案**:
```typescript
export const connectSocket : ConnectSocket = (options : ConnectSocketOptions) : SocketTask => {
	console.log(`[connectSocket] 开始连接: ${options.url}`)
	let task = WebSocketManager.getInstance().connectSocket(options);
	console.log(`[connectSocket] 连接已创建, taskId: ${task.id}`)
	return task
}

export const sendSocketMessage : SendSocketMessage = (options : SendSocketMessageOptions) : void => {
	console.log(`[sendSocketMessage] 发送消息, 数据类型: ${typeof options.data}`)
	return WebSocketManager.getInstance().sendSocketMessage(options);
}
```

---

## 功能完整性问题

### 1. 缺少连接状态查询
**问题描述**:
用户无法查询WebSocket的当前状态(CONNECTING, OPEN, CLOSING, CLOSED)。

**建议**:
```typescript
// 添加新的API
export function getSocketState(socketTask: SocketTask): number {
	return WebSocketManager.getInstance().getSocketState(socketTask)
}

// 或者在SocketTask上添加状态属性
interface SocketTask {
	readyState: number  // 0=CONNECTING, 1=OPEN, 2=CLOSING, 3=CLOSED
	// ...
}
```

### 2. 缺少重连机制
**问题描述**:
WebSocket断线后没有自动重连机制,需要用户手动处理。

**建议**:
1. 在ConnectSocketOptions中添加reconnect相关配置
2. 提供reconnect方法
3. 在文档中说明重连策略

```typescript
interface ConnectSocketOptions {
	url: string
	autoReconnect?: boolean  // 是否自动重连
	reconnectInterval?: number  // 重连间隔(ms)
	maxReconnectAttempts?: number  // 最大重连次数
	// ...
}
```

### 3. 缺少心跳机制
**问题描述**:
长连接场景下需要定期发送心跳包保持连接,但没有内置心跳机制。

**建议**:
```typescript
interface ConnectSocketOptions {
	heartbeat?: {
		enabled: boolean
		interval: number  // 心跳间隔(ms)
		message: string   // 心跳消息内容
	}
}
```

### 4. 缺少连接池管理
**问题描述**:
如果用户创建大量WebSocket连接但不关闭,可能导致资源泄漏。

**建议**:
1. 限制最大连接数
2. 自动清理长时间不活跃的连接
3. 提供getAllConnections方法查看活跃连接

---

## 性能问题

### 1. getInstance可能的性能开销
**位置**: 每个函数调用都调用getInstance()

**问题描述**:
虽然单例模式理论上只创建一次实例,但每次函数调用都要执行getInstance()。

**影响**:
在高频消息发送场景下可能有轻微性能影响。

**修复方案**:
```typescript
// 在模块加载时就获取实例
const wsManager = WebSocketManager.getInstance()

export const connectSocket : ConnectSocket = (options : ConnectSocketOptions) : SocketTask => {
	return wsManager.connectSocket(options);
}

export const sendSocketMessage : SendSocketMessage = (options : SendSocketMessageOptions) : void => {
	return wsManager.sendSocketMessage(options);
}
```

### 2. 缺少消息队列管理
**问题描述**:
如果在WebSocket未连接完成时就发送消息,可能丢失或出错。应该有消息队列机制。

**建议**:
1. 连接建立前的消息放入队列
2. 连接成功后自动发送队列中的消息
3. 提供队列大小限制避免内存溢出

---

## 安全问题

### 1. 缺少URL安全验证
**问题描述**:
没有验证WebSocket URL的安全性:
- 是否是合法域名
- 是否使用wss://加密连接(生产环境)
- 是否有SQL注入或XSS风险

**建议**:
```typescript
function validateWebSocketUrl(url: string): boolean {
	// 检查协议
	if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
		return false
	}

	// 生产环境建议使用wss://
	if (isProduction() && url.startsWith('ws://')) {
		console.warn('[WebSocket] 生产环境建议使用wss://加密连接')
	}

	// 检查URL格式
	try {
		new URL(url)
		return true
	} catch (e) {
		return false
	}
}
```

### 2. 缺少消息大小限制
**问题描述**:
没有限制单次发送的消息大小,恶意代码可能发送超大消息导致:
- 内存溢出
- 网络拥塞
- 应用崩溃

**建议**:
```typescript
const MAX_MESSAGE_SIZE = 1024 * 1024 // 1MB

export const sendSocketMessage : SendSocketMessage = (options : SendSocketMessageOptions) : void => {
	let dataSize = calculateDataSize(options.data)
	if (dataSize > MAX_MESSAGE_SIZE) {
		console.error(`[sendSocketMessage] 消息过大: ${dataSize} bytes, 最大允许: ${MAX_MESSAGE_SIZE} bytes`)
		options.fail?.({
			errMsg: 'sendSocketMessage:fail 消息过大'
		})
		return
	}

	return WebSocketManager.getInstance().sendSocketMessage(options);
}
```

---

## 总结

### 优先级分类

**高优先级（建议立即修复）**:
1. 添加输入参数验证,防止null引用和非法URL
2. 修复API设计问题,明确多连接场景的行为
3. 添加错误处理,避免未捕获异常

**中优先级（建议近期修复）**:
1. 添加连接状态查询API
2. 添加日志记录
3. 添加消息大小限制
4. 优化getInstance调用

**低优先级（可选优化）**:
1. 添加自动重连机制
2. 添加心跳机制
3. 添加连接池管理
4. 添加消息队列管理

### 整体评价
uni-websocket插件实现简洁,使用单例模式管理WebSocket连接。但存在几个重要问题:
1. API设计存在缺陷,全局回调vs实例方法不一致
2. 缺少基本的参数验证和错误处理
3. 多连接场景下的行为不明确
4. 缺少生产环境必需的功能(重连、心跳、状态查询)

建议优先修复API设计和参数验证问题,然后补充重连、心跳等核心功能。该插件需要重点关注多连接场景的测试。
