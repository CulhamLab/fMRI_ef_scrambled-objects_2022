%%
GetParam

number_par = 5;
number_run = 8;

number_stims_per_cond = 20;

%%
sec_baseline_init = 16;
sec_baseline_final = 16;
sec_presentation = 1;
sec_ITI = 10;

%%
fol_out = ['..' filesep 'Orders' filesep];
if ~exist(fol_out,'dir')
    mkdir(fol_out,'s')
end

%%
for par = 1:number_par
    if mod(par,2)
        first_format = repmat([1 2], [1 number_run/2]);
    else
        first_format = repmat([2 1], [1 number_run/2]);
    end
    
    first_category = [randperm(number_category) randperm(number_category,number_run-number_category)];
    
    imbalance_allowed_category = ones(number_category, number_category);
    imbalance_allowed_category(eye(size(imbalance_allowed_category))==1) = nan;
    
    imbalance_allowed_format = ones(number_format, number_format) * 2;
    
    for run = 1:number_run
        %% generate orders until valid is found
        while 1
            [order, imbalance_format, imbalance_category] = CalcRunOrder(first_format(run), first_category(run));
            
            ind_format = find(imbalance_format>0);
            ind_category = find(imbalance_category>0);
            
            if imbalance_allowed_category(ind_category)>0 && imbalance_allowed_format(ind_format)>0
                imbalance_allowed_category(ind_category) = imbalance_allowed_category(ind_category) - 1;
                imbalance_allowed_format(ind_format) = imbalance_allowed_format(ind_format) - 1;
                break;
            end
            
        end
        
        %% randomize stims per cond
        number_trials = length(order);
        stims = cell(1, number_trials);
        for cond = 1:number_cond
            stim_order = randperm(number_stims_per_cond);
            
            inds = find(order==cond);
            stims{inds(1)} = stim_order(1:10);
            stims{inds(2)} = stim_order(11:20);
        end
        
        %% create table
        v = cell(0,2);
        v(end+1,:) = {'Trial' 'double'};
        v(end+1,:) = {'Condition' 'string'};
        v(end+1,:) = {'Duration_Seconds' 'double'};
        v(end+1,:) = {'Filename_left' 'string'};
        v(end+1,:) = {'Filename_right' 'string'};
        v(end+1,:) = {'Format' 'string'};
        v(end+1,:) = {'Is_repeat' 'logical'};
        v(end+1,:) = {'Motion' 'string'};
        v(end+1,:) = {'Fixation' 'string'};
        v(end+1,:) = {'Display' 'string'};
        v(end+1,:) = {'Category' 'string'};
        v(end+1,:) = {'Stim' 'double'};
        tbl = table('Size', [(number_trials*11)+1 12], 'VariableTypes', v(:,2), 'VariableNames', v(:,1));
        tbl.Trial(:) = 0;
        tbl.Fixation(:) = {'On'};
        tbl.Is_repeat(:) = false;
        
        %initial baseline
        row = 1;
        tbl.Condition{row} = 'NULL';
        tbl.Duration_Seconds(row) = sec_baseline_init;
        tbl.Format{row} = 'NULL';
        
        %trials...
        for trial = 1:number_trials
            cond = order(trial);
            format = cond_format(cond);
            category = cond_category(cond);
            
            name_format = names_format{format};
            name_cateogry = names_category{category};
            
            for s = 1:10
                row = row + 1;
                
                tbl.Trial(row) = trial;
                tbl.Condition(row) = [name_format ' ' name_cateogry];
                tbl.Duration_Seconds(row) = sec_presentation;
                
                switch name_format
                    case '2D'
                        views = 'rr';
                    case '3D'
                        views = 'lr';
                    otherwise
                        error
                end
                stim = stims{trial}(s);
                tbl.Filename_left{row} = sprintf('%s_%02d_%s.png', name_cateogry, stim, views(1));
                tbl.Filename_right{row} = sprintf('%s_%02d_%s.png', name_cateogry, stim, views(2));
                
% %                 switch name_format
% %                     case '2D'
% %                         tbl.Filename_left{row} = 'apple_R.png';
% %                         tbl.Filename_right{row} = 'apple_R.png';
% %                     case '3D'
% %                         tbl.Filename_left{row} = 'apple_L.png';
% %                         tbl.Filename_right{row} = 'apple_R.png';
% %                     otherwise
% %                         error
% %                 end
                
                tbl.Format{row} = 'image';
                tbl.Display{row} = name_format;
                tbl.Category{row} = name_cateogry;
                tbl.Stim(row) = stim;
                
                
            end
            
            
            %ITI
            if trial<number_trials
                row = row + 1;
                
                tbl.Condition{row} = 'NULL';
                tbl.Duration_Seconds(row) = sec_ITI;
                tbl.Format{row} = 'NULL';
            end
                
        end
        
        %final baseline
        row = row + 1;
        tbl.Condition{row} = 'NULL';
        tbl.Duration_Seconds(row) = sec_baseline_final;
        tbl.Format{row} = 'NULL';
        
        %% write table
        fp = [fol_out sprintf('PAR%02d_RUN%02d', par, run)];
        writetable(tbl, [fp '.xlsx']);
        order = struct;
        order.table = tbl;
        save([fp '.mat'], 'order');
        
    end
    
end

disp Done.