function RunExperiment(participant_number, run_number)

%% Check PsychToolbox
AssertOpenGL();


%% Initialize Random Number Generator
% Uses the participant and run numbers to initialize RNG. This ensures that
% "random" events (calls to rand) will be replicated if you need to repeat
% the run
rng_seed = (participant_number*100) + run_number;
rng(rng_seed);


%% Parameters - General (stored in "p" structure)

%DEBUG MODE - doesn't do anything by default but you can easily add function to it
p.DEBUG = false;
p.FIRST_VOL = 1; %use this to start partway through

%TR in seconds
p.TR = 1;

%paths
p.PATH.ORDERS_FOLDER = [pwd filesep 'Orders' filesep];
p.PATH.DATA_FOLDER = [pwd filesep 'Data' filesep];
p.PATH.ORDER = [p.PATH.ORDERS_FOLDER sprintf('PAR%02d_RUN%02d.xlsx', participant_number, run_number)];
p.PATH.DATA = [p.PATH.DATA_FOLDER sprintf('PAR%02d_RUN%02d_%s', participant_number, run_number, get_timestamp)];

%trigger checking
p.TRIGGER.TIME_BEFORE_TRIGGER_CAN_START_LOOKING_SEC = 0.500;
% p.TRIGGER.TIME_BEFORE_TRIGGER_MUST_START_LOOKING_SEC = 0.010; %not used in this implementation
p.TRIGGER.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC = 0.005;

%keys
KbName('UnifyKeyNames');
p.KEY.STOP = KbName({'ESCAPE'}); %Escape
p.KEY.TRIGGER = KbName({'t' '5%' '5'}); %T or 5
p.KEY.BUTTON_BOX = KbName({'r' 'g' 'b' 'y' '1!' '2@' '3#' '4$' '1' '2' '3' '4'}); %RGBY or 1-4


%% Parameters - Task-Specific

p.USE_PROPIXX = true;

p.DISPLAY_SEC = 0.8; %must be less than TR

p.MEASURE.VIEW_DISTANCE_CM = 65;
p.MEASURE.WIDTH_CM = 54.2;

p.STEREO_MODE = 1; %1 or 11: projector 10: dual monitors
p.SCREEN.NUMBER = max(Screen('Screens')); %may need to set to specific value (usually 0-2)
p.SCREEN.RESOLUTION = Screen('Resolution', p.SCREEN.NUMBER);

%calculate pixels per degree (assumes iso pixels)
p.PPD = pi * p.SCREEN.RESOLUTION.width / atan(p.MEASURE.WIDTH_CM/p.MEASURE.VIEW_DISTANCE_CM/2) / 360;

p.CELLS.CELL_COUNTS = [6 8]; %6x8 grid
p.CELLS.SHIFT_DEGREES = [-0.22 -0.11 0 +0.11 +0.22]; %roughly equal number of each
p.CELLS.SHIFT_PIXELS = p.CELLS.SHIFT_DEGREES * p.PPD; %calculated value
p.CELLS.GRID_GAP_PIXELS = 10;
p.CELLS.SIZE_PIXELS = [200 200];

%this bit is messy - logic copied from original version
p.DOTS.DENSITY = 0.25;
p.DOTS.SIZE_DEGREES = 0.09;
p.DOTS.SIZE_PIXELS = p.DOTS.SIZE_DEGREES * p.PPD;
p.DOTS.TYPE = 4; %square
if p.DOTS.TYPE==4
    p.DOTS.SIZE_PIXELS = round(p.DOTS.SIZE_PIXELS); %dotSize 1:10 corresponding to displayed pixels 3:12 !!BE CAREFUL
end
p.DOTS.COUNT = round(prod(p.CELLS.SIZE_PIXELS)/(p.DOTS.SIZE_PIXELS^2)*p.DOTS.DENSITY);
p.DOTS.SIZE_PIXELS_ACTUAL = p.DOTS.SIZE_PIXELS;
if p.DOTS.TYPE==4
    p.DOTS.SIZE_PIXELS = p.DOTS.SIZE_PIXELS - 2; %dotSize 1:10 corresponding to displayed pixels 3:12 !!BE CAREFUL
end
if p.DOTS.SIZE_PIXELS < 1
    error('There is a limitation in DrawDots with dotsType=4. you wont be able to get dot less than 3 pixels')
end

p.FIXATION.LINE_WIDTH = 3;
p.FIXATION.LENGTH_PIXELS = 30;
r = p.FIXATION.LENGTH_PIXELS/2;
p.FIXATION.XY = [-r r 0 0; 0 0 -r r];

