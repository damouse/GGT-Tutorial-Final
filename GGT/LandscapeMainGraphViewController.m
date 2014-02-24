//
//  LandscapeMainGraphViewController.m
//  iOSGGT
//
//  Created by Mihnea Barboi on 4/19/13.
//  Copyright (c) 2013 Mihnea Barboi. All rights reserved.
//

/***
    NOTE: there is a method in the dropplot file that handles CSV files directly as input. Likely pointless, but just keep it in mind
 */

#import "LandscapeMainGraphViewController.h"
#import "CorePlot-CocoaTouch.h"

#import "GrantObject.h"
#import "AccountEntryObject.h"
#import "CPTPlotRange.h"
#import <QuartzCore/QuartzCore.h>

@interface LandscapeMainGraphViewController () {
    CPTGraph *graph;
    double minimumValueForXAxis;
    double maximumValueForXAxis;
    double minimumValueForYAxis;
    double maximumValueForYAxis;
    double maximumValueForYAxisSum;
    
    double majorIntervalLengthForX;
    double majorIntervalLengthForY;
    
    CPTPlotRange *test;
    CPTPlotRange *lastRangeX;
    CPTPlotRange *lastRangeY;
    CPTPlotRange *savedRangeX;
    CPTPlotRange *savedRangeY;
    
    NSMutableArray *plots; //array of the plots created, just get the index of each to fetch grants
    NSMutableArray *plotsOfEndDates;
    NSMutableArray *grants; //array of arrays of dictionarys. Grants[ Accounts {entries}]
    NSMutableArray *endDateValues; //same as above
    
    NSMutableArray *grantObjects; //saved just to retain metadata
    NSDate *refDate;
    NSTimeInterval oneDay;
    
    NSMutableArray *buttonReferences;
    NSMutableArray *colors; //all avaliable colors for coloring plots
    
    UITextView *popup;
    UIButton *back;
    
    //assign these programatically for varying screen sizes. For now, just set in init
    int constCoordinateOffsetY;
    int constCoordinateOffsetX;
}

@end

@implementation LandscapeMainGraphViewController
//@synthesize buttonsLegend;

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
    
    [self.navigationController setNavigationBarHidden:YES];

    //init the popup index tracker
    
    constCoordinateOffsetX = 22;
    constCoordinateOffsetY = -45;
    
 //reference date is 2006
    plots = [NSMutableArray array];
    plotsOfEndDates = [NSMutableArray array];
    endDateValues = [NSMutableArray array];
    lastRangeY = nil;
    lastRangeX = nil;

    majorIntervalLengthForX = oneDay * 30 * 6; //half a month. Consider a year?
    majorIntervalLengthForY = 100000;
    
    [self initPopup];
    
    //init the back button
    /*back = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [back setFrame:CGRectMake(220, 0, 80, 20)];
    [back setTitle:@"Back" forState:UIControlStateNormal];
    [back addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:back];*/
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillAppear:(BOOL)animated
{
    [self.view layoutSubviews];
    
    if(graph == nil)
        [self initPlot];
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeLeft;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {    // Or whatever orientation it will be presented in.
        return YES;
    }
    return NO;
}

