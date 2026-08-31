package com.aco.aco_chat

import android.content.ContentValues
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
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
                if (call.method != "saveText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val filename = call.argument<String>("filename") ?: "aco-chat.txt"
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("INVALID_DATA", "文件内容为空", null)
                    return@setMethodCallHandler
                }
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
                        val intent = Intent(this, LiveAudioForegroundService::class.java)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aco/live-audio-route")
            .setMethodCallHandler { call, result ->
                if (call.method != "routeInfo") {
                    result.notImplemented()
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
