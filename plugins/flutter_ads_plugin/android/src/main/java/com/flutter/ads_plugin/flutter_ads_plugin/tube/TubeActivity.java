package com.flutter.ads_plugin.flutter_ads_plugin.tube;

import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.bytedance.sdk.djx.DJXRewardAdResult;
import com.bytedance.sdk.djx.DJXSdk;
import com.bytedance.sdk.djx.IDJXWidget;
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaHomeListener;
import com.bytedance.sdk.djx.interfaces.listener.IDJXDramaUnlockListener;
import com.bytedance.sdk.djx.model.DJXDrama;
import com.bytedance.sdk.djx.model.DJXDramaDetailConfig;
import com.bytedance.sdk.djx.model.DJXDramaUnlockAdMode;
import com.bytedance.sdk.djx.model.DJXDramaUnlockInfo;
import com.bytedance.sdk.djx.model.DJXDramaUnlockMethod;
import com.bytedance.sdk.djx.model.DJXUnlockModeType;
import com.bytedance.sdk.djx.params.DJXWidgetDramaHomeParams;
import com.flutter.ads_plugin.flutter_ads_plugin.R;
import com.hzhj.openads.HJAdsSdkReward;
import com.hzhj.openads.HJRewardVerify;
import com.hzhj.openads.domain.HJAdError;
import com.hzhj.openads.listener.HJOnAdsSdkRewardListener;
import com.hzhj.openads.req.HJRewardAdRequest;

import java.util.HashMap;
import java.util.Map;

//csj短剧
public class TubeActivity extends AppCompatActivity {
    private HJAdsSdkReward rewardAd;
    private HashMap<String, Object> map = new HashMap<>();

    boolean isInited = false;
    IDJXWidget dpWidget;

    private long lastRequestTime = 0;
    private static final long REQUEST_INTERVAL = 1500; // 1.5秒间隔
    private int dramaUnlockAdMode;
    private int csjFreeSet;
    private int csjLockSet;
    private String rewardVideoId;
    private String userId;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        dramaUnlockAdMode = getIntent().getIntExtra("dramaUnlockAdMode", 0);
        csjFreeSet = getIntent().getIntExtra("CSJ_FREE_SET", 1);
        csjLockSet = getIntent().getIntExtra("CSJ_LOCK_SET", 1);
        rewardVideoId = getIntent().getStringExtra("rewardVideoId");
        userId = getIntent().getStringExtra("userId");

