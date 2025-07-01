package uts.sdk.modules.uniRecorder;

import android.content.Context;
import android.media.AudioManager;
import android.os.Build;

import androidx.annotation.NonNull;

import java.util.List;

import io.dcloud.uniapp.util.LogUtils;
import io.dcloud.uniapp.util.PermissionCallback;
import io.dcloud.uniapp.util.PermissionUtils;
import io.dcloud.uts.UTSAndroid;
import uts.sdk.modules.uniRecorder.recorder.AbsRecorder;
import uts.sdk.modules.uniRecorder.recorder.AudioRecorder;
import uts.sdk.modules.uniRecorder.recorder.HighGradeRecorder;
import uts.sdk.modules.uniRecorder.recorder.RecordOption;
import uts.sdk.modules.uniRecorder.recorder.RecorderUtil;
import kotlin.Unit;
import kotlin.jvm.functions.Function1;
import kotlin.jvm.functions.Function2;
import io.dcloud.uts.UTSAndroid;
import io.dcloud.uts.UTSArray;
import io.dcloud.uts.UTSObject;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.HashMap;
import java.util.Map;

import io.dcloud.uts.UTSJSONObject;
import io.dcloud.uts.json.IJsonStringify;
import io.dcloud.uts.log.LogSelfV2;

public class AudioRecorderMgr extends AbsAudio {
    AbsRecorder mNativeRecorder;
    RecordOption mOption;
    private AudioManager mAudioManager;
    private AudioManager.OnAudioFocusChangeListener mAudioFocusChangeListener;

    public AudioRecorderMgr() {
        mAudioManager = (AudioManager) UTSAndroid.INSTANCE.getUniActivity().getSystemService(Context.AUDIO_SERVICE);
        mAudioFocusChangeListener = new AudioManager.OnAudioFocusChangeListener() {
            @Override
            public void onAudioFocusChange(int focusChange) {
                LogUtils.INSTANCE.d("。", "onAudioFocusChange: " + focusChange);

                switch (focusChange) {
                    case AudioManager.AUDIOFOCUS_GAIN:
                        // 重新获得焦点
                        if (mNativeRecorder != null && mOnInterruptionEnd != null) {
                            mOnInterruptionEnd.invoke("");
                        }
                        break;
                    case AudioManager.AUDIOFOCUS_LOSS:
                        // 永久失去焦点
                        if (mNativeRecorder != null && mOnInterruptionBegin != null) {
                            mOnInterruptionBegin.invoke("");
                            invokeStop();
                        }
                        break;
                    case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
                        // 暂时失去焦点
                        if (mNativeRecorder != null && mOnInterruptionBegin != null) {
                            mOnInterruptionBegin.invoke("");
                            invokeStop();
                        }
                        break;
                }
            }
        };
    }

    private Function1<IRecorderManagerFail, Unit> mErrorCB;
    private Function1<Object, Unit> mStartCB;
    private Function1<RecorderManagerOnStopResult, Unit> mStopCB;
    private Function1<Object, Unit> mPauseCB;
    private Function1<Object, Unit> mResumeCB;
    private Function1<Object, Unit> mOnInterruptionBegin;
    private boolean isStarted = false;

    public void setOnInterruptionBegin(Function1<Object, Unit> onInterruptionBegin) {
        this.mOnInterruptionBegin = onInterruptionBegin;
    }

    private Function1<Object, Unit> mOnInterruptionEnd;

    public void setOnInterruptionEnd(Function1<Object, Unit> onInterruptionEnd) {
        this.mOnInterruptionEnd = onInterruptionEnd;
    }

    public void setErrorCB(Function1<IRecorderManagerFail, Unit> errorCB) {
        this.mErrorCB = errorCB;
    }

    public void setStartCB(Function1<Object, Unit> startCB) {
        this.mStartCB = startCB;
    }

    public void setPauseCB(Function1<Object, Unit> pauseCB) {
        this.mPauseCB = pauseCB;
    }

    public void setResumeCB(Function1<Object, Unit> resumeCB) {
        this.mResumeCB = resumeCB;
    }


    public void setStopCB(Function1<RecorderManagerOnStopResult, Unit> stopCB) {
        this.mStopCB = stopCB;
    }

    public class RecorderCallback implements HighGradeRecorder.Callback {
        @Override
        public void onStart() {

        }

        @Override
        public void onPause() {
            if (mPauseCB != null) {
                mPauseCB.invoke("");
            }
        }

        @Override
        public void onResume() {
            if (mResumeCB != null) {
                mResumeCB.invoke("");
            }
        }

        @Override
        public void onStop(int action) {

        }

        @Override
        public void onReset() {

        }

        @Override
        public void onRecording(double duration, double volume) {

        }

        @Override
        public void onMaxDurationReached() {

        }
    }

