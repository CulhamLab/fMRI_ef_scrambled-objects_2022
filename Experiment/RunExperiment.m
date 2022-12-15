%RunExperiment(type,par,run)
%
%Important Note:
%   If you change parameters, run "ClearGlobal" to ensure that loading uses
%   the new settings.
%
function RunExperiment(par,run)

%% Test Arguments - delete later

%% Uncomment this only if the screen won't start even after "clear all" and "close all" (visual presentation timing will not be good)
% Screen('Preference', 'SkipSyncTests', 1);


%% Check PsychToolbox
AssertOpenGL();


%% Inputs and Type-Specific Parameters
if ~exist('run','var')
    error(sprintf('%s\nToo few inputs!',help(mfilename)))
end
% type = upper(type);
% type = 'PILOT';
% switch type
%     case 'PILOT'
        p.DURATION.IMAGE_PRESENTATION_SECONDS = 4;
%         p.SCREEN.BACKGROUND_COLOUR = [0 0 0];
%         p.SCREEN.TEXT_COLOUR = [255 255 255];
        p.SCREEN.BACKGROUND_COLOUR = [128 128 128];
        p.SCREEN.TEXT_COLOUR = [0 0 0];
        p.FIXATION.LEFT_VIEW.ADJUST_X = -0;
        p.FIXATION.LEFT_VIEW.ADJUST_Y = -75;
        p.FIXATION.RIGHT_VIEW.ADJUST_X = -0;
        p.FIXATION.RIGHT_VIEW.ADJUST_Y = -75;
        p.VIDEOS.VERTICAL_SHIFT = -130; %number of PIXELS, positive is down, negative is up
        p.IMAGES.VERTICAL_SHIFT = -130; %number of PIXELS, positive is down, negative is up
%     otherwise
%         error('Unknown type!');
% end


%% Parameters - General

%debug is for testing without the projector
p.DEBUG = true;

%TR in seconds
p.TR = 1;

%paths
p.PATH.ORDERS_FOLDER = [pwd filesep 'Orders' filesep];
p.PATH.DATA_FOLDER = [pwd filesep 'Data' filesep];
p.PATH.IMAGE = [pwd filesep 'Images' filesep];
p.PATH.ORDER = [p.PATH.ORDERS_FOLDER sprintf('PAR%02d_RUN%02d.xls*',par,run)];
p.PATH.DATA = [p.PATH.DATA_FOLDER sprintf('PAR%02d_RUN%02d_%s',par,run,get_timestamp)];

%trigger checking
p.TRIGGER.TIME_BEFORE_TRIGGER_MUST_START_LOOKING_SEC = 0.005; %0.017; %should be less than TR
p.TRIGGER.TIME_BEFORE_TRIGGER_CAN_START_LOOKING_SEC = 0.500;
p.TRIGGER.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC = 0.005;

%misc
KbName('UnifyKeyNames');
p.KEY.STOP = KbName('ESCAPE'); %ESC key
p.KEY.TRIGGER = KbName({'5%' 't'}); %5 and/or T
p.KEY.BUTTON_BOX = KbName({'1!' '2@' '3#' '4$' 'r' 'g' 'b' 'y' '1' '2' '3' '4'}); %1-4 top of key board, rgby, 1-4 numpad

%screen
p.SCREEN.NUMBER = max(Screen('Screens'));
p.SCREEN.RECT = []; %[0 0 1920 1080];
p.SCREEN.EXPECTED_SIZE = [1080 1920]; %[height width]

%stereo
p.SCREEN.STEREO_MODE = 1; %1 or 11 for shutter glasses (1 seems to work better)
p.SCREEN.PIPELINE_MODE = kPsychNeedFastBackingStore; %kPsychNeedFastBackingStore seems to work well
p.SCREEN.BUFFER_ID.LEFT = 1; %flip these if L/R is reversed
p.SCREEN.BUFFER_ID.RIGHT = 0;

%image
p.IMAGES.OFFSET_FOR_MOTION = 50; %Offset from center for the motion (in pixels). If this value is x, then a Left motion would start +1x from center and move to -1x from center during its display time (i.e., a movement of 2x to the left)
p.IMAGES.FLIP_HORIZONTAL = true;
p.IMAGES.HEIGHT = 1080; %images are resized to have this height

%video
p.VIDEOS.MEMORY_SAVING_FACTOR = 0.4;   %ratio of frame size to store
                                        %1 = full quality, no loss of quality or change to processing requiremnets
                                        %0<x<1 = less memory used, but reduces image quality and increases processing requirements (may impact display frame rate)
                                        %e.g., 0.75 means stored at 75% quality and then resized to original for display

