package uts.sdk.modules.uniRecorder.recorder;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

public class RecorderUtil {

    public static Context getContext() {
        return context;
    }

    private static  Context context;

     static boolean isDebug() {
        return isDebug;
    }

    private static  boolean isDebug;
    private static Handler mainHandler;

    public static void init(Context context ,boolean isDebug){
        RecorderUtil.context = context;
        RecorderUtil.isDebug = isDebug;
        mainHandler = getMainHandler();
    }

     static Handler getMainHandler() {
        if(mainHandler ==null){
            mainHandler = new Handler(Looper.getMainLooper());
        }
        return mainHandler;
    }

     static void postTaskSafely(Runnable runnable){
        getMainHandler().post(runnable);
    }


    public static boolean isContainMp3() {
        try {
            Class.forName("io.dcloud.feature.audio.mp3.mp3Impl");
            return true;
        }catch(Exception e) {
            return false;
        }
    }


}
