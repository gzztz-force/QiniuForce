public with sharing class ChatterUtils {
    private static Integer limitSize;

    public ChatterUtils()
    {
        limitSize = 20480;
    }
    
    public static List<FeedItem> getFeedItem()
    {
        List<FeedItem> itemList = new List<FeedItem>();
        for(FeedItem feed : [select Id, ContentData, ContentType, ContentSize, ContentFileName, RelatedRecordId from FeedItem limit 1000])
        {
            if(feed.ContentSize > limitSize)
            {
                itemList.add(feed);
            }
        }
        return itemList;
    }

    public static void postCommentwithNewCompressedFile(FeedItem feed)
    {
        // Get the blob of compressed picture
        QiNiuUtil q = new QiNiuUtil();
        Blob myBlob = q.compressImg(feed);
        
        ConnectApi.CommentInput commentInput = new ConnectApi.CommentInput();

        ConnectApi.MessageBodyInput messageInput = new ConnectApi.MessageBodyInput();
        ConnectApi.TextSegmentInput segmentInput = new ConnectApi.TextSegmentInput();
        
        ConnectApi.ContentCapabilityInput contentCapabilityInput = new ConnectApi.ContentCapabilityInput();
        ConnectApi.CommentCapabilitiesInput commentCapabilitiesInput = new ConnectApi.CommentCapabilitiesInput();
        // Add the new compressed picture
        ConnectApi.BinaryInput binaryInput = new ConnectApi.BinaryInput(myBlob, feed.ContentType, feed.ContentFileName);

        segmentInput.text = 'Thumbnail';
        messageInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();
        messageInput.messageSegments.add(segmentInput);

        String contentFileName = feed.ContentFileName;
        String title = contentFileName.substring(0, contentFileName.indexOf('.'));
        contentCapabilityInput.title = 'Thumbnail of: ' + title;
        commentCapabilitiesInput.content = contentCapabilityInput;

        // Add the body and title
        commentInput.body = messageInput;
        commentInput.capabilities = commentCapabilitiesInput;
        // Post it
        ConnectApi.ChatterFeeds.postCommentToFeedElement(Network.getNetworkId(), feed.Id, commentInput, binaryInput);
    }

    public static void deleteOriginalFile(FeedItem feed)
    {
        Id contentVersionId = feed.RelatedRecordId;
        ContentVersion conVersion = [select Id, ContentDocumentId from ContentVersion where Id =: contentVersionId limit 1];
        Id contentDocumentId = conVersion.ContentDocumentId;
        ContentDocument document = [select Id from ContentDocument where Id =: contentDocumentId limit 1];
        try
        {
            delete document;
        }
        catch(Exception ex)
        {
            System.debug(ex.getMessage());
        }
    }
}