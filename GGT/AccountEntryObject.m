//
//  AccountEntryObject.m
//  iOSGGT
//
//  Created by Mihnea Barboi on 4/25/13.
//  Copyright (c) 2013 Mihnea Barboi. All rights reserved.
//

// This class represents a change in the balance of a grant. It stores relevant information about that change. 

#import "AccountEntryObject.h"

@implementation AccountEntryObject {
    NSDate *date;
}
@synthesize label, amount, runningTotalToDate, accountName, description;

-(id) initWithDate:(NSString *)dateString
{
    self = [super init];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yy"];
    date = [formatter dateFromString:dateString];
    
    return self;
}

- (NSComparisonResult) compare:(AccountEntryObject *)other
{
    return [date compare: [other date]];
}

-(NSDate *)date
{
    return date;
}

-(void)setDate:(NSDate *)dateN
{
    //NSLog(@"%@", dateN);
    //if(date == nil)
        date = dateN;
    //else
      //  NSLog(@"%@", dateN);
}

- (AccountEntryObject *) copy {
    AccountEntryObject *new = [AccountEntryObject alloc];
    [new setDate:self.date];
    [new setLabel:self.label];
    [new setAmount:self.amount];
    [new setRunningTotalToDate:self.runningTotalToDate];
    
    
    return new;
}

//CorePlot doesn't play well with NSDate objects, at least not easily. Use this method to return dates as decimals,
//where each digit represents one second of offset from a referance date. 
- (NSNumber *) dateAsTimeInterval
{
    NSDate *refDate = [NSDate dateWithTimeIntervalSinceReferenceDate:157680000]; //reference date is 2006
    NSTimeInterval difference = [date timeIntervalSinceDate:refDate]; //difference between today and 2006
    
    return [NSNumber numberWithDouble:difference];
}

#pragma mark Coder/Archiver
-(void)encodeWithCoder:(NSCoder *)encoder
{    
    [encoder encodeObject:date forKey:@"1"];
    [encoder encodeObject:label forKey:@"2"];
    [encoder encodeObject:accountName forKey:@"3"];
    [encoder encodeObject:[NSNumber numberWithInt:amount] forKey:@"4"];
    [encoder encodeObject:[NSNumber numberWithInt:runningTotalToDate] forKey:@"5"];
    [encoder encodeObject:description forKey:@"6"];
    
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    self.date = [decoder decodeObjectForKey:@"1"];
    self.label = [decoder decodeObjectForKey:@"2"];
    self.accountName = [decoder decodeObjectForKey:@"3"];
    self.amount = [[decoder decodeObjectForKey:@"4"] intValue];
    self.runningTotalToDate = [[decoder decodeObjectForKey:@"5"] intValue];
    self.description = [decoder decodeObjectForKey:@"6"];
    
    
    return self;
}
@end