        setContentView(R.layout.activity_tube);
        //https://www.csjplatform.com/supportcenter/28148
        if (DJXSdk.isStartSuccess()) {
            init();
        }
    }

    private void init() {
        if (isInited) {
            return;
        }
        initWidget();
        if (dpWidget != null) {
            getSupportFragmentManager().beginTransaction()
                    .replace(R.id.a_tube_fl, dpWidget.getFragment())
                    .commit();
            isInited = true;
        }
    }

    private void initWidget() {
        //DJXDramaUnlockAdMode.MODE_COMMON,//短剧内置的默认激励视频
        //DJXDramaUnlockAdMode.MODE_SPECIFIC,//自定义的激励视频
        DJXDramaUnlockAdMode mode = DJXDramaUnlockAdMode.MODE_SPECIFIC;
        if (dramaUnlockAdMode == 0) {
            mode = DJXDramaUnlockAdMode.MODE_SPECIFIC;
        } else {
            mode = DJXDramaUnlockAdMode.MODE_COMMON;
        }
        DJXDramaDetailConfig detailConfig = DJXDramaDetailConfig.obtain(
                mode,
                csjFreeSet,
                new IDJXDramaUnlockListener() {
                    @Override
                    public void unlockFlowStart(@NonNull DJXDrama drama, @NonNull UnlockCallback unlockCallback, @Nullable Map<String, ?> map) {
                        //DJXDramaUnlockInfo unlockInfo = new DJXDramaUnlockInfo(djxDrama.id, ConfigInfo.CSJ_LOCK_SET, DJXDramaUnlockMethod.METHOD_AD, false);
                        DJXDramaUnlockInfo unlockInfo = new DJXDramaUnlockInfo(drama.id, csjLockSet, DJXDramaUnlockMethod.METHOD_AD, false, null, false, DJXUnlockModeType.UNLOCKTYPE_DEFAULT);
                        unlockCallback.onConfirm(unlockInfo);
                    }

                    @Override
                    public void unlockFlowEnd(@NonNull DJXDrama djxDrama, @Nullable UnlockErrorStatus unlockErrorStatus, @Nullable Map<String, ?> map) {
                        Log.d("###TAG###", "unlockFlowEnd");
                        Log.d("###TAG###", "DJXDrama=" + djxDrama.toString());
                        if (unlockErrorStatus == null) {
                            Log.d("###TAG###", "UnlockErrorStatus==null");
                        } else {
                            Log.d("###TAG###", "UnlockErrorStatus=" + unlockErrorStatus.toString());
                        }
                        if (map == null) {
                            Log.d("###TAG###", "Map==null");
                        } else {
                            Log.d("###TAG###", "Map=" + map.toString());
                        }
                    }

                    @Override
                    public void showCustomAd(@NonNull DJXDrama djxDrama, @NonNull CustomAdCallback customAdCallback) {
                        //https://www.csjplatform.com/supportcenter/28261
                        //showRewardAd(customAdCallback);
                        showRewardAdWithThrottle(customAdCallback);
                    }
                }
        );
        DJXWidgetDramaHomeParams djxWidgetDramaHomeParams = DJXWidgetDramaHomeParams.obtain(detailConfig)
                .listener(new IDJXDramaHomeListener() {
                    @Override
                    public void onItemClick(DJXDrama djxDrama, @Nullable Map<String, Object> map) {
                        super.onItemClick(djxDrama, map);
                    }
                });
        dpWidget = DJXSdk.factory().createDramaHome(djxWidgetDramaHomeParams);
    }

    private void showRewardAdWithThrottle(IDJXDramaUnlockListener.CustomAdCallback customAdCallback) {
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastRequestTime < REQUEST_INTERVAL) {
            Log.d("######", "请求过于频繁，已拦截。距离上次请求: " + (currentTime - lastRequestTime) + "ms");
            return;
        }
        lastRequestTime = currentTime;
        Log.d("######", "发起广告请求");
        showRewardAd(customAdCallback);
    }

    private void showRewardAd(IDJXDramaUnlockListener.CustomAdCallback customAdCallback) {
        HJRewardAdRequest hjRewardAdRequest = new HJRewardAdRequest(rewardVideoId, userId, null);
        if (rewardAd == null || !rewardAd.isReady()) {
            rewardAd = new HJAdsSdkReward(this, hjRewardAdRequest, new HJOnAdsSdkRewardListener() {
                @Override
                public void onVideoAdLoadSuccess(String s) {
                    Log.d("######", "onVideoAdLoadSuccess=" + s);
                    if (rewardAd.isReady()) {
                        rewardAd.show(map);
                    }
                }

                @Override
                public void onVideoAdPlayEnd() {
                    Log.d("######", "onVideoAdPlayEnd");
                }

                @Override
                public void onVideoAdPlayStart() {
                    Log.d("######", "展现回调");
                    customAdCallback.onShow("");
                }

                @Override
                public void onVideoAdClicked() {
                    Log.d("######", "onVideoAdClicked");
                }

                @Override
                public void onVideoRewarded(String transId, HJRewardVerify hjRewardVerify) {
                    Log.d("######", "########解锁剧集 成功回调 开始");
                    DJXRewardAdResult result = new DJXRewardAdResult(true, new HashMap<>());
                    customAdCallback.onRewardVerify(result);
                    Log.d("######", "########解锁剧集 成功回调 结束");
                }

                @Override
                public void onVideoAdClosed() {
                    Log.d("######", "onVideoAdClosed");
                }

                @Override
                public void onVideoAdLoadError(HJAdError hjAdError, String s) {
                    Log.d("######", "视频加载失败=" + hjAdError.msg);
                    customAdCallback.onError();
                }

                @Override
                public void onVideoAdPlayError(HJAdError hjAdError, String s) {
                    Log.d("######", "视频播放失败=" + hjAdError.msg);
                    customAdCallback.onError();
                }
            });
            rewardAd.loadAd();
        } else {
            rewardAd.show(map);
        }
    }

    @Override
    protected void onDestroy() {
        Log.d("######", "onDestroy");
        super.onDestroy();
    }
}
