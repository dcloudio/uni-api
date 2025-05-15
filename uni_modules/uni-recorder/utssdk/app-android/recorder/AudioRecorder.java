package uts.sdk.modules.uniRecorder.recorder;

import android.media.MediaRecorder;
import android.os.Build;

import java.io.IOException;

import uts.sdk.modules.uniRecorder.util.DHFile;
import uts.sdk.modules.uniRecorder.util.PdrUtil;

public class AudioRecorder extends AbsRecorder{
    private MediaRecorder mRecorder;
    HighGradeRecorder.Callback mStateListener;

    public AudioRecorder(RecordOption option) {
        mRecorder = new MediaRecorder();
        try {
            mRecorder.reset();
            mRecorder.setAudioSource(MediaRecorder.AudioSource.DEFAULT);// 使用设备默认音源
            String _fullPath = option.mFileName;
            if (!DHFile.isExist(_fullPath)) {
                DHFile.createNewFile(DHFile.createFileHandler(_fullPath));
            }
            mRecorder.setOutputFile(_fullPath);
            try {
//				mRecorder.setAudioChannels(2);// 设置立体声
                // mRecorder.setAudioEncodingBitRate(bitRate);//设置比特率
                mRecorder.setAudioSamplingRate(option.mSamplingRate);
                if (option.mSamplingRate == 44100) {
                    mRecorder.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
                    mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);// AMR_WB\AAC\AMR_NB\DEFAULT
                } else if (option.mSamplingRate == 16000) {
                    mRecorder.setOutputFormat(MediaRecorder.OutputFormat.AMR_WB);
                    mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_WB);// AMR_WB\ACC\AMR_NB\DEFAULT
                } else if (option.mSamplingRate == 8000) {
                    mRecorder.setOutputFormat(MediaRecorder.OutputFormat.AMR_NB);
                    mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);// AMR_WB\ACC\AMR_NB\DEFAULT
                } else {
                    mRecorder.setOutputFormat(MediaRecorder.OutputFormat.DEFAULT);// AMR_WB\ACC\AMR_NB\DEFAULT
                    mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.DEFAULT);// AMR_WB\ACC\AMR_NB\DEFAULT
                }
            } catch (Exception e) {//出现设置异常时，需要重新设置参数
                mRecorder.reset();
                mRecorder.setAudioSource(MediaRecorder.AudioSource.DEFAULT);// 使用设备默认音源
                mRecorder.setOutputFile(_fullPath);
                if (PdrUtil.isEquals(option.mFormat, "3gp")) {
                    mRecorder.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
                } else if (Build.VERSION.SDK_INT >= 10) {
                    mRecorder.setOutputFormat(MediaRecorder.OutputFormat.AMR_NB);
                } else {
                    mRecorder.setOutputFormat(MediaRecorder.OutputFormat.DEFAULT);
                }
                mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);
            }
            mRecorder.prepare();
        } catch (IOException e) {
            e.printStackTrace();
        }


    }

    @Override
    public void start() {
        mRecorder.start();
    }

    @Override
    public void stop() {
        mRecorder.stop();
    }

    @Override
    public void pause() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            if (mStateListener != null) mStateListener.onPause();
        }
    }

    @Override
    public void resume() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            mRecorder.resume();
            if (mStateListener != null) mStateListener.onResume();
        }
    }

    @Override
    public void release() {
        mRecorder.release();
    }
    public AudioRecorder setCallback(HighGradeRecorder.Callback listener){
        this.mStateListener = listener;
        return this;
    }
}
