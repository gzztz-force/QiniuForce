@isTest
public class S3UtilTest
{
    @isTest
    static void testUploadFileToS3()
    {
        TestImgData testData = new TestImgData();
        Blob data = testData.getBlobImgData();
        FeedItem feed = new FeedItem(ContentData=data, ContentFileName='testImg1.1.png', ParentId='00528000000HiDcAAK');
        //insert feed;
        S3Util s = new S3Util();
        Test.setMock(HttpCalloutMock.class, new MockS3HttpResponseGenerator());
        Integer statusCode = s.uploadFile(feed);
        System.assertEquals(200, statusCode);
    }
}