#pragma mark Data Init
//method takes in the grant objects and then makes it "horizontal." If the changes are just plotted by themselves, then each change in the amount of the graph
//has a slope. Each point must therefor get a second, auxilliary point that sits right before the next point in the grant. This auxilliary point
// keeps the changes horizontal. Also, each account entry should be processed as a change in the total balance, not a data point
- (void) initWithGrantArray:(NSMutableArray *)grantArray {
    grants = [NSMutableArray array];
    grantObjects = [grantArray mutableCopy];
    oneDay = 24 * 60 * 60;
    refDate = [NSDate dateWithTimeIntervalSinceReferenceDate:157680000]; //2006 is the reference date
    
    //variables to set the bounds of the window
    NSInteger largestValue = 0; //the largest value seen over all entries
    NSInteger smallestValue = 0;
    NSDate *earliestDate = [NSDate date]; //will break if all grants are listed in the future... unlikely
    NSDate *latestDate = [NSDate dateWithTimeIntervalSince1970:0];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yy"];
    
    //create the SUM grant, aggregate accounting entries into one supergrant
    GrantObject *sumGrant = [self calculateGrantsSum];
    [grantObjects addObject:sumGrant];
    
    //iterate over every grant. NOTE: the accounting entries have already been sorted
    //each element of the overarching array is an array representing a grant. Each element of this array is a dictionary
    //with the date as a key and the account entry as the object
    for(GrantObject *grant in grantObjects) {
        NSMutableArray *accountEntries = [NSMutableArray array];
        
        AccountEntryObject *lastEntry;
        //for each entry, create the horizontal entry and add it to the new array
        for(AccountEntryObject *entry in [grant accountEntries]) {
            //NSLog(@"entry amount: %i", [entry amount]);
            
            //re-add the last entry with the date changed. Copy first.
            if(lastEntry != nil) {
                
                NSDate *tmp = [entry date];
                NSDate *tmp2 = [tmp dateByAddingTimeInterval:-1];
                
                [lastEntry setDate:tmp2];
                [accountEntries addObject:lastEntry];
                //NSLog(@"%i %@", [entry runningTotalToDate], [formatter stringFromDate:[entry date]]);
            }
            
            //add this entry
            [accountEntries addObject:[entry copy]];
            lastEntry = [entry copy];
            
            if(grant != sumGrant) {
                //check to see if this entry breaks the bounds of the graph
                if([earliestDate compare:[entry date]] == NSOrderedDescending) //earliestDate is later than entry date
                    earliestDate = [entry date];
                if([latestDate compare:[entry date]] == NSOrderedAscending) //latestDate is earlier than entry date
                    latestDate = [entry date];
                if(largestValue < [entry runningTotalToDate])
                    largestValue = [entry runningTotalToDate];
                if(smallestValue > [entry runningTotalToDate])
                    smallestValue = [entry runningTotalToDate];
            }            
        }   //END ENTRY LOOP
        
        [lastEntry setDate:[[lastEntry date] dateByAddingTimeInterval:1]]; //add this just so the end of the graph is level
        [accountEntries addObject:lastEntry];
        
        //check if end date is later than anything else
        
        NSDate *endDate = [formatter dateFromString:[[grant getMetadata] objectForKey:@"endDate"]];
        if([latestDate compare:endDate] == NSOrderedAscending) //latestDate is earlier than endDate
            latestDate = endDate;
        
        [grants addObject:accountEntries];
    } //END GRANTS LOOP
    
    
    //reset the bounds of the graph
    NSTimeInterval earliest = [earliestDate timeIntervalSinceDate:refDate];
    NSTimeInterval latest = [latestDate timeIntervalSinceDate:refDate];

    minimumValueForXAxis = earliest - oneDay * 380; //the earliest date, plus a cushion of about a year
    maximumValueForXAxis = latest + oneDay ; //the latest date, plus a cushion of two months
    minimumValueForYAxis = smallestValue;
    maximumValueForYAxis = largestValue;
}

- (GrantObject *) calculateGrantsSum {
    //given all of the grants, create one grant called "sum" that is the sum of all accounting entries
    NSMutableArray *allAccountingEntries = [NSMutableArray array];
    NSMutableArray *grantArrayCopy = [grantObjects copy];
    NSInteger sumLargestValue = 0; //the largest value seen over all (aggregate) entries
    
    //if the graph is nil, then we haven't instantiated the graph yet; if the graph is up and the plot is not hidden, include it
    for(int i = 0; i < [grantArrayCopy count]; i++) {
        if(graph == nil || !((CPTScatterPlot *)[plots objectAtIndex:i]).hidden) {
            GrantObject *grant = [grantArrayCopy objectAtIndex:i];
            
            //make sure we're not including the sum graph in this calculation (if this is not the first run)
            if(![[[grant getMetadata] objectForKey:@"title"] isEqualToString:@"SUM"]) {
                for(AccountEntryObject *entry in [grant accountEntries])
                    [allAccountingEntries addObject:[entry copy]];
            }
        }
    }
    
    //have all of the entries in the account, sort by date then calculate running totals
    [allAccountingEntries sortUsingSelector:@selector(compare:)];
    
    int currentTotal = 0;
    for(AccountEntryObject *entry in allAccountingEntries) {
        currentTotal = currentTotal + [entry amount];
        [entry setRunningTotalToDate:currentTotal];
        
        //NSLog(@"e: %@ a: %i t: %i", [entry label], [entry amount], [entry runningTotalToDate]);
        
        //calculate max
        if(sumLargestValue < [entry runningTotalToDate])
            sumLargestValue = [entry runningTotalToDate];
    }
    
    GrantObject *superGrant = [[GrantObject alloc] init];
    [superGrant setAccountEntries:allAccountingEntries];
    
    maximumValueForYAxisSum = sumLargestValue; //the highest bounds for the aggregate graph
    
    //fake the metadata
    NSMutableDictionary *metaData = [NSMutableDictionary dictionary];
    [metaData setObject:@"SUM" forKey:@"title"];
    [metaData setObject:@"0" forKey:@"endDate"];
    [superGrant setMetadata:metaData];
    
    return superGrant;
}

