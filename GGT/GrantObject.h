//
//  GrantObject.h
//  iOSGGT
//
//  Created by Mihnea Barboi on 4/25/13.
//  Copyright (c) 2013 Mihnea Barboi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GrantObject : NSObject <NSCoding>

//All changes in the value of the account. Array holds accountentryobjects
@property (strong, nonatomic) NSMutableArray *accountEntries;
@property (strong, nonatomic) NSString *timeLastAccessed;
@property (strong, nonatomic) NSString *fileName;

-(id)initWithCSVArray:(NSArray *)csvFile;

//return column headers, row 6 of the spreadsheet starting with "Amount"
-(NSArray *) getAccounts;
-(NSArray *) getEntriesWithAccountNames;

//retrieve the dictionaries that represent the totals rows in the table. Dictionaries are keyed by column headers
-(NSDictionary *)getBalanceRow;
-(NSDictionary *)getBudgetRow;
-(NSDictionary *)getPaidRow;

//Keys: {dateLastAccessed, startDate, endDate, name, accountNumber, grantor, title, overhead, awardNumber}
- (NSDictionary *) getMetadata;

//to be used only when making the supergrant in landscape!
- (void) setMetadata:(NSMutableDictionary *)data;

@end
