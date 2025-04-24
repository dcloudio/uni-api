package uts.sdk.modules.uniRecorder.recorder;

import uts.sdk.modules.uniRecorder.AudioRecorderMgr;
import uts.sdk.modules.uniRecorder.util.PdrUtil;
import uts.sdk.modules.uniRecorder.RecorderManagerStartOptions;

public class RecordOption {
    public String mFileName;
    public int mSamplingRate;
    //录音输出格式类型：3gp/amr_nb/amr_wb/acc/mp3,默认amr
    public String mFormat;
    public boolean isRateDeft = false;

    public RecordOption(RecorderManagerStartOptions pOption, String fileName) {
        Number rate = pOption.getSampleRate();
        mFormat = pOption.getFormat();
        if (PdrUtil.isEmpty(mFormat)) {
            mFormat = "amr";
        }
        int pDeft = 8000;
        if (AudioRecorderMgr.isPause(mFormat)) {
            pDeft = 44100;
        }
        if (!PdrUtil.isEmpty(rate)) {
            isRateDeft = false;
            mSamplingRate = PdrUtil.parseInt(rate.toString(), pDeft);
        } else {
            isRateDeft = true;
            mSamplingRate = pDeft;
        }
        mFileName = fileName;
    }
}