p.COLOUR.BACKGROUND = [128 128 128];
p.COLOUR.TEXT = [0 0 0];
p.COLOUR.FIXATION = [255 255 255];
% if ~p.DEBUG
    p.COLOUR.DOTS_LEFT = [50 50 50];
    p.COLOUR.DOTS_RIGHT = [50 50 50];
% else
%     p.COLOUR.DOTS_LEFT = [50 50 255];
%     p.COLOUR.DOTS_RIGHT = [255 50 50];
% end


%% Preparations

%initialize data structure "d"
d = struct;
d.datetime_init = datetime('Now');
d.rng_seed = rng_seed;

%pre-call time sensitive functions to improve timing later
for i = 1:10
    GetSecs;
    KbCheck;
end

%create data folder if it does not yet exist
if ~exist(p.PATH.DATA_FOLDER, 'dir'), mkdir(p.PATH.DATA_FOLDER); end

%store git repo info
if exist('IsGitRepo','file') && ~IsGitRepo
    warning('This project does not appear to be part of a git repository. No git data will be saved.');
elseif exist('GetGitInfo','file')
    d.GitInfo = GetGitInfo;
else
    warning('The "CulhamLab/Git-Version" repo has not been configured. Information about this project''s current repository status (version, etc.) will NOT be saved to the data file.');
end

%load order
if ~exist(p.PATH.ORDER, 'file')
    error('Order file not found: %s', p.PATH.ORDER)
else
    d.order = readtable(p.PATH.ORDER);
end

%count volumes
d.number_volumes = sum(d.order.Duration_Seconds);


%% Create Volume Event Schedule
% Define table of volume events
d.sched = table('Size', [d.number_volumes 6], ...
                'VariableNames',{'Volume'   'Condition' 'DrawDots'	'Is3D'      'DrawGrid'  'CellOffsets'}, ...
                'VariableTypes', {'int32'   'string'      'logical'	'logical'   'logical'   'cell'       });
disp 'Creating volume event schedule...';
vol = 0;
for row = 1:height(d.order)
    if strcmp(d.order.Condition(row), 'Null')
        DrawDots = false;
        DrawGrid = false;
        Is3D = false;
    else
        DrawDots = true;
        switch d.order.Condition{row}
            case '2D'
                Is3D = false;
                DrawGrid  = false;
            case '2DGrid'
                Is3D = false;
                DrawGrid = true;
            case '3D'
                Is3D = true;
                DrawGrid = false;
            case '3DGrid'
                Is3D = true;
                DrawGrid = true;
            otherwise
                error
        end
    end
    
    for i = 1:d.order.Duration_Seconds(row)
        vol = vol + 1;
        
        d.sched.Volume(vol) = vol;
        d.sched.Condition{vol} = d.order.Condition{row};
        d.sched.DrawDots(vol) = DrawDots;
        d.sched.DrawGrid(vol) = DrawGrid;
        d.sched.Is3D(vol) = Is3D;
        if Is3D
            d.sched.CellOffsets{vol} = GetCellOffsets(p);
        else
            d.sched.CellOffsets{vol} = zeros(p.CELLS.CELL_COUNTS);
        end
    end
end

%% Pre-Calculate Dot Locations
disp 'Pre-calculating dot locations...';
dot_xy = repmat(struct, [d.number_volumes 1]);
for vol = 1:d.number_volumes
    if d.sched.DrawDots(vol)
        %uses the original "generateDots.m" with no changes, must define trial parameters
        par = struct;
        
        par.totalTrials = 1;
        par.checkboardSize = p.CELLS.CELL_COUNTS([2 1]);
        par.numDots = p.DOTS.COUNT;
        par.numPixelInPatch = p.CELLS.SIZE_PIXELS;
        par.disparityInPixel = d.sched.CellOffsets{vol}';
        par.actualDotSizeInPixel = p.DOTS.SIZE_PIXELS_ACTUAL;
        par.dotsDensity = p.DOTS.DENSITY;
        
        if d.sched.DrawGrid(vol)
            gap = p.CELLS.GRID_GAP_PIXELS;
        else
            gap = 0;
        end
        par.dot2LineGapX = gap;
        par.dot2LineGapY = gap;
        
        if d.sched.Is3D(vol) && ~d.sched.DrawGrid(vol)
            par.dotConstraintFlag = 3;
        else
            par.dotConstraintFlag = 2;
        end
        
        [dot_xy(vol).Left, dot_xy(vol).Right] = generateDots(par);
    end