#pragma mark - Chart behavior
-(void) initPlot
{
    //create array of avaliable colors for coloring plots
    colors = [NSMutableArray arrayWithObjects:[CPTColor redColor], [CPTColor greenColor], [CPTColor blueColor], [CPTColor cyanColor], [CPTColor yellowColor],[CPTColor magentaColor],[CPTColor orangeColor],[CPTColor purpleColor], [CPTColor whiteColor], nil];
    
    [self configureHost];
    [self configureGraph];
    [self configureXYChart];
    [self configureLegend];
    
    //add ghost button
    
    //consider doing this programatically EDIT: programatically might not work for screen sizes, keep it like this for now
    /*for(UIButton *button in buttonsLegend) {
        [self.view bringSubviewToFront:button];
        button.alpha = 0.5f;
        
    }*/
    [self.view bringSubviewToFront:back];
}

-(void) configureHost
{
	// set up view frame
	CGRect parentRect = self.view.bounds;
	parentRect = CGRectMake(parentRect.origin.x, parentRect.origin.y, parentRect.size.width, parentRect.size.height);
    
	// create host view
	self.hostView = [(CPTGraphHostingView *) [CPTGraphHostingView alloc] initWithFrame:parentRect];
	self.hostView.allowPinchScaling = YES;
	[self.view addSubview:self.hostView];
}

-(void) configureGraph
{
	// 1 - Create and initialise graph
	graph = [[CPTXYGraph alloc] initWithFrame:self.hostView.bounds];
    
	self.hostView.hostedGraph = graph;
	graph.paddingLeft = 10.0f;
	graph.paddingTop = 10.0f;
	graph.paddingRight = 10.0f;
	graph.paddingBottom = 10.0f;
    
	// 2 - Set up text style
	CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
	textStyle.color = [CPTColor whiteColor];
	textStyle.fontName = @"Helvetica-Bold";
	textStyle.fontSize = 20.0f;
    
	// 3 - Configure title
	NSString *title = @"All Grants";
	graph.title = title;
	graph.titleTextStyle = textStyle;
	graph.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
	graph.titleDisplacement = CGPointMake(0.0f, -12.0f);
    
    //graph padding
    graph.paddingLeft   = 0.0;
    graph.paddingTop    = 0.0;
    graph.paddingRight  = 0.0;
    graph.paddingBottom = 0.0;
    
    graph.plotAreaFrame.paddingLeft   = 20.0;
    graph.plotAreaFrame.paddingTop    = 20.0;
    graph.plotAreaFrame.paddingRight  = 20.0;
    graph.plotAreaFrame.paddingBottom = 25.0;
    
    //remove that weird line area
    graph.plotAreaFrame.borderLineStyle = nil;
    graph.plotAreaFrame.cornerRadius    = 0.0;
    
	// 4 - Set theme
	self.selectedTheme = [CPTTheme themeNamed:kCPTDarkGradientTheme];
	[graph applyTheme:self.selectedTheme];
}

