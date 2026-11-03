package com.flutter.ads_plugin.flutter_ads_plugin;

import android.app.Activity;
import android.content.Intent;
import android.os.Process;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.flutter.ads_plugin.flutter_ads_plugin.interstitial.InterstitialAd;
import com.flutter.ads_plugin.flutter_ads_plugin.reward.RewardAd;
import com.flutter.ads_plugin.flutter_ads_plugin.splash.SplashAd;
import com.flutter.ads_plugin.flutter_ads_plugin.tube.TubeActivity;
import com.flutter.ads_plugin.flutter_ads_plugin.utils.ValueUtils;
import com.flutter.ads_plugin.flutter_ads_plugin.view.BannerViewFlutterPlugin;
import com.flutter.ads_plugin.flutter_ads_plugin.view.FeedViewFlutterPlugin;
import com.hzhj.openads.HJAdsSdk;
import com.hzhj.openads.listener.OnAdsSdkListener;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class FlutterAdsPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private static String hjTag = "HJ######TAG";
    private Activity mActivity;
    private FlutterPluginBinding flutterPluginBinding;
    private MethodChannel methodChannel;
    private ExecutorService executor = Executors.newSingleThreadExecutor();
    private SplashAd splashAd;
    private InterstitialAd interstitialAd;
    private RewardAd rewardAd;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        Log.d(hjTag, "___" + Process.myPid() + "___" + "onAttachedToEngine");
        this.flutterPluginBinding = flutterPluginBinding;
        methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_ads_plugin/method");
        methodChannel.setMethodCallHandler(this);
        if (splashAd == null) {
            splashAd = new SplashAd(flutterPluginBinding);
        }
        if (interstitialAd == null) {
            interstitialAd = new InterstitialAd(flutterPluginBinding);
        }
        if (rewardAd == null) {
            rewardAd = new RewardAd(flutterPluginBinding);
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        Log.d(hjTag, "___" + Process.myPid() + "___" + "onMethodCall=" + call.method);
        java.util.Map<String, Object> map = ValueUtils.getValue(call.arguments, new java.util.HashMap<>());
        if (call.method.equals("init")) {
            String initId = ValueUtils.getString(map.get("initId"));
            int isPersonalizedAdvertisingOn = ValueUtils.getInt(map.get("isPersonalizedAdvertisingOn"), 1);
            HJAdsSdk hjAdsSdk = HJAdsSdk.sharedAds();
            hjAdsSdk.setAdult(false); // Do not assume every user is an adult.
            hjAdsSdk.setDebugEnable(false);
            hjAdsSdk.setPersonalizedAdvertisingOn(isPersonalizedAdvertisingOn == 1);
            //hj初始化方法
            hjAdsSdk.startWithAppId(mActivity.getApplication(), initId);
        } else if (call.method.equals("init2")) {
            String initId = ValueUtils.getString(map.get("initId"));
            int isPersonalizedAdvertisingOn = ValueUtils.getInt(map.get("isPersonalizedAdvertisingOn"), 1);
            String csjAppId = ValueUtils.getString(map.get("csjAppId"));
            String djxJsonName = ValueUtils.getString(map.get("djxJsonName"));
            HJAdsSdk hjAdsSdk = HJAdsSdk.sharedAds();
            hjAdsSdk.setAdult(false); // Do not assume every user is an adult.
            hjAdsSdk.setDebugEnable(false);
            hjAdsSdk.setPersonalizedAdvertisingOn(isPersonalizedAdvertisingOn == 1);
            com.mobads.vivatb.WMNetworkConfig.Builder builder = new com.mobads.vivatb.WMNetworkConfig.Builder();
            if (!android.text.TextUtils.isEmpty(csjAppId)) {
                builder.addInitConfig(new com.mobads.vivatb.WMNetworkConfig.WMAdnInit() {
                    @Override
                    public int getAdnId() {
                        return com.mobads.vivatb.WMNetworkConfig.GROMORE;
                    }

                    @Override
                    public String getAppId() {
                        return csjAppId;
                    }

                    @Override
                    public String getAppKey() {
                        return "";
                    }
                });
            }
            com.mobads.vivatb.WMNetworkConfig wmNetworkConfig = builder.build();
            hjAdsSdk.setInitNetworkConfig(wmNetworkConfig, new OnAdsSdkListener() {
                @Override
                public void onNetworkInitBefore22() {
                    com.bytedance.sdk.djx.DJXSdkConfig config = new com.bytedance.sdk.djx.DJXSdkConfig.Builder().build();
                    com.bytedance.sdk.djx.DJXSdk.init(mActivity, djxJsonName, config);
                    com.bytedance.sdk.djx.DJXSdk.start(new com.bytedance.sdk.djx.DJXSdk.StartListener() {
                        @Override
                        public void onStartComplete(boolean b, String s, @Nullable com.bytedance.sdk.djx.model.DJXError djxError) {
                        }
                    });
                }

                @Override
                public void onNetworkInitBefore30() {
                }

                @Override
                public void onNetworkInitBefore19() {
                }
            });
            hjAdsSdk.startWithAppId(mActivity.getApplication(), initId);
        } else if (call.method.equals("openDJX")) {
            int dramaUnlockAdMode = ValueUtils.getInt(map.get("dramaUnlockAdMode"));
            int csjFreeSet = ValueUtils.getInt(map.get("csjFreeSet"));//短剧免费集数 5
            int csjLockSet = ValueUtils.getInt(map.get("csjLockSet"));//短剧解锁集数 2
            String rewardVideoId = ValueUtils.getString(map.get("rewardVideoId"));
            String userId = ValueUtils.getString(map.get("userId"));

            Intent intent = new Intent(mActivity, TubeActivity.class);
            intent.putExtra("dramaUnlockAdMode", dramaUnlockAdMode);
            intent.putExtra("CSJ_FREE_SET", csjFreeSet);
            intent.putExtra("CSJ_LOCK_SET", csjLockSet);
            intent.putExtra("rewardVideoId", rewardVideoId);
            intent.putExtra("userId", userId);

            mActivity.startActivity(intent);
        } else if (call.method.equals("loadSplash")) {
            if (splashAd != null) {
                String codeId = ValueUtils.getString(map.get("codeId"));
                splashAd.initHJAdsSdkSplash(mActivity, codeId);
                splashAd.loadAdOnly();
            }
        } else if (call.method.equals("showSplash")) {
            if (splashAd != null) {
                splashAd.showAd(mActivity);
            }
        } else if (call.method.equals("loadAndShowSplash")) {
            if (splashAd != null) {
                String codeId = ValueUtils.getString(map.get("codeId"));
                splashAd.initHJAdsSdkSplash(mActivity, codeId);
                splashAd.loadAndShow(mActivity);
            }
        } else if (call.method.equals("destroySplash")) {
            if (splashAd != null) {
                splashAd.destroyAd();
            }
        } else if (call.method.equals("loadInterstitial")) {
            if (interstitialAd != null) {
                String codeId = ValueUtils.getString(map.get("codeId"));
                String userId = ValueUtils.getString(map.get("userId"));
                interstitialAd.initHJAdsSdkInterstitial(mActivity, codeId, userId);
                interstitialAd.loadAd();
            }
        } else if (call.method.equals("showInterstitial")) {
            if (interstitialAd != null) {
                interstitialAd.showAd(mActivity);
            }
        } else if (call.method.equals("destroyInterstitial")) {
            if (interstitialAd != null) {
                interstitialAd.destroyAd();
            }
        } else if (call.method.equals("loadReward")) {
            if (rewardAd != null) {
                String codeId = ValueUtils.getString(map.get("codeId"));
                String userId = ValueUtils.getString(map.get("userId"));
                Map option = (Map) map.get("option");
                Map option2 = new HashMap();
                option2.putAll(option);
                rewardAd.initHJAdsSdkReward(mActivity, codeId, userId, option);
                rewardAd.loadAd();
            }
        } else if (call.method.equals("showReward")) {
            if (rewardAd != null) {
                Map option = (Map) map.get("option");
                HashMap option2 = new HashMap();
                option2.putAll(option);
                rewardAd.showAd(option2);
            }
        } else if (call.method.equals("destroyReward")) {
            if (rewardAd != null) {
                rewardAd.destroyAd();
            }
        } else if (call.method.equals("log")) {
            String msg = ValueUtils.getString(map.get("msg"));
            Log.d(hjTag, "___" + Process.myPid() + "___" + "FLUTTER=" + msg);
        } else {
            result.notImplemented();
            return;
        }
        result.success(null);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        Log.d(hjTag, "___" + Process.myPid() + "___" + "onDetachedFromEngine");
        methodChannel.setMethodCallHandler(null);
        if (splashAd != null) {
            splashAd.setStreamHandler();
            splashAd = null;
        }
        if (interstitialAd != null) {
            interstitialAd.setStreamHandler();
            interstitialAd = null;
        }
        if (rewardAd != null) {
            rewardAd.setStreamHandler();
            rewardAd = null;
        }
        executor.shutdown();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding activityPluginBinding) {
        mActivity = activityPluginBinding.getActivity();
        FeedViewFlutterPlugin.registerWith(mActivity, flutterPluginBinding);
        BannerViewFlutterPlugin.registerWith(mActivity, flutterPluginBinding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding activityPluginBinding) {

    }

    @Override
    public void onDetachedFromActivity() {

    }
}
