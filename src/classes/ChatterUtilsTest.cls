@isTest
public class ChatterUtilsTest
{
    @isTest
    static void testGetFeedItem()
    {
        TestImgData testData = new TestImgData();
        Blob data = testData.getBlobImgData();
        FeedItem feed = new FeedItem(ContentData=data, ContentFileName='testImg1.1.png', ParentId='00528000000HiDcAAK');
        insert feed;
        List<FeedItem> itemList = new List<FeedItem>();
        ChatterUtils ch = new ChatterUtils();
        itemList = ChatterUtils.getFeedItem();
        System.assertEquals(1, itemList.size());
    }

    @isTest(SeeAllData=true)
    static void testPostCommentwithNewCompressedFile()
    {
        FeedItem feed = [select Id, ContentData, ContentType, ContentSize, ContentFileName, RelatedRecordId from FeedItem limit 1];
        Test.setMock(HttpCalloutMock.class, new MockQiniuHttpResponseGenerator());
        Test.startTest();
        ChatterUtils.postCommentwithNewCompressedFile(feed);
        Test.stopTest();
        System.assertNotEquals(0, [select Count() from FeedComment where FeedItemId =: feed.Id and CommentBody = 'Thumbnail']);
    }

    @isTest(SeeAllData=true)
    static void testDeleteOriginalFile()
    {
        FeedItem feed = [select Id, ContentData, ContentType, ContentSize, ContentFileName, RelatedRecordId from FeedItem limit 1];
        Id contentVersionId = feed.RelatedRecordId;
        ContentVersion conVersion = [select Id, ContentDocumentId from ContentVersion where Id =: contentVersionId limit 1];
        Id contentDocumentId = conVersion.ContentDocumentId;
        Test.startTest();
        ChatterUtils.deleteOriginalFile(feed);
        Test.stopTest();
        System.assertEquals(0, [select Count() from ContentDocument where Id =: contentDocumentId limit 1]);
    }
}