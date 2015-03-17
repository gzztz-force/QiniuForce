@isTest
private class QiNiuUtilEvanTest {
	
	
	//@isTest (SeeAllData=true) 
	//static void testGetImgBody() 
	//{
	//	QiNiuUtilEvan  qn = new QiNiuUtilEvan();
	//	String imgBody = qn.getImgBody();
	//	System.assertEquals('123',imgBody);
	//}

	@isTest
	static void testGenerateToken()
	{
		QiNiuUtilEvan  qn = new QiNiuUtilEvan();
		String token = qn.generateToken();
		System.assertEquals('iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:Yf412eayp60v8B6mJb5MZX_LO_g=:eyJzY29wZSI6InF0ZXN0YnVja2V0IiwiZGVhZGxpbmUiOjE0MjIzMzM3MzF9',token);
	}
	
	
}