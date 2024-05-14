export type GetProviderSuccess = {
    /**
     * 服务类型
     * - oauth: 授权登录
     * - share: 分享
     * - payment: 支付
     * - push: 推送
     * - location: 定位
     * @type 'oauth' | 'share' | 'payment' | 'push' ｜ 'location'
     */
    service: 'oauth' | 'share' | 'payment' | 'push' | 'location',
    /**
     * 得到的服务供应商
     * @type PlusShareShareService['id'][] | PlusPushClientInfo['id'][] | PlusOauthAuthService['id'][] | PlusPaymentPaymentChannel['id'][]
     */
    provider: string[],
    /**
     * 描述信息
     */
    errMsg: string
};
export type GetProviderSuccessCallback = (result: GetProviderSuccess) => void;
export type GetProviderFail = UniError;
export type GetProviderFailCallback = (result: GetProviderFail) => void;
export type GetProviderComplete = any;
export type GetProviderCompleteCallback = (result: GetProviderComplete) => void;
export type GetProviderOptions = {
    /**
     * 服务类型，可取值“oauth”、“share”、“payment”、“push”、“location”
     * - oauth: 授权登录
     * - share: 分享
     * - payment: 支付
     * - push: 推送
     * - location: 定位
     * @type 'oauth' | 'share' | 'payment' | 'push' ｜ 'location'
     */
    service: 'oauth' | 'share' | 'payment' | 'push' | 'location',
    /**
     * 接口调用成功的回调
     */
    success?: GetProviderSuccessCallback | null,
    /**
     * 接口调用失败的回调函数
     */
    fail?: GetProviderFailCallback | null,
    /**
     * 接口调用结束的回调函数（调用成功、失败都会执行）
     */
    complete?: GetProviderCompleteCallback | null
};

export type GetProvider = (options: GetProviderOptions) => void;

export interface Uni {
  /**
   * 获取服务供应商
   * @param {GetProviderOptions} options
   * @return {void}
   * @tutorial https://doc.dcloud.net.cn/uni-app-x/api/get-provider.html
   * @uniPlatform {
   *  "app": {
   *    "android": {
   *      "osVer": "5.0",
   *      "uniVer": "√",
   *      "unixVer": "4.11"
   *    },
   *    "ios": {
   *      "osVer": "9.0",
   *      "uniVer": "√",
   *      "unixVer": "x"
   *    }
   *  },
   *  "web": {
   *    "uniVer": "√",
   *    "unixVer": "4.05"
   *  }
   * }
   * @example
    ```typescript
      uni.getProvider({service: ''})
    ```
   */
  getProvider(options: GetProviderOptions) : void;
}
