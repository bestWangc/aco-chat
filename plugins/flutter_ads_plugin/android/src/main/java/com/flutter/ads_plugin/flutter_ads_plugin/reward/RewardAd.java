package com.flutter.ads_plugin.flutter_ads_plugin.reward;

import android.app.Activity;
import android.os.Process;
import android.util.Log;

import com.hzhj.openads.HJAdsSdkReward;
import com.hzhj.openads.HJRewardVerify;
import com.hzhj.openads.domain.HJAdError;
import com.hzhj.openads.listener.HJOnAdsSdkRewardListener;
import com.hzhj.openads.req.HJRewardAdRequest;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;

public class RewardAd implements EventChannel.StreamHandler {
    private static String hjTag = "HJ######TAG";
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private HJAdsSdkReward hjAdsSdkReward;

    public RewardAd(FlutterPlugin.FlutterPluginBinding flutterPluginBinding) {
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_ads_plugin/events_RewardAd");
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        Log.d(hjTag, "___" + Process.myPid() + "___" + "onListen");
        this.eventSink = eventSink;
        // 模拟发送多个异步事件
        //eventSink.success("success");
        //eventSink.error("error", "中断异常", e.getMessage());
    }

    @Override
    public void onCancel(Object arguments) {
        Log.d(hjTag, "___" + Process.myPid() + "___" + "onCancel");
        this.eventSink = null;
    }

    public void setStreamHandler() {
        eventChannel.setStreamHandler(null);
        if (hjAdsSdkReward != null) {
            hjAdsSdkReward.destroy();
            hjAdsSdkReward = null;
        }
    }

    public void loadAd() {
        if (hjAdsSdkReward != null) {
            hjAdsSdkReward.loadAd();
        }
    }

    public void showAd(HashMap option) {
        if (hjAdsSdkReward != null && hjAdsSdkReward.isReady()) {
            hjAdsSdkReward.show(option);
        }
    }

    public void destroyAd() {
        if (hjAdsSdkReward != null) {
            hjAdsSdkReward.destroy();
            hjAdsSdkReward = null;
        }
    }

    public void initHJAdsSdkReward(Activity mActivity, String codeId, String userId, Map option) {
        if (hjAdsSdkReward != null) {
            return;
        }
        HJRewardAdRequest hjRewardAdRequest = new HJRewardAdRequest(codeId, userId, option);
        hjAdsSdkReward = new HJAdsSdkReward(mActivity, mActivity, hjRewardAdRequest, new HJOnAdsSdkRewardListener() {
            @Override
            public void onVideoAdLoadSuccess(String placementId) {//广告成功加载。参数说明：placementId（广告位Id）。
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoAdLoadSuccess=" + placementId);
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoAdLoadSuccess");
                result.put("placementId", placementId);
                if (eventSink != null) {
                    eventSink.success(result);
                    //eventSink.endOfStream();
                }
            }

            @Override
            public void onVideoAdPlayEnd() {//广告播放结束。
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoAdPlayEnd");
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoAdPlayEnd");
                if (eventSink != null) {
                    eventSink.success(result);
                    //eventSink.endOfStream();
                }
            }

            @Override
            public void onVideoAdPlayStart() {//广告成功展示，媒体可在此记录曝光。
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoAdPlayStart");
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoAdPlayStart");
                if (eventSink != null) {
                    eventSink.success(result);
                    //eventSink.endOfStream();
                }
            }

            @Override
            public void onVideoAdClicked() {//广告被点击。
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoAdClicked");
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoAdClicked");
                if (eventSink != null) {
                    eventSink.success(result);
                    //eventSink.endOfStream();
                }
            }

            @Override
            public void onVideoRewarded(String transId, HJRewardVerify hjRewardVerify) {//广告获取奖励。参数说明： transId（标识本次广告播放行为的唯一id）、hjRewardVerify：奖励对象
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoRewarded");
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoRewarded");
                result.put("transId", transId);
                result.put("isReward", hjRewardVerify != null && hjRewardVerify.isReward());
                if (hjRewardVerify != null) {
                    result.put("verifyErrorCode", hjRewardVerify.getErrorCode());
                    result.put("verifyErrorMsg", hjRewardVerify.getErrorMsg());
                }
                if (eventSink != null) {
                    eventSink.success(result);
                    //eventSink.endOfStream();
                }
            }

            @Override
            public void onVideoAdClosed() {//广告关闭。
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoAdClosed");
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoAdClosed");
                if (eventSink != null) {
                    eventSink.success(result);
                    eventSink.endOfStream();
                }
            }

            @Override
            public void onVideoAdLoadError(HJAdError hjAdError, String placementId) {//广告加载失败。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoAdLoadError=" + hjAdError.code + ":" + hjAdError.msg + ":" + placementId);
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoAdLoadError");
                result.put("code", hjAdError.code);
                result.put("msg", hjAdError.msg);
                result.put("placementId", placementId);
                if (eventSink != null) {
                    eventSink.success(result);
                    eventSink.endOfStream();
                }
            }

            @Override
            public void onVideoAdPlayError(HJAdError hjAdError, String placementId) {//广告播放出错。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
                Log.d(hjTag, "___" + Process.myPid() + "___" + "reward" + "_" + "onVideoAdPlayError=" + hjAdError.code + ":" + hjAdError.msg + ":" + placementId);
                java.util.Map<String, Object> result = new java.util.HashMap<>();
                result.put("event", "onVideoAdPlayError");
                result.put("code", hjAdError.code);
                result.put("msg", hjAdError.msg);
                result.put("placementId", placementId);
                if (eventSink != null) {
                    eventSink.success(result);
                    eventSink.endOfStream();
                }
            }
        });
    }
}
