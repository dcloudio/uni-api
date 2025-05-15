package uts.sdk.modules.uniRecorder;

import android.content.Context;
import android.media.AudioManager;
import android.os.Build;

import androidx.annotation.NonNull;

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

    private Function1<Object, Unit> mErrorCB;
    private Function1<Object, Unit> mStartCB;
    private Function1<RecorderManagerOnStopResult, Unit> mStopCB;
    private Function1<Object, Unit> mPauseCB;
    private Function1<Object, Unit> mResumeCB;
    private Function1<Object, Unit> mOnInterruptionBegin;

    public void setOnInterruptionBegin(Function1<Object, Unit> onInterruptionBegin) {
        this.mOnInterruptionBegin = onInterruptionBegin;
    }

    private Function1<Object, Unit> mOnInterruptionEnd;

    public void setOnInterruptionEnd(Function1<Object, Unit> onInterruptionEnd) {
        this.mOnInterruptionEnd = onInterruptionEnd;
    }

    public void setErrorCB(Function1<Object, Unit> errorCB) {
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
        PermissionUtils.INSTANCE.requestPermission(UTSAndroid.INSTANCE.getUniActivity(), "android.permission.RECORD_AUDIO", new PermissionCallback() {
            @Override
            public void isAllGranted(boolean result) {

            }

            @Override
            public void onGranted(@NonNull String[] permissions) {
                mAudioManager.requestAudioFocus(mAudioFocusChangeListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);

                LogUtils.INSTANCE.d("AudioRecorderMgr", "onGranted", mOption.mFormat);
                //mp3格式或者是aac格式
                if (isPause(mOption.mFormat)) {
                    mNativeRecorder = new HighGradeRecorder().
                            setRecordOption(mOption)
                            .setCallback(new RecorderCallback());

                    if (mOption.mFormat.equalsIgnoreCase("aac") && Build.VERSION.SDK_INT < 16) {
                        if (mErrorCB != null)
                            mErrorCB.invoke("the current system does not support AAC recording!");
                        return;
                    }
                    if (mOption.mFormat.equalsIgnoreCase("mp3") && !RecorderUtil.isContainMp3()) {
                        if (mErrorCB != null)
                            mErrorCB.invoke("the current application configuration does not support mp3");
                        return;
                    }
                    try {
                        mNativeRecorder.start();
                        LogUtils.INSTANCE.d("AudioRecorderMgr", "mStartCB", mStartCB);
                        if (mStartCB != null) mStartCB.invoke("");
                    } catch (Exception e) {
                        e.printStackTrace();
                        if (mErrorCB != null)
                            mErrorCB.invoke(e.getMessage());
                        stop();
                    }
                } else {//wav与pcm格式
                    mNativeRecorder = new AudioRecorder(mOption).setCallback(new RecorderCallback());
                    AbsRecorder mRecorder = mNativeRecorder;
                    try {
                        mRecorder.start();
                        LogUtils.INSTANCE.d("AudioRecorderMgr", "mStartCB", mRecorder);
                        if (mStartCB != null) mStartCB.invoke("");
                    } catch (Exception e) {
                        e.printStackTrace();
                        if (mErrorCB != null)
                            mErrorCB.invoke(e.getMessage());
                        stop();
                    }
                }

            }

            @Override
            public void onDenied(@NonNull String[] permissions) {
                if (mErrorCB != null)
                    mErrorCB.invoke("No Permission");
            }

            @Override
            public void onPermanentDenied(@NonNull String[] permissions) {

            }
        });
    }


    public void pause() {
        if (mOption != null) {
            mNativeRecorder.pause();
        }
    }

    public void resume() {
        if (mOption != null) {
            mNativeRecorder.resume();
        }
    }

    public void stopRecorder() {
        mAudioManager.abandonAudioFocus(mAudioFocusChangeListener);
        invokeStop();
    }

    private void invokeStop() {
        stop();
        if (mStopCB != null) mStopCB.invoke(new RecorderManagerOnStopResult() {
            @NonNull
            @Override
            public String getTempFilePath() {
                return mOption.mFileName;
            }

            @Override
            public void setTempFilePath(@NonNull String s) {

            }
        });
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

}
