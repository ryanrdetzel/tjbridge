//
//  ViewController.m
//  TJCBridge
//
//  Created by Ryan Detzel on 5/7/14.
//  Copyright (c) 2014 Tapjoy. All rights reserved.
//

#import "ViewController.h"
#import <AddressBook/AddressBook.h>

@interface ViewController ()

@end

@implementation ViewController

@synthesize webView;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"];
    NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
    [webView loadHTMLString:htmlString baseURL:nil];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    
    NSString *requestURLString = [[request URL] absoluteString];
    
    if ([requestURLString hasPrefix:@"tjbridge:"]) {
        
        NSArray *components = [requestURLString componentsSeparatedByString:@":"];
        
        NSString *commandName = (NSString*)[components objectAtIndex:1];
        NSString *argsAsString = [(NSString*)[components objectAtIndex:2]
                                  stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSError *error = nil;
        NSData *argsData = [argsAsString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *args = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:argsData options:kNilOptions error:&error];
        
        NSLog(@"Command: %@ - %@", commandName, [args description]);
        
        SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@:", commandName]);
        if ([self respondsToSelector:selector]) {
            IMP imp = [self methodForSelector:selector];
            void (*func)(id, SEL, NSDictionary*) = (void *)imp;
            func(self, selector, args);
        }else{
            NSLog(@"Command: %@ not found", commandName);
        }
        
        return NO;
        
    } else {
        return YES;
    }
}

-(void)getContacts:(NSDictionary *)args{
    __block BOOL accessGranted = NO;
    //NSError *error = nil;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, nil);
    
    if (ABAddressBookRequestAccessWithCompletion != NULL) { // we're on iOS 6
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        //dispatch_release(sema);
    }
    else { // we're on iOS 5 or older
        accessGranted = YES;
    }
    
    if (accessGranted){
        NSLog(@"Access granted");
        //ABAddressBookRef addressBook = ABAddressBookCreate( );
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople( addressBook );
        CFIndex nPeople = ABAddressBookGetPersonCount( addressBook );

        NSMutableArray *names = [[NSMutableArray alloc] init];
        for (int i = 0; i < nPeople; i++) {
            ABRecordRef person = CFArrayGetValueAtIndex(allPeople, i);
            NSString *firstName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
            NSString *lastName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
            NSLog(@"%@ %@", firstName, lastName);
            [names addObject:[NSString stringWithFormat:@"%@ %@", firstName, lastName]];
        }
        [self updateWebView:@{@"commandName": @"getContacts", @"contacts": names}];
    }
}

-(void)updateWebView:(NSDictionary *)payload{
        NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    NSString *json = [ [NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding] ;
    NSString *jsCommand = [NSString stringWithFormat:@"executeCommand(%@);", json];
    [self.webView stringByEvaluatingJavaScriptFromString:jsCommand];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
