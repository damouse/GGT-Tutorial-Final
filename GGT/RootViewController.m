//
//  RootViewController.m
//  GGT
//
//  Created by Mickey Barboi on 2/5/14.
//  Copyright (c) 2014 Mickey Barboi. All rights reserved.
//

#import "RootViewController.h"
#import "GrantObject.h"
#import "GrantCell.h"
#import "LandscapeMainGraphViewController.h"

@interface RootViewController () {
    NSMutableArray *queue;
}

@end

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.grants = [[NSMutableArray alloc] init];
    [self getMod];
}

- (void) viewWillAppear:(BOOL)animated {
    NSData *save = [[NSUserDefaults standardUserDefaults] objectForKey:@"grants"];
    
    if(save != nil)
        self.grants = [NSKeyedUnarchiver unarchiveObjectWithData:save];
    
    [tableGrants reloadData];
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    //double check the destination orientation
    if(UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
        
        //instantiate the view controller with the given indentifier
        //UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
        //LandscapeMainGraphViewController *landscape = [mainStoryboard instantiateViewControllerWithIdentifier: @"landscape"];
        
        LandscapeMainGraphViewController *landscape = [[LandscapeMainGraphViewController alloc] init];
        
        //use Landscape's init method to set the grant array
        [landscape initWithGrantArray:self.grants];
        
        //push the view controller onto the stack
        //[self presentViewController:landscape animated:YES completion:nil];
        [self.navigationController pushViewController:landscape animated:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) downloadGrants {
    
    if([queue count] == 0)
        return;
    
    NSString *fname = [queue objectAtIndex:0];
    [queue removeObjectAtIndex:0];
    
    NSString *key = @"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";
    NSString *urlString = [NSString stringWithFormat:@"http://pages.cs.wisc.edu/~mihnea/ggt/sheets/ggt_handler.php?type=download&fname=%@&key=%@", fname, key];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                // handle response
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSLog(@"%@", json);
        
        GrantObject *grant = [[GrantObject alloc] initWithCSVArray:[json objectForKey:@"data"]];
        
        if(![self.grants containsObject:grant]) {
            [self.grants addObject:grant];
            
            NSData* save = [NSKeyedArchiver archivedDataWithRootObject:self.grants];
            [[NSUserDefaults standardUserDefaults] setObject:save forKey:@"grants"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        
        }
        [tableGrants reloadData];
        [self downloadGrants];
        
    }] resume];
}

- (void) getMod {
    NSString *key = @"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";
    NSString *urlString = [NSString stringWithFormat:@"http://pages.cs.wisc.edu/~mihnea/ggt/sheets/ggt_handler.php?type=mod&key=%@", key];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // handle response
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSLog(@"%@", json);
        
        queue = [NSMutableArray arrayWithArray:[[json objectForKey:@"data"] allKeys]];
        [self downloadGrants];

    }] resume];
}

//given a grant, return the end date properly formatted
- (NSString *) formatEndDate:(GrantObject *)grant
{
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm/dd/YYYY"];
    NSDate *endDate = [formatter dateFromString:[[grant getMetadata] objectForKey:@"endDate"]];
    [formatter setDateFormat:@"MMMM dd, yyyy"];
    
    return [formatter stringFromDate:endDate];
}

//given a string of currency, format it correctly and return it as an int
- (NSDecimalNumber *) formatCurrency:(NSString *)amount
{
    NSString *ret = [[amount stringByReplacingOccurrencesOfString:@"\"" withString:@""] stringByReplacingOccurrencesOfString:@"," withString:@""];
    ret = [[ret componentsSeparatedByString:@"."] objectAtIndex:0];
    
    return [NSDecimalNumber decimalNumberWithString:ret];
}

//given a grant, format balance and budget so it reads: "balance$ out of budget$ remaining"
- (NSString *) formatBalance:(GrantObject *)grant
{
    NSDecimalNumber *budget = [self formatCurrency:[[grant getBudgetRow] objectForKey:@"Amount"]];
    NSDecimalNumber *balance = [self formatCurrency:[[grant getBalanceRow] objectForKey:@"Amount"]];
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle: NSNumberFormatterCurrencyStyle];
    NSString *balanceString = [numberFormatter stringFromNumber:balance];
    NSString *budgetString = [numberFormatter stringFromNumber:budget];
    
    balanceString = [balanceString stringByReplacingOccurrencesOfString:@".00" withString:@""];
    budgetString = [budgetString stringByReplacingOccurrencesOfString:@".00" withString:@""];
    
    return [NSString stringWithFormat:@"%@ of %@ remainng", balanceString, budgetString];
}

#pragma mark Table Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.grants count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GrantCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    if (cell == nil) {
        cell = [[GrantCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    
    GrantObject *grant = [self.grants objectAtIndex:indexPath.row];
    
    cell.labelName.text = [[grant getMetadata] objectForKey:@"title"];
    cell.labelEndDate.text = [self formatEndDate:grant];
    
    cell.labelRemaining.text = [self formatBalance:grant];
    
    return cell;
}

#pragma mark - Tableview Data Source
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    

}

@end
