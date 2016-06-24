//
//  ViewController.m
//  testCacheImage
//
//  Created by Evan on 2016/6/24.
//  Copyright © 2016年 Evan. All rights reserved.
//

#import "ViewController.h"
#import "ImageCache.h"
#import "ModelImage.h"

@interface ViewController ()
{
    
}
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *arr_ImgURL;
@property (nonatomic, strong) NSMutableArray *arr_Result;
@property (nonatomic, strong) NSOperationQueue *opQueue;
@property (nonatomic, strong) ImageCache *cache;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _cache = [ImageCache sharedImageCache];
    _opQueue = [[NSOperationQueue alloc] init];
    _arr_ImgURL = [[NSMutableArray alloc] init];
    [self getResultData];
}

-(void)getResultData
{
    NSString *urlString = @"http://data.coa.gov.tw/Service/OpenData/AnimalOpenData.aspx?$top=100&$skip=0&$filter=animal_kind+like+%E7%8B%97";
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
    
    NSURL * url = [NSURL URLWithString:urlString];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url
                                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                            if(error == nil)
                                                            {
                                                                [self saveResultData:data];
                                                            }
                                                            
                                                        }];
        
        [dataTask resume];
    });
}

-(void)saveResultData:(NSData *)data
{
    NSError *error = nil;
    _arr_Result = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &error];
    
    for (int i = 0; i < _arr_Result.count; i++)
    {
        NSDictionary * dic = [_arr_Result objectAtIndex:i];
        NSString *imgString = [dic objectForKey:@"album_file"];
        NSDictionary *d = [[NSDictionary alloc] initWithObjectsAndKeys:imgString,@"album_file", nil];
        ModelImage *m = [ModelImage modelImageWithDic:d];
        [_arr_ImgURL addObject:m];
    }
    
    [_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _arr_Result.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
     ModelImage *m = [_arr_ImgURL objectAtIndex:indexPath.row];
    if ([_cache.allImageCache objectForKey:m.album_file])
    {//有
        cell.imageView.image = [_cache.allImageCache objectForKey:m.album_file];
    }
    else
    {//没有
        //占位图
        cell.imageView.image = [UIImage imageNamed:@"user_default"];
        //下载图片
        [self downloadImage:indexPath];
    }
    
    return cell;
}

- (void)downloadImage:(NSIndexPath *)indexPath
{
    //判断下载缓存池中是否存在当前下载的操作
    ModelImage *m = [_arr_ImgURL objectAtIndex:indexPath.row];
    if ([_cache.allDownloadOperationCache objectForKey:m.album_file])
    {
        NSLog(@"正在下载ing...");
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    //缓存池中没有当前图片的下载操作
    //子线程中下载图片
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:m.album_file]];
        UIImage *image = [UIImage imageWithData:imageData];
        if (image) {
            //把图片添加到图片缓存池中
            [weakSelf.cache.allImageCache setObject:image forKey:m.album_file];
            //将下载操作从操作缓存池删除(下载操作已经完成)
            [weakSelf.cache.allDownloadOperationCache removeObjectForKey:m.album_file];
        }
        
        //在主线程更新UI
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            //刷新当前行
            [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }];
    }];
    
    //把下载操作添加到队列
    [self.opQueue addOperation:blockOperation];
    //把下载操作添加到下载缓存池中
    [_cache.allDownloadOperationCache setObject:blockOperation forKey:m.album_file];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    //需要在这里做一些内存清理的工作,如果不处理的话,会被系统强制闪退。
    //清理图片的缓存
    [_cache.allImageCache removeAllObjects];
    //清理操作的缓存
    [_cache.allDownloadOperationCache removeAllObjects];
    //取消下载队列里的任务
    [self.opQueue cancelAllOperations];
    
    [self.tableView reloadData];
}

@end
