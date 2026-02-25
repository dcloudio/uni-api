package uts.sdk.modules.DCloudUniOauthWeixin

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import com.tencent.mm.opensdk.constants.ConstantsAPI
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import uts.sdk.modules.uniOauthWeixin.UniOAuthWeixinProviderImpl

class WXEntryActivity : Activity(), IWXAPIEventHandler {

    private val api by lazy {
        WXAPIFactory.createWXAPI(this, getMetaData("WX_APPID"))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        api.handleIntent(intent, this)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        api.handleIntent(intent, this)
    }

    override fun onResp(resp: BaseResp) {
        if (resp.type == ConstantsAPI.COMMAND_SENDAUTH) {
            UniOAuthWeixinProviderImpl.onLoginResult(resp)
        }
        finish()
    }

    override fun onReq(req: BaseReq) {
        finish()
    }

    private fun getMetaData(key: String): String {
        val metaData = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA).metaData
        return metaData.getString(key, "")
    }
}