p.VIDEOS.EXPECTED_FRAME_RATE = 60;
p.VIDEOS.EXPECTED_RESOLUTION = [1080 3840];
p.VIDEOS.FRAMES_ORDER_MIRRORED = true; %if true, only the first half of frames are stored and later frames are assumed to mirror back to the starting frame
p.VIDEOS.FLIP_HORIZONTAL = true;

%fixation
p.FIXATION.SHOW = true;
p.FIXATION.FILEPATH = 'fixation_transparent.png';
p.FIXATION.SIZE = [30 30];
p.FIXATION.TRANSPARENCY_CUTOFF = 240;

%misc
p.MISC.CONDITIONS_WITH_UNLIMITED_DISPLAY_DURATION = {'CUE' 'Null'};


%% Prepare

%make future calls faster
GetSecs;
KbCheck;

%create data folder if needed
if ~exist(p.PATH.DATA_FOLDER), mkdir(p.PATH.DATA_FOLDER);, end

%store git repo info
if exist('IsGitRepo','file') && ~IsGitRepo
    warning('This project does not appear to be part of a git repository. No git data will be saved.');
elseif exist('GetGitInfo','file')
    d.GitInfo = GetGitInfo;
else
    warning('The "CulhamLab/Git-Version" repo has not been configured. Information about this project''s current repository status (version, etc.) will NOT be saved to the data file.');
end


%% load everything

%order
list = dir(p.PATH.ORDER);
if isempty(list)
    error('Could not locate order file: %s', p.PATH.ORDER)
elseif length(list)>1
    error('Multiple matches for order file: %s', p.PATH.ORDER);
else
    p.PATH.ORDER = [list.folder filesep list.name];
end
d.order = readtable(p.PATH.ORDER);

% %fix caps
% d.order.Format(strcmpi(d.order.Format, 'image')) = {'Image'};
% d.order.Format(strcmpi(d.order.Format, 'video')) = {'Video'};
% d.order.Motion(strcmpi(d.order.Motion, 'left')) = {'Left'};
% d.order.Motion(strcmpi(d.order.Motion, 'right')) = {'Right'};
% d.order.Condition(strcmpi(d.order.Condition, 'NULL')) = {'NULL'};
% d.order.Format(strcmpi(d.order.Condition, 'NULL')) = {'NULL'};

% %sliding positions
% file = load('SlidingPositions.mat');
% d.sliding_positions = file.sliding;
% d.sliding_positions.Left.Position = d.sliding_positions.Left.Position * p.IMAGES.OFFSET_FOR_MOTION;
% d.sliding_positions.Right.Position = d.sliding_positions.Right.Position * p.IMAGES.OFFSET_FOR_MOTION;

%fixation
LoadFixation(p)

%images
LoadImages(p,d)

%video
LoadVideos(p,d)

fprintf('Done loading stims.\n');

%global
global g


%% Create Event Schedule

%check all times divisible by TR
if any(mod(d.order.Duration_Seconds, p.TR) ~= 0)
    error('One or more event durations is not evenly divisibly by the TR')
end

%count volumes
d.total_sec = sum(d.order.Duration_Seconds);
d.total_vol = d.total_sec / p.TR;

%initialize
name_types = {
                'Volume' 'single'
                'Trial' 'single'
                'Condition' 'string'
                'DisplayEvent' 'single'
                'TimeStartEffective' 'double'
                'TimeStartActual' 'double'
                'TimeEnd' 'double'
                'DurationActual' 'double'
                'DurationEffective' 'double'
                'ReceivedTrigger' 'logical'
                'ButtonPress' 'logical'
                'ButtonPressTime' 'double'
                };
d.vol_events = table('Size',[d.total_vol size(name_types,1)],'VariableNames',name_types(:,1),'VariableTypes',name_types(:,2));
d.vol_events.Volume = (1:d.total_vol)';
d.vol_events.Trial(:) = nan;
d.vol_events.DisplayEvent(:) = nan;
d.vol_events.TimeStartEffective(:) = nan;
d.vol_events.TimeStartActual(:) = nan;
d.vol_events.TimeEnd(:) = nan;
d.vol_events.DurationActual(:) = nan;
d.vol_events.DurationEffective(:) = nan;
d.vol_events.ReceivedTrigger(:) = false;
d.vol_events.ButtonPress(:) = false;
d.vol_events.ButtonPressTime(:) = nan;

