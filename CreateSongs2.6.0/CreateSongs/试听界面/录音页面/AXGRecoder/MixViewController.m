//
//  ViewController.m
//  Audio Controller Test Suite
//
//  Created by Michael Tyson on 13/02/2012.
//  Copyright (c) 2012 A Tasty Pixel. All rights reserved.
//

#import "MixViewController.h"
#import "TheAmazingAudioEngine.h"
#import "TPOscilloscopeLayer.h"
#import "AEPlaythroughChannel.h"
#import "AEExpanderFilter.h"
#import "AELimiterFilter.h"
#import "AERecorder.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>


#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _checkResult(OSStatus result, const char *operation, const char* file, int line) {
    if ( result != noErr ) {
        int fourCC = CFSwapInt32HostToBig(result);
        NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&fourCC);
        return NO;
    }
    return YES;
}

static const int kInputChannelsChangedContext;

#define kAuxiliaryViewTag 251

@interface MixViewController () {
    AudioFileID _audioUnitFile;
    AEChannelGroupRef _group;
}
@property (nonatomic, strong) AEAudioController *audioController;
@property (nonatomic, strong) AEAudioFilePlayer *loop1;
@property (nonatomic, strong) AEAudioFilePlayer *loop2;
@property (nonatomic, strong) AEBlockChannel *oscillator;
@property (nonatomic, strong) AEAudioUnitChannel *audioUnitPlayer;
@property (nonatomic, strong) AEAudioFilePlayer *oneshot;
@property (nonatomic, strong) AEPlaythroughChannel *playthrough;
@property (nonatomic, strong) AELimiterFilter *limiter;
@property (nonatomic, strong) AEExpanderFilter *expander;
@property (nonatomic, strong) AEAudioUnitFilter *reverb;
@property (nonatomic, strong) TPOscilloscopeLayer *outputOscilloscope;
@property (nonatomic, strong) TPOscilloscopeLayer *inputOscilloscope;
@property (nonatomic, strong) CALayer *inputLevelLayer;
@property (nonatomic, strong) CALayer *outputLevelLayer;
@property (nonatomic, strong) NSTimer *levelsTimer;
@property (nonatomic, strong) AERecorder *recorder;
@property (nonatomic, strong) AEAudioFilePlayer *player;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *oneshotButton;
@property (nonatomic, strong) UIButton *oneshotAudioUnitButton;

@property (nonatomic, strong) NSArray *songsArray;
@property (nonatomic, strong) NSMutableArray *loopArray;

@end

@implementation MixViewController

- (NSMutableArray *)loopArray {
    if (_loopArray == nil) {
        _loopArray = [NSMutableArray array];
    }
    return _loopArray;
}

