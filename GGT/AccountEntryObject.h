//
//  AccountEntryObject.h
//  iOSGGT
//
//  Created by Mihnea Barboi on 4/25/13.
//  Copyright (c) 2013 Mihnea Barboi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AccountEntryObject : NSObject <NSCoding>

//@property (strong, nonatomic) NSDate *date;
@property (strong, nonatomic) NSString *label; //the name of the entry, "budget allocation" or a name usually
@property (strong, nonatomic) NSString* accountName; //this is the account that the entry came from
@property NSInteger amount;
@property NSInteger runningTotalToDate;

//ivars for account detail screen
@property (strong, nonatomic) NSString *description;

-(id) initWithDate:(NSString *)dateString;
- (NSNumber *) dateAsTimeInterval;

-(NSDate *)date;
-(void)setDate:(NSDate*)dateN;
@end
