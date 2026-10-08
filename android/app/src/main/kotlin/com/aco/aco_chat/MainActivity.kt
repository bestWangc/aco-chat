package com.aco.aco_chat

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingImageSave: Pair<ByteArray, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aco/sensitive-screen")
            .setMethodCallHandler { call, result ->
                if (call.method != "setEnabled") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled) window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aco/biometric-authentication")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "availability" -> result.success(biometricAvailability())
                    "authenticate" -> authenticateWithBiometrics(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aco/downloads")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveText" && call.method != "saveImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("INVALID_DATA", "文件内容为空", null)
                    return@setMethodCallHandler
                }
                if (call.method == "saveImage") {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                        checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingImageSave = bytes to result
                        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 4203)
                    } else {
                        saveImage(bytes, result)
                    }
                    return@setMethodCallHandler
                }
                val filename = call.argument<String>("filename") ?: "aco-chat.txt"
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, filename)
                        put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            put(MediaStore.Downloads.IS_PENDING, 1)
                        }
                    }
                    val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("无法创建下载文件")
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                        ?: throw IllegalStateException("无法写入下载文件")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        values.clear()
                        values.put(MediaStore.Downloads.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                    }
                    result.success(uri.toString())
                } catch (error: Exception) {
                    result.error("SAVE_FAILED", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aco/live-audio-background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val useMicrophone = call.argument<Boolean>("microphone") ?: false
                        val intent = Intent(this, LiveAudioForegroundService::class.java).apply {
                            putExtra(
                                LiveAudioForegroundService.EXTRA_USE_MICROPHONE,
                                useMicrophone,
                            )
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, LiveAudioForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aco/chat-background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4202)
                        }
                        val intent = Intent(this, ChatKeepAliveService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, ChatKeepAliveService::class.java))
                        result.success(null)
                    }
                    "openBackgroundSettings" -> {
                        startActivity(
                            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            },
                        )
                        result.success(null)
                    }
                    "showMessage" -> {
                        val title = call.argument<String>("title") ?: "新消息"
                        val body = call.argument<String>("body") ?: "你收到一条新消息"
                        val urgent = call.argument<Boolean>("urgent") ?: false
                        ChatKeepAliveService.showMessage(applicationContext, title, body, urgent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aco/live-audio-route")
            .setMethodCallHandler { call, result ->
                if (call.method != "routeInfo") {
                    if (call.method == "forceSpeaker") {
                        val audioManager = getSystemService(AudioManager::class.java)
                        if (hasBluetoothOutput(audioManager)) {
                            // Let Android/LiveKit keep the connected headset route.
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val speaker = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                            result.success(speaker != null && audioManager.setCommunicationDevice(speaker))
                        } else {
                            audioManager.isSpeakerphoneOn = true
                            result.success(audioManager.isSpeakerphoneOn)
                        }
                    } else {
                        result.notImplemented()
                    }
                    return@setMethodCallHandler
                }
                val audioManager = getSystemService(AudioManager::class.java)
                val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    .map { device ->
                        mapOf(
                            "type" to device.type,
                            "name" to device.productName.toString(),
                            "selected" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                                audioManager.communicationDevice?.id == device.id),
                        )
                    }
                result.success(
                    mapOf(
                        "mode" to audioManager.mode,
                        "speakerphoneOn" to audioManager.isSpeakerphoneOn,
                        "communicationDevice" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            audioManager.communicationDevice?.productName?.toString()
                        } else null),
                        "outputs" to outputs,
                    ),
                )
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4203) return
        val pending = pendingImageSave ?: return
        pendingImageSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            saveImage(pending.first, pending.second)
        } else {
            pending.second.error("PERMISSION_DENIED", "未获得相册权限", null)
        }
    }

    private fun saveImage(bytes: ByteArray, result: MethodChannel.Result) {
        val isPng = bytes.size > 3 && bytes[0] == 0x89.toByte() && bytes[1] == 0x50.toByte()
        val isGif = bytes.size > 3 && String(bytes, 0, 3) == "GIF"
        val isWebp = bytes.size > 12 && String(bytes, 8, 4) == "WEBP"
        val extension = when {
            isPng -> "png"
            isGif -> "gif"
            isWebp -> "webp"
            else -> "jpg"
        }
        val mimeType = when {
            isPng -> "image/png"
            isGif -> "image/gif"
            isWebp -> "image/webp"
            else -> "image/jpeg"
        }
        var uri: Uri? = null
        try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "aco-chat-${System.currentTimeMillis()}.$extension")
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Aco Chat")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("无法创建图片")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("无法写入图片")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            if (uri != null) contentResolver.delete(uri, null, null)
            result.error("SAVE_FAILED", error.message, null)
        }
    }

    private fun hasBluetoothOutput(audioManager: AudioManager): Boolean =
        audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { device ->
            when (device.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> true
                AudioDeviceInfo.TYPE_BLE_HEADSET ->
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                else -> false
            }
        }


    private fun authenticateWithBiometrics(result: MethodChannel.Result) {
        if (biometricAvailability() != "enrolled") {
            result.success(false)
            return
        }
        val prompt = BiometricPrompt(
            this,
            ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult,
                ) {
                    result.success(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    result.success(false)
                }
            },
        )
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("验证身份")
            .setSubtitle("使用指纹或人脸完成钱包创建")
            // Android requires a non-empty negative action when the prompt is
            // configured without device-credential fallback.
            .setNegativeButtonText("取消")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK)
            .build()
        prompt.authenticate(promptInfo)
    }

    private fun biometricAvailability(): String = when (
        BiometricManager.from(this).canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_WEAK,
        )
    ) {
        BiometricManager.BIOMETRIC_SUCCESS -> "enrolled"
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "not_enrolled"
        else -> "unavailable"
    }
}
