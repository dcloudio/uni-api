package uts.sdk.modules.uniRecorder.util;


import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;


/**
 * 
 * <p>Description:文件操作的封装</p>
 *
 * @version 1.0
 * @author cuidengfeng Email:cuidengfeng@dcloud.io
 * @Date 2013-4-25 下午4:46:37 created.
 * 
 * <pre><p>ModifiedLog:</p>
 * Log ID: 1.0 (Log编号 依次递增)
 * Modified By: cuidengfeng Email:cuidengfeng@dcloud.io at 2013-4-25 下午4:46:37</pre>
 */
public class DHFile {

	public static final int BUF_SIZE = 102400*2;// 存储缓冲
	public static final int READ = 1;
	public static final int WRITE = 2;
	public static final int READ_WRITE = 3;

	public static final byte FS_JAR = 0;
	public static final byte FS_RMS = 1;
	public static final byte FS_NATIVE = 2;
	/**
	 *  listroot时的根目录
	 */
	private static final String ROOTPATH="/";
	/**
	 * 
	 * Description: 格式为：C:\xxx.txt;\phone\xxx.txt;\phone\;c:\等，要求\与/兼容
	 * 
	 * @param pPath
	 * @return 返回一个文件句柄
	 */
	public static Object createFileHandler(String pPath) {
		Object _ret = null;
		pPath = pPath.replace('\\', '/');
		_ret = pPath;
		return _ret;
	}
	
	/**
	 * 
	 * Description: 创建一个新文件通过给定的句柄
	 * 
	 * @param FileHandler
	 * @return 返回值 为1时，创建成功；为-1时，文件创建失败，为-2时，文件已存在。
	 */
	public static byte createNewFile(Object FileHandler) {
		if(FileHandler == null){
			return -1;
		}
		File file = null;
		String temp = null;
		boolean isDir = false;

		if (FileHandler instanceof String) {
			temp = (String) FileHandler;
			file = new File(temp);
			if (temp.endsWith("/")) {
				isDir = true;
			}
		} else if (FileHandler instanceof File) {
			file = (File) FileHandler;
		}else{
			return -1;
		}
		
		byte _ret = 1;
		File parentPath = file.getParentFile();
		if (!parentPath.exists()) {
			boolean mkdirs = parentPath.mkdirs();
		}
		if (file.exists()) {
			_ret = -2;
			return _ret;
		} else {
			boolean success = false;
			if (isDir) {
				success = file.mkdirs();
			} else {

				try {
					success = file.createNewFile();
				} catch (IOException e) {
					_ret = -1;
				}
			}
			if (success) {
				_ret = 1;
			} else {
				_ret = -1;
			}
			return _ret;
		}

	}

	/**
	 * 
	 * Description: 删除文件
	 * 
	 * @param FileHandler
	 *            要删除的文件的句柄
	 */
	public static boolean delete(Object FileHandler) {
		if(FileHandler == null) {
			return false;
		}
		try {
			File d = getFile(FileHandler);
			boolean success = true;
			if (!d.exists()) {
				return false;
			}
			if (d.isFile()) {
				success = d.delete();
				return success;
			} else {
				File[] tmp = d.listFiles();
				if (tmp != null ) {
					if(tmp.length>0){

						for (int i = 0; i < tmp.length; i++) {
							if (tmp[i].isDirectory()) {
								String _path = d.getPath() + "/" + tmp[i].getName();
								success = delete(_path);
							} else {
								success = tmp[i].delete();
								Thread.sleep(2L);
							}
							if (!success)
								return false;
						}
					}

				}
				success=d.delete();
				// 递归删除
				return success;
			}


		} catch (Exception e) {
			return false;
		}
	}
	/**
	 * 
	 * Description: 判断文件是否存在
	 * 
	 * @param FileHandler
	 *            要判断的文件句柄
	 * @return 存在返回true,不存在返回false
	 */
	public static boolean exists(Object FileHandler){
		boolean isExist = false;
		if (FileHandler instanceof String) {
			try {
				String path = (String) FileHandler;
				if (path.endsWith("/")) {
					path = path.substring(0, path.length() - 1);
				}
				// URI uri = URI.create(path);
				File file = new File(path);
				isExist = file.exists();
			} catch (Exception e) {
				isExist = false;
			}
		} else if (FileHandler instanceof File) {
			try {
				File file = (File) FileHandler;
				isExist = file.exists();
			} catch (Exception e) {
				isExist = false;
			}
		}
		return isExist;
	}

