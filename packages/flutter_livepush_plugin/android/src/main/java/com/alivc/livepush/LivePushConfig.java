package com.alivc.livepush;


import android.content.Intent;

import com.alivc.live.annotations.AlivcLiveMode;
import com.alivc.live.pusher.AlivcAudioAACProfileEnum;
import com.alivc.live.pusher.AlivcAudioChannelEnum;
import com.alivc.live.pusher.AlivcAudioSampleRateEnum;
import com.alivc.live.pusher.AlivcEncodeModeEnum;
import com.alivc.live.pusher.AlivcEncodeType;
import com.alivc.live.pusher.AlivcFpsEnum;
import com.alivc.live.pusher.AlivcLivePushCameraTypeEnum;
import com.alivc.live.pusher.AlivcLivePushConfig;
import com.alivc.live.pusher.AlivcPreviewDisplayMode;
import com.alivc.live.pusher.AlivcPreviewOrientationEnum;
import com.alivc.live.pusher.AlivcQualityModeEnum;
import com.alivc.live.pusher.AlivcResolutionEnum;
import com.alivc.live.pusher.AlivcVideoEncodeGopEnum;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class LivePushConfig {

    private static Intent mediaProjectionPermissionResultData;
    private final AlivcLivePushConfig mAlivcLivePushConfig;

    private String externVideoPath;
    private String externAudioPath;

    public LivePushConfig() {
        mAlivcLivePushConfig = new AlivcLivePushConfig();
        mAlivcLivePushConfig.setExtraInfo("fluttersdk");
        if (mediaProjectionPermissionResultData != null) {
            mAlivcLivePushConfig.setMediaProjectionPermissionResultData(mediaProjectionPermissionResultData);
            mediaProjectionPermissionResultData = null;
        }
    }

    public static void setMediaProjectionPermissionResultData(Intent resultData) {
        mediaProjectionPermissionResultData = resultData;
    }

    public AlivcLivePushConfig getPushConfig() {
        return mAlivcLivePushConfig;
    }

    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "setResolution":
                String resolution = call.argument("arg");
                if (resolution != null) {
                    AlivcResolutionEnum resolutionEnum;
                    switch (resolution) {
                        case "0":
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_180P;
                            break;
                        case "1":
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_240P;
                            break;
                        case "2":
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_360P;
                            break;
                        case "3":
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_480P;
                            break;
                        case "4":
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_540P;
                            break;
                        case "5":
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_720P;
                            break;
                        case "6":
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_1080P;
                            break;
                        default:
                            resolutionEnum = AlivcResolutionEnum.RESOLUTION_540P;
                            break;
                    }
                    mAlivcLivePushConfig.setResolution(resolutionEnum);
                }
                result.success(null);
                break;
            case "getResolution":
                AlivcResolutionEnum getResolution = mAlivcLivePushConfig.getResolution();
                result.success(getResolution.ordinal() + "");
                break;
            case "setEnableAutoBitrate":
                String bitrateControl = call.argument("arg");
                if (bitrateControl != null) {
                    mAlivcLivePushConfig.setEnableBitrateControl(bitrateControl.equals("1"));
                }
                result.success(null);
                break;
            case "getEnableAutoBitrate":
                boolean enableBitrateControl = mAlivcLivePushConfig.isEnableBitrateControl();
                result.success(LivePushResultHelper.booleanToString(enableBitrateControl));
                break;
            case "setEnableAutoResolution":
                String autoResolution = call.argument("arg");
                if (autoResolution != null) {
                    mAlivcLivePushConfig.setEnableAutoResolution(autoResolution.equals("1"));
                }
                result.success(null);
                break;
            case "getEnableAutoResolution":
                boolean enableAutoResolution = mAlivcLivePushConfig.isEnableAutoResolution();
                result.success(LivePushResultHelper.booleanToString(enableAutoResolution));
                break;
            case "setQualityMode":
                String qualityMode = call.argument("arg");
                if (qualityMode != null) {
                    AlivcQualityModeEnum qualityModeEnum;
                    switch (qualityMode) {
                        case "0":
                            qualityModeEnum = AlivcQualityModeEnum.QM_RESOLUTION_FIRST;
                            break;
                        case "1":
                            qualityModeEnum = AlivcQualityModeEnum.QM_FLUENCY_FIRST;
                            break;
                        case "2":
                            qualityModeEnum = AlivcQualityModeEnum.QM_CUSTOM;
                            break;
                        default:
                            qualityModeEnum = AlivcQualityModeEnum.QM_RESOLUTION_FIRST;
                            break;
                    }
                    mAlivcLivePushConfig.setQualityMode(qualityModeEnum);
                }
                result.success(null);
                break;
            case "getQualityMode":
                AlivcQualityModeEnum getQualityMode = mAlivcLivePushConfig.getQualityMode();
                result.success(getQualityMode.ordinal() + "");
                break;
            case "setTargetVideoBitrate":
                String targetVideoBitrate = call.argument("arg");
                if (targetVideoBitrate != null) {
                    mAlivcLivePushConfig.setTargetVideoBitrate(Integer.parseInt(targetVideoBitrate));
                }
                result.success(null);
                break;
            case "getTargetVideoBitrate":
                int getTargetVideoBitrate = mAlivcLivePushConfig.getTargetVideoBitrate();
                result.success(getTargetVideoBitrate + "");
                break;
            case "setMinVideoBitrate":
                String minVideoBitrate = call.argument("arg");
                if (minVideoBitrate != null) {
                    mAlivcLivePushConfig.setMinVideoBitrate(Integer.parseInt(minVideoBitrate));
                }
                result.success(null);
                break;
            case "getMinVideoBitrate":
                int getMinVideoBitrate = mAlivcLivePushConfig.getMinVideoBitrate();
                result.success(getMinVideoBitrate + "");
                break;
            case "setInitialVideoBitrate":
                String initialVideoBitrate = call.argument("arg");
                if (initialVideoBitrate != null) {
                    mAlivcLivePushConfig.setInitialVideoBitrate(Integer.parseInt(initialVideoBitrate));
                }
                result.success(null);
                break;
            case "getInitialVideoBitrate":
                int getInitialVideoBitrate = mAlivcLivePushConfig.getInitialVideoBitrate();
                result.success(getInitialVideoBitrate + "");
                break;
            case "setAudioBitrate":
                String audioBitrate = call.argument("arg");
                if (audioBitrate != null) {
                    mAlivcLivePushConfig.setAudioBitRate(Integer.parseInt(audioBitrate));
                }
                result.success(null);
                break;
            case "getAudioBitrate":
                int getAudioBitrate = mAlivcLivePushConfig.getAudioBitRate();
                result.success(getAudioBitrate + "");
                break;
            case "setAudioSampleRate":
                String audioSampleRate = call.argument("arg");
                if (audioSampleRate != null) {
                    AlivcAudioSampleRateEnum audioSampleRateEnum;
                    switch (audioSampleRate) {
                        case "16000":
                            audioSampleRateEnum = AlivcAudioSampleRateEnum.AUDIO_SAMPLE_RATE_16000;
                            break;
                        case "32000":
                            audioSampleRateEnum = AlivcAudioSampleRateEnum.AUDIO_SAMPLE_RATE_32000;
                            break;
                        case "44100":
                            audioSampleRateEnum = AlivcAudioSampleRateEnum.AUDIO_SAMPLE_RATE_44100;
                            break;
                        case "48000":
                            audioSampleRateEnum = AlivcAudioSampleRateEnum.AUDIO_SAMPLE_RATE_48000;
                            break;
                        default:
                            audioSampleRateEnum = AlivcAudioSampleRateEnum.AUDIO_SAMPLE_RATE_48000;
                            break;
                    }
                    mAlivcLivePushConfig.setAudioSampleRate(audioSampleRateEnum);
                }
                result.success(null);
                break;
            case "getAudioSampleRate":
                AlivcAudioSampleRateEnum getAudioSampleRate = mAlivcLivePushConfig.getAudioSampleRate();
                result.success(getAudioSampleRate.ordinal() + "");
                break;
            case "setFps":
                String fps = call.argument("arg");
                if (fps != null) {
                    AlivcFpsEnum fpsEnum;
                    switch (fps) {
                        case "8":
                            fpsEnum = AlivcFpsEnum.FPS_8;
                            break;
                        case "10":
                            fpsEnum = AlivcFpsEnum.FPS_10;
                            break;
                        case "12":
                            fpsEnum = AlivcFpsEnum.FPS_12;
                            break;
                        case "15":
                            fpsEnum = AlivcFpsEnum.FPS_15;
                            break;
                        case "20":
                            fpsEnum = AlivcFpsEnum.FPS_20;
                            break;
                        case "25":
                            fpsEnum = AlivcFpsEnum.FPS_25;
                            break;
                        case "30":
                            fpsEnum = AlivcFpsEnum.FPS_30;
                            break;
                        default:
                            fpsEnum = AlivcFpsEnum.FPS_20;
                            break;
                    }
                    mAlivcLivePushConfig.setFps(fpsEnum);
                }
                result.success(null);
                break;
            case "getFps":
                int getFps = mAlivcLivePushConfig.getFps();
                result.success(getFps + "");
                break;
            case "setMinFps":
                String minFPS = call.argument("arg");
                if (minFPS != null) {
                    AlivcFpsEnum minFpsEnum;
                    switch (minFPS) {
                        case "0":
                            minFpsEnum = AlivcFpsEnum.FPS_8;
                            break;
                        case "1":
                            minFpsEnum = AlivcFpsEnum.FPS_10;
                            break;
                        case "2":
                            minFpsEnum = AlivcFpsEnum.FPS_12;
                            break;
                        case "3":
                            minFpsEnum = AlivcFpsEnum.FPS_15;
                            break;
                        case "4":
                            minFpsEnum = AlivcFpsEnum.FPS_20;
                            break;
                        case "5":
                            minFpsEnum = AlivcFpsEnum.FPS_25;
                            break;
                        case "6":
                            minFpsEnum = AlivcFpsEnum.FPS_30;
                            break;
                        default:
                            minFpsEnum = AlivcFpsEnum.FPS_8;
                            break;
                    }
                    mAlivcLivePushConfig.setMinFps(minFpsEnum);
                }
                result.success(null);
                break;
            case "getMinFPS":
                int getMinFPS = mAlivcLivePushConfig.getMinFps();
                result.success(getMinFPS + "");
                break;
            case "setVideoEncodeGop":
                String videoEncodeGop = call.argument("arg");
                if (videoEncodeGop != null) {
                    AlivcVideoEncodeGopEnum videoEncodeGopEnum;
                    switch (videoEncodeGop) {
                        case "1":
                            videoEncodeGopEnum = AlivcVideoEncodeGopEnum.GOP_ONE;
                            break;
                        case "2":
                            videoEncodeGopEnum = AlivcVideoEncodeGopEnum.GOP_TWO;
                            break;
                        case "3":
                            videoEncodeGopEnum = AlivcVideoEncodeGopEnum.GOP_THREE;
                            break;
                        case "4":
                            videoEncodeGopEnum = AlivcVideoEncodeGopEnum.GOP_FOUR;
                            break;
                        case "5":
                            videoEncodeGopEnum = AlivcVideoEncodeGopEnum.GOP_FIVE;
                            break;
                        default:
                            videoEncodeGopEnum = AlivcVideoEncodeGopEnum.GOP_TWO;
                            break;
                    }
                    mAlivcLivePushConfig.setVideoEncodeGop(videoEncodeGopEnum);
                }
                result.success(null);
                break;
            case "getVideoEncodeGop":
                int getVideoEncodeGop = mAlivcLivePushConfig.getVideoEncodeGop();
                result.success(getVideoEncodeGop + "");
                break;
            case "setAudioEncoderProfile":
                String audioEncodeProfile = call.argument("arg");
                if (audioEncodeProfile != null) {
                    AlivcAudioAACProfileEnum audioAACProfileEnum;
                    switch (audioEncodeProfile) {
                        case "2":
                            audioAACProfileEnum = AlivcAudioAACProfileEnum.AAC_LC;
                            break;
                        case "5":
                            audioAACProfileEnum = AlivcAudioAACProfileEnum.HE_AAC;
                            break;
                        case "29":
                            audioAACProfileEnum = AlivcAudioAACProfileEnum.HE_AAC_v2;
                            break;
                        case "23":
                            audioAACProfileEnum = AlivcAudioAACProfileEnum.AAC_LD;
                            break;
                        default:
                            audioAACProfileEnum = AlivcAudioAACProfileEnum.AAC_LC;
                            break;
                    }
                    mAlivcLivePushConfig.setAudioProfile(audioAACProfileEnum);
                }
                result.success(null);
                break;
            case "getAudioEncoderProfile":
                AlivcAudioAACProfileEnum getAudioEncoderProfile = mAlivcLivePushConfig.getAudioProfile();
                result.success(getAudioEncoderProfile.ordinal() + "");
                break;
            case "setAudioChannel":
                String audioChannel = call.argument("arg");
                if (audioChannel != null) {
                    AlivcAudioChannelEnum audioChannelEnum;
                    switch (audioChannel) {
                        case "1":
                            audioChannelEnum = AlivcAudioChannelEnum.AUDIO_CHANNEL_ONE;
                            break;
                        case "2":
                            audioChannelEnum = AlivcAudioChannelEnum.AUDIO_CHANNEL_TWO;
                            break;
                        default:
                            audioChannelEnum = AlivcAudioChannelEnum.AUDIO_CHANNEL_ONE;
                            break;
                    }
                    mAlivcLivePushConfig.setAudioChannels(audioChannelEnum);
                }
                result.success(null);
                break;
            case "getAudioChannel":
                int getAudioChannel = mAlivcLivePushConfig.getAudioChannels();
                result.success(getAudioChannel + "");
                break;
            case "setAudioOnly":
                String audioOnly = call.argument("arg");
                if (audioOnly != null) {
                    mAlivcLivePushConfig.setAudioOnly(audioOnly.equals("1"));
                }
                result.success(null);
                break;
            case "getAudioOnly":
                boolean getAudioOnly = mAlivcLivePushConfig.isAudioOnly();
                result.success(LivePushResultHelper.booleanToString(getAudioOnly));
                break;
            case "setVideoOnly":
                String videoOnly = call.argument("arg");
                if (videoOnly != null) {
                    mAlivcLivePushConfig.setVideoOnly(videoOnly.equals("1"));
                }
                result.success(null);
                break;
            case "getVideoOnly":
                boolean getVideoOnly = mAlivcLivePushConfig.isVideoOnly();
                result.success(LivePushResultHelper.booleanToString(getVideoOnly));
                break;
            case "setAudioEncoderMode":
                String audioEncoderMode = call.argument("arg");
                if (audioEncoderMode != null) {
                    AlivcEncodeModeEnum alivcEncodeModeEnum;
                    switch (audioEncoderMode) {
                        case "0":
                            alivcEncodeModeEnum = AlivcEncodeModeEnum.Encode_MODE_HARD;
                            break;
                        case "1":
                            alivcEncodeModeEnum = AlivcEncodeModeEnum.Encode_MODE_SOFT;
                            break;
                        default:
                            alivcEncodeModeEnum = AlivcEncodeModeEnum.Encode_MODE_SOFT;
                            break;
                    }
                    mAlivcLivePushConfig.setAudioEncodeMode(alivcEncodeModeEnum);
                }
                result.success(null);
                break;
            case "getAudioEncoderMode":
                AlivcEncodeModeEnum getAudioEncoderMode = mAlivcLivePushConfig.getAudioEncodeMode();
                result.success(getAudioEncoderMode.ordinal() + "");
                break;
            case "setVideoEncoderMode":
                String videoEncoderMode = call.argument("arg");
                if (videoEncoderMode != null) {
                    AlivcEncodeModeEnum encodeModeEnum;
                    switch (videoEncoderMode) {
                        case "0":
                            encodeModeEnum = AlivcEncodeModeEnum.Encode_MODE_HARD;
                            break;
                        case "1":
                            encodeModeEnum = AlivcEncodeModeEnum.Encode_MODE_SOFT;
                            break;
                        default:
                            encodeModeEnum = AlivcEncodeModeEnum.Encode_MODE_SOFT;
                            break;
                    }
                    mAlivcLivePushConfig.setVideoEncodeMode(encodeModeEnum);
                }
                result.success(null);
                break;
            case "getVideoEncoderMode":
                AlivcEncodeModeEnum getVideoEncoderMode = mAlivcLivePushConfig.getVideoEncodeMode();
                result.success(getVideoEncoderMode.ordinal() + "");
                break;
            case "setVideoHardEncoderCodec":
                String videoHardEncoderCodec = call.argument("arg");
                if (videoHardEncoderCodec != null) {
                    AlivcEncodeType alivcEncodeType;
                    switch (videoHardEncoderCodec) {
                        case "0":
                            alivcEncodeType = AlivcEncodeType.Encode_TYPE_H264;
                            break;
                        case "1":
                            alivcEncodeType = AlivcEncodeType.Encode_TYPE_H265;
                            break;
                        default:
                            alivcEncodeType = AlivcEncodeType.Encode_TYPE_H264;
                            break;
                    }
                    mAlivcLivePushConfig.setVideoEncodeType(alivcEncodeType);
                }
                result.success(null);
                break;
            case "getVideoHardEncoderCodec":
                AlivcEncodeType videoEncodeType = mAlivcLivePushConfig.getVideoEncodeType();
                result.success(videoEncodeType.ordinal() + "");
                break;
            case "setOpenBFrame":
                String openBFrame = call.argument("arg");
                if (openBFrame != null) {
                    mAlivcLivePushConfig.setBFrames(Integer.parseInt(openBFrame));
                }
                result.success(null);
                break;
            case "getOpenBFrame":
                int bFrames = mAlivcLivePushConfig.getBFrames();
                result.success(bFrames + "");
                break;
            case "setOrientation":
                String orientation = call.argument("arg");
                if (orientation != null) {
                    AlivcPreviewOrientationEnum alivcPreviewOrientationEnum;
                    switch (orientation) {
                        case "0":
                            alivcPreviewOrientationEnum = AlivcPreviewOrientationEnum.ORIENTATION_PORTRAIT;
                            break;
                        case "1":
                            alivcPreviewOrientationEnum = AlivcPreviewOrientationEnum.ORIENTATION_LANDSCAPE_HOME_RIGHT;
                            break;
                        case "2":
                            alivcPreviewOrientationEnum = AlivcPreviewOrientationEnum.ORIENTATION_LANDSCAPE_HOME_LEFT;
                            break;
                        default:
                            alivcPreviewOrientationEnum = AlivcPreviewOrientationEnum.ORIENTATION_PORTRAIT;
                            break;
                    }
                    mAlivcLivePushConfig.setPreviewOrientation(alivcPreviewOrientationEnum);
                }
                result.success(null);
                break;
            case "getOrientation":
                int getOrientation = mAlivcLivePushConfig.getPreviewOrientation();
                if (getOrientation == AlivcPreviewOrientationEnum.ORIENTATION_PORTRAIT.getOrientation()) {
                    result.success("0");
                } else if (getOrientation == AlivcPreviewOrientationEnum.ORIENTATION_LANDSCAPE_HOME_LEFT.getOrientation()) {
                    result.success("2");
                } else if (getOrientation == AlivcPreviewOrientationEnum.ORIENTATION_LANDSCAPE_HOME_RIGHT.getOrientation()) {
                    result.success("1");
                } else {
                    result.success("0");
                }
                break;
            case "setPreviewDisplayMode":
                String previewDisplayMode = call.argument("arg");
                if (previewDisplayMode != null) {
                    switch (previewDisplayMode) {
                        case "0":
                            mAlivcLivePushConfig.setPreviewDisplayMode(AlivcPreviewDisplayMode.ALIVC_LIVE_PUSHER_PREVIEW_SCALE_FILL);
                            break;
                        case "1":
                            mAlivcLivePushConfig.setPreviewDisplayMode(AlivcPreviewDisplayMode.ALIVC_LIVE_PUSHER_PREVIEW_ASPECT_FIT);
                            break;
                        case "2":
                            mAlivcLivePushConfig.setPreviewDisplayMode(AlivcPreviewDisplayMode.ALIVC_LIVE_PUSHER_PREVIEW_ASPECT_FILL);
                            break;
                    }
                }
                result.success(null);
                break;
            case "setConnectRetryInterval":
                String connectRetryInterval = call.argument("arg");
                if (connectRetryInterval != null) {
                    mAlivcLivePushConfig.setConnectRetryInterval((int) Double.parseDouble(connectRetryInterval));
                }
                result.success(null);
                break;
            case "getConnectRetryInterval":
                int getConnectRetryInterval = mAlivcLivePushConfig.getConnectRetryInterval();
                result.success(getConnectRetryInterval + "");
                break;
            case "setConnectRetryCount":
                String connectRetryCount = call.argument("arg");
                if (connectRetryCount != null) {
                    mAlivcLivePushConfig.setConnectRetryCount(Integer.parseInt(connectRetryCount));
                }
                result.success(null);
                break;
            case "getConnectRetryCount":
                int getConnectRetryCount = mAlivcLivePushConfig.getConnectRetryCount();
                result.success(getConnectRetryCount + "");
                break;
            case "setPushMirror":
                String pushMirror = call.argument("arg");
                if (pushMirror != null) {
                    mAlivcLivePushConfig.setPushMirror(pushMirror.equals("1"));
                }
                result.success(null);
                break;
            case "getPushMirror":
                boolean getPushMirror = mAlivcLivePushConfig.isPushMirror();
                result.success(LivePushResultHelper.booleanToString(getPushMirror));
                break;
            case "setPreviewMirror":
                String previewMirror = call.argument("arg");
                if (previewMirror != null) {
                    mAlivcLivePushConfig.setPreviewMirror(previewMirror.equals("1"));
                }
                result.success(null);
                break;
            case "getPreviewMirror":
                boolean getPreviewMirror = mAlivcLivePushConfig.isPreviewMirror();
                result.success(LivePushResultHelper.booleanToString(getPreviewMirror));
                break;
            case "setCameraType":
                String cameraType = call.argument("arg");
                if (cameraType != null) {
                    AlivcLivePushCameraTypeEnum cameraTypeEnum;
                    switch (cameraType) {
                        case "0":
                            cameraTypeEnum = AlivcLivePushCameraTypeEnum.CAMERA_TYPE_BACK;
                            break;
                        case "1":
                            cameraTypeEnum = AlivcLivePushCameraTypeEnum.CAMERA_TYPE_FRONT;
                            break;
                        default:
                            cameraTypeEnum = AlivcLivePushCameraTypeEnum.CAMERA_TYPE_BACK;
                            break;
                    }
                    mAlivcLivePushConfig.setCameraType(cameraTypeEnum);
                }
                result.success(null);
                break;
            case "getCameraType":
                int getCameraType = mAlivcLivePushConfig.getCameraType();
                result.success(getCameraType + "");
                break;
            case "setAutoFocus":
                String autoFocus = call.argument("arg");
                if (autoFocus != null) {
                    mAlivcLivePushConfig.setAutoFocus(autoFocus.equals("1"));
                }
                result.success(null);
                break;
            case "getAutoFocus":
                boolean getAutoFocus = mAlivcLivePushConfig.isAutoFocus();
                result.success(LivePushResultHelper.booleanToString(getAutoFocus));
                break;
            case "setPauseImg":
                String pauseImg = call.argument("arg");
                if (pauseImg != null) {
                    mAlivcLivePushConfig.setPausePushImage(pauseImg);
                }
                result.success(null);
                break;
            case "setNetworkPoorImg":
                String networkPoorImg = call.argument("arg");
                if (networkPoorImg != null) {
                    mAlivcLivePushConfig.setNetworkPoorPushImage(networkPoorImg);
                }
                result.success(null);
                break;
            case "setExternAudioFormat":
                String externAudioFormat = call.argument("arg");
//                mAlivcLivePushConfig.setAlivcExternMainSoundFormat();
                result.success(null);
                break;
            case "getExternAudioFormat":
//                mAlivcLivePushConfig.getAlivcExternMainSoundFormat()
                result.success(null);
                break;
            case "setAudioScene":
                String audioScene = call.argument("arg");
//                mAlivcLivePushConfig.setAudioSceneMode();
                result.success(null);
                break;
            case "getAudioScene":
//                mAlivcLivePushConfig.getAudioSceneMode();
                result.success(null);
                break;
            case "getExternMainStream":
//                mAlivcLivePushConfig.isExternMainStream()
                result.success(null);
                break;
            case "useExternMainStream":
                Map<String, Object> useExternMainStreamMap = call.argument("arg");
                if (useExternMainStreamMap != null) {
                    externVideoPath = (String) useExternMainStreamMap.get("videoDir");
                    externAudioPath = (String) useExternMainStreamMap.get("audioDir");
                }
                result.success(null);
                break;
            case "getPushResolution":
                int width = mAlivcLivePushConfig.getWidth();
                int height = mAlivcLivePushConfig.getHeight();
                Map<String, String> pushResolutionMap = new HashMap<>();
                pushResolutionMap.put("width", width + "");
                pushResolutionMap.put("height", height + "");
                result.success(pushResolutionMap);
                break;
            case "setLivePushMode":
                String setLivePushMode = call.argument("arg");
                if (setLivePushMode != null) {
                    switch (setLivePushMode) {
                        case "0":
                            mAlivcLivePushConfig.setLivePushMode(AlivcLiveMode.AlivcLiveBasicMode);
                            break;
                        case "1":
                            mAlivcLivePushConfig.setLivePushMode(AlivcLiveMode.AlivcLiveInteractiveMode);
                            break;
                    }
                }
                result.success(null);
                break;
            case "getLivePushMode":
                AlivcLiveMode getLivePushMode = mAlivcLivePushConfig.getLivePushMode();
                if (getLivePushMode == AlivcLiveMode.AlivcLiveBasicMode) {
                    result.success("0");
                } else {
                    result.success("1");
                }
                break;
        }
    }
}
