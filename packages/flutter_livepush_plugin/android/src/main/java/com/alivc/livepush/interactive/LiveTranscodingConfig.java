package com.alivc.livepush.interactive;

import android.text.TextUtils;
import android.util.Log;

import com.alivc.live.pusher.AlivcLiveMixStream;
import com.alivc.live.pusher.AlivcLiveTranscodingConfig;
import com.alivc.live.pusher.AlivcLiveTranscodingCropModeEnum;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class LiveTranscodingConfig {

    private final AlivcLiveTranscodingConfig mAlivcLiveTranscodingConfig;

    public LiveTranscodingConfig() {
        mAlivcLiveTranscodingConfig = new AlivcLiveTranscodingConfig();
    }

    public AlivcLiveTranscodingConfig getAlivcLiveTranscodingConfig() {
        return mAlivcLiveTranscodingConfig;
    }

    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "setBackgroundColor":
                String setBackgroundColor = call.argument("arg");
                if (setBackgroundColor != null) {
                    mAlivcLiveTranscodingConfig.setBackgroundColor(Integer.parseInt(setBackgroundColor));
                }
                result.success(null);
                break;
            case "getBackgroundColor":
                result.success(mAlivcLiveTranscodingConfig.getBackgroundColor());
                break;
            case "setCropMode":
                String setCropMode = call.argument("arg");
                if (setCropMode != null) {
                    AlivcLiveTranscodingCropModeEnum cropModeEnum;
                    if ("1".equals(setCropMode)) {
                        cropModeEnum = AlivcLiveTranscodingCropModeEnum.AlivcLiveTranscodingCropModeFill;
                    } else {
                        cropModeEnum = AlivcLiveTranscodingCropModeEnum.AlivcLiveTranscodingCropModeCrop;
                    }
                    mAlivcLiveTranscodingConfig.setCropMode(cropModeEnum);
                }
                result.success(null);
                break;
            case "getCropMode":
                AlivcLiveTranscodingCropModeEnum cropMode = mAlivcLiveTranscodingConfig.getCropMode();
                result.success((cropMode.ordinal() - 1) + "");
                break;
            case "setMixStreams":
                List<Map<String,String>> setMixStreamsArray = call.argument("arg");
                if (setMixStreamsArray != null) {
                    ArrayList<AlivcLiveMixStream> realMixStreamArray = new ArrayList<>();
                    for (Map<String, String> setMixStreamsMap : setMixStreamsArray) {
                        String mixStreamX = setMixStreamsMap.get("x");
                        String mixStreamY = setMixStreamsMap.get("y");
                        String mixStreamWidth = setMixStreamsMap.get("width");
                        String mixStreamHeight = setMixStreamsMap.get("height");
                        String mixStreamUserId = setMixStreamsMap.get("userId");
                        String mixStreamZOrder = setMixStreamsMap.get("zOrder");

                        AlivcLiveMixStream alivcLiveMixStream = new AlivcLiveMixStream();
                        if (!TextUtils.isEmpty(mixStreamX)) {
                            assert mixStreamX != null;
                            alivcLiveMixStream.setX(Integer.parseInt(mixStreamX));
                        }
                        if (!TextUtils.isEmpty(mixStreamY)) {
                            assert mixStreamY != null;
                            alivcLiveMixStream.setY(Integer.parseInt(mixStreamY));
                        }
                        if (!TextUtils.isEmpty(mixStreamWidth)) {
                            assert mixStreamWidth != null;
                            alivcLiveMixStream.setWidth(Integer.parseInt(mixStreamWidth));
                        }
                        if (!TextUtils.isEmpty(mixStreamHeight)) {
                            assert mixStreamHeight != null;
                            alivcLiveMixStream.setHeight(Integer.parseInt(mixStreamHeight));
                        }
                        if (!TextUtils.isEmpty(mixStreamUserId)) {
                            assert mixStreamUserId != null;
                            alivcLiveMixStream.setUserId(mixStreamUserId);
                        }
                        if (!TextUtils.isEmpty(mixStreamZOrder)) {
                            assert mixStreamZOrder != null;
                            alivcLiveMixStream.setZOrder(Integer.parseInt(mixStreamZOrder));
                        }
                        realMixStreamArray.add(alivcLiveMixStream);
                    }
                    mAlivcLiveTranscodingConfig.setMixStreams(realMixStreamArray);
                }
                result.success(null);
                break;
            case "getMixStreams":
                ArrayList<AlivcLiveMixStream> currentMixStreams = mAlivcLiveTranscodingConfig.getMixStreams();
                JSONArray jsonArray = new JSONArray();
                for (int i = 0; i < currentMixStreams.size(); i++) {
                    JSONObject jsonObject = new JSONObject();
                    AlivcLiveMixStream currentMixStream = currentMixStreams.get(i);
                    try {
                        jsonObject.put("userId",currentMixStream.getUserId());
                        jsonObject.put("x",currentMixStream.getX());
                        jsonObject.put("y",currentMixStream.getY());
                        jsonObject.put("width",currentMixStream.getWidth());
                        jsonObject.put("height",currentMixStream.getHeight());
                        jsonObject.put("zOrder",currentMixStream.getZOrder());
                        jsonArray.put(i,jsonObject);
                    } catch (JSONException e) {
                        throw new RuntimeException(e);
                    }
                }
                result.success(jsonArray.toString());
                break;
        }
    }
}