	/**
	 * 
	 * Description: 返回文件所在路径
	 * 
	 * @param FileHandler
	 *            文件句柄
	 * @return 文件的路径
	 */
	public static String getPath(Object FileHandler){
		String _path = null;
		String _ret = null;
		if (FileHandler instanceof String) {
			_path = (String) FileHandler;
			int _index = _path.lastIndexOf('/');
			_path = _path.substring(0, _index + 1);

			_ret = _path;
		} else if (FileHandler instanceof File) {
			File file = (File) FileHandler;
			_path = file.getPath();
			_ret = _path;
		} else {
			_ret = null;
		}
		return _ret;

	}

	/**
	 * 
	 * Description: 获得文件的名字
	 * 
	 * @param FileHandler
	 *            文件句柄
	 * @return 文件的名字
	 */
	public static String getName(Object FileHandler) {
		String _path = "";
		String _ret = "";
		if (FileHandler instanceof String) {
			_path = (String) FileHandler;
			if (_path.endsWith("/")) {
				_path = _path.substring(0, _path.length() - 1);
			}
			int _index = _path.lastIndexOf('/');
			_path = _path.substring(_index + 1);
			_ret = _path;
		} else {
			File file = (File) FileHandler;
			_ret = file.getName();
		}
		return _ret;
	}

	/**
	 * 
	 * Description: 获得上级目录
	 * 
	 * @param FileHandler
	 *            ,这里应该是一个String，表示一个路径 文件句柄
	 * @return 上级目录句柄
	 */
	public static Object getParent(Object FileHandler) throws IOException {
		String path = getPath(FileHandler);
		StringBuffer sb = new StringBuffer(path);
		File file = (File) FileHandler;
		if (file.isDirectory()) {// 是目录时
			sb.deleteCharAt(sb.length() - 1);// 除去目录最后边的‘/’符合
		}
		int pos = sb.toString().lastIndexOf(47);
		sb.delete(pos, sb.length());
		return createFileHandler(sb.toString());
	}

	/**
	 * 
	 * Description: 判断文件句柄是否是一个目录
	 * 
	 * @param FileHandler
	 *            文件句柄
	 * @return 当文件句柄是否一个目录时返回true,否则返回false
	 */
	public static boolean isDirectory(Object FileHandler) throws IOException {
		File file = (File) FileHandler;
		return file.isDirectory();
	}

	/**
	 *
	 * Description: 获得文件大小
	 *
	 * @param FileHandler
	 *            文件句柄
	 * @return 返回文件大小，错误时返回-1
	 */
	public static long length(Object FileHandler) {
		long _ret = -1;
		try {
			File file = (File) FileHandler;
			_ret = file.length();
		} catch (Exception e) {
			_ret = -1;
		}
		return _ret;
	}

	/**
	 * 
	 * Description: 列出当前目录下的所有文件和目录的名称
	 * 
	 * @param FileHandler
	 * @return 返回目录名称
	 */
	public static String[] list(Object FileHandler) throws IOException {
		String[] _ret = null;
		Object[] obj = listFiles(FileHandler);
		if (obj != null) {
			_ret = new String[obj.length];
			for (int i = 0; i < obj.length; i++) {
				File file = (File) obj[i];
				if (file.isDirectory()) {
					_ret[i] = file.getName() + "/";
				} else {
					_ret[i] = file.getName();
				}
			}
		}
		return _ret;
	}
	/**
	 * 
	 * Description: 列出目录下所有的子目录
	 * @param FileHandler 目录的句柄
	 * @return
	 */
	public static String[] listDir(Object FileHandler)throws IOException {
		String[] _ret = null;
			Object[] obj=listFiles(FileHandler);
			
			if(obj!=null){
				_ret=new String[obj.length];
				for(int i=0;i<obj.length;i++){
					File file=(File)obj[i];
					if(file.isDirectory()){
						_ret[i]=file.getName()+"/";
					}				
				}
			}
		return _ret;
	}

	/**
	 * 
	 * Description: 返回路径下的文件和目录
	 * 
	 * @param FileHandler
	 * @return
	 */
	public static Object[] listFiles(Object FileHandler) throws IOException {
		File file = null;
		if (FileHandler instanceof String) {
			String path = (String) FileHandler;
			file = new File(path);
		} else if (FileHandler instanceof File) {
			file = (File) FileHandler;
		}
		if(file!=null){
			Object[] _ret = null;
			if (!file.isDirectory()) { // 当pPath是不存在路径时，也会return null
				_ret = null;
			}
			try {
				_ret = file.listFiles();
			} catch (Exception e) {
				_ret = null;
			}
			return _ret;
		}
		else{
			return null;
		}
		
	}

