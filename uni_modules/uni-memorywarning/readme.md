## 使用说明

### uni.onMemoryWarning(function listener)

监听内存不足告警事件


当系统应用进程发出内存警告时，触发该事件。

触发该事件不意味应用被杀，大部分情况下仅仅是告警，开发者可在收到通知后回收一些不必要资源。

返回值说明: 

**注意平台差异：仅Android平台有返回值，iOS平台无返回值**

```kotlin

/**
 * The device is beginning to run low on memory. Your app is running and not killable.
 * 设备内存偏低
 */
int TRIM_MEMORY_RUNNING_MODERATE = 5;
/**
 * The device is running much lower on memory. 
 * Your app is running and not killable, but please release unused resources to improve system performance (which directly impacts your app's performance).
 * 内存设备偏低，虽然还不会杀死应用，但是建议开发者释放不必要的资源
 */
int TRIM_MEMORY_RUNNING_LOW = 10;
/**
 * The device is running extremely low on memory. 
 * Your app is not yet considered a killable process, but the system will begin killing background processes if apps do not release resources, 
 * so you should release non-critical resources now to prevent performance degradation.
 * 设备内存进一步吃紧，当前应用不会被考虑杀死，但是系统可能会杀死一些优先级更低的后台应用
 * 建议释放一些非关键资源
 */
int TRIM_MEMORY_RUNNING_CRITICAL = 15;
/**
 * the process had been showing a user interface, and is no longer doing so.
 * 当前应用前台UI已经被隐藏
 */
int TRIM_MEMORY_UI_HIDDEN = 20;
/**
 * The system is running low on memory and your process is near the beginning of the LRU list. 
 * Although your app process is not at a high risk of being killed, the system may already be killing processes in the LRU list, 
 * so you should release resources that are easy to recover so your process will remain in the list and resume quickly when the user returns to your app.
 * LRU算法列表中的应用已经被考虑杀死
 */
int TRIM_MEMORY_BACKGROUND = 40;
/**
 * The system is running low on memory and your process is near the middle of the LRU list. 
 * If the system becomes further constrained for memory, 
 * there's a chance your process will be killed.
 * LRU列表中的大部分应用已经被杀死
 */
int TRIM_MEMORY_MODERATE = 60;
/**
 * The system is running low on memory and your process is one of the first to be killed if the system does not recover memory now. 
 * You should release absolutely everything that's not critical to resuming your app state.
 * 当前应用将会是下一个被释放的进程
 */
int TRIM_MEMORY_COMPLETE = 80;

```


关于返回值的更多说明:[android官方文档](https://developer.android.com/reference/android/content/ComponentCallbacks2)

### uni.offMemoryWarning(function listener)

移除内存不足告警事件的监听函数

onMemoryWarning 传入的监听函数。不传此参数则移除所有监听函数。

