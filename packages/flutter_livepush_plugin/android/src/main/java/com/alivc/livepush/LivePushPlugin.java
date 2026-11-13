package com.alivc.livepush;


import android.content.Context;
import android.text.TextUtils;
import android.util.Log;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;

import com.alivc.live.annotations.AlivcLiveMode;
import com.alivc.live.player.AlivcLivePlayConfig;
import com.alivc.live.player.AlivcLivePlayerImpl;
import com.alivc.livepush.interactive.LivePlayer;
import com.alivc.livepush.interactive.LivePlayerConfig;
import com.alivc.livepush.interactive.LiveTranscodingConfig;

import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/**
 * LivePushPlugin
 */
public class LivePushPlugin extends PlatformViewFactory implements FlutterPlugin, MethodCallHandler {


    private static final String TAG = "LivePushPlugin";

    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;
    // private Synth synch;
    private static final String channelName = "livepush";
    private LivePusher mLivePusher;
    private LivePushConfig mLivePushConfig;
    private LiveBase mLiveBase;
    private LivePlayer mLivePlayer;
    private LivePlayerConfig livePlayerConfig;
    private LiveTranscodingConfig mLiveTranscodingConfig;
    private FlutterPluginBinding flutterPluginBinding;

    public LivePushPlugin() {
        super(StandardMessageCodec.INSTANCE);
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "livepush");
        channel.setMethodCallHandler(this);

        this.flutterPluginBinding = flutterPluginBinding;

        flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("plugins.livepush.base.preview", this);
        flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("plugins.livepush.preview", this);
        flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("plugins.liveplayer.view", this);