	/**
	 * 根据后缀递归查找文件
	 * @param fileTarget 文件夹
	 * @param suffix 后缀
	 * @return .
	 */
	public static List<String> listFilesWithSuffix(Object fileTarget , String suffix){
		List<String> result = new ArrayList<>();
		if (suffix == null) {
			return result;
		}
		File file = null;
		if (fileTarget instanceof String) {
			String path = (String) fileTarget;
			file = new File(path);
		} else if (fileTarget instanceof File) {
			file = (File) fileTarget;
		}

		if (file != null) {
			if (!file.exists()) {
				return result;
			}
			if (!file.isDirectory()) {
				return result;
			}

			File[] files = file.listFiles(new FilenameFilter() {
				@Override
				public boolean accept(File dir, String name) {
					return new File(dir, name).isDirectory() || name.toLowerCase().endsWith(suffix);
				}
			});
			if (files == null) {
				return result;
			}
			for (File temp : files) {
				if (temp.isDirectory()) {
					List<String> res = DHFile.listFilesWithSuffix(temp, suffix);
					result.addAll(res);
				}else {
					result.add(temp.getPath());
				}
			}
		}
		return result;
	}

	/**
	 * 递归查找特定名称的文件 , 区分大小写 .
	 * @param fileTarget .
	 * @param  pName .
	 * @return .
	 */
	public static List<String> listFilesWithName(Object fileTarget , String pName){
		List<String> result = new ArrayList<>();
		if (pName == null) {
			return result;
		}
		File file = null;
		if (fileTarget instanceof String) {
			String path = (String) fileTarget;
			file = new File(path);
		} else if (fileTarget instanceof File) {
			file = (File) fileTarget;
		}

		if (file != null) {
			if (!file.exists()) {
				return result;
			}
			if (!file.isDirectory()) {
				return result;
			}

			File[] files = file.listFiles(new FilenameFilter() {
				@Override
				public boolean accept(File dir, String name) {
					return new File(dir, name).isDirectory() || name.equals(pName);
				}
			});
			if (files == null) {
				return result;
			}
			for (File temp : files) {
				if (temp.isDirectory()) {
					List<String> res = DHFile.listFilesWithName(temp, pName);
					result.addAll(res);
				}else {
					result.add(temp.getPath());
				}
			}
		}
		return result;
	}


	/**
	 * 
	 * Description: 获得文件输出流
	 * 
	 * @param FileHandler
	 * @return 返回输出流
	 */
	public static OutputStream getOutputStream(Object FileHandler) throws IOException {
		File file = null;
		FileOutputStream fos;
		if (FileHandler instanceof String) {
			String temp = (String) FileHandler;
			file = new File(temp);
		} else if (FileHandler instanceof File) {
			file = (File) FileHandler;
		}
		if (file != null) {
			if (file.canWrite()) {
				try {
					fos = new FileOutputStream(file);
				} catch (FileNotFoundException e) {
					fos = null;
				}
			} else {
				fos = null;
			}

		} else {
			fos = null;
		}

		return fos;
	}
	/**
	 * 
	 * Description: 获得文件输出流
	 * 
	 * @param FileHandler 文件句柄
	 * @param append 是否在原有文件内容后继续拼接
	 * @return 返回输出流
	 */
	public static OutputStream getOutputStream(Object FileHandler, boolean append) throws IOException {
		File file = null;
		FileOutputStream fos;
		if (FileHandler instanceof String) {
			String temp = (String) FileHandler;
			file = new File(temp);
		} else if (FileHandler instanceof File) {
			file = (File) FileHandler;
		}
		if (file != null) {
			if (file.canWrite()) {
				try {
					//modified by caimingfu 2010-06-17 begin
					fos = new FileOutputStream(file,append);
					//modified by caimingfu 2010-06-17 end
					
				} catch (FileNotFoundException e) {
					fos = null;
				}
			} else {
				fos = null;
			}

		} else {
			fos = null;
		}

		return fos;
	}

