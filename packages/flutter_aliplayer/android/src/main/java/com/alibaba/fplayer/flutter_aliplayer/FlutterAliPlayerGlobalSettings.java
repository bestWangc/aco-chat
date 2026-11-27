package com.alibaba.fplayer.flutter_aliplayer;

import android.annotation.SuppressLint;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.aliyun.aio.aio_env.AlivcEnv;
import com.aliyun.common.AlivcBase;
import com.aliyun.player.AliPlayerGlobalSettings;

import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * @author junhuiYe
 * @date 2024/11/19
 * @brief
 */
@SuppressLint("LongLogTag")
public class FlutterAliPlayerGlobalSettings implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel mMethodChannel;
    private final String TAG = "FlutterAliPlayerGlobalSettings";
    private volatile FlutterInvokeCallback flutterInvokeCallback;

    public FlutterAliPlayerGlobalSettings(Context context, FlutterPlugin.FlutterPluginBinding flutterPluginBinding) {
        flutterInvokeCallback = new FlutterInvokeCallback(context, flutterPluginBinding);
        this.mMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "plugins.flutter_global_setting");
        this.mMethodChannel.setMethodCallHandler(this);
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {

    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "setGlobalEnvironment":
                setGlobalEnvironment((Integer) call.arguments());
                result.success(null);
                break;
            case "setOption":
                Map<String, Object> args = call.arguments();
                setOption((Integer) args.get("opt1"), args.get("opt2"));
                result.success(null);
                break;
            case "disableCrashUpload":
                AliPlayerGlobalSettings.disableCrashUpload((Boolean) call.arguments());
                break;
            case "enableEnhancedHttpDns":
                AliPlayerGlobalSettings.enableEnhancedHttpDns((Boolean) call.arguments());
                break;
            case "setCacheUrlHashCallback":
                AliPlayerGlobalSettings.setCacheUrlHashCallback(url -> {
                    FlutterInvokeCallback callback = flutterInvokeCallback;
                    if (callback != null) {
                        String newUrl = (String) callback.invokeOneParameterFlutterCallback(url, "getUrlHashCallback");
                        return newUrl != null ? newUrl : url;
                    }
                    return url;
                });
                break;
            case "setNetworkCallback":
                AliPlayerGlobalSettings.setNetworkCallback((s, byteBuffer, l, byteBuffer1) -> {
                    FlutterInvokeCallback callback = flutterInvokeCallback;
                    if (callback != null) {
                        return (Boolean) callback.invokeFourParameterFlutterCallback(s, byteBuffer, l, byteBuffer1, "onNetworkDataProcess");
                    }
                    return false;
                });
                break;
            case "setAdaptiveDecoderGetBackupURLCallback":
                AliPlayerGlobalSettings.setAdaptiveDecoderGetBackupURLCallback((oriBizScene, oriCodecType, original_url) -> {
                    FlutterInvokeCallback callback = flutterInvokeCallback;
                    if (callback != null) {
                        return (String) callback.invokeThreeParameterFlutterCallback(oriBizScene, oriCodecType, original_url, "getBackupUrlCallback");
                    }
                    return null;
                });
                break;
            default:
                break;
        }
    }

    private void setOption(int opt1, Object opt2) {
        if (opt2 instanceof Integer) {
            AliPlayerGlobalSettings.setOption(opt1, (Integer) opt2);
        } else if (opt2 instanceof String) {
            AliPlayerGlobalSettings.setOption(opt1, (String) opt2);
        }
    }

    private void setGlobalEnvironment(int GlobalEnv) {
        switch (GlobalEnv) {
            case 1:
                AlivcBase.getEnvironmentManager().setGlobalEnvironment(AlivcEnv.GlobalEnv.ENV_CN);
                break;
            case 2:
                AlivcBase.getEnvironmentManager().setGlobalEnvironment(AlivcEnv.GlobalEnv.ENV_SEA);
                break;
            case 3:
                AlivcBase.getEnvironmentManager().setGlobalEnvironment(AlivcEnv.GlobalEnv.ENV_GLOBAL_OVERSEA);
                break;
            default:
                AlivcBase.getEnvironmentManager().setGlobalEnvironment(AlivcEnv.GlobalEnv.ENV_DEFAULT);
                break;
        }
    }

    public void destroy() {
        if (mMethodChannel != null) {
            mMethodChannel.setMethodCallHandler(null);
            mMethodChannel = null;
        }
        flutterInvokeCallback = null;
    }
}
