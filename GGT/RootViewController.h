//
//  RootViewController.h
//  GGT
//
//  Created by Mickey Barboi on 2/5/14.
//  Copyright (c) 2014 Mickey Barboi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RootViewController : UIViewController {
    
    __weak IBOutlet UITableView *tableGrants;
}

@property (strong, nonatomic) NSMutableArray *grants;

@end