	/**
	 * 
	 * Description: 获得文件输入流
	 * 
	 * @param FileHandler
	 * @return 返回输入流
	 */
	public static InputStream getInputStream(Object FileHandler) throws IOException {
		File file = null;
		InputStream _ret = null;
	
		if (FileHandler instanceof String) {
			String temp = (String) FileHandler;
			if(temp.startsWith("file://")){
				temp=temp.substring(7);
			}
			file = new File(temp);
		} else if (FileHandler instanceof File) {
			file = (File) FileHandler;
		}
		if (file != null && file.exists()) {
			if (file.isDirectory()) {
				return  null;// 如果是目录就返回null
			}

			try {
				_ret = new FileInputStream(file);
//				_ret = new UnicodeInputStream(_ret,Charset.defaultCharset().name());
			} catch (FileNotFoundException e) {
				_ret = null;
			} catch (SecurityException ex) {
				_ret = null;
			}
		}
		return _ret;
	}


	/**
	 * 
	 * Description: 获得文件路径
	 * 
	 * @param fileHandler
	 * @return
	 */
	public static String getFilePath(Object fileHandler){
		return getPath(fileHandler);
	}

	/**
	 * 
	 * Description: 返回文件路径
	 * 
	 * @param FileHandler
	 * @return
	 */
	public static String getFileUrl(Object FileHandler){
		return getPath(FileHandler);
		// String _path=null;
		// String _ret=null;
		// if(FileHandler instanceof String){
		// _path=(String)FileHandler;
		// _ret= _path;
		// }
		// else if(FileHandler instanceof java.io.File){
		// java.io.File file = (java.io.File) FileHandler;
		// _path=file.getPath();
		// _path=_path;
		// _ret= _path;
		// }
		// else{
		// _ret= null;
		// }
		// return _ret;
	}

	/**
	 * 
	 * Description: 获得文件名字
	 * 
	 * @param fileHandler
	 * @return
	 */
	public static String getFileName(Object fileHandler) {
		return getName(fileHandler);
	}

	/**
	 * 
	 * Description: 文件是否存在
	 * 
	 * @param pFilePath
	 * @return
	 */
	public static boolean isExist(String pFilePath) throws IOException {
		File file =new File(pFilePath);
		return file.exists();
	}

	/**
	 * 
	 * Description: 文件是否存在
	 * 
	 * @param pFileHandler
	 * @return
	 */
	public static boolean isExist(Object pFileHandler) throws IOException {
		File file = getFile(pFileHandler);
		if (file == null) {
			return false;
		} else {
			return file.exists();
		}

	}

	
	/**
	 * 
	 * Description: 文件是否是隐藏的
	 * 
	 * @param pFileHandler
	 * @return
	 */
	public static boolean isHidden(Object pFileHandler) throws IOException {
		File file = getFile(pFileHandler);
		if (file == null) {
			return false;
		} else {
			return file.isHidden();
		}

	}

	private static File getFile(Object pFileHandler) {
		File file = null;
		if (pFileHandler instanceof String) {
			String path = (String) pFileHandler;
			if (path.endsWith("/")) {
				path = path.substring(0, path.length() - 1);
			}
			file = new File(path);
		} else if (pFileHandler instanceof File) {
			file = (File) pFileHandler;
		}
		return file;
	}

	/**
	 * 
	 * Description: 获得文件的大小
	 * 
	 * @return
	 */
	public static long getFileSize(File file){		
		long _ret = 0;
		if(file.isDirectory()){
			File[] fileList = file.listFiles();
			for(File _file : fileList){
				_ret += getFileSize(_file);
			}
		}else{
			_ret += file.length();
		}
		return _ret;
	}
	/**
	 * Description: 在应用中添加一个文件
	 * 
	 * @param pFileName
	 *            文件名
	 * @param pData
	 *            文件数据
	 */
	public static void addFile(String pFileName, byte[] pData) throws IOException {
		// File f = new File(pFileName);
		// f.Open4Write();
		// f.write(pData);
		// if (APISupport.SupportFC) {
		// f.Close();
		// }
		Object f = DHFile.createFileHandler(pFileName);
		DHFile.createNewFile(f);
		OutputStream os = DHFile.getOutputStream(f, false);
		if (os != null) {
			try {
				os.write(pData, 0, pData.length);
				os.flush();
				os.close();

			} catch (IOException ex) {
				ex.printStackTrace();
			}
		}

	}

	/**
	 * 
	 * Description:通过文件名的尾字母判断程序需要的图片等类型（需要重新获取）
	 * @param pStrFileName 文件名
	 * @return
	 */
	private static boolean checkIsNeedReload(String pStrFileName) {
		return pStrFileName.endsWith(".png")
				||pStrFileName.endsWith(".jpg")
				||pStrFileName.endsWith(".xml")
				||pStrFileName.endsWith(".bmp");
	}
}