-(void) configureXYChart
{
    // Setup plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minimumValueForXAxis)
                                                    length:CPTDecimalFromDouble(ceil( (maximumValueForXAxis - minimumValueForXAxis) / majorIntervalLengthForX ) * majorIntervalLengthForX)];
    
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minimumValueForYAxis)
                                                    length:CPTDecimalFromDouble(ceil( (maximumValueForYAxis - minimumValueForYAxis) / majorIntervalLengthForY ) * majorIntervalLengthForY)];
    
    test = plotSpace.yRange;
    lastRangeY = plotSpace.yRange;
    lastRangeX = plotSpace.xRange;
    
    // this allows the plot to respond to touch events
    [plotSpace setDelegate:self]; //set delegate fromm other file  ABE: what does this mean?
    [plotSpace setAllowsUserInteraction:YES];
    
    //set up x axis
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;

    CPTXYAxis *x = axisSet.xAxis;
    
    //x.labelOffset           = 5.0; //conflict
    //x.axisConstraints       = [CPTConstraints constraintWithLowerOffset:0.0]; //what is this?
    //x.orthogonalCoordinateDecimal = [[NSNumber numberWithInt:20] decimalValue]; //conflict and i dont know what this is
    //x.labelOffset = 10.0f;
    //x.labelingPolicy = CPTAxisLabelingPolicyAutomatic; //no conflict, please test this
    
    // plotting style is set to line plots
    /*CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle]; //this block changes and sets the color of the axis
    lineStyle.lineColor = [CPTColor blackColor];
    lineStyle.lineWidth = 2.0f;
    x.majorTickLineStyle = lineStyle;
    x.minorTickLineStyle = lineStyle;
    x.axisLineStyle = lineStyle; */
    
    x.majorIntervalLength = CPTDecimalFromDouble(majorIntervalLengthForX * 2);
    x.minorTicksPerInterval = 0;
    x.orthogonalCoordinateDecimal = CPTDecimalFromString(@"1"); //added for date, adjust x line
    x.axisConstraints       = [CPTConstraints constraintWithLowerOffset:0.0]; //where is the y axis?
    x.minorTickLength = 5.0f;
    x.majorTickLength = 7.0f;
    x.labelOffset = 3.0f;

    // Date Formatting
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM/YY"];
    CPTTimeFormatter *timeFormatter = [[CPTTimeFormatter alloc] initWithDateFormatter:dateFormatter];
    timeFormatter.referenceDate = refDate;
    x.labelFormatter = timeFormatter;
    
    //number formatter for y, makes it into thousands. Still need to add a $ sign
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setPositiveFormat:@"$0k"];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setMaximumFractionDigits:0];
    [numberFormatter setMultiplier:[NSNumber numberWithDouble:.001]]; //removed the 1/1000 conversion
    
    //set up y axis
    CPTXYAxis *y = axisSet.yAxis;
    y.minorTicksPerInterval = 1;
    y.majorIntervalLength   = CPTDecimalFromDouble(majorIntervalLengthForY);
    y.labelOffset           = 1.0;
    y.axisConstraints       = [CPTConstraints constraintWithLowerOffset:-10.0]; //where is the y axis?
    y.labelFormatter = numberFormatter;
    y.tickDirection = CPTSignPositive; //moves the labels to the inside of the graph instead of the to the left of the y axis
    
    //y axis grid lines
    CPTMutableLineStyle *yGridLines = [CPTMutableLineStyle lineStyle];
    yGridLines.lineColor = [CPTColor darkGrayColor];
    y.majorGridLineStyle = yGridLines;
    
    //TEST
    //y axis label
    //y.title = @"(thousands)";
    //y.titleLocation =
    //y.titleRotation = 0.0; //this moves it to the top of the axis
    //y.titleLocation = plotSpace.yRange.maxLimit
    

    
    // Create plots for every grant
    //graph line style 
    CPTMutableLineStyle *dataLineStyle = [CPTMutableLineStyle lineStyle];
    CPTMutableLineStyle *endLineStyle = [CPTMutableLineStyle lineStyle];
    dataLineStyle.lineWidth = 1.0f;
    endLineStyle.lineWidth = 1.0f;
    endLineStyle.dashPattern = [NSArray arrayWithObjects:[NSDecimalNumber numberWithInt:1],[NSDecimalNumber numberWithInt:3], nil];
    
    int indexColor = 0;
    
    for(GrantObject *grant in grantObjects) {
        
        //part 1: plot the grant
        CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] initWithFrame:graph.bounds];
        dataSourceLinePlot.identifier = [[grant getMetadata] objectForKey:@"title"];
        dataSourceLinePlot.dataSource = self;
        dataSourceLinePlot.delegate = self;
        dataSourceLinePlot.plotSymbolMarginForHitDetection = 10;
        
        //assign this plot the color, then remove it. Multiple runs of this loop should retain color pairing
        dataLineStyle.lineColor = [colors objectAtIndex:indexColor];
        dataSourceLinePlot.dataLineStyle = dataLineStyle;
        
        [graph addPlot:dataSourceLinePlot];
        [plots addObject:dataSourceLinePlot]; //the index at which this was added corresponds to the index of this grant in "grants" array
        
        //part 2: plot the end date of the grant as a vertical, dotted line with the same color
        //NSNumber *endDate = [self dateAsTimeIntervalFromString:[[grant getMetadata] objectForKey:@"endDate" ]];
        NSMutableArray *verticalEntries = [NSMutableArray array];
        
        //add the first data point, way down
        CPTScatterPlot *endLinePlot = [[CPTScatterPlot alloc] initWithFrame:graph.bounds];
        endLineStyle.lineColor = [colors objectAtIndex:indexColor];
        endLinePlot.identifier = @"endLine";
        endLinePlot.dataSource = self;
        endLinePlot.delegate = self;
        endLinePlot.dataLineStyle = endLineStyle;
        
        AccountEntryObject *entry = [[AccountEntryObject alloc] initWithDate:[[grant getMetadata] objectForKey:@"endDate"]];
        [entry setRunningTotalToDate:-1000000];
        [verticalEntries addObject:entry];
        
        entry = [entry copy];
        [entry setDate:[[entry date] dateByAddingTimeInterval:1]];
        [entry setRunningTotalToDate:100000000];
        [verticalEntries addObject:entry];
        
        [endDateValues addObject:verticalEntries];
        [plotsOfEndDates addObject:endLinePlot];
        [graph addPlot:endLinePlot];
        
        //end part 2
        indexColor++; //get the next color in the array
        
        //if this is the sum graph, start hidden
        /*if([(NSString *)dataSourceLinePlot.identifier isEqualToString:@"SUM"]) {
            dataSourceLinePlot.hidden = YES;
        }*/
    }
}

