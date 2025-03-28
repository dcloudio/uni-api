import { hidebug } from '@kit.PerformanceAnalysisKit';

let systemMemInfo: hidebug.SystemMemInfo = hidebug.getSystemMemInfo();

type MemoryInfoChangeCallback = (memInfo: number[]) => void

export class MemoryInfoNative {
  private static _memoryInfoChangeCallbacks: MemoryInfoChangeCallback[] = []
  private static _interval: number = -1
  static onMemoryInfoChangeArkts(callback: MemoryInfoChangeCallback) {
    MemoryInfoNative._memoryInfoChangeCallbacks.push(callback)
    if(MemoryInfoNative._interval = -1) {
      MemoryInfoNative._interval = setInterval(() => {
        const memInfo = MemoryInfoNative.getMemInfoArkts()
        MemoryInfoNative._memoryInfoChangeCallbacks.forEach(callback => {
          callback(memInfo)
        })
      }, 2000)
    }
  }
  static offMemoryInfoChangeArkts() {
    MemoryInfoNative._memoryInfoChangeCallbacks = []
    clearInterval(MemoryInfoNative._interval)
    MemoryInfoNative._interval = -1
  }
  static getMemInfoArkts(): number[] {
    let systemMemInfo: hidebug.SystemMemInfo = hidebug.getSystemMemInfo();
    return [Number(systemMemInfo.freeMem / 1024n), Number(systemMemInfo.totalMem / 1024n)]
  }
}