%init table for DisplayEvents
name_types = {
                'TimeInEvent' 'double'
                'TimeDisplayedActual' 'double'
                'TimeInEventDisplayed' 'double'
                'VolDisplayed' 'single'
                'TimeInVolDisplayed' 'double'
                'Format' 'string'
                'Fixation' 'logical'
                
                'LeftSourceName' 'string'
                'LeftSourceIndex' 'single'
                'LeftSourceSubindex' 'single'
                'LeftShiftX' 'double'
                'LeftShiftY' 'double'
                
                'RightSourceName' 'string'
                'RightSourceIndex' 'single'
                'RightSourceSubindex' 'single'
                'RightShiftX' 'double'
                'RightShiftY' 'double'
                };
template_display_event = table('Size',[1 size(name_types,1)],'VariableNames',name_types(:,1),'VariableTypes',name_types(:,2));
template_display_event.TimeDisplayedActual = nan;
template_display_event.TimeInEventDisplayed = nan;
template_display_event.VolDisplayed = nan;
template_display_event.TimeInVolDisplayed = nan;

%init display events
name_types = {
                'EventID' 'double'
                'Trial' 'single'
                'Condition' 'string'
                'Events' 'cell'
                };
d.display_events = table('Size',[height(d.order) size(name_types,1)],'VariableNames',name_types(:,1),'VariableTypes',name_types(:,2));
d.display_events.EventID = (1:height(d.order))';

%add events from order
vol = 0;
for e = 1:height(d.order)
    nvol = d.order.Duration_Seconds(e) / p.TR;

    %fill in volume events
    for v = 1:nvol
        vol = vol+1;
        
        %trial
        d.vol_events.Trial(vol) = d.order.Trial(e);
        
        %condition
        d.vol_events.Condition{vol} = d.order.Condition{e};
        
        %display event
        d.vol_events.DisplayEvent(vol) = e;
    end
    
    %has fixation?
    switch lower(d.order.Fixation{e})
        case 'on'
            fixation = true;
        case 'off'
            fixation = false;
        otherwise
            error
    end
    
    %define the display event
    tbl = template_display_event;
    tbl.Fixation = fixation;
    if strcmpi(d.order.Format{e},'NULL')
        tbl.Format = 'NULL';
    elseif strcmpi(d.order.Format{e},'image')
        if ~iscell(d.order.Motion) || isempty(d.order.Motion{e})
            %static...
            
            %limited duration?
            if p.DURATION.IMAGE_PRESENTATION_SECONDS < d.order.Duration_Seconds(e)
                tbl = repmat(tbl, [2 1]);
                tbl.Format{2} = 'NULL';
                tbl.TimeInEvent(2) = p.DURATION.IMAGE_PRESENTATION_SECONDS;
            end
            
            tbl.Format{1} = 'Image';
            
            %left
            tbl.LeftSourceName{1} = d.order.Filename_left{e};
            ind = find(strcmp(g.images.filenames, tbl.LeftSourceName{1}));
            if length(ind)~=1, error; end
            tbl.LeftSourceIndex(1) = ind;
            tbl.LeftShiftY = p.IMAGES.VERTICAL_SHIFT;
            
            %right
            tbl.RightSourceName{1} = d.order.Filename_right{e};
            ind = find(strcmp(g.images.filenames, tbl.RightSourceName{1}));
            if length(ind)~=1, error; end
            tbl.RightSourceIndex(1) = ind;
            tbl.RightShiftY = p.IMAGES.VERTICAL_SHIFT;
        else
            %translation...
            switch lower(d.order.Motion{e})
                case 'left'
                    slide = d.sliding_positions.Left;
                case 'right'
                    slide = d.sliding_positions.Right;
                otherwise
                    error
            end
            
            tbl.Format{1} = 'Image';
            
            %left
            tbl.LeftSourceName{1} = d.order.Filename_left{e};
            ind = find(strcmp(g.images.filenames, tbl.LeftSourceName{1}));
            if length(ind)~=1, error; end
            tbl.LeftSourceIndex(1) = ind;
            tbl.LeftShiftY = p.IMAGES.VERTICAL_SHIFT;
            
            %right
            tbl.RightSourceName{1} = d.order.Filename_right{e};
            ind = find(strcmp(g.images.filenames, tbl.RightSourceName{1}));
            if length(ind)~=1, error; end
            tbl.RightSourceIndex(1) = ind;
            tbl.RightShiftY = p.IMAGES.VERTICAL_SHIFT;
            
            %positions
            tbl = repmat(tbl, [height(slide) 1]);
            tbl.TimeInEvent = slide.Time;
            tbl.LeftShiftX = tbl.LeftShiftX + slide.Position;
            tbl.RightShiftX = tbl.RightShiftX + slide.Position;
            
            %null after
            row = height(tbl)+1;
            t = mean(diff(tbl.TimeInEvent));
            tbl(row,:) = template_display_event;
            tbl.Format{row} = 'NULL';
            tbl.Fixation(row) = fixation;
            tbl.TimeInEvent(row) = tbl.TimeInEvent(row-1) + t;
        end
    elseif strcmpi(d.order.Format{e},'video')
            tbl.Format{1} = 'Video';
            
            %left
            tbl.LeftSourceName{1} = d.order.Filename_left{e};
            ind = find(strcmp(g.videos.filenames, tbl.LeftSourceName{1}));
            if length(ind)~=1, error; end
            tbl.LeftSourceIndex(1) = ind;
            tbl.LeftShiftY = p.VIDEOS.VERTICAL_SHIFT;
            
            %right
            tbl.RightSourceName{1} = d.order.Filename_left{e}; %video uses left for both, video has both views
            ind = find(strcmp(g.videos.filenames, tbl.RightSourceName{1}));
            if length(ind)~=1, error; end
            tbl.RightSourceIndex(1) = ind;
            tbl.RightShiftY = p.VIDEOS.VERTICAL_SHIFT;
            
            %time
            frame_time = 1 / g.videos.vid(ind).FrameRate;
            times = 0 : frame_time : (g.videos.vid(ind).NumberFrames - 1)*frame_time;
            
            %frames
            frames = 1 : g.videos.vid(ind).NumberFrames;
            if g.videos.vid(ind).MirroredFrames
                m = (g.videos.vid(ind).NumberFrames+1) / 2;
                frames = ceil(m - abs(m - frames));
            end
            
            %put together
            tbl = repmat(tbl, [g.videos.vid(ind).NumberFrames 1]);
            tbl.TimeInEvent = times';
            tbl.LeftSourceSubindex = frames';
            tbl.RightSourceSubindex = frames';
            
