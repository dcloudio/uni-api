package uts.sdk.modules.uniChooseSystemImage

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.text.TextUtils
import android.view.WindowManager
import android.widget.LinearLayout
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.VisualMediaType
import androidx.fragment.app.FragmentActivity
import java.util.Locale


class ChooseSystemImageActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setStatusBarTransparent(this)
        val layout = LinearLayout(this)
        layout.setBackgroundColor(Color.TRANSPARENT)
        setContentView(layout)
        if (intent.hasExtra("page_orientation")) {
            requestedOrientation =
                intent.getIntExtra("page_orientation", ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)
        }
        val count = intent.getIntExtra("count", 9)
        val type = intent.getIntExtra("type", 1)
        val mediaType: VisualMediaType = when (type) {
            1 -> {
                ActivityResultContracts.PickVisualMedia.ImageOnly
            }

            2 -> {
                ActivityResultContracts.PickVisualMedia.VideoOnly
            }

            3 -> {
                ActivityResultContracts.PickVisualMedia.ImageAndVideo
            }

            else -> {
                ActivityResultContracts.PickVisualMedia.ImageOnly
            }
        }
        val pickMultipleMedia = if (count == 1) {
            this.registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
                val intent = Intent()
                if (uri != null) {
                    this.contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                    var path = FileUtils.getFilePathByUri(this, uri)
                    if (TextUtils.isEmpty(path)) {
                        path = getFilePathFromUri(uri)
                    }
                    val mediaT = this.contentResolver.getType(uri)?.lowercase(Locale.ENGLISH)
                    val m = Media(
                        if (mediaT?.startsWith("video/") == true) {
                            2
                        } else if (mediaT?.startsWith("image/") == true) {
                            1
                        } else {
                            0
                        }, path
                    )
                    intent.putExtra("paths", arrayOf(m))
                    this.setResult(RESULT_OK, intent)
                    this.finish()
                } else {
                    this.setResult(RESULT_OK, intent)
                    this.finish()
                }
            }
        } else
            this.registerForActivityResult(
                ActivityResultContracts.PickMultipleVisualMedia(count)
            ) { result ->
                val paths = mutableListOf<Media>()
                for (uri in result) {
                    this.contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                    var path = FileUtils.getFilePathByUri(this, uri)
                    if (TextUtils.isEmpty(path)) {
                        path = getFilePathFromUri(uri)
                    }
                    val mediaT = this.contentResolver.getType(uri)?.lowercase(Locale.ENGLISH)
                    val m = Media(
                        if (mediaT?.startsWith("video/") == true) {
                            2
                        } else if (mediaT?.startsWith("image/") == true) {
                            1
                        } else {
                            0
                        }, path
                    )
                    paths.add(m)
                }
                val intent = Intent()
                intent.putExtra("paths", paths.toTypedArray())
                this.setResult(RESULT_OK, intent)
                this.finish()
            }
        pickMultipleMedia.launch(
            PickVisualMediaRequest.Builder()
                .setMediaType(mediaType)
                .build()
        )
    }

    private fun getFilePathFromUri(uri: Uri): String? {
        var filePath: String? = null
        if (uri.scheme == "file") {
            filePath = uri.path
        } else if (uri.scheme == "content") {
            val contentResolver = contentResolver
            val cursor =
                contentResolver.query(uri, arrayOf(MediaStore.Images.Media.DATA), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val columnIndex = cursor.getColumnIndex("_data")
                filePath = cursor.getString(columnIndex)
                cursor.close()
            }
        }
        return filePath
    }

    private fun setStatusBarTransparent(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT && Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            val window = activity.window
            // 设置透明状态栏标志
            window.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS
                        or WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION
            )
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            window.statusBarColor = Color.TRANSPARENT
        }
    }
}