//this used to be the coreplot legend method, but its customized to run off buttons linked from IB
//spin through all grants, make the IB buttons visible, set the color correctly
-(void)configureLegend {
    //turn on the popup label
    [self.view bringSubviewToFront:popup];
    
    [self addButtons];
}

- (void) addButtons {
    //buttons are tagged from 100 to 119, in order from top to bottom, right to left. Maximum supported grants:20. All start hidden.
    //consider putting them in a table to remove the upper limit
    buttonReferences = [NSMutableArray array];
    
    //Create an array of color objects that are removed in order for each grant, ensuring uniquie colors
    NSArray *plotColors = [NSArray arrayWithObjects:[UIColor redColor], [UIColor greenColor], [UIColor blueColor], [UIColor cyanColor], [UIColor yellowColor],[UIColor magentaColor],[UIColor orangeColor],[UIColor purpleColor], [UIColor grayColor], [UIColor whiteColor], nil];
    
    int buttonWidth = 118;
    int buttonHeight = 25;
    int topBorder = 20;
    
    CGRect border = CGRectMake(100, 100, buttonWidth, buttonHeight);
    
    for(int i = 0; i < [grantObjects count]; i ++) {
        GrantObject *grant = [grantObjects objectAtIndex:i];
        UIButton *button = [[UIButton alloc] initWithFrame:border];
        [self.view addSubview:button];
        
        [button setTitle:[[grant getMetadata] objectForKey:@"title"] forState:UIControlStateNormal];
        
        //coloring
        UIColor *temp = [plotColors objectAtIndex:i];
        
        const CGFloat* components = CGColorGetComponents(temp.CGColor);
        
        button.backgroundColor = [UIColor colorWithRed:components[0] green:components[1] blue:components[2] alpha:.4];
        [[button layer] setCornerRadius:8.0f];
        [[button layer] setMasksToBounds:YES];
        [[button layer] setBorderWidth:1.0f];
        [button.titleLabel setFont:[UIFont systemFontOfSize:8]];
        
        //SET VIEW FRAME HERE
        int x = self.view.frame.size.width - buttonWidth;
        int y = topBorder + i * buttonHeight;
        
        CGRect newFrame = CGRectMake(x, y, buttonWidth, buttonHeight);
        button.frame = newFrame;
        
        [button addTarget:self action:@selector(buttonPress:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view bringSubviewToFront:button];
        [buttonReferences addObject:button];
    }
    
    /*
    int buttonTagIndex = 100;
    int colorIndex = 0;
    UIButton *button;
    
    NSArray *plotColors = [NSArray arrayWithObjects:[UIColor redColor], [UIColor greenColor], [UIColor blueColor], [UIColor cyanColor], [UIColor yellowColor],[UIColor magentaColor],[UIColor orangeColor],[UIColor purpleColor], [UIColor grayColor], [UIColor whiteColor], nil];
    
    for(GrantObject *grant in grantObjects) {
        button = (UIButton *)[self.view viewWithTag:buttonTagIndex];
        [button setTitle:[[grant getMetadata] objectForKey:@"title"] forState:UIControlStateNormal];
        
        UIColor *temp = [plotColors objectAtIndex:colorIndex];
        
        const CGFloat* components = CGColorGetComponents(temp.CGColor);
        
        button.backgroundColor = [UIColor colorWithRed:components[0] green:components[1] blue:components[2] alpha:.4];
        [[button layer] setCornerRadius:8.0f];
        [[button layer] setMasksToBounds:YES];
        [[button layer] setBorderWidth:1.0f];
        //[[button layer] setOpacity:0.5];
        
        buttonTagIndex++;
        colorIndex++;
        
        [button setHidden:NO];
        [self.view bringSubviewToFront:button];
        [buttonReferences addObject:button];
    }
    
    //after all of the buttons are made, button as listed above is the last button: call hide on it
    [self buttonPress:button];*/

}

#pragma mark - CPTPlotDataSource methods
-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    int i = [plots indexOfObject:plot];
    
    if(i == NSNotFound) {
        return 2;
    }
    
    NSArray *grant = [grants objectAtIndex:i];
    return  grant.count;
}