%             %half framerate
%             tbl = tbl(1:2:end,:);
            
            %null after
            row = height(tbl)+1;
            t = mean(diff(tbl.TimeInEvent));
            tbl(row,:) = template_display_event;
            tbl.Format{row} = 'NULL';
            tbl.Fixation(row) = fixation;
            tbl.TimeInEvent(row) = tbl.TimeInEvent(row-1) + t;
    else
        error
    end
    
    %set display event
    d.display_events.Trial(e) = d.order.Trial(e);
    d.display_events.Condition{e} = d.order.Condition{e};
    d.display_events.Events{e} = tbl;
end

%% Try
try

%% Enable PROPixx RB3D Sequencer
if ~p.DEBUG
    Datapixx('Open'); 
    Datapixx('EnableVideoStereoBlueline');
end
    
%% Open Screen
for attempt = 1:5
    try
        [s.win, s.rect] = Screen('OpenWindow', p.SCREEN.NUMBER, p.SCREEN.BACKGROUND_COLOUR, p.SCREEN.RECT, [], [], p.SCREEN.STEREO_MODE, [], p.SCREEN.PIPELINE_MODE);
        HideCursor;
        break;
    catch err
        if attempt < 5
            WaitSecs(0.5);
        else
            warning('Failed to open screen 5 times')
            rethrow(err)
        end
    end
end
if s.rect(1)~=0 || s.rect(2)~=0 || s.rect(3)~=p.SCREEN.EXPECTED_SIZE(2) || s.rect(4)~=p.SCREEN.EXPECTED_SIZE(1)
    error('Unexpected screen size! [%s]',num2str(s.rect))
end

s.width = s.rect(3);
s.height = s.rect(4);
s.center = [s.width/2 s.height/2];

%fixation rect
rect = [-1 -1 +1 +1] .* [p.FIXATION.SIZE p.FIXATION.SIZE]/2;
rect = rect + [s.center s.center];
s.rect_left = rect + [p.FIXATION.LEFT_VIEW.ADJUST_X p.FIXATION.LEFT_VIEW.ADJUST_Y p.FIXATION.LEFT_VIEW.ADJUST_X p.FIXATION.LEFT_VIEW.ADJUST_Y];
s.rect_right = rect + [p.FIXATION.RIGHT_VIEW.ADJUST_X p.FIXATION.RIGHT_VIEW.ADJUST_Y p.FIXATION.RIGHT_VIEW.ADJUST_X p.FIXATION.RIGHT_VIEW.ADJUST_Y];


