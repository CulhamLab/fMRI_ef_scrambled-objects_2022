function MakePRT

fol_data = [pwd filesep 'Data' filesep];

task = '3DReachspace';
TR = 1000;

list = dir([fol_data '*_COMPLETE.mat']);

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
    data = load([file.folder filesep file.name]);
    order = data.d.order;

    %find unique conditions
    cond_names = unique(order.Condition);
    cond_names(strcmpi(cond_names,'null')) = [];
%     cond_colours = uint8(jet(length(cond_names)) * 255);

    %calculate onset/offset
    for r = 1:height(data.d.order)
        if r==1
            order.Onset(r) = 0;
        else
            order.Onset(r) = order.Offset(r-1);
        end
        order.Offset(r) = order.Onset(r) + order.Duration_Seconds(r);
    end

    %fix rounding
    ind = abs(order.Onset - round(order.Onset)) < 1E-10;
    order.Onset(ind) = round(order.Onset(ind));
    ind = abs(order.Offset - round(order.Offset)) < 1E-10;
    order.Offset(ind) = round(order.Offset(ind));

    cond_colours = zeros(length(cond_names),3,'uint8');
    cond_colours(strcmp(cond_names,'2D body-part'),:) = [4 51 255];
    cond_colours(strcmp(cond_names,'2D face'),:) = [255 64 255];
    cond_colours(strcmp(cond_names,'2D object-scrambled'),:) = [121 121 121];
    cond_colours(strcmp(cond_names,'2D object-solid'),:) = [255 147 0];
    cond_colours(strcmp(cond_names,'2D scene'),:) = [0 143 0];
    cond_colours(strcmp(cond_names,'3D body-part'),:) = [0 253 255];
    cond_colours(strcmp(cond_names,'3D face'),:) = [242 176 249];
    cond_colours(strcmp(cond_names,'3D object-scrambled'),:) = [214 214 214];
    cond_colours(strcmp(cond_names,'3D object-solid'),:) = [255 212 121];
    cond_colours(strcmp(cond_names,'3D scene'),:) = [115 250 121];

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
    if abs(number_vol - round(number_vol)) < 1E-10
        number_vol = round(number_vol);
    end
    vol_events = nan(1,number_vol);
    number_conditions = length(cond_names);
    
    for trial = min(order.Trial(order.Trial>0)) : max(order.Trial)
        select = find(order.Trial == trial);
        on = order.Onset(select(1)) + 1;
        off = order.Offset(select(end));

        %confirm whole number
        if any([on off] ~= round([on off]))
            error
        end
        
        %get trial condition
        cond = find(strcmp(cond_names, order.Condition{select(1)}));
        if length(cond)~=1
            error
        end

        %set vols
        vol_events(on:off) = cond;
    end

%     v = 0;
%     for i = 1:height(order)
%         cond = find(strcmp(cond_names, order.Condition{i}));
%         for j = 1:order.Duration_Seconds(i)
%             v=v+1;
%             if ~isempty(cond)
%                 vol_events(v) = cond;
%             end
%         end
%     end

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