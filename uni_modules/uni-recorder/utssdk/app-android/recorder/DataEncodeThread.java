package uts.sdk.modules.uniRecorder.recorder;

import android.media.AudioRecord;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;

import io.dcloud.feature.audio.mp3.SimpleLame;
import uts.sdk.modules.uniRecorder.aac.AacEncode;

public class DataEncodeThread extends Thread implements AudioRecord.OnRecordPositionUpdateListener {
	public static final int PROCESS_STOP = 1;
	private StopHandler mHandler;
	private byte[] mBuffer;
	private FileOutputStream mFileOutputStream;
	private String mFormat;
	private CountDownLatch mHandlerInitLatch = new CountDownLatch(1);

	static class StopHandler extends Handler {
		
		WeakReference<DataEncodeThread> encodeThread;
		
		public StopHandler(DataEncodeThread encodeThread) {
			this.encodeThread = new WeakReference<DataEncodeThread>(encodeThread);
		}
		
		@Override
		public void handleMessage(Message msg) {
			if (msg.what == PROCESS_STOP) {
				DataEncodeThread threadRef = encodeThread.get();
				//处理缓冲区中的数据
				while (threadRef.processData() > 0);
				// Cancel any event left in the queue
				removeCallbacksAndMessages(null);					
				threadRef.flushAndRelease();
				getLooper().quit();
			}
			super.handleMessage(msg);
		}
	};

	/**
	 *
	 * @param file
	 * @param bufferSize
	 * @throws FileNotFoundException
	 */
	public DataEncodeThread(File file, int bufferSize, String format) throws FileNotFoundException {
		this.mFileOutputStream = new FileOutputStream(file);
		mBuffer = new byte[(int) (7200 + (bufferSize * 2 * 1.25))];
		this.mFormat = format;

	}

	@Override
	public void run() {
		Looper.prepare();
		mHandler = new StopHandler(this);
		mHandlerInitLatch.countDown();
		Looper.loop();
	}

	/**
	 * Return the handler attach to this thread
	 * @return
	 */
	public Handler getHandler() {
		try {
			mHandlerInitLatch.await();
		} catch (InterruptedException e) {
			e.printStackTrace();
		}
		return mHandler;
	}

	@Override
	public void onMarkerReached(AudioRecord recorder) {
		// Do nothing		
	}

	@Override
	public void onPeriodicNotification(AudioRecord recorder) {
		processData();
	}
	/**
	 * 从缓冲区中读取并处理数据，使用lame编码MP3
	 * @return  从缓冲区中读取的数据的长度
	 * 			缓冲区中没有数据时返回0 
	 */
	private int processData() {	
		if (mTasks.size() > 0) {
			Task task = mTasks.remove(0);
			short[] buffer = task.getData();
			short[] rightData = task.getRightData();
			int readSize = task.getReadSize();
			if(task.getRightData() != null && task.getRightData().length > 0){
				rightData = task.getRightData();
			}else{
				rightData = task.getData();
			}
			int encodedSize = 0;
			if(mFormat.equalsIgnoreCase("aac")) {
				try {
					mBuffer = AacEncode.getAacEncode().offerEncoder(task.getByteData());
					encodedSize = mBuffer.length;
				} catch (Exception e) {
					e.printStackTrace();
				}
			} else {
				encodedSize = SimpleLame.encode(buffer, rightData, readSize, mBuffer);
			}

			if (encodedSize > 0){
				try {
					mFileOutputStream.write(mBuffer, 0, encodedSize);
				} catch (IOException e) {
					e.printStackTrace();
				}
			}
			return readSize;
		}
		return 0;
	}
	
	
	/**
	 * Flush all data left in lame buffer to file
	 */
	private void flushAndRelease() {
		//将结尾信息写入buffer中
		int flushResult = 0;
		if(mFormat.equalsIgnoreCase("aac")) {
			try {
				mBuffer = AacEncode.getAacEncode().offerEncoder(mBuffer);
				flushResult = mBuffer.length;
			} catch (Exception e) {
				e.printStackTrace();
			}
		} else {
			flushResult = SimpleLame.flush(mBuffer);
		}
		if (flushResult > 0) {
			try {
				mFileOutputStream.write(mBuffer, 0, flushResult);
			} catch (IOException e) {
				e.printStackTrace();
			}finally{
				if (mFileOutputStream != null) {
					try {
						mFileOutputStream.close();
						mFileOutputStream=null;
					} catch (IOException e) {
						e.printStackTrace();
					}
				}
			}
		}
		if(mFormat.equalsIgnoreCase("aac")) {
			AacEncode.getAacEncode().close();
		} else {
			SimpleLame.close();
		}
	}
	private List<Task> mTasks = Collections.synchronizedList(new ArrayList<Task>());
	public void addTask(short[] rawData, int readSize){
		mTasks.add(new Task(rawData, readSize));
	}
	public void addTask(short[] rawData,short[] rightData, int readSize){
		mTasks.add(new Task(rawData, rightData,readSize));
	}
	public void addTask(byte[] rawData, int readSize) {
		mTasks.add(new Task(rawData, readSize));
	}
	private class Task{
		private short[] rawData;
		private byte[] byteRawData;
		private int readSize;
		private short[] rightData;
		public Task(short[] rawData, int readSize){
			this.rawData = rawData.clone();
			this.readSize = readSize;
		}

		public Task(byte[] rawData, int readSize){
			this.byteRawData = rawData.clone();
			this.readSize = readSize;
		}

		public Task(short[] leftData, short[] rightData,int readSize){
			this.rawData = leftData.clone();
			this.rightData = rightData.clone();
			this.readSize = readSize;
		}
		public short[] getData(){
			return rawData;
		}
		
		public short[] getRightData(){
			return rightData;
		}
		
		public int getReadSize(){
			return readSize;
		}

		public byte[] getByteData() {
			return byteRawData;
		}
	}
}
