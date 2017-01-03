//
//  FileServer.m
//  DLNAWrapper
//
//  Created by Key.Yao on 16/9/26.
//  Copyright © 2016年 Key. All rights reserved.
//

#import "GCDWebServerPrivate.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerFileResponse.h"

#import "Config.h"
#import "FileServer.h"

@interface FileServer ()

@property (nonatomic, strong) GCDWebServer *webServer;

@end

@implementation FileServer

@synthesize webServer = _webServer;

+ (instancetype)shareServer
{
    static FileServer *s;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        s = [[self alloc] init];
        
    });
    
    return s;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        [GCDWebServer setLogLevel:IS_DEBUGING ? kGCDWebServerLoggingLevel_Debug : kGCDWebServerLoggingLevel_Error];
        
        _webServer = [[GCDWebServer alloc] init];
        
    }
    
    return self;
}

- (void)start
{
    [_webServer removeAllHandlers];
    
    [_webServer addHandlerForMethod:@"GET" path:@"/image" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
        
        NSString *url = request.URL.absoluteString;
        
        NSRange range = [url rangeOfString:@"/image?"];
        
        NSString *localId = [url substringFromIndex:(range.location + range.length)];
        
        if (localId == nil || [localId isEqualToString:@""])
        {
            completionBlock([GCDWebServerResponse responseWithStatusCode:404]);
            
            return;
        }
        
        PHAsset *asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil].firstObject;
        
        if (asset == nil)
        {
            completionBlock([GCDWebServerResponse responseWithStatusCode:404]);
            
            return;
        }
        
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        
        options.synchronous = false;
        
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        
        [options setNetworkAccessAllowed:YES];
        
        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            
            GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithData:UIImageJPEGRepresentation(result, 1.0f) contentType:@"image/jpeg"];
            
            completionBlock(response);
            
        }];
        
    }];
    
    [_webServer addHandlerForMethod:@"GET" path:@"/video" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
        
        NSString *url = request.URL.absoluteString;
        
        NSRange range = [url rangeOfString:@"/video?"];
        
        NSString *localId = [url substringFromIndex:(range.location + range.length)];
        
        if (localId == nil || [localId isEqualToString:@""])
        {
            completionBlock([GCDWebServerResponse responseWithStatusCode:404]);
            
            return;
        }
        
        PHAsset *asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil].firstObject;
        
        if (asset == nil)
        {
            completionBlock([GCDWebServerResponse responseWithStatusCode:404]);
            
            return;
        }
        
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        
        options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
        
        options.version = PHVideoRequestOptionsVersionCurrent;
        
        [options setNetworkAccessAllowed:YES];
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            
            AVURLAsset *avUrlAsset = (AVURLAsset *)asset;
            
            NSString *filePath = avUrlAsset.URL.path;
            
            GCDWebServerFileResponse *response = [GCDWebServerFileResponse responseWithFile:filePath byteRange:request.byteRange];
            
            completionBlock(response);
            
        }];
        
    }];
    
    [_webServer startWithPort:FILE_SERVER_PORT bonjourName:nil];
}

- (void)stop
{
    [_webServer stop];
}

- (NSString *)getUrlFromAsset:(PHAsset *)asset
{
    if (asset.mediaType == PHAssetMediaTypeImage)
    {
        return [NSString stringWithFormat:@"%@%@%@", _webServer.serverURL, @"image?", asset.localIdentifier];
    }
    else if (asset.mediaType == PHAssetMediaTypeVideo)
    {
        return [NSString stringWithFormat:@"%@%@%@", _webServer.serverURL, @"video?", asset.localIdentifier];
    }
    
    return [_webServer serverURL].absoluteString;
}

@end
