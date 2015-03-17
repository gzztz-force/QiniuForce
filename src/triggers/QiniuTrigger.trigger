trigger QiniuTrigger on FeedItem (after insert) 
{
    for(FeedItem feed : Trigger.new)
    {
        //if(feed.ContentSize > 20480)
        //{
            ChatterUtils.postCommentwithNewCompressedFile(feed);
            ChatterUtils.deleteOriginalFile(feed);
        //}
    }
}