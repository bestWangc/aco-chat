package com.alivc.livepush;

import android.content.Context;

import com.alivc.live.pusher.AlivcLiveBase;
import com.alivc.live.pusher.AlivcLiveBaseListener;
import com.alivc.live.pusher.AlivcLivePushConstants;
import com.alivc.live.pusher.AlivcLivePushInstance;
import com.alivc.live.pusher.AlivcLivePushLogLevel;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class LiveBase {

    private static final String LIVE_BASE_EVENT_NAME = "plugins.livebase.event";

    private final Context mContext;
    private EventChannel.EventSink mEvents;

    public LiveBase(FlutterPlugin.FlutterPluginBinding flutterPluginBinding) {
        this.mContext = flutterPluginBinding.getApplicationContext();
        EventChannel livePushBaseEventChannel = new EventChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), LIVE_BASE_EVENT_NAME);
        livePushBaseEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                mEvents = events;
            }

            @Override
            public void onCancel(Object arguments) {
                mEvents = null;
            }
        });
    }

    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "getSdkVersion":
                String sdkVersion = AlivcLiveBase.getSDKVersion();
                result.success(sdkVersion);
                break;
            case "registerSDK":
                AlivcLivePushInstance.loadInstance(mContext);
                AlivcLiveBase.registerSDK();
                result.success(null);
                break;
            case "setListener":
                AlivcLiveBase.setListener(new AlivcLiveBaseListener() {
                    @Override
                    public void onLicenceCheck(AlivcLivePushConstants.AlivcLiveLicenseCheckResultCode alivcLiveLicenseCheckResultCode, String s) {
                        if (mEvents != null) {
                            Map<String, Object> result = new HashMap<>();
                            result.put("method", "onLicenceCheck");
                            result.put("result", alivcLiveLicenseCheckResultCode.getValue() + "");
                            result.put("reason", s);
                            mEvents.success(result);
                        }
                    }
                });
                result.success(null);
                break;
            case "setLogLevel":
                String logLevel = call.argument("arg");
                if (logLevel != null) {
                    switch (logLevel) {
                        case "0":
                            AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelAll);
                            break;
                        case "1":
                            AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelVerbose);
                            break;
                        case "2":
                            AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelDebug);
                            break;
                        case "3":
                            AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelInfo);
                            break;
                        case "4":
                            AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelWarn);
                            break;
                        case "5":
                            AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelError);
                            break;
                        case "6":
                            AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelNone);
                            break;
                    }
                }
                result.success(null);
                break;
            case "setConsoleEnable":
                String enableConsole = call.argument("arg");
                if (enableConsole != null) {
                    AlivcLiveBase.setConsoleEnabled(enableConsole.equals("1"));
                }
                result.success(null);
                break;
            case "setLogPath":
                Map<String, Object> setLogPathMap = call.argument("arg");
                if (setLogPathMap != null) {
                    String logPath = (String) setLogPathMap.get("logPath");
                    String maxPartFileSizeInKB = (String) setLogPathMap.get("maxPartFileSizeInKB");
                    AlivcLiveBase.setLogDirPath(logPath, Integer.parseInt(maxPartFileSizeInKB));
                }
                result.success(null);
                break;
        }
    }
}