- (instancetype)initWIthAudioController:(AEAudioController *)audioController {
    if ( !(self = [super initWithStyle:UITableViewStyleGrouped]) ) return nil;
    
    self.audioController = audioController;
    self.songsArray = @[@"斑马斑马", @"青花瓷", @"月半小夜曲", @"成都" ,@"演员"];
    
    for (NSInteger i = 0; i < self.songsArray.count; i++) {
        AEAudioFilePlayer *aeAudioFilePlayer = [AEAudioFilePlayer audioFilePlayerWithURL:[[NSBundle mainBundle] URLForResource:self.songsArray[i] withExtension:@"mp3"]
                                                                         audioController:_audioController
                                                                                   error:NULL];
        aeAudioFilePlayer.volume = 1.0;
        aeAudioFilePlayer.channelIsMuted = YES;
        aeAudioFilePlayer.loop = YES;
        [aeAudioFilePlayer addObserver:self forKeyPath:@"currentTime" options:0 context:nil];
        [self.loopArray addObject:aeAudioFilePlayer];
    }
    
//    self.loop1 = [AEAudioFilePlayer audioFilePlayerWithURL:[[NSBundle mainBundle] URLForResource:self.songsArray[0] withExtension:@"mp3"]
//                                           audioController:_audioController
//                                                     error:NULL];
//    _loop1.volume = 1.0;
//    _loop1.channelIsMuted = YES;
//    _loop1.loop = YES;
    
//    self.loop2 = [AEAudioFilePlayer audioFilePlayerWithURL:[[NSBundle mainBundle] URLForResource:@"001" withExtension:@"mp3"]
//                                           audioController:_audioController
//                                                     error:NULL];
//    _loop2.volume = 1.0;
//    _loop2.channelIsMuted = YES;
//    _loop2.loop = YES;
    
    __block float oscillatorPosition = 0;
    __block float oscillatorRate = 622.0/44100.0;
    self.oscillator = [AEBlockChannel channelWithBlock:^(const AudioTimeStamp  *time,
                                                         UInt32           frames,
                                                         AudioBufferList *audio) {
        for ( int i=0; i<frames; i++ ) {
            float x = oscillatorPosition;
            x *= x;
            x -= 1.0;
            x *= x;
            x *= INT16_MAX;
            x -= INT16_MAX / 2;
            oscillatorPosition += oscillatorRate;
            if ( oscillatorPosition > 1.0 ) oscillatorPosition -= 2.0;
            
            ((SInt16*)audio->mBuffers[0].mData)[i] = x;
            ((SInt16*)audio->mBuffers[1].mData)[i] = x;
        }
    }];
    _oscillator.audioDescription = [AEAudioController nonInterleaved16BitStereoAudioDescription];
    
    _oscillator.channelIsMuted = YES;
    self.audioUnitPlayer = [[AEAudioUnitChannel alloc] initWithComponentDescription:AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer)
                                                                     audioController:_audioController
                                                                               error:NULL];
    
    _group = [_audioController createChannelGroup];
//    [_audioController addChannels:[NSArray arrayWithObjects:_loop1, _loop2, _oscillator, nil] toChannelGroup:_group];
    [_audioController addChannels:self.loopArray toChannelGroup:_group];
    [_audioController addChannels:[NSArray arrayWithObjects:_audioUnitPlayer, nil]];
    [_audioController addObserver:self forKeyPath:@"numberOfInputChannels" options:0 context:(void*)&kInputChannelsChangedContext];
    return self;
}

-(void)dealloc {
    [_audioController removeObserver:self forKeyPath:@"numberOfInputChannels"];
    
    if (_audioUnitFile) {
        AudioFileClose(_audioUnitFile);
    }
    
    if (_levelsTimer) [_levelsTimer invalidate];
    
    NSMutableArray *channelsToRemove = [NSMutableArray arrayWithArray:self.loopArray];

//    NSMutableArray *channelsToRemove = [NSMutableArray arrayWithObjects:_loop1, _loop2, nil];
    
//    self.loop1 = nil;
//    self.loop2 = nil;
    
    for (NSInteger i = 0; i < self.loopArray.count; i++) {
        AEAudioFilePlayer *loop = self.loopArray[i];
        loop = nil;
    }
    
    if (_player) {
        [channelsToRemove addObject:_player];
        self.player = nil;
    }
    
    if (_oneshot) {
        [channelsToRemove addObject:_oneshot];
        self.oneshot = nil;
    }
    
    if (_playthrough) {
        [channelsToRemove addObject:_playthrough];
        [_audioController removeInputReceiver:_playthrough];
        self.playthrough = nil;
    }
    
    [_audioController removeChannels:channelsToRemove];
    
    if (_limiter) {
        [_audioController removeFilter:_limiter];
        self.limiter = nil;
    }
    
    if (_expander) {
        [_audioController removeFilter:_expander];
        self.expander = nil;
    }
    
    if (_reverb) {
        [_audioController removeFilter:_reverb];
        self.reverb = nil;
    }
    
    self.recorder = nil;
    self.recordButton = nil;
    self.playButton = nil;
    self.oneshotButton = nil;
    self.oneshotAudioUnitButton = nil;
    self.outputOscilloscope = nil;
    self.inputOscilloscope = nil;
    self.inputLevelLayer = nil;
    self.outputLevelLayer = nil;
    self.audioController = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 100)];
    headerView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    self.outputOscilloscope = [[TPOscilloscopeLayer alloc] initWithAudioController:_audioController];
    _outputOscilloscope.frame = CGRectMake(0, 0, headerView.bounds.size.width, 80);
