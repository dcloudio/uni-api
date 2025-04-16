package uts.sdk.modules.uniRecorder.util;

import java.util.Locale;

public class PdrUtil {
	/**
	 * 比较两个字符串时候相等(不区分大小写)
	 * @param pStr1
	 * @param pStr2
	 * @return
	 * <br/>Create By: yanglei Email:yanglei@dcloud.io at 2013-1-15 下午03:35:47
	 */
	public static boolean isEquals(String pStr1,String pStr2){
		if (null==pStr1)return false;
		if (null==pStr2)return false;
		return pStr1.equalsIgnoreCase(pStr2);
	}
	/**
	 * 判断传入参数是否为null或""或'null'
	 * @param pObj
	 * @return
	 * <br/>Create By: yanglei Email:yanglei@dcloud.io at 2013-1-14 下午08:23:01
	 */
	public static boolean isEmpty(Object pObj){
		return pObj == null || pObj.equals("") || (pObj.toString().length() == 4 && pObj.toString().toLowerCase(Locale.ENGLISH).equals("null"));
	}
	public static int parseInt(String pInt, int pDeft){
		try {
			if(pInt == null) return pDeft;
			return Integer.parseInt(pInt);
		} catch (Exception e) {
			return pDeft;
		}
	}
}
