package com.alivc.livepush;

import android.content.Context;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;

import java.util.Map;

import io.flutter.plugin.platform.PlatformView;


public class LivePusherView implements PlatformView {

    public static final String BASE_PUSH_VIEW = "plugins.livepush.base.preview";
    public static final String INTERACTIVE_PUSH_VIEW = "plugins.livepush.preview";
    public static final String INTERACTIVE_PULL_VIEW = "plugins.liveplayer.view";
    private View mView;
    private OnSurfaceHolderCallback mOnSurfaceHolderCallback;

    private String viewType;

    public LivePusherView(Context context, Object args) {
        viewType = "";
        if (args != null) {
            Map<String, Object> argsMap = (Map<String, Object>) args;
            viewType = (String) argsMap.get("viewType");
        }
        if (isInteractiveView()) {
            mView = new FrameLayout(context);
        } else {
            mView = new SurfaceView(context);
            ((SurfaceView) mView).getHolder().addCallback(new SurfaceHolder.Callback() {
                @Override
                public void surfaceCreated(@NonNull SurfaceHolder surfaceHolder) {
                    if (mOnSurfaceHolderCallback != null) {
                        mOnSurfaceHolderCallback.surfaceCreated();
                    }
                }

                @Override
                public void surfaceChanged(@NonNull SurfaceHolder surfaceHolder, int i, int i1, int i2) {
                    if (mOnSurfaceHolderCallback != null) {
                        mOnSurfaceHolderCallback.surfaceChanged();
                    }
                }

                @Override
                public void surfaceDestroyed(@NonNull SurfaceHolder surfaceHolder) {
                    if (mOnSurfaceHolderCallback != null) {
                        mOnSurfaceHolderCallback.surfaceDestroyed();
                    }
                }
            });
        }
    }

    public boolean isInteractiveView() {
        return INTERACTIVE_PUSH_VIEW.equals(viewType) || INTERACTIVE_PULL_VIEW.equals(viewType);
    }

    @Override
    public void onFlutterViewAttached(@NonNull View flutterView) {
        PlatformView.super.onFlutterViewAttached(flutterView);
    }

    @Override
    public View getView() {
        return mView;
    }

    @Override
    public void dispose() {
    }

    public interface OnSurfaceHolderCallback {
        void surfaceCreated();

        void surfaceChanged();

        void surfaceDestroyed();
    }

    public void setOnSurfaceHolderCallback(OnSurfaceHolderCallback callback) {
        this.mOnSurfaceHolderCallback = callback;
    }
}