//    [headerView.layer addSublayer:_outputOscilloscope];
    [_audioController addOutputReceiver:_outputOscilloscope];
    [_outputOscilloscope start];
    
    self.inputOscilloscope = [[TPOscilloscopeLayer alloc] initWithAudioController:_audioController];
    _inputOscilloscope.frame = CGRectMake(0, 0, headerView.bounds.size.width, 80);
    _inputOscilloscope.lineColor = [UIColor colorWithWhite:0.0 alpha:0.3];
//    [headerView.layer addSublayer:_inputOscilloscope];
    [_audioController addInputReceiver:_inputOscilloscope];
    [_inputOscilloscope start];
    
    self.inputLevelLayer = [CALayer layer];
    _inputLevelLayer.backgroundColor = [[UIColor colorWithWhite:0.0 alpha:0.3] CGColor];
    _inputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0 - 5.0 - (0.0), 90, 0, 10);
//    [headerView.layer addSublayer:_inputLevelLayer];
    
    self.outputLevelLayer = [CALayer layer];
    _outputLevelLayer.backgroundColor = [[UIColor colorWithWhite:0.0 alpha:0.3] CGColor];
    _outputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0 + 5.0, 90, 0, 10);
//    [headerView.layer addSublayer:_outputLevelLayer];
    
    self.tableView.tableHeaderView = headerView;
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 80)];
    self.recordButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_recordButton setTitle:@"Record" forState:UIControlStateNormal];
    [_recordButton setTitle:@"Stop" forState:UIControlStateSelected];
    [_recordButton addTarget:self action:@selector(record:) forControlEvents:UIControlEventTouchUpInside];
    _recordButton.frame = CGRectMake(20, 10, ((footerView.bounds.size.width-50) / 2), footerView.bounds.size.height - 20);
    _recordButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.playButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_playButton setTitle:@"Play" forState:UIControlStateNormal];
    [_playButton setTitle:@"Stop" forState:UIControlStateSelected];
    [_playButton addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    _playButton.frame = CGRectMake(CGRectGetMaxX(_recordButton.frame)+10, 10, ((footerView.bounds.size.width-50) / 2), footerView.bounds.size.height - 20);
    _playButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [footerView addSubview:_recordButton];
    [footerView addSubview:_playButton];
    self.tableView.tableFooterView = footerView;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(earPod) name:@"earPod" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noneEarPod) name:@"noneEarPod" object:nil];
    
    self.levelsTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateLevels:) userInfo:nil repeats:YES];
}

- (void)noneEarPod {
    [self turnOffVoice];
}

- (void)earPod {
    [self turnOnVoice];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_levelsTimer invalidate];
    self.levelsTimer = nil;
}

