## 使用说明

### uni.onMemoryWarning(function listener)

监听内存不足告警事件(目前仅Android)


当 Android 向小程序进程发出内存警告时，触发该事件。

触发该事件不意味应用被杀，大部分情况下仅仅是告警，开发者可在收到通知后回收一些不必要资源。

返回值说明:

```kotlin

/**
 * The device is beginning to run low on memory. Your app is running and not killable.
 */
int TRIM_MEMORY_RUNNING_MODERATE = 5;
/**
 * The device is running much lower on memory. Your app is running and not killable, but please release unused resources to improve system performance (which directly impacts your app's performance).
 */
int TRIM_MEMORY_RUNNING_LOW = 10;
/**
 * The device is running extremely low on memory. Your app is not yet considered a killable process, but the system will begin killing background processes if apps do not release resources, 
 * so you should release non-critical resources now to prevent performance degradation.
 */
int TRIM_MEMORY_RUNNING_CRITICAL = 15;
/**
 * The device is beginning to run low on memory. Your app is running and not killable.
 */
int TRIM_MEMORY_UI_HIDDEN = 20;
/**
 * The system is running low on memory and your process is near the beginning of the LRU list. 
 * Although your app process is not at a high risk of being killed, the system may already be killing processes in the LRU list, 
 * so you should release resources that are easy to recover so your process will remain in the list and resume quickly when the user returns to your app.
 */
int TRIM_MEMORY_BACKGROUND = 40;
/**
 * The system is running low on memory and your process is near the middle of the LRU list. 
 * If the system becomes further constrained for memory, 
 * there's a chance your process will be killed.
 */
int TRIM_MEMORY_MODERATE = 60;
/**
 * The system is running low on memory and your process is one of the first to be killed if the system does not recover memory now. 
 * You should release absolutely everything that's not critical to resuming your app state.
 */
int TRIM_MEMORY_COMPLETE = 80;

```


关于返回值的更多说明:[android官方文档](https://developer.android.com/reference/android/content/ComponentCallbacks2)

### uni.offMemoryWarning(function listener)

移除内存不足告警事件的监听函数(目前仅Android)

onMemoryWarning 传入的监听函数。不传此参数则移除所有监听函数。