//fetches the index of the appropriate plot, uses that index to retrieve the array of acocunting entries from the grant indexed. 
-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index {
    NSArray *grant;

    int i = [plots indexOfObject:plot];
    
    if(i == NSNotFound) {
        int i = [plotsOfEndDates indexOfObject:plot];
        grant = [endDateValues objectAtIndex:i];
    }
    else {
        grant = [grants objectAtIndex:i];
    }
    
    AccountEntryObject *entry = [grant objectAtIndex:index];
    
    if(fieldEnum == CPTScatterPlotFieldY) {
        //NSLog(@"amount: %i", [entry runningTotalToDate]);
        return [NSNumber numberWithInt:[entry runningTotalToDate]];
    }
    else {
        //NSLog(@"Date as Time Interval: %@  for entry: %@", [entry dateAsTimeInterval], [entry label]);
        return [entry dateAsTimeInterval];
    }
}

//allows the user to click on individual plot points. Consider a popup, or a transistion to another VC
-(void)scatterPlot:(CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex: (NSUInteger)index {
    if(!plot.hidden){
        
        int i = [plots indexOfObject:plot];
        NSArray *accountEntries = [grants objectAtIndex:i];
        GrantObject *grant = [grantObjects objectAtIndex:i];
        
        //actual entries are at EVEN values. The odd values are the horizontal entries; if odd the next entry should be retrieved
        
        if(index % 2 != 0)
            index++;
        
        AccountEntryObject *entry = [accountEntries objectAtIndex:index];
        NSString *title = [[grant getMetadata] objectForKey:@"title"];
        NSRange stringRange = {0, MIN([title length], 15)};
        
        // adjust the range to include dependent chars
        stringRange = [title rangeOfComposedCharacterSequencesForRange:stringRange];
        
        // Now you can create the short string
        NSString *shortString = [title substringWithRange:stringRange];
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [formatter setMaximumFractionDigits:0];
        
        NSString *amount = [formatter stringFromNumber:[NSNumber numberWithInt:[entry amount]]];
        
        popup.text = [NSString stringWithFormat:@"%@\n%@\n%@\n", shortString, [entry label], amount];
        
        //NSLog(@"plotSymbolWasSelectedAtRecordIndex %d", index);
        
        //present the info po©pup
        NSDecimal plotPoint[2];
        NSNumber *plotXvalue = [self numberForPlot:plot field:CPTScatterPlotFieldX recordIndex:index];
        plotPoint[CPTCoordinateX] = plotXvalue.decimalValue;
        
        NSNumber *plotYvalue = [self numberForPlot:plot field:CPTScatterPlotFieldY recordIndex:index];
        plotPoint[CPTCoordinateY] = plotYvalue.decimalValue;
        
        CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
        
        // convert from data coordinates to plot area coordinates
        CGPoint dataPoint = [plotSpace plotAreaViewPointForPlotPoint:plotPoint];
        
        // convert from plot area coordinates to graph (and hosting view) coordinates
        //dataPoint = [graph convertPoint:dataPoint fromLayer:graph.plotAreaFrame];
        
        // convert from hosting view coordinates to self.view coordinates (if needed)
        dataPoint = [self.view convertPoint:dataPoint fromView:self.hostView];
        
        //NSLog(@"datapoint coordinates tapped: %@", NSStringFromCGPoint(dataPoint));
        
        int diff;
        if(dataPoint.y > 160) {
            //if greater than 160, subtract diff *2
            diff = dataPoint.y - 160;
            dataPoint.y -= diff*2;
        }
        else {
            diff = 160 - dataPoint.y;
            dataPoint.y += diff*2;
        }
        
        //because of the borders, the coordinates don't seem to be right on. This is a hardcoded fix
        //TODO: fix this dynamically
        dataPoint.y += constCoordinateOffsetY;
        dataPoint.x += constCoordinateOffsetX;
        
        //NSLog(@"datapoint coordinates tapped: %@", NSStringFromCGPoint(dataPoint));
        
        //0,0 is top LEFT in the view window. In the hostview, 0,0 is bottom left
        popup.frame = CGRectMake(dataPoint.x, dataPoint.y, popup.frame.size.width, popup.frame.size.height);
        
        popup.hidden = NO;
        [UIView animateWithDuration:.5 animations:^{
            popup.alpha = .8;
        }];
    }
}

#pragma mark Plot Customization Methods
//when a button is pressed, toggle opacity of button and visibility of plot
- (IBAction)buttonPress:(id)sender {
    [self removePopup];
    
    UIButton *button = (UIButton *)sender;
    int index = [buttonReferences indexOfObject:button];
    CPTScatterPlot *plot = [plots objectAtIndex:index];
    CPTScatterPlot *end = [plotsOfEndDates objectAtIndex:index];
    
    if(button.alpha == 1) {
        button.alpha = .2;
        plot.hidden = YES;
        end.hidden = YES;
    }
    else {
        button.alpha = 1;
        plot.hidden = NO;
        end.hidden = NO;
    }
    
    //call the sumGrant method to change the graphs included in the sum
    GrantObject *sum = [self calculateGrantsSum];
    [grants replaceObjectAtIndex:[grants count] - 1 withObject:[sum accountEntries]];
    [[plots objectAtIndex:[plots count] - 1] reloadData];
    
    BOOL isSum = NO;
    if(index == [buttonReferences count] - 1)
        isSum = YES;
    
    [self resizeGraph:YES];
}

- (void) back:(id)sender
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    //double check the destination orientation
    if(UIInterfaceOrientationIsPortrait(toInterfaceOrientation)) {

        //[self presentViewController:landscape animated:YES completion:nil];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void) movePopup {
    //move the popup in the graph view
    
}

-(CPTPlotRange *)plotSpace:(CPTPlotSpace *)space willChangePlotRangeTo:(CPTPlotRange *)newRange forCoordinate:(CPTCoordinate)coordinate {
    
    
    if(coordinate == 0) {//if x coordinate, allow modification
        //NSLog(@"%@", newRange);
        
        CPTXYAxisSet *axisSet = (id)graph.axisSet;
        
        //set the maximum zoom
        if(newRange.lengthDouble <= 15000000)
            return lastRangeX;
        
        
        //constrict the horizontal scrolling to the maximum values + 2yr
        if(newRange.locationDouble < minimumValueForXAxis - oneDay * 365) { //this is stuttery, values that are only a little smaller will work, big swipes make it ehh
            //NSLog(@"SMALL %@", newRange);
            return lastRangeX;
        }
        
        //constrict the horizontal scrolling to the maximum values + 2yr
        if(newRange.locationDouble > maximumValueForXAxis) {
            //NSLog(@"BIG %@", newRange);
            return lastRangeX;
        }

        //if the length passes a certain amount, resize the interval ticks to keep them readable
        if(newRange.lengthDouble > 140000000)
            axisSet.xAxis.majorIntervalLength = CPTDecimalFromDouble(majorIntervalLengthForX * 2);
        else if(newRange.lengthDouble < 35000000)
            axisSet.xAxis.majorIntervalLength = CPTDecimalFromDouble(majorIntervalLengthForX / 4);
        else if(newRange.lengthDouble < 70000000)
            axisSet.xAxis.majorIntervalLength = CPTDecimalFromDouble(majorIntervalLengthForX / 2);
        else
            axisSet.xAxis.majorIntervalLength = CPTDecimalFromDouble(majorIntervalLengthForX);
        
        //remember the last range in case we want to freeze
        lastRangeX = newRange;
        return newRange;
    }
    else  { //y axis, allow some scrolling and zooming
        //set the maximum zoom
        //if(newRange.lengthDouble <= 15000000)
        //    return lastRange;
        
        
        //constrict the horizontal scrolling to the maximum values + 2yr
        if(newRange.locationDouble < minimumValueForYAxis) { //this is stuttery, values that are only a little smaller will work, big swipes make it ehh
            //NSLog(@"SMALL %@", newRange);
            return lastRangeY;
        }
        
        //constrict the horizontal scrolling to the maximum values + 2yr
        if(newRange.locationDouble > maximumValueForYAxis) {
            //NSLog(@"BIG %@", newRange);
            return lastRangeY;
        }
        
        //remember the last range in case we want to freeze
        lastRangeY = newRange;
        return newRange;
        
        //NSLog(@"%@", newRange);
        return test;
    }
}

///////////////////////////////////// CODE from the other project, kepy around for referance on how to change

-(void) initGraphSpace
{
    // Create graph from theme
    graph = [[CPTXYGraph alloc] initWithFrame:self.view.frame];
    CPTTheme *theme = [CPTTheme themeNamed:kCPTDarkGradientTheme];
    [graph applyTheme:theme];
    self.hostView.hostedGraph = graph;
    //graphView.hostedGraph = graph;
    
    graph.paddingLeft   = 0.0;
    graph.paddingTop    = 0.0;
    graph.paddingRight  = 0.0;
    graph.paddingBottom = 0.0;
    
    graph.plotAreaFrame.paddingLeft   = 55.0;
    graph.plotAreaFrame.paddingTop    = 40.0;
    graph.plotAreaFrame.paddingRight  = 40.0;
    graph.plotAreaFrame.paddingBottom = 35.0;
    
    graph.plotAreaFrame.plotArea.fill = graph.plotAreaFrame.fill;
    graph.plotAreaFrame.fill          = nil;
    
    graph.plotAreaFrame.borderLineStyle = nil;
    graph.plotAreaFrame.cornerRadius    = 0.0;
    
    // Setup plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minimumValueForXAxis) length:CPTDecimalFromDouble(ceil( (maximumValueForXAxis - minimumValueForXAxis) / majorIntervalLengthForX ) * majorIntervalLengthForX)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minimumValueForYAxis) length:CPTDecimalFromDouble(ceil( (maximumValueForYAxis - minimumValueForYAxis) / majorIntervalLengthForY ) * majorIntervalLengthForY)];
    
    // this allows the plot to respond to mouse events
    [plotSpace setDelegate:self]; //set delegate form other file
    [plotSpace setAllowsUserInteraction:YES];
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    
    CPTXYAxis *x = axisSet.xAxis;
    x.minorTicksPerInterval = 9;
    x.majorIntervalLength   = CPTDecimalFromDouble(majorIntervalLengthForX);
    x.labelOffset           = 5.0;
    x.axisConstraints       = [CPTConstraints constraintWithLowerOffset:0.0];
    
    CPTXYAxis *y = axisSet.yAxis;
    y.minorTicksPerInterval = 9;
    y.majorIntervalLength   = CPTDecimalFromDouble(majorIntervalLengthForY);
    y.labelOffset           = 5.0;
    y.axisConstraints       = [CPTConstraints constraintWithLowerOffset:0.0];
    
    // Create the main plot for the delimited data
    CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] initWithFrame:graph.bounds];
    dataSourceLinePlot.identifier = @"Data Source Plot";
    
    CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
    lineStyle.lineWidth              = 1.0;
    lineStyle.lineColor              = [CPTColor whiteColor];
    dataSourceLinePlot.dataLineStyle = lineStyle;
    
    dataSourceLinePlot.dataSource = self;
    [graph addPlot:dataSourceLinePlot];
}

