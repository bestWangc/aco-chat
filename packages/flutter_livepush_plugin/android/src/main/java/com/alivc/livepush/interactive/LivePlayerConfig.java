package com.alivc.livepush.interactive;

import com.alivc.live.player.AlivcLivePlayConfig;
import com.alivc.live.player.annotations.AlivcLivePlayRenderMode;
import com.alivc.live.player.annotations.AlivcLivePlayRotationMode;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class LivePlayerConfig {

    private final AlivcLivePlayConfig mAlivcLivePlayConfig;

    public LivePlayerConfig() {
        mAlivcLivePlayConfig = new AlivcLivePlayConfig();
    }

    public AlivcLivePlayConfig getAlivcLivePlayConfig() {
        return mAlivcLivePlayConfig;
    }

    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "setRenderMode":
                String setRenderMode = call.argument("arg");
                if (setRenderMode != null) {
                    AlivcLivePlayRenderMode mSetRenderMode;
                    switch (setRenderMode) {
                        case "0":
                            mSetRenderMode = AlivcLivePlayRenderMode.AlivcLivePlayRenderModeAuto;
                            break;
                        case "1":
                            mSetRenderMode = AlivcLivePlayRenderMode.AlivcLivePlayRenderModeStretch;
                            break;
                        case "2":
                            mSetRenderMode = AlivcLivePlayRenderMode.AlivcLivePlayRenderModeFill;
                            break;
                        case "3":
                            mSetRenderMode = AlivcLivePlayRenderMode.AlivcLivePlayRenderModeCrop;
                            break;
                        default:
                            mSetRenderMode = AlivcLivePlayRenderMode.AlivcLivePlayRenderModeAuto;
                            break;
                    }
                    mAlivcLivePlayConfig.renderMode = mSetRenderMode;
                }
                result.success(null);
                break;
            case "getRenderMode":
                result.success(mAlivcLivePlayConfig.renderMode + "");
                break;
            case "setMirror":
                String setMirrorMode = call.argument("arg");
                if (setMirrorMode != null) {
                    mAlivcLivePlayConfig.isMirror = setMirrorMode.equals("true");
                }
                result.success(null);
                break;
            case "getMirror":
                result.success(mAlivcLivePlayConfig.isMirror + "");
                break;
            case "setRotationMode":
                String setRotationMode = call.argument("arg");
                if (setRotationMode != null) {
                    AlivcLivePlayRotationMode mRotationMode;
                    switch (setRotationMode) {
                        case "0":
                            mRotationMode = AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_0;
                            break;
                        case "1":
                            mRotationMode = AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_90;
                            break;
                        case "2":
                            mRotationMode = AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_180;
                            break;
                        case "3":
                            mRotationMode = AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_270;
                            break;
                        default:
                            mRotationMode = AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_0;
                            break;
                    }
                    mAlivcLivePlayConfig.rotationMode = mRotationMode;
                }
                result.success(null);
                break;
            case "getRotationMode":
                AlivcLivePlayRotationMode rotationMode = mAlivcLivePlayConfig.rotationMode;
                if (rotationMode == AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_0) {
                    result.success("0");
                } else if (rotationMode == AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_90) {
                    result.success("1");
                } else if (rotationMode == AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_180) {
                    result.success("2");
                } else if (rotationMode == AlivcLivePlayRotationMode.AlivcLivePlayRotationMode_270) {
                    result.success("3");
                } else {
                    result.success("0");
                }
                break;
            case "isFullScreen":
                String isFullScreen = call.argument("arg");
                if (isFullScreen != null) {
                    mAlivcLivePlayConfig.isFullScreen = isFullScreen.equals("1");
                }
                result.success(null);
                break;
        }
    }
}