%% Set GPU CLUTs to linear
Screen('LoadNormalizedGammaTable', s.win, linspace(0,1,256)'*[1,1,1]);
Screen('BlendFunction', s.win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');


%% Prepare Images
g.fixation.texture = Screen('MakeTexture', s.win, g.fixation.img);

msg = 'Preparing textures...';

Screen('TextSize', s.win, 80);
Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.LEFT);
DrawFormattedText(s.win, 'LEFT EYE', s.width/2 - 525, 'center', p.SCREEN.TEXT_COLOUR);
DrawFormattedText(s.win, msg, 'center', 80, p.SCREEN.TEXT_COLOUR);
Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.RIGHT);
DrawFormattedText(s.win, 'RIGHT EYE', s.width/2 + 150, 'center', p.SCREEN.TEXT_COLOUR);
DrawFormattedText(s.win, msg, 'center', 80, p.SCREEN.TEXT_COLOUR);
if d.display_events.Events{1}.Fixation(1)
    DrawFixation(p,s)
end
Screen('flip', s.win);

for i = 1:length(g.images.img)
    g.images.texture(i) = Screen('MakeTexture', s.win, g.images.img{i});
end

%video textures per frame
for i = 1:length(g.videos.vid)
    g.videos.vid(i).LeftTextures = nan(1, g.videos.vid(i).NumberFramesStored);
    g.videos.vid(i).RightTextures = nan(1, g.videos.vid(i).NumberFramesStored);
    
    for frame = 1:g.videos.vid(i).NumberFramesStored
        g.videos.vid(i).LeftTextures(frame) = Screen('MakeTexture', s.win, g.videos.vid(i).Left(:,:,:,frame));
        g.videos.vid(i).RightTextures(frame) = Screen('MakeTexture', s.win, g.videos.vid(i).Right(:,:,:,frame));
    end
end

%% 3D Test Image
msg = sprintf('Waiting for trigger (%d volumes, %g sec)', d.total_vol, d.total_sec);

Screen('TextSize', s.win, 80);
Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.LEFT);
DrawFormattedText(s.win, 'LEFT EYE', s.width/2 - 525, 'center', p.SCREEN.TEXT_COLOUR);
DrawFormattedText(s.win, msg, 'center', 80, p.SCREEN.TEXT_COLOUR);
Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.RIGHT);
DrawFormattedText(s.win, 'RIGHT EYE', s.width/2 + 150, 'center', p.SCREEN.TEXT_COLOUR);
DrawFormattedText(s.win, msg, 'center', 80, p.SCREEN.TEXT_COLOUR);

if d.display_events.Events{1}.Fixation(1)
    DrawFixation(p,s)
end

Screen('flip', s.win);


%% Wait First Trigger

%make sure nothing is pressed currently
while KbCheck, end

%wait for first trigger
while 1
    %%%KbWait; %more efficient way to wait for a key - caused problems
    [keyIsDown, ~, keyCode] = KbCheck(-1); %get key(s)
    if keyIsDown
        if any(keyCode(p.KEY.TRIGGER))
            t0 = GetSecs;
            break
        elseif any(keyCode(p.KEY.STOP))
            error('Stop key was pressed.')
        end
    end
end
d.t0 = t0;