-(BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    return YES;
}

#pragma mark Popup 
- (void) initPopup {
    popup = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 150, 55)];
    popup.text = @"Label";
    popup.font = [UIFont fontWithName:@"Helvetica" size:12];
    popup.alpha = .8;
    popup.layer.cornerRadius = 2;
    popup.layer.borderWidth = 1;
    popup.layer.borderColor = [[UIColor grayColor] CGColor];
    popup.hidden = YES;
    popup.editable = NO;
    
    [self.view addSubview:popup];
}

- (void) removePopup {
    //plotSymbolWasSelected is the appear method, this should animate the hide
    if(popup.alpha != 0) {
        [UIView animateWithDuration:.5 animations:^{
            popup.alpha = 0;
        } completion:^(BOOL finished) {
            popup.hidden = YES;
        }];
    }
}

#pragma mark Auxilliary
-(BOOL)plotSpace:(CPTPlotSpace *)space shouldHandlePointingDeviceDownEvent:(id)event atPoint:(CGPoint)point {
    //NSLog(@"Touch!");
    
    //remove popup
    [self removePopup];
    return YES;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"Touches!");
}

- (void) resizeGraph:(BOOL) sumButtonPressed {
    //if button.hidden, then we should save the current view and resize. Else revert to a previously saved view
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;

    //if the sum plot is hidden AND the sumButtonPressed, then switch to old view. If the button is not pressed
    if(((CPTScatterPlot *)[plots objectAtIndex:[plots count] - 1]).hidden && sumButtonPressed) {
        if(savedRangeX != nil) {
            plotSpace.xRange = savedRangeX;
            plotSpace.yRange = savedRangeY;
        }
    }
    
    //if the sum plot is not hidden, then always redraw
    if(!((CPTScatterPlot *)[plots objectAtIndex:[plots count] - 1]).hidden) {
        savedRangeX = plotSpace.xRange;
        savedRangeY = plotSpace.yRange;
        
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minimumValueForXAxis)
                                                        length:CPTDecimalFromDouble(ceil( (maximumValueForXAxis - minimumValueForXAxis) / majorIntervalLengthForX ) * majorIntervalLengthForX)];
        
        plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minimumValueForYAxis)
                                                        length:CPTDecimalFromDouble(ceil( (maximumValueForYAxisSum - minimumValueForYAxis) / majorIntervalLengthForY ) * majorIntervalLengthForY)];
    }
}
@end
