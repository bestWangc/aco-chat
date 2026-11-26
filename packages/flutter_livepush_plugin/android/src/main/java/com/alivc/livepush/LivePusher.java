package com.alivc.livepush;

import static android.os.Environment.MEDIA_MOUNTED;

import android.content.Context;
import android.graphics.Bitmap;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.view.SurfaceView;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;

import com.alivc.component.custom.AlivcLivePushCustomDetect;
import com.alivc.component.custom.AlivcLivePushCustomFilter;
import com.alivc.live.annotations.AlivcLiveNetworkQuality;
import com.alivc.live.annotations.AlivcLivePushKickedOutType;
import com.alivc.live.annotations.AlivcLiveRecordMediaEvent;
import com.alivc.live.player.annotations.AlivcLivePlayVideoStreamType;
import com.alivc.live.pusher.AlivcImageFormat;
import com.alivc.live.pusher.AlivcLiveBase;
import com.alivc.live.pusher.AlivcLivePushBGMListener;
import com.alivc.live.pusher.AlivcLivePushCameraTypeEnum;
import com.alivc.live.pusher.AlivcLivePushConfig;
import com.alivc.live.pusher.AlivcLivePushError;
import com.alivc.live.pusher.AlivcLivePushErrorListener;
import com.alivc.live.pusher.AlivcLivePushInfoListener;
import com.alivc.live.pusher.AlivcLivePushLogLevel;
import com.alivc.live.pusher.AlivcLivePushNetworkListener;
import com.alivc.live.pusher.AlivcLivePushStatsInfo;
import com.alivc.live.pusher.AlivcLivePusher;
import com.alivc.live.pusher.AlivcPreviewDisplayMode;
import com.alivc.live.pusher.AlivcSnapshotListener;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import com.alivc.live.pusher.AlivcSoundFormat;
import com.alivc.livepush.beauty.BeautyFactory;
import com.alivc.livepush.beauty.BeautyInterface;
import com.alivc.livepush.beauty.BeautySDKType;
import com.alivc.livepush.interactive.LiveTranscodingConfig;

public class LivePusher {

    private static final String TAG = "LivePusher";

    private EventChannel.EventSink mEventSink;
    private AlivcLivePusher mAlivcLivePusher;
    private AlivcLivePushConfig mAlivcLivePushConfig;

    private final Context mContext;

    private SurfaceView mSurfaceView;
    private boolean mSurfaceViewCreated = false;
    private final Handler mMainHandler = new Handler(Looper.getMainLooper());
    private LiveTranscodingConfig mLiveTranscodingConfig;
    private boolean isInteractiveView;
    private FrameLayout mFrameLayout;

    private BeautyInterface mBeautyManager;
    private int mCameraId;
    private boolean mUseBeauty = false;

