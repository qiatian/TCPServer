//
//  main.m
//  TCPServer
//
//  Created by sanjingrihua on 17/6/20.
//  Copyright © 2017年 sanjingrihua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#define PORT 9000
//服务端接收到客户端请求后回调，它是CFSocketCallBack类型
void AcceptCallBack(CFSocketRef,CFSocketCallBackType,CFDataRef,const void *,void *);

//当客户端在socket中读取数据时候调用，它是CFWriteStreamClientCallBack类型
void WriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType eventType,void *);

//当客户端把数据写入socket时候调用，它是CFReadStreamClientCallBack类型
void ReadStreamClientCallBack (CFReadStreamRef stream, CFStreamEventType eventType,void *);


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        
//        定义一个server socket 引用
        CFSocketRef sserver;
        
//        创建socket context 变量，CFSocketContext是一个结构体，用来配置socket对象的行为，它提供程序定义数据和回调函数。参数：结构体的版本必须是0；任何程序定义数据的指针；retain info时回调函数，可以为NULL；release info时回调函数，可以为NULL；
        CFSocketContext CTX = {0,NULL,NULL,NULL,NULL};
        
//        创建serversocket TCP ipv4 设置回调函数  创建socket对象。参数：指定创建对象的时候，内存分配方式，NULL或默认；指定socket的协议族类型，PF_INET是传递0或负数；指定 socket的类型，SOCK_STREAM是TCP协议，SOCK_DGRAM是UDP协议；指定socket的协议类型，IPPROTO_TCP是TCP协议，IPPROTO_UDP是UDP协议；回调类型，kCFSocketAcceptCallBack是接受客户端请求时回调；AcceptCallBack回调函数名；socket context对象；
        sserver = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)AcceptCallBack, &CTX);
        
        if (sserver == NULL) {
            return -1;
        }
        
//        设置是否重新绑定标志
        int yes = 1;
//        使用setsockopt函数 设置socket属性；参数：本地socket对象，可以使用CFSocketGetNative函数获取；socket属性的级别，一般都是SOL_SOCKET这个常量来设置，是设置tcp；指定要设置的socket属性名，SO_REUSEADDR设置可重用地址属性，是重新绑定；指定设置属性的值； 指定设置属性的值的长度，yes是否重新绑定
        setsockopt(CFSocketGetNative(sserver), SOL_SOCKET, SO_REUSEADDR, (void*)&yes, sizeof(yes));
        
//        设置端口和地址
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));//memset函数对指定的地址进行内存复制
        addr.sin_len = sizeof(addr);
        addr.sin_family = AF_INET;//AF_INET是设置IPv4
        addr.sin_port = htons(PORT); //htons函数 无符号 短整型数转化成“网络字节序”
        addr.sin_addr.s_addr = htonl(INADDR_ANY);//INADDR_ANY有内核分配，htonl函数 无符号长整型数转换成“网络字节序”
        
//        从指定字节缓冲区复制，一个不可变的CFData对象
        CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr, sizeof(addr));
        
//        绑定socket
        if (CFSocketSetAddress(sserver, (CFDataRef)address) != kCFSocketSuccess) {
            fprintf(stderr, "Socket绑定失败\n");
            CFRelease(sserver);
            return -1;
        }
        
        
//        创建一个Run Loop Socket源
        CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sserver, 0);
//        socket 源添加到 run loop中
        CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef,kCFRunLoopCommonModes);
        CFRelease(sourceRef);
        
        printf("Socket listening on port %d\n",PORT);
        
//        运行runloop
        CFRunLoopRun();
    
        
    }
    return 0;
}
void AcceptCallBack(CFSocketRef socket,CFSocketCallBackType type ,CFDataRef address,const void *data,void *info){
    CFReadStreamRef  readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    
    //data 参数的含义是：如果回调类型是kCFSocketAcceptCallBack,data就是CFSocketNativeHandle类型的指针。
    CFSocketNativeHandle sock = *(CFSocketNativeHandle *)data;
    
//    创建读写流对象并 连接Socket 参数：内存分配方式；由main函数传递过来的socket对象； 输入流对象指针； 输出流对象指针；
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
    
    if (!readStream || !writeStream) {
        close(sock);
        fprintf(stderr, "CFStreamCreatePairWithSocket()失败\n");
        return;
    }
    
    CFStreamClientContext streamCtxt = {0,NULL,NULL,NULL,NULL};
    //注册两种回调函数
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable, ReadStreamClientCallBack, &streamCtxt);
    
    CFWriteStreamSetClient(writeStream, kCFStreamEventCanAcceptBytes, WriteStreamClientCallBack, &streamCtxt);
    
    //加入循环中
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
    //打开流对象
    CFReadStreamOpen(readStream);
    CFWriteStreamOpen(writeStream);
    
}
void WriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType eventType,void *clientCallBackInfo){
    CFWriteStreamRef outputStream = stream;
    //输出
    UInt8 buff[] = "Hellow Client";
    if (NULL != outputStream) {
        //参数：输出流对象；发送数据缓冲区；发送的数据长度 －－－strlen函数获取字符的长度
        CFWriteStreamWrite(outputStream, buff, strlen((const char *)buff)+1);
        CFWriteStreamClose(outputStream);
        CFWriteStreamUnscheduleFromRunLoop(outputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        outputStream = NULL;
    }
}
void ReadStreamClientCallBack (CFReadStreamRef stream, CFStreamEventType eventType,void *clientCallBackInfo){
    UInt8 buff[255];
    CFReadStreamRef  inputStream = stream;
    if (NULL != inputStream) {
        //参数：输入流对象；接收数据准备的数据缓冲区；读入的数据长度
        CFReadStreamRead(stream, buff, 255);
        printf("接收到的数据：%s\n",buff);
        CFReadStreamClose(inputStream);
        CFReadStreamUnscheduleFromRunLoop(inputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        inputStream = NULL;
    }
}