    public void startRecorder(final RecordOption pOption) {
        LogUtils.INSTANCE.d("AudioRecorderMgr", "startRecorder", pOption);
        mOption = pOption;
        Function2<Boolean, List<String>, Unit> successCallback = new Function2<Boolean, List<String>, Unit>() {
            @Override
            public Unit invoke(Boolean allRight, List<String> grantedList) {
                // 权限请求成功
                mAudioManager.requestAudioFocus(mAudioFocusChangeListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);

                LogUtils.INSTANCE.d("AudioRecorderMgr", "onGranted", mOption.mFormat);
                //mp3格式或者是aac格式
                if (isPause(mOption.mFormat)) {
                    mNativeRecorder = new HighGradeRecorder().
                            setRecordOption(mOption)
                            .setCallback(new RecorderCallback());

                    if (mOption.mFormat.equalsIgnoreCase("aac") && Build.VERSION.SDK_INT < 16) {
                        isStarted = false;
                        if (AudioRecorderMgr.this.mErrorCB != null)
                            AudioRecorderMgr.this.mErrorCB.invoke(new RecorderManagerFailImpl(1107605, "the current system does not support AAC recording!"));
                        return Unit.INSTANCE;
                    }
                    if (mOption.mFormat.equalsIgnoreCase("mp3") && !RecorderUtil.isContainMp3()) {
                        isStarted = false;
                        if (AudioRecorderMgr.this.mErrorCB != null)
                            AudioRecorderMgr.this.mErrorCB.invoke(new RecorderManagerFailImpl(1107605, "the current application configuration does not support mp3"));
                        return Unit.INSTANCE;
                    }
                    try {
                        mNativeRecorder.start();
                        LogUtils.INSTANCE.d("AudioRecorderMgr", "mStartCB", mStartCB);
                        isStarted = true;
                        if (mStartCB != null) mStartCB.invoke("");
                    } catch (Exception e) {
                        e.printStackTrace();
                        isStarted = false;
                        if (AudioRecorderMgr.this.mErrorCB != null)
                            AudioRecorderMgr.this.mErrorCB.invoke(new RecorderManagerFailImpl(1107606, e.getMessage()));
                        stop();
                    }
                } else {//wav与pcm格式
                    mNativeRecorder = new AudioRecorder(mOption).setCallback(new RecorderCallback());
                    AbsRecorder mRecorder = mNativeRecorder;
                    try {
                        mRecorder.start();
                        LogUtils.INSTANCE.d("AudioRecorderMgr", "mStartCB", mRecorder);
                        isStarted = true;
                        if (mStartCB != null) mStartCB.invoke("");
                    } catch (Exception e) {
                        e.printStackTrace();
                        isStarted = false;
                        if (AudioRecorderMgr.this.mErrorCB != null)
                            AudioRecorderMgr.this.mErrorCB.invoke(new RecorderManagerFailImpl(1107606, e.getMessage()));
                        stop();
                    }
                }
                return Unit.INSTANCE;
            }
        };

        // 实现失败回调
        Function2<Boolean, List<String>, Unit> failureCallback = new Function2<Boolean, List<String>, Unit>() {
            @Override
            public Unit invoke(Boolean doNotAskAgain, List<String> grantedList) {
                // 权限请求失败
                isStarted = false;
                if (AudioRecorderMgr.this.mErrorCB != null)
                    AudioRecorderMgr.this.mErrorCB.invoke(new RecorderManagerFailImpl(1107601, ""));
                return Unit.INSTANCE;
            }
        };
        UTSAndroid.INSTANCE.requestSystemPermission(UTSAndroid.INSTANCE.getUniActivity(), new UTSArray<String>() {{
            push("android.permission.RECORD_AUDIO");
        }}, successCallback, failureCallback, false);
    }


    public void pause() {
        if (mNativeRecorder != null) {
            mNativeRecorder.pause();
        }
    }

    public void resume() {
        if (mNativeRecorder != null) {
            mNativeRecorder.resume();
        }
    }

    public void stopRecorder() {
        mAudioManager.abandonAudioFocus(mAudioFocusChangeListener);
        invokeStop();
    }

    private void invokeStop() {
        stop();
        if (isStarted == true) {
            isStarted = false;
            if (mStopCB != null) mStopCB.invoke(new RecorderStopCallback(mOption.mFileName));
        }
    }

    private void stop() {
        if (mNativeRecorder != null) {
            mNativeRecorder.stop();
            mNativeRecorder.release();
            mNativeRecorder = null;
        }
    }

    public static boolean isPause(String format) {
        return format.equalsIgnoreCase("mp3") || format.equalsIgnoreCase("aac");
    }
	
	private static class RecorderStopCallback implements RecorderManagerOnStopResult,io.dcloud.uts.json.IJsonStringify, LogSelfV2 {
		
		String tempFilePath = "";
		
		public RecorderStopCallback(String filePath) {
			this.tempFilePath = filePath;
		}
		
		@NonNull
		@Override
		public String getTempFilePath() {
		    return this.tempFilePath;
		}
		
		@Override
		public void setTempFilePath(@NonNull String s) {
		
		}
		
        @Nullable
        @Override
        public Object toJSON() {
            UTSJSONObject object = new UTSJSONObject();
            object.set("tempFilePath",this.tempFilePath);
            return object;
        }

        @NonNull
        @Override
        public Map<String, Object> toLogMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("tempFilePath", this.tempFilePath);
            return map;
        }
	}
}
