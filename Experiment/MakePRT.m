function MakePRT

fol_order = [pwd filesep 'Orders' filesep];

task = '3DReachspace';
TR = 1000;

list = dir([fol_order '*.xlsx']);

%output folder
fol = [pwd filesep 'PRT' filesep];
if ~exist(fol, 'dir')
    mkdir(fol);
end

%process files...
for file = list'
    %output
    fp_out = [fol file.name(1:find(file.name=='.',1,'last')) 'prt'];
    if exist(fp_out,'file')
        fprintf('Output already exists, skipping: %s\n', file.name);
        continue
    end

    %read
    order = readtable([file.folder filesep file.name]);

    %find unique conditions
    cond_names = unique(order.Condition);
    cond_names(strcmpi(cond_names,'null')) = [];
    cond_colours = uint8(jet(length(cond_names)) * 255);

%     %separate one-backs?
%     if sep_oneback
%         ind = find(order.Is_repeat);
%         names = arrayfun(@(i) sprintf('OneBack%d',i), 1:length(ind), 'UniformOutput', false)';
%         order.Condition(ind) = names;
%         cond_names = [cond_names; names];
%         cond_colours(end+1:length(cond_names),:) = 128;
%     end

    %make vol events
    number_vol = sum(order.Duration_Seconds);
    vol_events = nan(1,number_vol);
    number_conditions = length(cond_names);
    v = 0;
    for i = 1:height(order)
        cond = find(strcmp(cond_names, order.Condition{i}));
        for j = 1:order.Duration_Seconds(i)
            v=v+1;
            if ~isempty(cond)
                vol_events(v) = cond;
            end
        end
    end

    %make prt
    prt = xff('prt');
    prt.Experiment = task;
    prt.NrOfConditions = number_conditions;
    for c = 1:number_conditions
        prt.Cond(c).ConditionName = cond_names(c);
        prt.Cond(c).Color = cond_colours(c,:);

        onoff = [];
        active = false;
        evt = 0;
        for v = 1:number_vol
            if (vol_events(v) == c)
                %start of event
                if ~active
                    evt = evt + 1;
                    onoff(evt,1) = v;
                    active = true;
                end
            else
                %end of event
                if active
                    onoff(evt,2) = v-1;
                    active = false;
                end
            end


        end
        %last event goes to last vol
        if active
            onoff(end,2) = number_vol;
        end

        %convert vol to msec
        onoff = (onoff-[1 0]) * TR;

        %store
        prt.Cond(c).OnOffsets = onoff;
        prt.Cond(c).NrOfOnOffsets = size(prt.Cond(c).OnOffsets,1);
    end

    %save
    prt.SaveAs(fp_out);
    prt.ClearObject;
end

disp Done!