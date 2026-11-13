package com.alivc.livepush.interactive;


import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.widget.FrameLayout;

import com.alivc.live.annotations.AlivcLiveMode;
import com.alivc.live.annotations.AlivcLiveNetworkQuality;
import com.alivc.live.player.AlivcLivePlayInfoListener;
import com.alivc.live.player.AlivcLivePlayer;
import com.alivc.live.player.AlivcLivePlayerImpl;
import com.alivc.live.player.AlivcLivePlayerStatsInfo;
import com.alivc.live.player.annotations.AlivcLivePlayError;
import com.alivc.livepush.LivePusherView;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class LivePlayer {

    private final Context mContext;
    private AlivcLivePlayer mAlivcLivePlayer;
    private LivePusherView mLivePusherView;
    private EventChannel.EventSink mEventSink;
    private final Handler mMainHandler = new Handler(Looper.getMainLooper());
    private LivePlayerConfig mLivePlayerConfig;

    public LivePlayer(FlutterPlugin.FlutterPluginBinding flutterPluginBinding) {
        this.mContext = flutterPluginBinding.getApplicationContext();

        EventChannel livePushEventChannel = new EventChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "plugins.liveplayer.event");
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

    public void setPreviewView(LivePusherView livePusherView) {
        this.mLivePusherView = livePusherView;
    }

    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "initLivePlayer":
                mAlivcLivePlayer = new AlivcLivePlayerImpl(mContext, AlivcLiveMode.AlivcLiveInteractiveMode);
                result.success(null);
                break;
            case "setLivePlayerDelegate":
                //设置所有监听
                mAlivcLivePlayer.setPlayInfoListener(new AlivcLivePlayInfoListener() {
                    @Override
                    public void onPlayStarted() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> snapShotMap = new HashMap<>();
                                snapShotMap.put("method", "onPlayStarted");
                                mEventSink.success(snapShotMap);
                            }
                        });
                    }

                    @Override
                    public void onPlayStopped() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> snapShotMap = new HashMap<>();
                                snapShotMap.put("method", "onPlayStopped");
                                mEventSink.success(snapShotMap);
                            }
                        });
                    }

                    @Override
                    public void onFirstVideoFrameDrawn() {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> snapShotMap = new HashMap<>();
                                snapShotMap.put("method", "onFirstVideoFrameDrawn");
                                mEventSink.success(snapShotMap);
                            }
                        });
                    }

                    @Override
                    public void onReceiveSEIMessage(int payload, byte[] data) {
//                        mMainHandler.post(() -> {
//                            if (mEventSink != null) {
//                                Map<String, Object> snapShotMap = new HashMap<>();
//                                snapShotMap.put("method", "onReceiveSEIMessage");
//                                mEventSink.success(snapShotMap);
//                            }
//                        });
                    }

                    @Override
                    public void onError(AlivcLivePlayError code, String msg) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> snapShotMap = new HashMap<>();
                                snapShotMap.put("method", "onError");
                                snapShotMap.put("errorCode", code.getError() + "");
                                snapShotMap.put("errorMessage", msg);
                                mEventSink.success(snapShotMap);
                            }
                        });
                    }

                    @Override
                    public void onPlayerStatistics(AlivcLivePlayerStatsInfo statsInfo) {
                        mMainHandler.post(() -> {
                            if (mEventSink != null) {
                                Map<String, Object> snapShotMap = new HashMap<>();
                                snapShotMap.put("method", "onPlayStopped");
                                mEventSink.success(snapShotMap);
                            }
                        });
                    }

                    @Override
                    public void onNetworkQualityChanged(AlivcLiveNetworkQuality upQuality, AlivcLiveNetworkQuality downQuality) {
                    }

                    @Override
                    public void onPlayoutVolumeUpdate(int volume, boolean isSpeaking) {
                        // TODO keria: need to implement
                    }

                    @Override
                    public void onAudioMuted(boolean mute) {
                        // TODO keria: need to implement
                    }

                    @Override
                    public void onVideoMuted(boolean mute) {
                        // TODO keria: need to implement
                    }

                    @Override
                    public void onVideoEnabled(boolean enable) {
                        // TODO keria: need to implement
                    }

                    @Override
                    public void onVideoResolutionChanged(int width, int height) {
                        // TODO keria: need to implement
                    }
                });
                result.success(null);
                break;
            case "setPlayView":
                //setPlayView 的时候会设置 Config。
                if (mLivePlayerConfig != null) {
                    mAlivcLivePlayer.setupWithConfig(mLivePlayerConfig.getAlivcLivePlayConfig());
                }
                mAlivcLivePlayer.setPlayView((FrameLayout) mLivePusherView.getView());
                result.success(null);
                break;
            case "startPlayWithURL":
                String startPlayWithUrl = call.argument("arg");
                if (!TextUtils.isEmpty(startPlayWithUrl)) {
                    mAlivcLivePlayer.startPlay(startPlayWithUrl);
                }
                result.success(null);
                break;
            case "stopPlay":
                mAlivcLivePlayer.stopPlay();
                result.success(null);
                break;
            case "pauseAudioPlaying":
                mAlivcLivePlayer.pauseAudioPlaying();
                result.success(null);
                break;
            case "resumeAudioPlaying":
                mAlivcLivePlayer.resumeAudioPlaying();
                result.success(null);
                break;
            case "pauseVideoPlaying":
                mAlivcLivePlayer.pauseVideoPlaying();
                result.success(null);
                break;
            case "resumeVideoPlaying":
                mAlivcLivePlayer.resumeVideoPlaying();
                result.success(null);
                break;
        }
    }

    public void setLivePlayerConfig(LivePlayerConfig livePlayerConfig) {
        this.mLivePlayerConfig = livePlayerConfig;
    }
}
