//
//  GrantObject.m
//  iOSGGT
//
//  Created by Mihnea Barboi on 4/25/13.
//  Copyright (c) 2013 Mihnea Barboi. All rights reserved.
//

#import "GrantObject.h"
#import "AccountEntryObject.h"

@implementation GrantObject {
    //NOTE: keys WILL NEED TO BE CHANGED. Dynamically add them from the column headers for different spreadsheets
    //contains info from top 5 lines. Keys: {dateLastAccessed, startDate, endDate, name, accountNumber, grantor, title, overhead, awardNumber}
    NSMutableDictionary *metadata;
    
    //contains budget amounts. Keys: {totalBudget, staff, otherPersonnel, fringeBenefits, tuitionRemission, supplies, travel}
    NSMutableDictionary *budget;
    NSMutableDictionary *balance;
    NSMutableDictionary *paid;
    
    //row 6 of the spreadsheets: holds the name of all the columns for reference
    NSMutableArray *columnHeaders;
    
    //entries paired with their account names. The difference between this and accountEntries is that entries tracks overall changes in
    //total balance, only contains an entry for each change. This dictionary will contain multiple entries for each single allocation, each paired
    //with the respective account.
    NSMutableArray *accountEntriesWithAccount;
}

@synthesize accountEntries;

//take the whole slew of arrays from the csv and put all the info in the right places
//NOTE: again, this has to be rewritten to allow for differently styled spreadsheets or different sized columns
//It is currently hardcoded just to test.
-(id)initWithCSVArray:(NSArray *)csvFile
{
    NSLog(@"Grant Parse starting...");    
    
    self = [super init];
    metadata = [NSMutableDictionary dictionary];
    budget = [NSMutableDictionary dictionary];
    balance = [NSMutableDictionary dictionary];
    paid = [NSMutableDictionary dictionary];
    accountEntries = [NSMutableArray array];
    accountEntriesWithAccount = [NSMutableArray array];
    
    NSArray *dateSplit = [[[csvFile objectAtIndex:1] objectAtIndex:1] componentsSeparatedByString:@" - "];
    
    //metadata
    //[metadata setObject:[[csvFile objectAtIndex:0] objectAtIndex:0] forKey:@"dateLastAccessed"];
    [metadata setObject:[[csvFile objectAtIndex:2] objectAtIndex:1] forKey:@"name"];
    [metadata setObject:[[csvFile objectAtIndex:3] objectAtIndex:1] forKey:@"accountNumber"];
    [metadata setObject:[[csvFile objectAtIndex:1] objectAtIndex:4] forKey:@"grantor"];
    [metadata setObject:[[csvFile objectAtIndex:2] objectAtIndex:4] forKey:@"title"];
    [metadata setObject:[[csvFile objectAtIndex:3] objectAtIndex:4] forKey:@"overhead"];
    [metadata setObject:[[csvFile objectAtIndex:4] objectAtIndex:1] forKey:@"awardNumber"];
    [metadata setObject:[dateSplit objectAtIndex:0] forKey:@"startDate"];
    [metadata setObject:[dateSplit objectAtIndex:1] forKey:@"endDate"];
    
    //STRING FORMATTING FICXES
    NSString *tmp = [metadata objectForKey:@"title"];
    tmp = [[tmp componentsSeparatedByString:@"Title: "] objectAtIndex:1];
    [metadata setObject:tmp forKey:@"title"];
    
    tmp = [metadata objectForKey:@"grantor"];
    tmp = [[tmp componentsSeparatedByString:@"Grantor:"] objectAtIndex:1];
    [metadata setObject:tmp forKey:@"grantor"];
    
    tmp = [metadata objectForKey:@"awardNumber"];
    tmp = [[tmp componentsSeparatedByString:@"Agency Award Number: "] objectAtIndex:1];
    if([tmp isEqualToString:@""])
        tmp = @"[not entered]";
    [metadata setObject:tmp forKey:@"awardNumber"];
    
    tmp = [metadata objectForKey:@"overhead"];
    tmp = [[tmp componentsSeparatedByString:@"Overhead @ "] objectAtIndex:1];
    [metadata setObject:tmp forKey:@"overhead"];
    
    tmp = [metadata objectForKey:@"accountNumber"];
    tmp = [[tmp componentsSeparatedByString:@"Account #: "] objectAtIndex:1];
    [metadata setObject:tmp forKey:@"accountNumber"];
    
    //column headers, main three
    columnHeaders = [NSMutableArray arrayWithArray:[csvFile objectAtIndex:5]];
    
    NSArray *line;
    NSString *cell;
    
    //get the budget, balance, paid lines from the spreadsheet
    NSArray *budgetLine;
    NSArray *balanceLine;
    NSArray *paidLine;
    //loop begins in the row of the column headers and keeps going until it finds the appropriate rows for budget, balance, paid
    for(int g = 5; g < 25; g++) {
        cell = [[csvFile objectAtIndex:g] objectAtIndex:1];
        
        //NSLog(@"%@", [csvFile objectAtIndex:g]);

        if([cell isEqualToString:@"Current Budget:"]) {
            budgetLine = [csvFile objectAtIndex:g];
            balanceLine = [csvFile objectAtIndex:g+1];
            
        }
        
        if([cell isEqualToString:@"Total Open and Paid:"])
            paidLine = [csvFile objectAtIndex:g];
        
        //if we have found all the lines, break the loop
        if(budgetLine != nil && balanceLine != nil && paidLine != nil)
            break;
    }

    //TODO: FIX ME
    //hardcoded fix below because of a nasty spreadsheet parse error, may need to check the parser
    
    //fallthrough: if the above loop did not find the correct lines then assign them statically
    if((budgetLine == nil && balanceLine == nil && paidLine == nil)) {
        budgetLine = [csvFile objectAtIndex:12]; //these are here so they can be replaced if we need to find them dynamically
        balanceLine = [csvFile objectAtIndex:13];
        paidLine = [csvFile objectAtIndex:15];
    }    int i = 0;
    
    
    
    //remove the extraneous columns in headers
    NSString *header = [columnHeaders objectAtIndex:0];
    while(![header isEqualToString:@"Amount"]) {
        i++;
        [columnHeaders removeObjectAtIndex:0];
        header = [columnHeaders objectAtIndex:0];
    }
    
    for(NSString *header in columnHeaders) {
        [budget setValue:[[budgetLine objectAtIndex:i] stringByReplacingOccurrencesOfString:@"\"" withString:@""] forKey:header];
        [balance setValue:[[balanceLine objectAtIndex:i] stringByReplacingOccurrencesOfString:@"\"" withString:@""] forKey:header];
        [paid setValue:[[paidLine objectAtIndex:i] stringByReplacingOccurrencesOfString:@"\"" withString:@""] forKey:header];
        i++;
    }
    
    //Build an array of account entries
    i = 6; //budget allocations start on row 7 of the spreadsheet

    line = [csvFile objectAtIndex:i];
    cell = [line objectAtIndex:1];

    //parse the allocations
    while(![cell isEqualToString:@"Current Budget:"]) {
        //NSLog(@"Spinning 1: %i", i);
        if([[line objectAtIndex:1] isEqualToString:@"Budget Allocation"]) {
            line = [csvFile objectAtIndex:i]; //get the next line
            cell = [line objectAtIndex:1];
        
            //get the date, amount, and label of the entry. 
            AccountEntryObject *entry = [[AccountEntryObject alloc] initWithDate:[line objectAtIndex:0]];
            [entry setLabel:cell];
            [entry setAmount:[[line objectAtIndex:6] intValue]];
            
            [entry setDescription:[NSString stringWithFormat:@" %@",[line objectAtIndex:4]]]; //keep a space in here, else the string is null
            
            [accountEntries addObject:entry];
            
            int j  = 7; //individual account entries start on column 7
            
            //Second part of the parse: make an entry object for each non-zero account, add it accountEntriesWithAccount for detail controller
            for(NSString *header in columnHeaders) {
                if(![header isEqualToString:@"Amount"]) {
                    
                    if(j < [line count]) {
                        cell = [line objectAtIndex:j];
                        
                        if(![cell isEqualToString:@"0.00"] && ![cell isEqualToString:@""]){ //if entry is nonzero
                        
                            //some string parsing to get the numbers to convert well; cents are omitted
                            entry = [entry copy]; //just copy the entry, since only two values change
                            [entry setAccountName:header];
                            [entry setAmount:[self formatCurrency:cell]];
                        
                            [accountEntriesWithAccount addObject:entry]; //to retrieve entries for a specific account, search for accountName
                        }
                    
                        j++; //j tracks the index under column headers
                        
                    }
                }
            }
        }
        
        //get the next line
        i++;
        line = [csvFile objectAtIndex:i];
        cell = [line objectAtIndex:1];
    }       
       
    
    //set the index to the first account withdrawl. New index references the first line with a withdrawl
    cell = [line objectAtIndex:0];
    while([cell isEqualToString:@""]) {
        //NSLog(@"Spinning 2: %i", i);
        i++;
        line = [csvFile objectAtIndex:i];
        cell = [line objectAtIndex:0];
    }
    
    //build array of account withdrawls. Keep searching until three cells pass 
    int emptyCells = 0;
    cell = [line objectAtIndex:1];

    while(emptyCells < 3) {
        //NSLog(@"Spinning 3: %i", i);
        
        if(![cell isEqualToString:@""]) {
            //emptyRow represents an error in the spreadsheet where the entry is not listed under any account, leading to an iobe error in the loop below. 
            BOOL emptyRow = NO; 
            
            //get the date, amount, and label of the entry
            AccountEntryObject *entry = [[AccountEntryObject alloc] initWithDate:[line objectAtIndex:0]];
            [entry setLabel:cell];
            [entry setAmount:-[[line objectAtIndex:6] intValue]];
            [entry setDescription:[line objectAtIndex:4]];
            
            [accountEntries addObject:entry];
            
            //Part 2: search for the entry under a specific account, set that header as the accountName, add the entry to accountEntriesWithAccount
            
            int j = 7;
            cell = [line objectAtIndex:j]; //first column of account entries
            while([cell isEqualToString:@""]){
                j++;
                
                //use emptyRow to check if the row has an entry error
                if(j == 20) {
                    emptyRow = YES;
                    break;
                }
                
                cell = [line objectAtIndex:j];
            } //j holds index (offset) to the correct header
            
            if(!emptyRow) {
                [entry setAccountName:[columnHeaders objectAtIndex:(j - 6)]];
                [accountEntriesWithAccount addObject:entry];
            }
            //end part 2
            
            emptyCells = 0; //reset empty cell count
        }
        else {
            emptyCells++; //start counting empty cells
        }
        
        //move to the next line. 
        i++;
        line = [csvFile objectAtIndex:i];
        cell = [line objectAtIndex:1];
    }

    
    //sort the entries by date
    [accountEntries sortUsingSelector:@selector(compare:)];
    [accountEntriesWithAccount sortUsingSelector:@selector(compare:)];
    
    
    //set the time last accessed
    [metadata setObject:[[accountEntries objectAtIndex:[accountEntries count] - 1] date] forKey:@"dateLastAccessed"];
    
    //the account entries have all been added and sorted in order of date. This sets up the "running total" of the grant
    int currentTotal = 0;
    
    for(AccountEntryObject *entry in accountEntries) {
        currentTotal = currentTotal + [entry amount];
        [entry setRunningTotalToDate:currentTotal];
    }
    
    /* correct
    NSLog(@"Account Entry Parse");
    for(AccountEntryObject *entry in accountEntries) {
        NSLog(@"%i %@", [entry runningTotalToDate], [entry label]);
    }*/
    
    NSLog(@"Grant Parse finished");
    
    return self;
}

