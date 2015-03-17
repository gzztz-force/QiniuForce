@isTest(SeeAllData=true)
private class QiniuUtilGeorgeTest
{
	/*
	@isTest
	public static void testSliceUpload()
	{
		QiNiuUtil q = new QiNiuUtil();
		String result = q.sliceUpload(Blob.valueOf('testBlob'), 'test1', 'test2');
		System.assertNotEquals(null, result);
	}*/

	@isTest
	public static void testNormalUpload()
	{
		QiNiuUtil qiniu = new QiNiuUtil();
		FeedItem feed = [select Id from FeedItem limit 1];

		Blob bodyString = qiniu.compressImg(feed);
		System.assertNotEquals(null, bodyString);
	}
}