%% Run Volume Events
evt = nan;
vol_start = 1;
for v = vol_start:d.total_vol
    %volume start time actual
    if v==vol_start
        d.vol_events.TimeStartActual(v) = 0;
    else
        d.vol_events.TimeStartActual(v) = GetSecs - t0;
    end
    
    %volume start time
    if v==vol_start || d.vol_events.ReceivedTrigger(v-1) %is first vol OR prior vol recieved trigger
        d.vol_events.TimeStartEffective(v) = d.vol_events.TimeStartActual(v); %use actual time
    else %missed a trigger
        d.vol_events.TimeStartEffective(v) = d.vol_events.TimeStartEffective(v-1) + p.TR; %use expected trigger time
    end
    
    %event?
    if evt ~= d.vol_events.DisplayEvent(v)
        evt = d.vol_events.DisplayEvent(v);
        time_event_start = d.vol_events.TimeStartEffective(v);
    end
    
    %start message
    fprintf('\nStarting volume %d/%d at %fsec (actual %fsec):\n',v,d.total_vol,d.vol_events.TimeStartEffective(v),d.vol_events.TimeStartActual(v));
    fprintf('\tCondition: %s\n', d.vol_events.Condition{v});
    
    %volume events
    saved = false;
    while 1
        time_in_vol = (GetSecs-t0) - d.vol_events.TimeStartEffective(v);
        
        %overdue for trigger?
        if time_in_vol>(p.TR+p.TRIGGER.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC)
            warning('No trigger was recieved. Continuing with expected timing...')
            break
        end
        
        %look for trigger or button press
        [keyIsDown, ~, keyCode] = KbCheck(-1); %get key(s)
        if keyIsDown
            if any(keyCode(p.KEY.TRIGGER))
                if time_in_vol > p.TRIGGER.TIME_BEFORE_TRIGGER_CAN_START_LOOKING_SEC
                    d.vol_events.ReceivedTrigger(v) = true;
                    fprintf('~~~~~~~~~~~~~~~~~TRIGGER RECIEVED~~~~~~~~~~~~~~~~~\n')
                    break
                end
            elseif any(keyCode(p.KEY.STOP))
                error('Stop key was pressed.') 
            elseif ~d.vol_events.ButtonPress(v) && any(keyCode(p.KEY.BUTTON_BOX))
                d.vol_events.ButtonPress(v) = true;
                d.vol_events.ButtonPressTime(v) = time_in_vol;
                fprintf('-Button Box\n');
            end
        end
        
        %can do display?
        if time_in_vol < (p.TR - p.TRIGGER.TIME_BEFORE_TRIGGER_MUST_START_LOOKING_SEC)
        
            %display
            time_in_event = (GetSecs-t0) - time_event_start;
            ind = find(d.display_events.Events{evt}.TimeInEvent < time_in_event, 1, 'last');
            if isnan(d.display_events.Events{evt}.TimeInEventDisplayed(ind))
                %display this event
                DisplayEvent(p,s,d.display_events.Events{evt}(ind,:))

                %timing
                d.display_events.Events{evt}.TimeDisplayedActual(ind) = GetSecs;
                d.display_events.Events{evt}.TimeInEventDisplayed(ind) = time_in_event;
                d.display_events.Events{evt}.VolDisplayed(ind) = v;
                d.display_events.Events{evt}.TimeInVolDisplayed(ind) = time_in_vol;
            elseif ~saved && (time_in_vol < (p.TR/2))
                %save
                saved = true;
                save(p.PATH.DATA,'d','p','s')
                fprintf('-Saved\n');
            end
        end
        
    end
    
    %end of volume timing
    d.vol_events.TimeEnd(v) = GetSecs-t0;
    d.vol_events.DurationEffective(v) = d.vol_events.TimeEnd(v) - d.vol_events.TimeStartEffective(v);
    d.vol_events.DurationActual(v) = d.vol_events.TimeEnd(v) - d.vol_events.TimeStartActual(v);
    fprintf('-duration: %f seconds\n',d.vol_events.DurationEffective(v))
    
end



%% End
sca
sca
ShowCursor;
save([p.PATH.DATA '_COMPLETE'],'d','p','s')

%PROPixx complete
if ~p.DEBUG
    % Set the PROPixx back to normal sequencer
    Datapixx('SetPropixxDlpSequenceProgram', 0);
    Datapixx('RegWrRd');

    % Close PROPixx connection
    Datapixx('Close');
end

disp Complete!

%% Catch
catch err
    %TODO
    sca
    sca
    ShowCursor;
    clear g
    save([p.PATH.DATA '_ERROR'])
    
    %PROPixx complete
    if ~p.DEBUG
        % Set the PROPixx back to normal sequencer
        Datapixx('SetPropixxDlpSequenceProgram', 0);
        Datapixx('RegWrRd');
        
        % Close PROPixx connection
        Datapixx('Close');
    end
    
    rethrow(err)
end


%% Subfunctions...

function [timestamp] = get_timestamp
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));

function LoadFixation(p)
global g
[g.fixation.img,~,alpha] = imread(p.FIXATION.FILEPATH);
g.fixation.img = imresize(g.fixation.img, p.FIXATION.SIZE);
alpha = (imresize(alpha, p.FIXATION.SIZE) > p.FIXATION.TRANSPARENCY_CUTOFF) * 255;
g.fixation.img(:,:,4) = alpha;

function LoadImages(p,d)
global g
is_img = strcmpi(d.order.Format,'Image');
filenames = unique([d.order.Filename_left(is_img); d.order.Filename_right(is_img)]);
if ~isfield(g, 'images')
    g.images.filenames = cell(0);
    g.images.img = cell(0);
