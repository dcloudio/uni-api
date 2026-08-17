package uts.sdk.modules.uniChooseSystemImage

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.URLConnection
import java.security.MessageDigest


object FileUtils {
    fun getFilePathByUri(context: Context, uri: Uri): String? {
        var path: String? = null
        // 以 file:// 开头的
        if (ContentResolver.SCHEME_FILE == uri.scheme) {
            path = uri.path
            return path
        }
        // 以 content:// 开头的，比如 content://media/extenral/images/media/17766
        if (ContentResolver.SCHEME_CONTENT == uri.scheme && Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            val cursor = context.contentResolver.query(
                uri,
                arrayOf(MediaStore.Images.Media.DATA),
                null,
                null,
                null
            )
            if (cursor != null) {
                if (cursor.moveToFirst()) {
                    val columnIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                    if (columnIndex > -1) {
                        path = cursor.getString(columnIndex)
                    }
                }
                cursor.close()
            }
            return path
        }
        // 4.4及之后的 是以 content:// 开头的，比如 content://com.android.providers.media.documents/document/image%3A235700
        if (ContentResolver.SCHEME_CONTENT == uri.scheme && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            if (DocumentsContract.isDocumentUri(context, uri)) {
                if (isExternalStorageDocument(uri)) {
                    // ExternalStorageProvider
                    val docId = DocumentsContract.getDocumentId(uri)
                    val split =
                        docId.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
                    val type = split[0]
                    if ("primary".equals(type, ignoreCase = true)) {
                        path = Environment.getExternalStorageDirectory().toString() + "/" + split[1]
                        return path
                    }
                } else if (isDownloadsDocument(uri)) {
                    // DownloadsProvider
                    val id = DocumentsContract.getDocumentId(uri)
                    val contentUri = ContentUris.withAppendedId(
                        Uri.parse("content://downloads/public_downloads"),
                        id.toLong()
                    )
                    path = getDataColumn(context, contentUri, null, null)
                    return path
                } else if (isMediaDocument(uri)) {
                    // MediaProvider
                    val docId = DocumentsContract.getDocumentId(uri)
                    val split =
                        docId.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
                    val type = split[0]
                    var contentUri: Uri? = null
                    if ("image" == type) {
                        contentUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    } else if ("video" == type) {
                        contentUri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    } else if ("audio" == type) {
                        contentUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                    }
                    val selection = "_id=?"
                    val selectionArgs = arrayOf(split[1])
                    path = getDataColumn(context, contentUri, selection, selectionArgs)
                    return path
                }
            }
        }
        return null
    }

    // 新增：将 uri 拷贝到传入的父文件夹，文件名为 uri 的 MD5，后缀从头信息或原文件名推断。
    // 若目标文件已存在则直接返回已存在路径，不重复拷贝。
    // 返回目标文件的绝对路径，失败返回 null。
    fun copyUriToDir(context: Context, parentDirStr: String, uriString: String): String? {
        try {
            var uri = Uri.parse(uriString)
            var parentDir = File(parentDirStr)
            val resolver = context.contentResolver
            // 读取全部数据到内存（用于判断 MIME 并写入目标文件）
            val inputStream = resolver.openInputStream(uri) ?: return null
            val baos = ByteArrayOutputStream()
            inputStream.use { ins ->
                val buf = ByteArray(8 * 1024)
                var len: Int
                while (ins.read(buf).also { len = it } != -1) {
                    baos.write(buf, 0, len)
                }
            }
            val data = baos.toByteArray()
            // 通过头信息猜 MIME
            var mime: String? = null
            try {
                mime = URLConnection.guessContentTypeFromStream(ByteArrayInputStream(data))
            } catch (_: Exception) {
            }
            if (mime == null) {
                try {
                    mime = resolver.getType(uri)
                } catch (_: Exception) {
                }
            }
            // 若仍为空，尝试从原始路径推断
            var originalPath: String? = null
            try {
                originalPath = getFilePathByUri(context, uri)
            } catch (_: Exception) {
            }
            // 根据 mime 获取扩展名
            var ext: String? = null
            if (mime != null) {
                ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
            }
            // 如果通过 mime 无法得到扩展名，尝试从原始路径取后缀
            if (ext.isNullOrEmpty() && !originalPath.isNullOrEmpty()) {
                val idx = originalPath.lastIndexOf('.')
                if (idx != -1 && idx + 1 < originalPath.length) {
                    ext = originalPath.substring(idx + 1).lowercase()
                }
            }
            val extSuffix = if (!ext.isNullOrEmpty()) ".${ext}" else ""
            // 计算 MD5 作为文件名（基于 uri.toString()）
            val name = md5(uri.toString()) + extSuffix
            // 确保父目录存在
            if (!parentDir.exists()) {
                parentDir.mkdirs()
            }
            val destFile = File(parentDir, name)
            // 若已存在，直接返回
            if (destFile.exists()) {
                return destFile.absolutePath
            }
            // 写入文件
            FileOutputStream(destFile).use { fos ->
                fos.write(data)
                fos.flush()
            }
            return destFile.absolutePath
        } catch (e: Exception) {
            // 出错返回 null
            return null
        }
    }

    // 辅助：计算字符串的 MD5（小写 hex）
    private fun md5(input: String): String {
        val md = MessageDigest.getInstance("MD5")
        val bytes = md.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun getDataColumn(
        context: Context,
        uri: Uri?,
        selection: String?,
        selectionArgs: Array<String>?,
    ): String? {
        var cursor: Cursor? = null
        val column = "_data"
        val projection = arrayOf(column)
        try {
            cursor =
                context.contentResolver.query(uri!!, projection, selection, selectionArgs, null)
            if (cursor != null && cursor.moveToFirst()) {
                val column_index = cursor.getColumnIndexOrThrow(column)
                return cursor.getString(column_index)
            }
        } finally {
            cursor?.close()
        }
        return null
    }

    private fun isExternalStorageDocument(uri: Uri): Boolean {
        return "com.android.externalstorage.documents" == uri.authority
    }

    private fun isDownloadsDocument(uri: Uri): Boolean {
        return "com.android.providers.downloads.documents" == uri.authority
    }

    private fun isMediaDocument(uri: Uri): Boolean {
        return "com.android.providers.media.documents" == uri.authority
    }


}