        MethodChannel livePushBaseMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "plugins.livebase.method");
        livePushBaseMethodChannel.setMethodCallHandler(this);

        MethodChannel livePushMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "plugins.livepush.pusher.method");
        livePushMethodChannel.setMethodCallHandler(this);

        MethodChannel livePushConfigMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "plugins.livepush.pushConfig.method");
        livePushConfigMethodChannel.setMethodCallHandler(this);

        MethodChannel livePlayerMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "plugins.liveplayer.method");
        livePlayerMethodChannel.setMethodCallHandler(this);

        MethodChannel livePlayerConfigMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "plugins.liveplayerconfig.method");
        livePlayerConfigMethodChannel.setMethodCallHandler(this);

        MethodChannel liveTranscodingConfigMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "plugins.livetranscodingconfig.method");
        liveTranscodingConfigMethodChannel.setMethodCallHandler(this);

        mLivePusher = new LivePusher(flutterPluginBinding);
        mLiveBase = new LiveBase(flutterPluginBinding);
        mLivePlayer = new LivePlayer(flutterPluginBinding);
    }


    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "getSdkVersion":
            case "setListener":
            case "setLogLevel":
            case "setConsoleEnable":
            case "setLogPath":
            case "registerSDK":
                mLiveBase.onMethodCall(call, result);
                break;
            case "createConfig":
                mLivePushConfig = new LivePushConfig();
                mLivePusher.setPushConfig(mLivePushConfig);
                mLivePusher.onMethodCall(call, result);
                break;
            case "bindLiveMixTranscodingConfig":
                mLiveTranscodingConfig = new LiveTranscodingConfig();
                mLivePusher.setLiveTranscodingConfig(mLiveTranscodingConfig);
                mLivePusher.onMethodCall(call, result);
                break;
            case "setLiveMixTranscodingConfig":
            case "initLivePusher":
            case "openLog":
                //preview
            case "startPreview":
            case "stopPreview":
            case "setPreviewDisplayMode_push":
            case "setPreviewMirror_push":
                //push
            case "startPushWithURL":
            case "stopPush":
            case "pause":
            case "resume":
            case "destroy":
            case "resumeAsync":
            case "restartPush":
            case "restartPushAsync":
            case "setPushMirror_push":
            case "setTargetVideoBitrate_push":
            case "setMinVideoBitrate_push":
            case "useBeauty":
                //BGM
            case "setBGMEarsBack":
            case "setAudioDenoise":
            case "setMute":
            case "setBGMLoop":
            case "startBGMWithMusicPathAsync":
            case "stopBGMAsync":
            case "pauseBGM":
            case "resumeBGM":
            case "setCaptureVolume":
            case "setBGMVolume":
                //
            case "setFlash":
            case "switchCamera":
            case "snapshot":
            case "addWatermark":
            case "setWatermarkVisible":
            case "sendMessage":
            case "addDynamicWaterMarkImageData":
            case "enableSpeakerphone":
            case "isEnableSpeakerphone":
                //config
            case "setExternMainStream":
            case "sendVideoData":
            case "sendPCMData":
                //listener
            case "setErrorDelegate":
            case "setInfoDelegate":
            case "setNetworkDelegate":
            case "setBGMDelegate":
            case "setCustomFilterDelegate":
            case "setCustomDetectorDelegate":
                mLivePusher.onMethodCall(call, result);
                break;
            case "setResolution":
            case "getResolution":
            case "setEnableAutoBitrate":
            case "getEnableAutoBitrate":
            case "setEnableAutoResolution":
            case "getEnableAutoResolution":
            case "setQualityMode":
            case "getQualityMode":
            case "setTargetVideoBitrate":
            case "getTargetVideoBitrate":
            case "setMinVideoBitrate":
            case "getMinVideoBitrate":
            case "setInitialVideoBitrate":
            case "getInitialVideoBitrate":
            case "setAudioBitrate":
            case "getAudioBitrate":
            case "setAudioSampleRate":
            case "getAudioSampleRate":
            case "setFps":
            case "getFps":
            case "setMinFps":
            case "getMinFPS":
            case "setVideoEncodeGop":
            case "getVideoEncodeGop":
            case "setAudioEncoderProfile":
            case "getAudioEncoderProfile":
            case "setAudioChannel":
            case "getAudioChannel":
            case "setAudioOnly":
            case "getAudioOnly":
            case "setVideoOnly":
            case "getVideoOnly":
            case "setAudioEncoderMode":
            case "getAudioEncoderMode":
            case "setVideoEncoderMode":
            case "getVideoEncoderMode":
            case "setVideoHardEncoderCodec":
            case "getVideoHardEncoderCodec":
            case "setOpenBFrame":
            case "getOpenBFrame":
            case "setOrientation":
            case "getOrientation":
            case "setPreviewDisplayMode":
            case "setConnectRetryInterval":
            case "getConnectRetryInterval":
            case "setConnectRetryCount":
            case "getConnectRetryCount":
            case "setPushMirror":
            case "getPushMirror":
            case "setPreviewMirror":
            case "getPreviewMirror":
            case "setCameraType":
            case "getCameraType":
            case "setAutoFocus":
            case "getAutoFocus":
            case "setPauseImg":
            case "setNetworkPoorImg":
            case "setExternAudioFormat":
            case "getExternAudioFormat":
            case "setAudioScene":
            case "getAudioScene":
            case "getExternMainStream":
            case "useExternMainStream":
            case "setLivePushMode":
            case "getLivePushMode":
            case "getPushResolution":
                mLivePushConfig.onMethodCall(call, result);
                break;
            //TranscodingConfig
            case "setBackgroundColor":
            case "getBackgroundColor":
            case "setCropMode":
            case "getCropMode":
            case "setMixStreams":
                mLiveTranscodingConfig.onMethodCall(call, result);
                mLivePusher.setMixStreams(mLiveTranscodingConfig);
                break;
            case "getMixStreams":
                mLiveTranscodingConfig.onMethodCall(call, result);
                break;
            //livePlayer
            case "bindPlayConfig":
                livePlayerConfig = new LivePlayerConfig();
                mLivePlayer.setLivePlayerConfig(livePlayerConfig);
                mLivePlayer.onMethodCall(call, result);
                break;
            case "initLivePlayer":
            case "setLivePlayerDelegate":
            case "setPlayView":
            case "startPlayWithURL":
            case "stopPlay":
            case "pauseAudioPlaying":
            case "resumeAudioPlaying":
            case "pauseVideoPlaying":
            case "resumeVideoPlaying":
                mLivePlayer.onMethodCall(call, result);
                break;
            //livePlayerConfig
            case "setRenderMode":
            case "getRenderMode":
            case "setMirror":
            case "getMirror":
            case "setRotationMode":
            case "getRotationMode":
            case "isFullScreen":
                livePlayerConfig.onMethodCall(call, result);
                break;
            default:
                break;
        }
    /*
     * try {
        ArrayList arguments = (ArrayList) call.arguments;
        int numKeysDown = synth.keyDown((Integer) arguments.get(0));
        result.success(numKeysDown);
      } catch (Exception ex) {
        result.error("1", ex.getMessage(), ex.getStackTrace());
      }
     */
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @NonNull
    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        LivePusherView livePusherView = new LivePusherView(context, args);
        if (args != null) {
            Map<String,String> argsMap  = (Map<String, String>) args;
            String viewType = argsMap.get("viewType");
            if (viewType != null) {
                if (LivePusherView.INTERACTIVE_PULL_VIEW.equals(viewType)) {
                    if (mLivePlayer != null) {
                        mLivePlayer.setPreviewView(livePusherView);
                    }
                } else {
                    if (mLivePusher != null) {
                        mLivePusher.setPreviewView(livePusherView);
                    }

                }
            }
        }
        return livePusherView;
    }
}