    public LivePusher(FlutterPlugin.FlutterPluginBinding flutterPluginBinding) {
        mAlivcLivePusher = new AlivcLivePusher();
        this.mContext = flutterPluginBinding.getApplicationContext();

        EventChannel livePushEventChannel = new EventChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "plugins.livepush.pusher.event");
        livePushEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                mEventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                mEventSink = null;
            }
        });
    }

    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "createConfig":
                result.success(null);
                break;
            case "initLivePusher":
                this.mCameraId = mAlivcLivePushConfig.getCameraType();
                mAlivcLivePusher.init(mContext, mAlivcLivePushConfig);
                result.success(null);
                break;
            case "openLog":
                String isOpenLog = call.argument("arg");
                if (isOpenLog != null) {
                    openLog(Boolean.parseBoolean(isOpenLog));
                }
                result.success(null);
                break;
            case "setLiveMixTranscodingConfig":
                String enableMixTranscodingConfig = call.argument("arg");
                if (enableMixTranscodingConfig != null && enableMixTranscodingConfig.equals("1")) {
                    mAlivcLivePusher.setLiveMixTranscodingConfig(mLiveTranscodingConfig.getAlivcLiveTranscodingConfig());
                } else {
                    mAlivcLivePusher.setLiveMixTranscodingConfig(null);
                }
                break;
            //preview
            case "startPreview":
                if (isInteractiveView) {
                    Boolean startPreviewIsAnchor = call.argument("arg");
                    mAlivcLivePusher.startPreview(mContext, mFrameLayout, startPreviewIsAnchor == null || startPreviewIsAnchor);
                } else {
                    if (mSurfaceViewCreated) {
                        mAlivcLivePusher.startPreview(mSurfaceView);
                    }
                }
                result.success(null);
                break;
            case "stopPreview":
                mAlivcLivePusher.stopPreview();
                result.success(null);
                break;
            case "setPreviewMirror_push":
                String previewMirror = call.argument("arg");
                if (previewMirror != null) {
                    mAlivcLivePusher.setPreviewMirror(previewMirror.equals("1"));
                }
                result.success(null);
                break;
            case "setPreviewDisplayMode_push":
                String previewDisplayMode = call.argument("arg");
                if (TextUtils.isEmpty(previewDisplayMode)) {
                    previewDisplayMode = "1";
                }
                assert (previewDisplayMode != null);
                switch (previewDisplayMode) {
                    case "0":
                        mAlivcLivePusher.setPreviewMode(AlivcPreviewDisplayMode.ALIVC_LIVE_PUSHER_PREVIEW_SCALE_FILL);
                        break;
                    case "1":
                        mAlivcLivePusher.setPreviewMode(AlivcPreviewDisplayMode.ALIVC_LIVE_PUSHER_PREVIEW_ASPECT_FIT);
                        break;
                    case "2":
                        mAlivcLivePusher.setPreviewMode(AlivcPreviewDisplayMode.ALIVC_LIVE_PUSHER_PREVIEW_ASPECT_FILL);
                        break;
                }
                result.success(null);
                break;
            //push
            case "startPushWithURL":
                String pushUrl = call.argument("arg");
                mAlivcLivePusher.startPush(pushUrl);
                result.success(null);
                break;
            case "stopPush":
                mAlivcLivePusher.stopPush();
                result.success(null);
                break;
            case "pause":
                mAlivcLivePusher.pause();
                result.success(null);
                break;
            case "resume":
                mAlivcLivePusher.resume();
                result.success(null);
                break;
            case "destroy":
                mAlivcLivePusher.destroy();
                // AlivcLivePusher cannot be initialized again after destroy.
                // Recreate the wrapper so a later host transfer can start a
                // fresh screen-share push in the same Flutter process.
                mAlivcLivePusher = new AlivcLivePusher();
                destroyBeautyManager();
                result.success(null);
                break;
            case "resumeAsync":
                mAlivcLivePusher.resumeAsync();
                result.success(null);
                break;
            case "restartPush":
                mAlivcLivePusher.restartPush();
                result.success(null);
                break;
            case "restartPushAsync":
                mAlivcLivePusher.restartPushAsync();
                result.success(null);
                break;
            case "setPushMirror_push":
                String pushMirror = call.argument("arg");
                if (pushMirror != null) {
                    mAlivcLivePusher.setPushMirror(pushMirror.equals("1"));
                }
                result.success(null);
                break;
            //BGM
            case "setBGMEarsBack":
                String isOpenBGMEarsBack = call.argument("arg");
                if (isOpenBGMEarsBack != null) {
                    mAlivcLivePusher.setBGMEarsBack(isOpenBGMEarsBack.equals("1"));
                }
                result.success(null);
                break;
            case "setAudioDenoise":
                String isOpenBGMAudioDenoise = call.argument("arg");
                if (isOpenBGMAudioDenoise != null) {
                    mAlivcLivePusher.setAudioDenoise(isOpenBGMAudioDenoise.equals("1"));
                }
                result.success(null);
                break;
            case "setMute":
                String isEnableBGMMute = call.argument("arg");
                if (isEnableBGMMute != null) {
                    mAlivcLivePusher.setMute(isEnableBGMMute.equals("1"));
                }
                result.success(null);
                break;
            case "setBGMLoop":
                String isEnableBGMLoop = call.argument("arg");
                if (isEnableBGMLoop != null) {
                    mAlivcLivePusher.setBGMLoop(isEnableBGMLoop.equals("1"));
                }
                result.success(null);
                break;
            case "startBGMWithMusicPathAsync":
                String bgmPath = call.argument("arg");
                if (bgmPath != null) {
                    mAlivcLivePusher.startBGMAsync(bgmPath);
                }
                result.success(null);
                break;
            case "stopBGMAsync":
                mAlivcLivePusher.stopBGMAsync();
                result.success(null);
                break;
            case "pauseBGM":
                mAlivcLivePusher.pauseBGM();
                result.success(null);
                break;
            case "resumeBGM":
                mAlivcLivePusher.resumeBGM();
                result.success(null);
                break;
            case "setCaptureVolume":
                String captureVolume = call.argument("arg");
                if (captureVolume != null) {
                    mAlivcLivePusher.setCaptureVolume(Integer.parseInt(captureVolume));
                }
                result.success(null);
                break;
            case "setBGMVolume":
                String bgmVolume = call.argument("arg");
                if (bgmVolume != null) {
                    mAlivcLivePusher.setBGMVolume(Integer.parseInt(bgmVolume));
                }
                result.success(null);
                break;
            case "setTargetVideoBitrate_push":
                String targetVideoBitrate = call.argument("arg");
                if (targetVideoBitrate != null) {
                    mAlivcLivePusher.setTargetVideoBitrate(Integer.parseInt(targetVideoBitrate));
                }
                result.success(null);
                break;
            case "setMinVideoBitrate_push":
                String minVideoBitrate = call.argument("arg");
                if (minVideoBitrate != null) {
                    mAlivcLivePusher.setMinVideoBitrate(Integer.parseInt(minVideoBitrate));
                }
                result.success(null);
                break;
            case "useBeauty":
                this.mUseBeauty = true;
                result.success(null);
                break;
            //
            case "setFlash":
                String enableFlash = call.argument("arg");
                if (enableFlash != null) {
                    mAlivcLivePusher.setFlash(enableFlash.equals("1"));
                }
                result.success(null);
                break;
            case "switchCamera":
                mAlivcLivePusher.switchCamera();
                if (mCameraId == AlivcLivePushCameraTypeEnum.CAMERA_TYPE_FRONT.getCameraId()) {
                    mCameraId = AlivcLivePushCameraTypeEnum.CAMERA_TYPE_BACK.getCameraId();
                } else {
                    mCameraId = AlivcLivePushCameraTypeEnum.CAMERA_TYPE_FRONT.getCameraId();
                }
                result.success(null);
                break;
            case "snapshot":
                Map<String, Object> snapShotParams = call.argument("arg");
                if (snapShotParams != null) {
                    String snapshotCountParams = (String) snapShotParams.get("count");
                    String snapshotIntervalParams = (String) snapShotParams.get("interval");
                    String snapshotSaveDirParams = (String) snapShotParams.get("saveDir");

                    mAlivcLivePusher.snapshot(Integer.parseInt(snapshotCountParams), Integer.parseInt(snapshotIntervalParams), new AlivcSnapshotListener() {
                        @Override
                        public void onSnapshot(Bitmap bitmap) {
                            String dateFormat = new SimpleDateFormat("yyyy-MM-dd-hh-mm-ss-SS").format(new Date());
                            File f = new File(snapshotSaveDirParams, "snapshot-" + dateFormat + ".png");
                            if (f.exists()) {
                                f.delete();
                            }
                            try {
                                FileOutputStream out = new FileOutputStream(f);
                                bitmap.compress(Bitmap.CompressFormat.PNG, 90, out);
                                out.flush();
                                out.close();
                            } catch (FileNotFoundException e) {
                                e.printStackTrace();
                            } catch (IOException e) {
                                e.printStackTrace();
                            }
                            mMainHandler.post(() -> {
                                if (mEventSink != null) {
                                    Map<String, Object> snapShotMap = new HashMap<>();
                                    snapShotMap.put("method", "onSnapshot");
                                    snapShotMap.put("saveResult", "1");
                                    snapShotMap.put("savePath", snapshotSaveDirParams + "/snapshot-" + dateFormat + ".png");
                                    mEventSink.success(snapShotMap);
                                }
                            });
                            Log.e("LivePusher", "截图已保存:" + snapshotSaveDirParams + "/snapshot-" + dateFormat + ".png");
                        }
                    });
                }
                result.success(null);
                break;
            case "addWatermark":
                Map<String, Object> addWatermarkParams = call.argument("arg");
                if (addWatermarkParams != null) {
                    String addWaterMarkPath = (String) addWatermarkParams.get("path");
                    String addWaterMarkCoordX = (String) addWatermarkParams.get("coordX");
                    String addWaterMarkCoordY = (String) addWatermarkParams.get("coordY");
                    String addWaterMarkWidth = (String) addWatermarkParams.get("width");
                    mAlivcLivePusher.addWaterMark(addWaterMarkPath, Float.valueOf(addWaterMarkCoordX),
                            Float.valueOf(addWaterMarkCoordY), Float.valueOf(addWaterMarkWidth));
                }
                result.success(null);
                break;
            case "setWatermarkVisible":
                String setWatermarkVisible = call.argument("arg");
                if (setWatermarkVisible != null) {
                    mAlivcLivePusher.setWatermarkVisible(setWatermarkVisible.equals("1"));
                }
                result.success(null);
                break;
            case "sendMessage":
                Map<String, Object> sendMessage = call.argument("arg");
                if (sendMessage != null) {
                    String sendMessageMsg = (String) sendMessage.get("message");
                    String sendMessageCount = (String) sendMessage.get("count");
                    String sendMessageTime = (String) sendMessage.get("time");
                    String sendMessageIsKeyFrame = (String) sendMessage.get("isKeyFrame");
                    mAlivcLivePusher.sendMessage(sendMessageMsg, Integer.valueOf(sendMessageCount),
                            Integer.valueOf(sendMessageTime), sendMessageIsKeyFrame.equals("1"));
                }
                result.success(null);
                break;
            case "addDynamicWaterMarkImageData":
                Map<String, Object> addDynamicWaterMarkImageDataMap = call.argument("arg");
                if (addDynamicWaterMarkImageDataMap != null) {
                    String addDynamicWaterMarkImageDataMapPath = (String) addDynamicWaterMarkImageDataMap.get("path");
                    String addDynamicWaterMarkImageDataMapX = (String) addDynamicWaterMarkImageDataMap.get("x");
                    String addDynamicWaterMarkImageDataMapY = (String) addDynamicWaterMarkImageDataMap.get("y");
                    String addDynamicWaterMarkImageDataMapW = (String) addDynamicWaterMarkImageDataMap.get("w");
                    String addDynamicWaterMarkImageDataMapH = (String) addDynamicWaterMarkImageDataMap.get("h");
                    mAlivcLivePusher.addDynamicsAddons(addDynamicWaterMarkImageDataMapPath, Float.valueOf(addDynamicWaterMarkImageDataMapX),
                            Float.valueOf(addDynamicWaterMarkImageDataMapY), Float.valueOf(addDynamicWaterMarkImageDataMapW),
                            Float.valueOf(addDynamicWaterMarkImageDataMapH));
                }
                result.success(null);
                break;
            case "enableSpeakerphone":
                String enableSpeakerphone = call.argument("arg");
                if (enableSpeakerphone != null) {
                    mAlivcLivePusher.enableSpeakerphone(enableSpeakerphone.equals("1"));
                }
                result.success(null);
                break;
            case "isEnableSpeakerphone":
                result.success(mAlivcLivePusher.isSpeakerphoneOn() ? "1" : "0");
                break;
            //config
            case "setExternMainStream":
                String externMainStream = call.argument("arg");
                if (externMainStream != null) {
                    mAlivcLivePushConfig.setExternMainStream(externMainStream.equals("1"), AlivcImageFormat.IMAGE_FORMAT_YUVNV12, AlivcSoundFormat.SOUND_FORMAT_S16);
                }
                result.success(null);
                break;
            case "sendVideoData":
                Map<String, Object> sendVideoDataMap = call.argument("arg");
                if (sendVideoDataMap != null) {
                    byte[] sendVideoDataMapData = (byte[]) sendVideoDataMap.get("data");
                    String sendVideoDataMapWidth = (String) sendVideoDataMap.get("width");
                    String sendVideoDataMapHeight = (String) sendVideoDataMap.get("height");
                    String sendVideoDataMapSize = (String) sendVideoDataMap.get("size");
                    String sendVideoDataMapPts = (String) sendVideoDataMap.get("pts");
                    mAlivcLivePusher.inputStreamVideoData(sendVideoDataMapData, Integer.parseInt(sendVideoDataMapWidth),
                            Integer.parseInt(sendVideoDataMapHeight), Integer.parseInt(sendVideoDataMapWidth),
                            Integer.parseInt(sendVideoDataMapSize), Long.parseLong(sendVideoDataMapPts), 0);
                }
                break;
            case "sendPCMData":
                Map<String, Object> sendPCMDataMap = call.argument("arg");
                if (sendPCMDataMap != null) {
                    byte[] sendPCMDataMapData = (byte[]) sendPCMDataMap.get("data");
                    String sendPCMDataMapSize = (String) sendPCMDataMap.get("size");
                    String sendPCMDataMapSampleRate = (String) sendPCMDataMap.get("sampleRate");
                    String sendPCMDataMapChannel = (String) sendPCMDataMap.get("channel");
                    String sendPCMDataMapPts = (String) sendPCMDataMap.get("pts");
                    mAlivcLivePusher.inputStreamAudioData(sendPCMDataMapData, Integer.parseInt(sendPCMDataMapSize),
                            Integer.parseInt(sendPCMDataMapSampleRate), Integer.parseInt(sendPCMDataMapChannel),
                            Long.parseLong(sendPCMDataMapPts));
                }
                break;
            //listener
            case "setErrorDelegate":
                mAlivcLivePusher.setLivePushErrorListener(new AlivcLivePushErrorListener() {
                    @Override
                    public void onSystemError(AlivcLivePusher alivcLivePusher, AlivcLivePushError alivcLivePushError) {
                        Map<String, Object> result = new HashMap<>();
                        result.put("method", "onSystemError");
                        result.put("errorCode", alivcLivePushError.getCode());
                        result.put("errorDescription", alivcLivePushError.getMsg());
                        mEventSink.success(result);
                    }

                    @Override
                    public void onSDKError(AlivcLivePusher alivcLivePusher, AlivcLivePushError alivcLivePushError) {
                        Map<String, Object> result = new HashMap<>();
                        result.put("method", "onSDKError");
                        result.put("errorCode", alivcLivePushError.getCode());
                        result.put("errorDescription", alivcLivePushError.getMsg());
                        mEventSink.success(result);
                    }
                });
                result.success(null);
                break;
            case "setInfoDelegate":
                mAlivcLivePusher.setLivePushInfoListener(new AlivcLivePushInfoListener() {
                    @Override
                    public void onPreviewStarted(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPreviewStarted");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onPreviewStopped(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPreviewStoped");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onPushStarted(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPushStarted");
                                mEventSink.success(result);
                            }
                        });

                    }

                    @Override
                    public void onPushPaused(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPushPaused");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onPushResumed(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPushResumed");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onPushStopped(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPushStoped");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onPushRestarted(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPushRestart");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onFirstFramePreviewed(AlivcLivePusher alivcLivePusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onFirstFramePreviewed");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onFirstFramePushed(AlivcLivePusher alivcLivePusher) {
                        if (mEventSink != null) {

                        }
//                Map<String,Object> result = new HashMap<>();
//                result.put("method","onFirstFramePushed");
//                mEventSink.success(result);
                    }

                    @Override
                    public void onDropFrame(AlivcLivePusher alivcLivePusher, int i, int i1) {
                        if (mEventSink != null) {

                        }
//                Map<String, Object> result = new HashMap<>();
//                result.put("method", "onFirstFramePushed");
//                mEventSink.success(result);
                    }

                    @Override
                    public void onAdjustBitrate(AlivcLivePusher alivcLivePusher, int i, int i1) {
                        if (mEventSink != null) {

                        }

                    }

                    @Override
                    public void onAdjustFps(AlivcLivePusher alivcLivePusher, int i, int i1) {
                        if (mEventSink != null) {

                        }
                    }

                    @Override
                    public void onPushStatistics(AlivcLivePusher alivcLivePusher, AlivcLivePushStatsInfo alivcLivePushStatsInfo) {

                    }

                    @Override
                    public void onSetLiveMixTranscodingConfig(AlivcLivePusher alivcLivePusher, boolean b, String s) {

                    }

                    @Override
                    public void onKickedOutByServer(AlivcLivePusher pusher, AlivcLivePushKickedOutType kickedOutType) {

                    }

                    @Override
                    public void onMicrophoneVolumeUpdate(AlivcLivePusher pusher, int volume) {

                    }

                    @Override
                    public void onLocalRecordEvent(AlivcLiveRecordMediaEvent mediaEvent, String storagePath) {

                    }

                    @Override
                    public void onRemoteUserEnterRoom(AlivcLivePusher pusher, String userId, boolean isOnline) {

                    }

                    @Override
                    public void onRemoteUserAudioStream(AlivcLivePusher pusher, String userId, boolean isPushing) {

                    }

                    @Override
                    public void onRemoteUserVideoStream(AlivcLivePusher pusher, String userId, AlivcLivePlayVideoStreamType videoStreamType, boolean isPushing) {

                    }
                });
                result.success(null);
                break;
            case "setNetworkDelegate":
                mAlivcLivePusher.setLivePushNetworkListener(new AlivcLivePushNetworkListener() {
                    @Override
                    public void onNetworkPoor(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onNetworkPoor");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onNetworkRecovery(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onNetworkRecovery");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onReconnectStart(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onReconnectStart");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onConnectionLost(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onConnectionLost");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onReconnectFail(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onReconnectError");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onReconnectSucceed(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onReconnectSuccess");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onSendDataTimeout(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onSendDataTimeout");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onConnectFail(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onConnectFail");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onNetworkQualityChanged(AlivcLiveNetworkQuality upQuality, AlivcLiveNetworkQuality downQuality) {

                    }

                    @Override
                    public String onPushURLAuthenticationOverdue(AlivcLivePusher pusher) {
                        return null;
                    }

                    @Override
                    public void onPushURLTokenWillExpire(AlivcLivePusher pusher) {

                    }

                    @Override
                    public void onPushURLTokenExpired(AlivcLivePusher pusher) {

                    }

                    @Override
                    public void onSendMessage(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onSendSeiMessage");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onPacketsLost(AlivcLivePusher pusher) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onPacketsLost");
                                mEventSink.success(result);
                            }
                        });
                    }
                });
                result.success(null);
                break;
            case "setBGMDelegate":
                mAlivcLivePusher.setLivePushBGMListener(new AlivcLivePushBGMListener() {
                    @Override
                    public void onStarted() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMStarted");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onStopped() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMStoped");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onPaused() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMPaused");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onResumed() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMResumed");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onProgress(long progress, long duration) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMProgress");
                                result.put("progress", String.valueOf(progress));
                                result.put("duration", String.valueOf(duration));
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onCompleted() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMCompleted");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onDownloadTimeout() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMDownloadTimeout");
                                mEventSink.success(result);
                            }
                        });
                    }

                    @Override
                    public void onOpenFailed() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("method", "onBGMOpenFailed");
                                mEventSink.success(result);
                            }
                        });
                    }
                });
                result.success(null);
                break;
            case "setCustomFilterDelegate":
                mAlivcLivePusher.setCustomFilter(new AlivcLivePushCustomFilter() {
                    @Override
                    public void customFilterCreate() {
                        initBeautyManager();
                    }

                    @Override
                    public int customFilterProcess(int inputTexture, int textureWidth, int textureHeight, long extra) {
                        if (mBeautyManager == null) {
                            return inputTexture;
                        }

                        return mBeautyManager.onTextureInput(inputTexture, textureWidth, textureHeight);
                    }

                    @Override
                    public void customFilterDestroy() {
                        destroyBeautyManager();
                    }
                });
                result.success(null);
                break;
            case "setCustomDetectorDelegate":
                mAlivcLivePusher.setCustomDetect(new AlivcLivePushCustomDetect() {
                    @Override
                    public void customDetectCreate() {

                    }

                    @Override
                    public long customDetectProcess(long dataPtr, int width, int height, int rotation, int format, long extra) {
                        return 0;
                    }

                    @Override
                    public void customDetectDestroy() {

                    }
                });
                result.success(null);
                break;
        }
    }

    public void openLog(boolean isOpen) {
        AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.AlivcLivePushLogLevelInfo);
        AlivcLiveBase.setConsoleEnabled(isOpen);
        if (isOpen) {
            // adb pull /sdcard/Android/data/com.alivc.live.pusher.demo/files/Ali_RTS_Log/ ~/Downloads
            String logPath = getLogFilePath(mContext.getApplicationContext(), null);
            // full log file limited was kLogMaxFileSizeInKB * 5 (parts)
            int maxPartFileSizeInKB = 100 * 1024 * 1024; //100G
            AlivcLiveBase.setLogDirPath(logPath, maxPartFileSizeInKB);
        }
    }

    private static String getLogFilePath(@NonNull Context context, String dir) {
        String logFilePath = "";
        //判断SD卡是否可用
        if (MEDIA_MOUNTED.equals(Environment.getExternalStorageState())) {
            logFilePath = context.getExternalFilesDir(dir).getAbsolutePath();
        } else {
            //没内存卡就存机身内存
            logFilePath = context.getFilesDir() + File.separator + dir;
        }
        File file = new File(logFilePath);
        if (!file.exists()) {//判断文件目录是否存在
            file.mkdirs();
        }

        Log.d(TAG, "log file path: " + logFilePath);
        return logFilePath;
    }


    public void setPreviewView(LivePusherView livePusherView) {
        isInteractiveView = livePusherView.isInteractiveView();
        if (isInteractiveView) {
            mFrameLayout = (FrameLayout) livePusherView.getView();
        } else {
            livePusherView.setOnSurfaceHolderCallback(new LivePusherView.OnSurfaceHolderCallback() {
                @Override
                public void surfaceCreated() {
                    mSurfaceViewCreated = true;
                    mSurfaceView = (SurfaceView) livePusherView.getView();
                }

                @Override
                public void surfaceChanged() {

                }

                @Override
                public void surfaceDestroyed() {
                    mSurfaceViewCreated = false;
                }
            });
        }
    }

    public void setPushConfig(LivePushConfig livePushConfig) {
        this.mAlivcLivePushConfig = livePushConfig.getPushConfig();
    }

    public void setLiveTranscodingConfig(LiveTranscodingConfig liveTranscodingConfig) {
        this.mLiveTranscodingConfig = liveTranscodingConfig;
    }

    public void setMixStreams(LiveTranscodingConfig liveTranscodingConfig) {
        if (mAlivcLivePusher != null) {
            mAlivcLivePusher.setLiveMixTranscodingConfig(liveTranscodingConfig.getAlivcLiveTranscodingConfig());
        }
    }

    //////// 美颜处理逻辑 -----start
    private void initBeautyManager() {
        if (mBeautyManager == null) {
            Log.d(TAG, "initBeautyManager start");
            // 从v6.2.0开始，基础模式下的美颜，和互动模式下的美颜，处理逻辑保持一致，即：QueenBeautyImpl；
            mBeautyManager = BeautyFactory.createBeauty(BeautySDKType.QUEEN, mContext);
            // initialize in texture thread.
            mBeautyManager.init();
            mBeautyManager.setBeautyEnable(mUseBeauty);
            mBeautyManager.switchCameraId(mCameraId);
            Log.d(TAG, "initBeautyManager end");
        }
    }

    private void destroyBeautyManager() {
        if (mBeautyManager != null) {
            mBeautyManager.release();
            mBeautyManager = null;
        }
    }
    //////// 美颜处理逻辑 -----end
}