-(void)viewDidLayoutSubviews {
    _outputOscilloscope.frame = CGRectMake(0, 0, self.tableView.tableHeaderView.bounds.size.width, 80);
    _inputOscilloscope.frame = CGRectMake(0, 0, self.tableView.tableHeaderView.bounds.size.width, 80);
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ( section ) {
        case 0:
            return self.songsArray.count;
            
        case 1:
            return 2;
            
        case 2:
            return 3;
            
        case 3:
            return 1 + (_audioController.numberOfInputChannels > 1 ? 1 : 0);
            
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isiPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    
    static NSString *cellIdentifier = @"cellIndentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [[cell viewWithTag:kAuxiliaryViewTag] removeFromSuperview];
    
    switch (indexPath.section) {
        case 0: {
            cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
            UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(cell.bounds.size.width - (isiPad ? 250 : 210), 0, 100, cell.bounds.size.height)];
            slider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            slider.tag = kAuxiliaryViewTag;
            slider.maximumValue = 1.0;
            slider.minimumValue = 0.0;
            [cell addSubview:slider];
            
            AEAudioFilePlayer *loop = self.loopArray[indexPath.row];
            cell.textLabel.text = self.songsArray[indexPath.row];
            ((UISwitch*)cell.accessoryView).on = !loop.channelIsMuted;
            slider.value = loop.volume;
            
            cell.accessoryView.tag = indexPath.row;
            [((UISwitch*)cell.accessoryView) addTarget:self
                                                action:@selector(loopSwitchChanged:)
                                      forControlEvents:UIControlEventValueChanged];
            
            slider.tag = indexPath.row;
            [slider addTarget:self
                       action:@selector(loopVolumeChanged:)
             forControlEvents:UIControlEventValueChanged];
            
            break;
        }
        case 1: {
            switch (indexPath.row) {
                case 0: {
                    cell.accessoryView = self.oneshotButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                    [_oneshotButton setTitle:@"Play" forState:UIControlStateNormal];
                    [_oneshotButton setTitle:@"Stop" forState:UIControlStateSelected];
                    [_oneshotButton sizeToFit];
                    [_oneshotButton setSelected:_oneshot != nil];
                    [_oneshotButton addTarget:self action:@selector(oneshotPlayButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                    cell.textLabel.text = @"One Shot";
                    break;
                }
                case 1: {
                    cell.accessoryView = self.oneshotAudioUnitButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                    [_oneshotAudioUnitButton setTitle:@"Play" forState:UIControlStateNormal];
                    [_oneshotAudioUnitButton setTitle:@"Stop" forState:UIControlStateSelected];
                    [_oneshotAudioUnitButton sizeToFit];
                    [_oneshotAudioUnitButton setSelected:_oneshot != nil];
                    [_oneshotAudioUnitButton addTarget:self action:@selector(oneshotAudioUnitPlayButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                    cell.textLabel.text = @"One Shot (Audio Unit)";
                    break;
                }
            }
            break;
        }//  http://www.woyaoxiege.com/data/music/accwav/ff223d1f56e3bbdbd3cbaf4b8303ebb7_2_v.wav
        case 2: {// data/music/accwav/63df2568ed2fbff2d7ccd6c12f9449bb_1_v.wav
            cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
            
            switch (indexPath.row) {
                case 0: {
                    cell.textLabel.text = @"Limiter";
                    ((UISwitch*)cell.accessoryView).on = _limiter != nil;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(limiterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
                case 1: {
                    cell.textLabel.text = @"Expander";
                    ((UISwitch*)cell.accessoryView).on = _expander != nil;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(expanderSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
                case 2: {
                    cell.textLabel.text = @"Reverb";
                    ((UISwitch*)cell.accessoryView).on = _expander != nil;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(reverbSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
            }
            break;
        }
        case 3: {
            cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
            
            switch (indexPath.row) {
                case 0: {
                    cell.textLabel.text = @"Input Playthrough";
                    ((UISwitch*)cell.accessoryView).on = _playthrough != nil;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(playthroughSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
                case 1: {
                    cell.textLabel.text = @"Channels";
                    
                    NSInteger channelCount = _audioController.numberOfInputChannels;
                    CGSize buttonSize = CGSizeMake(30, 30);
                    
                    UIScrollView *channelStrip = [[UIScrollView alloc] initWithFrame:CGRectMake(0,
                                                                                                 0,
                                                                                                 MIN(channelCount * (buttonSize.width+5) + 5,
                                                                                                     isiPad ? 400 : 200),
                                                                                                 cell.bounds.size.height)];
                    channelStrip.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
                    channelStrip.backgroundColor = [UIColor clearColor];
                    
                    for (int i=0; i<channelCount; i++) {
                        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                        button.frame = CGRectMake(i*(buttonSize.width+5), round((channelStrip.bounds.size.height-buttonSize.height)/2), buttonSize.width, buttonSize.height);
                        [button setTitle:[NSString stringWithFormat:@"%d", i+1] forState:UIControlStateNormal];
                        button.highlighted = [_audioController.inputChannelSelection containsObject:[NSNumber numberWithInt:i]];
                        button.tag = i;
                        [button addTarget:self action:@selector(channelButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                        [channelStrip addSubview:button];
                    }
                    channelStrip.contentSize = CGSizeMake(channelCount * (buttonSize.width+5) + 5, channelStrip.bounds.size.height);
                    cell.accessoryView = channelStrip;
                    
                    break;
                }
            }
            break;
        }
    }
    return cell;
}

- (void)loopSwitchChanged:(UISwitch*)sender {
    AEAudioFilePlayer *loop = self.loopArray[sender.tag];
    loop.currentTime = 0.0f;
    loop.channelIsMuted = !sender.isOn;
}

- (void)loopVolumeChanged:(UISlider*)sender {
    AEAudioFilePlayer *loop = self.loopArray[sender.tag];
    loop.volume = sender.value;
}

- (void)loop1SwitchChanged:(UISwitch*)sender {
    _loop1.channelIsMuted = !sender.isOn;
}

- (void)loop1VolumeChanged:(UISlider*)sender {
    _loop1.volume = sender.value;
}

- (void)loop2SwitchChanged:(UISwitch*)sender {
    _loop2.channelIsMuted = !sender.isOn;
}

- (void)loop2VolumeChanged:(UISlider*)sender {
    _loop2.volume = sender.value;
}

- (void)oscillatorSwitchChanged:(UISwitch*)sender {
    _oscillator.channelIsMuted = !sender.isOn;
}

- (void)oscillatorVolumeChanged:(UISlider*)sender {
    _oscillator.volume = sender.value;
}

- (void)channelGroupSwitchChanged:(UISwitch*)sender {
    [_audioController setMuted:!sender.isOn forChannelGroup:_group];
}

- (void)channelGroupVolumeChanged:(UISlider*)sender {
    [_audioController setVolume:sender.value forChannelGroup:_group];
}

- (void)oneshotPlayButtonPressed:(UIButton*)sender {
    if ( _oneshot ) {
        [_audioController removeChannels:[NSArray arrayWithObject:_oneshot]];
        self.oneshot = nil;
        _oneshotButton.selected = NO;
    } else {
        self.oneshot = [AEAudioFilePlayer audioFilePlayerWithURL:[[NSBundle mainBundle] URLForResource:@"Organ Run" withExtension:@"m4a"]
                                                 audioController:_audioController
                                                           error:NULL];
        _oneshot.removeUponFinish = YES;
        __weak typeof(self) weakSelf = self;
        _oneshot.completionBlock = ^{
            __strong typeof(weakSelf) self = weakSelf;
            self.oneshot = nil;
            self.oneshotButton.selected = NO;
        };
        [_audioController addChannels:[NSArray arrayWithObject:_oneshot]];
        _oneshotButton.selected = YES;
    }
}

- (void)oneshotAudioUnitPlayButtonPressed:(UIButton*)sender {
    if ( !_audioUnitFile ) {
        NSURL *playerFile = [[NSBundle mainBundle] URLForResource:@"Organ Run" withExtension:@"m4a"];

        checkResult(AudioFileOpenURL((__bridge CFURLRef)playerFile, kAudioFileReadPermission, 0, &_audioUnitFile), "AudioFileOpenURL");
    }
    
    // Set the file to play
    checkResult(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &_audioUnitFile, sizeof(_audioUnitFile)),
                "AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileIDs)");
    
    // Determine file properties
    UInt64 packetCount;
    UInt32 size = sizeof(packetCount);
    checkResult(AudioFileGetProperty(_audioUnitFile, kAudioFilePropertyAudioDataPacketCount, &size, &packetCount),
                "AudioFileGetProperty(kAudioFilePropertyAudioDataPacketCount)");
    
    AudioStreamBasicDescription dataFormat;
    size = sizeof(dataFormat);
    checkResult(AudioFileGetProperty(_audioUnitFile, kAudioFilePropertyDataFormat, &size, &dataFormat),
                "AudioFileGetProperty(kAudioFilePropertyDataFormat)");
    
    // Assign the region to play
    ScheduledAudioFileRegion region;
    memset (&region.mTimeStamp, 0, sizeof(region.mTimeStamp));
    region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    region.mTimeStamp.mSampleTime = 0;
    region.mCompletionProc = NULL;
    region.mCompletionProcUserData = NULL;
    region.mAudioFile = _audioUnitFile;
    region.mLoopCount = 0;
    region.mStartFrame = 0;
    region.mFramesToPlay = (UInt32)packetCount * dataFormat.mFramesPerPacket;
    checkResult(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(region)),
                "AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileRegion)");
    
    // Prime the player by reading some frames from disk
    UInt32 defaultNumberOfFrames = 0;
    checkResult(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultNumberOfFrames, sizeof(defaultNumberOfFrames)),
                "AudioUnitSetProperty(kAudioUnitProperty_ScheduledFilePrime)");
    
    // Set the start time (now = -1)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    checkResult(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)),
                "AudioUnitSetProperty(kAudioUnitProperty_ScheduleStartTimeStamp)");
    
}

- (void)playthroughSwitchChanged:(UISwitch*)sender {
    if (sender.isOn) {
        [self turnOnVoice];
    } else {
        [self turnOffVoice];
    }
}
// 开关实时播放录音
- (void)turnOnVoice {
    self.playthrough = [[AEPlaythroughChannel alloc] initWithAudioController:_audioController];
    [_audioController addInputReceiver:_playthrough];
    [_audioController addChannels:[NSArray arrayWithObject:_playthrough]];
}

- (void)turnOffVoice {
    if (self.playthrough == nil) {
        return;
    }
    [_audioController removeChannels:[NSArray arrayWithObject:_playthrough]];
    [_audioController removeInputReceiver:_playthrough];
    self.playthrough = nil;
}

- (BOOL)isHeadsetPluggedIn {
    AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [route outputs]) {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones])
            return YES;
    }
    return NO;
}

- (void)limiterSwitchChanged:(UISwitch*)sender {
    if ( sender.isOn ) {
        self.limiter = [[AELimiterFilter alloc] initWithAudioController:_audioController];
        _limiter.level = 0.1;
        [_audioController addFilter:_limiter];
    } else {
        [_audioController removeFilter:_limiter];
        self.limiter = nil;
    }
}

- (void)expanderSwitchChanged:(UISwitch*)sender {
    if ( sender.isOn ) {
        self.expander = [[AEExpanderFilter alloc] initWithAudioController:_audioController];
        [_audioController addFilter:_expander];
    } else {
        [_audioController removeFilter:_expander];
        self.expander = nil;
    }
}

- (void)reverbSwitchChanged:(UISwitch*)sender {
    if ( sender.isOn ) {
        self.reverb = [[AEAudioUnitFilter alloc] initWithComponentDescription:AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Effect, kAudioUnitSubType_Reverb2) audioController:_audioController error:NULL];
        
        AudioUnitSetParameter(_reverb.audioUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, 100.f, 0);
        
        [_audioController addFilter:_reverb];
    } else {
        [_audioController removeFilter:_reverb];
        self.reverb = nil;
    }
}

- (void)channelButtonPressed:(UIButton*)sender {
    BOOL selected = [_audioController.inputChannelSelection containsObject:[NSNumber numberWithInt:sender.tag]];
    selected = !selected;
    if ( selected ) {
        _audioController.inputChannelSelection = [[_audioController.inputChannelSelection arrayByAddingObject:[NSNumber numberWithInt:sender.tag]] sortedArrayUsingSelector:@selector(compare:)];
        [self performSelector:@selector(highlightButtonDelayed:) withObject:sender afterDelay:0.01];
    } else {
        NSMutableArray *channels = [_audioController.inputChannelSelection mutableCopy];
        [channels removeObject:[NSNumber numberWithInt:sender.tag]];
        _audioController.inputChannelSelection = channels;
        sender.highlighted = NO;
    }
}

- (void)highlightButtonDelayed:(UIButton*)button {
    button.highlighted = YES;
}

- (void)record:(id)sender {
    if ( _recorder ) {
        [self turnOffVoice];
        [_recorder finishRecording];
        [_audioController removeOutputReceiver:_recorder];
        [_audioController removeInputReceiver:_recorder];
        self.recorder = nil;
        _recordButton.selected = NO;
    } else {
        if ([self isHeadsetPluggedIn]) {
            [self turnOnVoice];
        } else {
            [self turnOffVoice];
        }

        self.recorder = [[AERecorder alloc] initWithAudioController:_audioController];
        NSArray *documentsFolders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [[documentsFolders objectAtIndex:0] stringByAppendingPathComponent:@"Recording.aiff"];
        NSError *error = nil;
        if ( ![_recorder beginRecordingToFileAtPath:path fileType:kAudioFileAIFFType error:&error] ) {
            [[[UIAlertView alloc] initWithTitle:@"Error"
                                         message:[NSString stringWithFormat:@"Couldn't start recording: %@", [error localizedDescription]]
                                        delegate:nil
                               cancelButtonTitle:nil
                               otherButtonTitles:@"OK", nil] show];
            self.recorder = nil;
            return;
        }
        
        _recordButton.selected = YES;
        
        [_audioController addOutputReceiver:_recorder];
        [_audioController addInputReceiver:_recorder];
    }
}

- (void)play:(id)sender {
    if ( _player ) {
        [_audioController removeChannels:[NSArray arrayWithObject:_player]];
        self.player = nil;
        _playButton.selected = NO;
    } else {
        NSArray *documentsFolders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [[documentsFolders objectAtIndex:0] stringByAppendingPathComponent:@"Recording.aiff"];
        
        NSLog(@"%@", path);
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:path] ) return;
        
        NSError *error = nil;
        self.player = [AEAudioFilePlayer audioFilePlayerWithURL:[NSURL fileURLWithPath:path] audioController:_audioController error:&error];
        
        if (!_player) {
            [[[UIAlertView alloc] initWithTitle:@"Error"
                                         message:[NSString stringWithFormat:@"Couldn't start playback: %@", [error localizedDescription]]
                                        delegate:nil
                               cancelButtonTitle:nil
                               otherButtonTitles:@"OK", nil] show];
            return;
        }
        
        _player.removeUponFinish = YES;
        __weak typeof(self) weakSelf = self;
        _player.completionBlock = ^{
            __strong typeof(weakSelf) self = weakSelf;
            self.playButton.selected = NO;
            self.player = nil;
        };
        [_audioController addChannels:[NSArray arrayWithObject:_player]];
        
        _playButton.selected = YES;
    }
}

static inline float translate(float val, float min, float max) {
    if (val < min) val = min;
    if (val > max) val = max;
    return (val - min) / (max - min);
}

- (void)updateLevels:(NSTimer*)timer {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    Float32 inputAvg, inputPeak, outputAvg, outputPeak;
    [_audioController inputAveragePowerLevel:&inputAvg peakHoldLevel:&inputPeak];
    [_audioController outputAveragePowerLevel:&outputAvg peakHoldLevel:&outputPeak];
    UIView *headerView = self.tableView.tableHeaderView;
    
    _inputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0 - 5.0 - (translate(inputAvg, -20, 0) * (headerView.bounds.size.width/2.0 - 15.0)),
                                        90,
                                        translate(inputAvg, -20, 0) * (headerView.bounds.size.width/2.0 - 15.0),
                                        10);
    
    _outputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0,
                                         _outputLevelLayer.frame.origin.y,
                                         translate(outputAvg, -20, 0) * (headerView.bounds.size.width/2.0 - 15.0),
                                         10);
    
    [CATransaction commit];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
//    if ( context == &kInputChannelsChangedContext ) {
//        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
//    }

        if ([keyPath isEqualToString:@"currentTime"]) {
            NSLog(@"%@", object);
        }
    
}

@end