end
number_files = length(filenames);
fprintf('Loading images...\n');
for fid = 1:number_files
    fn = filenames{fid};
    fprintf('\tImage %d of %d: %s\n', fid, number_files, fn);
    ind = find(strcmp(fn, g.images.filenames));
    switch length(ind)
        case 0
            %find file
            list = dir(fullfile(p.PATH.IMAGE, '**', fn));
            switch length(list)
                case 0
                    error('File not found!')
                case 1
                    fp = [list.folder filesep list.name];
                otherwise
                    %multiple matches, default to top level folder
                    fp = [p.PATH.IMAGE fn];
                    if ~exist(fp, 'file')
                        %doesn't exist in top level folder, cannot default
                        error('Multiple matches found!')
                    end
            end
            fprintf('\t\t\tLoading: %s\n', strrep(fp,pwd,'.'));
            
            %load
            ind = length(g.images.filenames) + 1;
            g.images.filenames{ind} = fn;
            [img,~,alpha] = imread(fp);
            if isempty(alpha)
                alpha = ones(size(img(:,:,1)),'uint8') * 255;
            end
            
            %apply background if transparent
            sz = size(img);
            bgd = double(repmat(reshape(p.SCREEN.BACKGROUND_COLOUR,[1 1 3]), [sz(1:2) 1]));
            alpha = repmat(double(alpha)/255, [1 1 3]);
            g.images.img{ind} = uint8((double(img) .* alpha) + (bgd .* (1-alpha)));
            
            %resize?
            h = size(g.images.img{ind},1);
            if p.IMAGES.HEIGHT ~= h
                r = p.IMAGES.HEIGHT / h;
                g.images.img{ind} = imresize(g.images.img{ind}, r);
            end
            
            %flip?
            if p.IMAGES.FLIP_HORIZONTAL
                g.images.img{ind} = g.images.img{ind}(:,end:-1:1,:);
            end
            
            %apply same quality loss as video but store at correct size
            if p.VIDEOS.MEMORY_SAVING_FACTOR < 1
                sz = size(g.images.img{ind});
                
                g.images.img{ind} = imresize(g.images.img{ind}, p.VIDEOS.MEMORY_SAVING_FACTOR);
                g.images.img{ind} = imresize(g.images.img{ind}, sz(1:2));
            end
            
        case 1
            fprintf('\t\tAlready loaded\n');
        otherwise
            error('Multiple pre-existing matches')
    end
end

function LoadVideos(p,d)
global g
is_img = strcmpi(d.order.Format,'Video');
filenames = unique(d.order.Filename_left(is_img));
if ~isfield(g, 'videos')
    g.videos.filenames = cell(0);
    g.videos.vid = [];
end
number_files = length(filenames);
fprintf('Loading video...\n');
for fid = 1:number_files
    fn = filenames{fid};
    fprintf('\tVideo %d of %d: %s\n', fid, number_files, fn);
    ind = find(strcmp(fn, g.videos.filenames));
    switch length(ind)
        case 0
            %find file
            list = dir(fullfile(p.PATH.IMAGE, '**', fn));
            switch length(list)
                case 0
                    error('File not found!')
                case 1
                    fp = [list.folder filesep list.name];
                otherwise
                    %multiple matches, default to top level folder
                    fp = [p.PATH.IMAGE fn];
                    if ~exist(fp, 'file')
                        %doesn't exist in top level folder, cannot default
                        error('Multiple matches found!')
                    end
            end
            fprintf('\t\t\tLoading: %s\n', strrep(fp,pwd,'.'));
            
            %checks
            vr = VideoReader(fp);
            if vr.FrameRate ~= p.VIDEOS.EXPECTED_FRAME_RATE
                error('Unexpected frame rate (%g)', vr.FrameRate)
            elseif (vr.Height ~= p.VIDEOS.EXPECTED_RESOLUTION(1)) || (vr.Width ~= p.VIDEOS.EXPECTED_RESOLUTION(2))
                error('Unexpected resolution (%d %d)', vr.Height, vr.Width)
            end
            
            %load
            ind = length(g.videos.filenames) + 1;
            g.videos.filenames{ind} = fn;
            g.videos.vid(ind).filenames = fn;
            g.videos.vid(ind).FrameRate = vr.FrameRate;
            g.videos.vid(ind).NumberFrames = vr.NumFrames;
            
            %if videos are mirrored, store only first half of frames
            g.videos.vid(ind).NumberFramesStored = g.videos.vid(ind).NumberFrames;
            g.videos.vid(ind).MirroredFrames = p.VIDEOS.FRAMES_ORDER_MIRRORED;
            if p.VIDEOS.FRAMES_ORDER_MIRRORED
                g.videos.vid(ind).NumberFramesStored = ceil(g.videos.vid(ind).NumberFramesStored / 2);
            end
            
            %calculate stored width/height
            m = floor(vr.Width / 2);
            w = round(m * p.VIDEOS.MEMORY_SAVING_FACTOR);
            h = round(vr.Height * p.VIDEOS.MEMORY_SAVING_FACTOR);
            
            %store size info
            g.videos.vid(ind).WidthOriginal = m;
            g.videos.vid(ind).HeightOriginal = vr.Height;
            g.videos.vid(ind).WidthStored = w;
            g.videos.vid(ind).HeightStored = h;
            g.videos.vid(ind).MemorySavingFactor = p.VIDEOS.MEMORY_SAVING_FACTOR;
            g.videos.vid(ind).RequiresResizing = (g.videos.vid(ind).MemorySavingFactor ~= 1);
            
            %init
            g.videos.vid(ind).Left = zeros(h, w, 3, g.videos.vid(ind).NumberFramesStored, 'uint8');
            g.videos.vid(ind).Right = zeros(h, w, 3, g.videos.vid(ind).NumberFramesStored, 'uint8');
            
            %processes frames one-by-one, it's slower by reduces memory requiremnt
            for f = 1:g.videos.vid(ind).NumberFramesStored
                frame = read(vr, f);
                
                %split left/right
                left = frame(:,1:m,:);
                right = frame(:,m+1:end,:);
                
                %resize for memory-saving at the cost of quality
                if g.videos.vid(ind).RequiresResizing
                    left = imresize(left, [h w]);
                    right = imresize(right, [h w]);
                end
                
                %flip
                if p.VIDEOS.FLIP_HORIZONTAL
                    left = left(:,end:-1:1,:);
                    right = right(:,end:-1:1,:);
                end
                
                %store
                g.videos.vid(ind).Left(:,:,:,f) = left;
                g.videos.vid(ind).Right(:,:,:,f) = right;
            end
        case 1
            fprintf('\t\tAlready loaded\n');
        otherwise
            error('Multiple pre-existing matches')
    end
