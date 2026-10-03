package com.pipis.pip_edit

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "pipedit/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> {
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                                Environment.isExternalStorageManager()
                        )
                    }
                    "requestAllFilesAccess" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "externalStorageRoot" -> {
                        result.success(
                            Environment.getExternalStorageDirectory().absolutePath
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}