#pragma mark Parsing
//given a string of currency, format it correctly and return it as an int
- (int) formatCurrency:(NSString *)amount {
    NSString *ret = [[amount stringByReplacingOccurrencesOfString:@"\"" withString:@""] stringByReplacingOccurrencesOfString:@"," withString:@""];
    ret = [[ret componentsSeparatedByString:@"."] objectAtIndex:0];
    
    return [ret intValue];
}

#pragma mark Accessor
- (NSDictionary *) getMetadata
{
    return metadata;
}

-(NSArray *)getAccounts
{
    return columnHeaders;
}

-(NSDictionary *)getBudgetRow
{
    return budget;
}

-(NSDictionary *)getBalanceRow
{
    return balance;
}

-(NSDictionary *)getPaidRow
{
    return paid;
}

-(NSArray *) getEntriesWithAccountNames {
    return accountEntriesWithAccount;
}

- (void) setMetadata:(NSMutableDictionary *)data {
    metadata = data;
}


-(BOOL)isEqual:(id)otherObject {
    GrantObject *other = (GrantObject *)otherObject;
    
    if([[[other getMetadata] objectForKey:@"name"] isEqualToString:[metadata objectForKey:@"name"]])
        return YES;
    return NO;
}

#pragma mark Coder/Archiver
-(void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:accountEntries forKey:@"1"];
    [encoder encodeObject:_timeLastAccessed forKey:@"2"];
    [encoder encodeObject:_fileName forKey:@"3"];
    [encoder encodeObject:metadata forKey:@"4"];
    [encoder encodeObject:budget forKey:@"5"];
    [encoder encodeObject:balance forKey:@"6"];
    [encoder encodeObject:paid forKey:@"7"];
    [encoder encodeObject:columnHeaders forKey:@"8"];
    [encoder encodeObject:accountEntriesWithAccount forKey:@"9"];
    
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    self.accountEntries =[decoder decodeObjectForKey:@"1"];
    _timeLastAccessed =[decoder decodeObjectForKey:@"2"];
    _fileName =[decoder decodeObjectForKey:@"3"];
    self->metadata =[decoder decodeObjectForKey:@"4"];
    self->budget =[decoder decodeObjectForKey:@"5"];
    self->balance =[decoder decodeObjectForKey:@"6"];
    self->paid =[decoder decodeObjectForKey:@"7"];
    self->columnHeaders =[decoder decodeObjectForKey:@"8"];
    self->accountEntriesWithAccount =[decoder decodeObjectForKey:@"9"];
    
    return self;
}

@end