end

function DrawFixation(p,s)
global g
Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.LEFT);
Screen('DrawTexture', s.win, g.fixation.texture, [], s.rect_left);
Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.RIGHT);
Screen('DrawTexture', s.win, g.fixation.texture, [], s.rect_right);

function DisplayEvent(p,s,info)
global g

for lr = [1 2]
    switch lr
        case 1
            Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.LEFT);
            source_index = info.LeftSourceIndex;
            source_subindex = info.LeftSourceSubindex;
            shift_x = info.LeftShiftX;
            shift_y = info.LeftShiftY;
        case 2
            Screen('SelectStereoDrawBuffer', s.win, p.SCREEN.BUFFER_ID.RIGHT);
            source_index = info.RightSourceIndex;
            source_subindex = info.RightSourceSubindex;
            shift_x = info.RightShiftX;
            shift_y = info.RightShiftY;
    end
    
    switch info.Format
        case 'NULL'
            %nothing needed
        case 'Image'
            tex = g.images.texture(source_index);
            
            sz = size(g.images.img{source_index});
            sz = sz([2 1]);
            rect = [-1 -1 +1 +1] .* [sz sz]/2;
            
            %center
            rect = rect + [s.center s.center];
            
            %shift
            rect = rect + [shift_x shift_y shift_x shift_y];
            
            Screen('DrawTexture', s.win, tex, [], rect);
            
        case 'Video'
            switch lr
                case 1
%                     img = g.videos.vid(source_index).Left(:,:,:,source_subindex);
                    tex = g.videos.vid(source_index).LeftTextures(source_subindex);
                case 2
%                     img = g.videos.vid(source_index).Right(:,:,:,source_subindex);
                    tex = g.videos.vid(source_index).RightTextures(source_subindex);
            end
            
%             if g.videos.vid(source_index).RequiresResizing
%                 img = imresize(img, [g.videos.vid(source_index).HeightOriginal g.videos.vid(source_index).WidthOriginal]);
%             end
            
%             sz = size(img);
%             sz = sz([2 1]);

            sz = [g.videos.vid(source_index).WidthOriginal g.videos.vid(source_index).HeightOriginal];
            
            rect = [-1 -1 +1 +1] .* [sz sz]/2;
            
            %center
            rect = rect + [s.center s.center];
            
            %shift
            rect = rect + [shift_x shift_y shift_x shift_y];
            
%             tex = Screen('MakeTexture', s.win, img);
            Screen('DrawTexture', s.win, tex, [], rect);
            
    end
    
    if info.Fixation
        switch lr
            case 1
                Screen('DrawTexture', s.win, g.fixation.texture, [], s.rect_left);
            case 2
                Screen('DrawTexture', s.win, g.fixation.texture, [], s.rect_right);
        end
    end
end

%fixation?
% if info.Fixation
%     DrawFixation(p,s);
% end

%draw
Screen('flip', s.win);