end


%% Try/Catch before into screen etc.
try
    
    
%% Final Preparations

%stereo requires screen sync
Screen('Preference', 'SkipSyncTests', 0);

%open screen
disp 'Preparing "Screen"...';
for attempt = 1:5
    try
        [windowPtr,windowRect] = Screen('OpenWindow', p.SCREEN.NUMBER, p.COLOUR.BACKGROUND, [],[],2, p.STEREO_MODE);
        break;
    catch
        sca
        sca
        if attempt < 5
            WaitSecs(0.5);
        else
            error('Failed to open screen 5 times')
        end
    end
end

%propixx settings
if p.USE_PROPIXX
    Datapixx('Open'); 
    Datapixx('EnableVideoStereoBlueline');
    
    %set GPU CLUTs to linear
    Screen('LoadNormalizedGammaTable', windowPtr, linspace(0,1,256)'*[1,1,1]);
end

% Set up alpha-blending for smooth (anti-aliased) drawing of dots:
Screen('BlendFunction', windowPtr, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%hide cursor
HideCursor;


%% Wait for First Trigger
message = sprintf('\nWaiting For Keys To Release...');
StereoDrawBackground(windowPtr,p);
StereoDrawText(windowPtr,p,message);
Screen('DrawingFinished',windowPtr);
Screen('Flip', windowPtr);

%make sure nothing is pressed currently
while KbCheck, end

message = sprintf('\nWaiting For Trigger (%d vol, TR %d)',d.number_volumes,p.TR);
StereoDrawBackground(windowPtr,p);
StereoDrawText(windowPtr,p,message);
StereoDrawFixation(windowPtr, windowRect, p);
Screen('DrawingFinished',windowPtr);
Screen('Flip', windowPtr);

while 1
    [keyIsDown, ~, keyCode] = KbCheck(-1); %get key(s)
    if keyIsDown
        if any(keyCode(p.KEY.TRIGGER))
            break
        elseif any(keyCode(p.KEY.STOP))
            error('Stop key was pressed.')
        end
    end
end

%% Play Out Volumes
t0 = GetSecs;
d.t0 = t0;
for v = p.FIRST_VOL:d.number_volumes
    %volume start time actual
    if v==1
        d.volume_data(v).time_startActual = 0;
    else
        d.volume_data(v).time_startActual = GetSecs-t0;
    end
    
    %volume start time
    if v==p.FIRST_VOL || d.volume_data(v-1).trigger_recieved %is first vol OR prior vol recieved trigger
        d.volume_data(v).time_start = d.volume_data(v).time_startActual; %use actual time
    else %missed a trigger
        d.volume_data(v).time_start = d.volume_data(v-1).time_start + p.TR; %use expected trigger time
    end
    
    %store schedule row
    d.volume_data(v).sched = d.sched(v,:);
    
    %start message
    fprintf('\nStarting volume %d/%d at %fsec (actual %fsec):\n-%s\n',v,d.number_volumes,d.volume_data(v).time_start,d.volume_data(v).time_startActual,d.volume_data(v).sched.Condition);
    
    %defaults
    d.volume_data(v).time_draw = nan;
    d.volume_data(v).time_clear = nan;
    d.volume_data(v).button_pressed = false;
    d.volume_data(v).time_button_pressed = nan;
    d.volume_data(v).trigger_recieved = false;
    d.volume_data(v).time_trigger = nan;
    
    %start drawing...
    StereoDrawBackground(windowPtr,p);
    if p.DEBUG
        StereoDrawText(windowPtr,p,sprintf('%03d/%03d %s', v, d.number_volumes, d.volume_data(v).sched.Condition));
    end
    
    %draw dots?
    if d.volume_data(v).sched.DrawDots
        StereoDrawDots(windowPtr, windowRect, p, dot_xy(v))
    end
    
    %drag fixation last
    StereoDrawFixation(windowPtr, windowRect, p);
    
    %done drawing
    Screen('DrawingFinished',windowPtr);
    Screen('Flip',windowPtr);
    d.volume_data(v).time_draw = (GetSecs-t0) - d.volume_data(v).time_start;
    
    %save progress
    save(p.PATH.DATA, 'p', 'd')
    
    %prep clear?
    needs_clear = d.volume_data(v).sched.DrawDots;
    if needs_clear
        StereoDrawBackground(windowPtr,p);
        if p.DEBUG
            StereoDrawText(windowPtr,p,sprintf('%03d/%03d %s', v, d.number_volumes, d.volume_data(v).sched.Condition));
        end
        StereoDrawFixation(windowPtr, windowRect, p);
        Screen('DrawingFinished',windowPtr);
    end
    
    %loop until end
    max_duration = p.TR + p.TRIGGER.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC;
    while 1
        [keyIsDown, t, keyCode] = KbCheck(-1);
        timeInVol = (t-t0) - d.volume_data(v).time_start;
        
        %button events
        if keyIsDown
            if any(keyCode(p.KEY.STOP))
                error('Stop key was pressed.') 
            elseif ~d.volume_data(v).button_pressed && any(keyCode(p.KEY.BUTTON_BOX))
                d.volume_data(v).button_pressed = true;
                d.volume_data(v).time_button_pressed = timeInVol;
                fprintf('-Button Box\n');
            elseif (timeInVol>p.TRIGGER.TIME_BEFORE_TRIGGER_CAN_START_LOOKING_SEC) && any(keyCode(p.KEY.TRIGGER))
                d.volume_data(v).trigger_recieved = true;
                d.volume_data(v).time_trigger = timeInVol;
                fprintf('~~~~~~~~~~~~~~~~~TRIGGER RECIEVED~~~~~~~~~~~~~~~~~\n')
                break
            end
        end
        
        %time events
        if timeInVol > max_duration
            warning('No trigger was recieved. Continuing with expected timing...')
            break
        elseif needs_clear && (timeInVol > p.DISPLAY_SEC)
            Screen('Flip',windowPtr);
            d.volume_data(v).time_clear = (GetSecs-t0) - d.volume_data(v).time_start;
            needs_clear = false;
        end
    end
    
    %end of volume timing
    d.volume_data(v).time_endActual = GetSecs-t0;
    d.volume_data(v).volDuration = d.volume_data(v).time_endActual - d.volume_data(v).time_start;
    d.volume_data(v).volDurationActual = d.volume_data(v).time_endActual - d.volume_data(v).time_startActual;
    fprintf('-duration: %f seconds\n',d.volume_data(v).volDuration)
end

%% Finish Up

%final save
save([p.PATH.DATA '_Finished'], 'p', 'd')

%do cleanup
cleanup(p)

%done!
disp Done!


%% Catch Errors During Runtime
catch err
    %do cleanup
    cleanup(p)
    
    %don't save dot_xy
    clear dot_xy
    
    %save everything
    save([p.PATH.DATA '_errorDump']);
    
    %rethrow error
    rethrow(err)
end

%% Helper Functions
function [timestamp] = get_timestamp
x = datetime('Now');
timestamp = sprintf('%d-%d-%d_%d-%d_%d',x.Year,x.Month,x.Day,x.Hour,x.Minute,round(x.Second));

function cleanup(p)
%if screen is open, unhide the cursor
ShowCursor;
%if screen is open, close the screen (can take 2 calls when it's really broken)
sca;
sca;
%PROPixx complete
if p.USE_PROPIXX
    % Set the PROPixx back to normal sequencer
    Datapixx('SetPropixxDlpSequenceProgram', 0);
    Datapixx('RegWrRd');

    % Close PROPixx connection
    Datapixx('Close');
end

%% Task-Specific Functions
function [cell_offsets] = GetCellOffsets(p)
number_shifts = length(p.CELLS.SHIFT_PIXELS);
number_cells = prod(p.CELLS.CELL_COUNTS);
max_shift_count = ceil(number_cells / number_shifts);
rp_max = max_shift_count * number_shifts;

t = GetSecs;
while 1
    valid = true;
    
    %choose how many of each shift / init shift info
    shift_inds = mod(randperm(rp_max,number_cells), number_shifts) + 1;
    for s = 1:number_shifts
        shift(s).count = sum(shift_inds==s);
        shift(s).value = p.CELLS.SHIFT_PIXELS(s);
        shift(s).cells_valid = true(p.CELLS.CELL_COUNTS);
    end
    
    %init offsets
    cell_offsets = nan(p.CELLS.CELL_COUNTS);
    
    %apply shifts, alternating
    for i = 1:max_shift_count
        for s = 1:number_shifts
            if shift(s).count >= i
                %select valid cells
                cells_valid = isnan(cell_offsets) & shift(s).cells_valid;
                
                %find valid cells
                ind = find(cells_valid);
                if isempty(ind)
                    %no valid cells
                    valid = false;
                    break;
                else
                    %randomly select a valid cell
                    ind = ind(randperm(length(ind),1));
                    
                    %assign
                    cell_offsets(ind) = shift(s).value;
                    
                    %block off adjacent
                    [xc,yc] = ind2sub(p.CELLS.CELL_COUNTS, ind);
                    for xy = [-1 0; +1 0; 0 -1; 0 +1]'
                        x = xc + xy(1);
                        y = yc + xy(2);

                        if x<1 || x>p.CELLS.CELL_COUNTS(1) || y<1 || y>p.CELLS.CELL_COUNTS(2)
                            continue
                        end

                        shift(s).cells_valid(x,y) = false;
                    end
                end
                
            end
            
            if ~valid
                break;
            end
        end
        if ~valid
            break;
        end
    end
    
    if valid
        break;
    elseif (GetSecs - t) > 20
        error('Failed to create valid offsets in under 20 seconds. Check parameters for issues.')
    end
end

%NOTE: copied from original version with no changes
function [xyL, xyR] = generateDots(par)
xyL = [];
xyR = [];

if par.dotConstraintFlag == 0
    for nx = 1:par.checkboardSize(1)
        for ny = 1:par.checkboardSize(2)
            x = rand(par.numDots, 1)'*(par.numPixelInPatch(1)-par.dot2LineGapX);
            y = rand(par.numDots, 1)'*(par.numPixelInPatch(2)-par.dot2LineGapY);
            bufL = [x-par.disparityInPixel(nx, ny)/2+(nx-1)*par.numPixelInPatch(1); y+(ny-1)*par.numPixelInPatch(2)];
            bufR = [x+par.disparityInPixel(nx, ny)/2+(nx-1)*par.numPixelInPatch(1); y+(ny-1)*par.numPixelInPatch(2)];
            xyL = [xyL, bufL];
            xyR = [xyR, bufR];
        end
    end
elseif par.dotConstraintFlag == 1 % universal contraint
    for nx = 1:par.checkboardSize(1)
        for ny = 1:par.checkboardSize(2)
            dx = par.disparityRangeInPixel(2)+par.dot2LineGapX;
            dy = par.dot2LineGapY;
            x = rand(par.numDots, 1)'*(par.numPixelInPatch(1)-dx)+dx/2;
            y = rand(par.numDots, 1)'*(par.numPixelInPatch(2)-dy)+dy/2;
            bufL = [x-par.disparityInPixel(nx, ny)/2+(nx-1)*par.numPixelInPatch(1); y+(ny-1)*par.numPixelInPatch(2)];
            bufR = [x+par.disparityInPixel(nx, ny)/2+(nx-1)*par.numPixelInPatch(1); y+(ny-1)*par.numPixelInPatch(2)];
            xyL = [xyL, bufL];
            xyR = [xyR, bufR];
        end
    end
elseif par.dotConstraintFlag == 2 % individual grid contraint
    for nx = 1:par.checkboardSize(1)
        for ny = 1:par.checkboardSize(2)
            dx = abs(par.disparityInPixel(nx, ny)) + par.dot2LineGapX/2;
            %dx = par.dot2LineGapX;
            dy = par.dot2LineGapY;
%             keyboard
            x = rand(par.numDots, 1)'*(par.numPixelInPatch(1)-dx)+dx;
            y = rand(par.numDots, 1)'*(par.numPixelInPatch(2)-dy)+dy;
            bufL = [x-par.disparityInPixel(nx, ny)/2+(nx-1)*par.numPixelInPatch(1); y+(ny-1)*par.numPixelInPatch(2)];
            bufR = [x+par.disparityInPixel(nx, ny)/2+(nx-1)*par.numPixelInPatch(1); y+(ny-1)*par.numPixelInPatch(2)];
            xyL = [xyL, bufL];
            xyR = [xyR, bufR];
        end
    end
elseif par.dotConstraintFlag == 3 % individual grid contraint
    L = [];
    R = [];
    for ny = 1:par.checkboardSize(2)
        for nx = 1:par.checkboardSize(1)
            disparity = par.disparityInPixel(nx, ny)/2;
            lx = par.numPixelInPatch(1);
            ly = par.numPixelInPatch(2);
            
            dx = abs(disparity) + par.dot2LineGapX;
            dy = par.dot2LineGapY;
            
            x = rand(1, par.numDots)*lx;
            y = rand(1, par.numDots)*ly;
            
            %adding some dots to fill the void gap
            n = getDotsFromDensity(dx, ly, par.actualDotSizeInPixel, par.dotsDensity);
            x1 = rand(1, n)*dx;
            y1 = rand(1, n)*ly;
            
            if disparity>=0
                padL = [lx-dx+x1+(nx-1)*lx; y1+(ny-1)*ly];
                padR = [x1+(nx-1)*lx; y1+(ny-1)*ly];
            else
                padL = [x1+(nx-1)*lx; y1+(ny-1)*ly];
                padR = [lx-dx+x1+(nx-1)*lx; y1+(ny-1)*ly];
            end
            
            bufL = [x-disparity+(nx-1)*lx; y+(ny-1)*ly];
            bufR = [x+disparity+(nx-1)*lx; y+(ny-1)*ly];
            
            L{nx, ny} = [bufL, padL];
            R{nx, ny} = [bufR, padR];
            
        end
    end
    
    %get rid of overlapping dots
    for ny = 1:par.checkboardSize(2)
        for nx = 1:par.checkboardSize(1)-1
            %left
            x0 = L{nx, ny}(1, :);
            y0 = L{nx, ny}(2, :);
            x1 = L{nx+1, ny}(1, :);
            y1 = L{nx+1, ny}(2, :);
            %clf; plot(x0, y0, '.r', x1, y1, '.b');
            
            if par.disparityInPixel(nx+1, ny)>=par.disparityInPixel(nx, ny)
                ind = x0<min(x1);
                L{nx, ny} = [x0(ind); y0(ind)];
            else
                ind = x1>max(x0);
                L{nx+1, ny} = [x1(ind); y1(ind)];
            end
            
            x0 = R{nx, ny}(1, :);
            y0 = R{nx, ny}(2, :);
            x1 = R{nx+1, ny}(1, :);
            y1 = R{nx+1, ny}(2, :);
            
            if par.disparityInPixel(nx+1, ny)>=par.disparityInPixel(nx, ny)
                ind = x0<min(x1);
                R{nx, ny} = [x0(ind); y0(ind)];
            else
                ind = x1>max(x0);
                R{nx+1, ny} = [x1(ind); y1(ind)];
            end
            
        end
    end
    
    xyL = [];
    xyR = [];
    
    for ny = 1:par.checkboardSize(2)
        for nx = 1:par.checkboardSize(1)
            xyL = [xyL, L{nx, ny}];
            xyR = [xyR, R{nx, ny}];
        end
    end
end

xyL(1, :) = xyL(1, :) - par.numPixelInPatch(1)*nx/2;
xyL(2, :) = xyL(2, :) - par.numPixelInPatch(2)*ny/2;
xyR(1, :) = xyR(1, :) - par.numPixelInPatch(1)*nx/2;
xyR(2, :) = xyR(2, :) - par.numPixelInPatch(2)*ny/2;

function n = getDotsFromDensity(x, y, dotSize, dotsDensity)
n = round(x*y*dotsDensity/(dotSize^2));

function StereoDrawBackground(windowPtr,p)
for view = 0:1
    Screen('SelectStereoDrawBuffer', windowPtr, view);
    Screen('FillRect', windowPtr, p.COLOUR.BACKGROUND);
end

function StereoDrawText(windowPtr,p,text)
for view = 0:1
    Screen('SelectStereoDrawBuffer', windowPtr, view);
    Screen('DrawText', windowPtr, text, 0, 0, p.COLOUR.TEXT);
end

function StereoDrawFixation(windowPtr, windowRect, p)
for view = 0:1
    Screen('SelectStereoDrawBuffer', windowPtr, view);
    Screen('DrawLines', windowPtr, p.FIXATION.XY, p.FIXATION.LINE_WIDTH, p.COLOUR.FIXATION, windowRect(3:4)/2);
end

function StereoDrawDots(windowPtr, windowRect, p, dot_xy)
Screen('SelectStereoDrawBuffer', windowPtr, 0);
Screen('DrawDots', windowPtr, dot_xy.Left, p.DOTS.SIZE_PIXELS, p.COLOUR.DOTS_LEFT, windowRect(3:4)/2, p.DOTS.TYPE);
Screen('SelectStereoDrawBuffer', windowPtr, 1);
Screen('DrawDots', windowPtr, dot_xy.Right, p.DOTS.SIZE_PIXELS, p.COLOUR.DOTS_RIGHT, windowRect(3:4)/2, p.DOTS.TYPE);
