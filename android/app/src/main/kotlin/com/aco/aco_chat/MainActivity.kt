package com.aco.aco_chat

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
                if (call.method != "authenticate") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                authenticateWithBiometrics(result)
            }
    }

    private fun authenticateWithBiometrics(result: MethodChannel.Result) {
        val authenticators = BiometricManager.Authenticators.BIOMETRIC_WEAK
        when (BiometricManager.from(this).canAuthenticate(authenticators)) {
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE,
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED,
            BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED -> {
                result.success(true)
                return
            }
            BiometricManager.BIOMETRIC_SUCCESS -> Unit
            else -> {
                result.success(false)
                return
            }
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
            .setSubtitle("验证身份以完成钱包创建")
            .setNegativeButtonText("取消")
            .setAllowedAuthenticators(authenticators)
            .build()
        prompt.authenticate(promptInfo)
    }
}
