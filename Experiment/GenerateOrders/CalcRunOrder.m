function [order, imbalance_format, imbalance_category] = CalcRunOrder(first_format, first_category)

%%
GetParam

%%
first_cond = find((cond_format == first_format) & (cond_category == first_category));

%%
while 1
    %% init
    imbalance_category = ones(number_category,number_category);
    imbalance_format = ones(number_format,number_format) * 5;
    success = true;
    
    order = nan(1,number_cond);
    
    %% categories cannot follow themself
    imbalance_category(eye(size(imbalance_category))==1) = nan;
    
    %%
    i = 0;
    for half = 1:2
        cond_available = 1:number_cond;
        
        if half==1
            i=i+1;
            order(i) = first_cond;
            cond_available(cond_available==first_cond) = [];
        end
        
        while ~isempty(cond_available)
            i=i+1;
            format_prior = cond_format(order(i-1));
            category_prior = cond_category(order(i-1));
            
            %what could follow?
            valid_cateogry = imbalance_category(category_prior,:)>0;
            valid_format = imbalance_format(format_prior,:)>0;
            valid_cond = find(arrayfun(@(c,f) valid_cateogry(c) & valid_format(f), cond_category, cond_format));
            
            %which available can follow?
            options = intersect(cond_available, valid_cond);
            
            %no options?
            if isempty(options)
                success = false;
                break; %invalid order
            end
            
            %select one randomly
            cond = options(randperm(length(options),1));
            
            %apply
            order(i) = cond;
            cond_available(cond_available==cond) = [];
            imbalance_category(category_prior,cond_category(cond)) = imbalance_category(category_prior,cond_category(cond)) - 1;
            imbalance_format(format_prior,cond_format(cond)) = imbalance_format(format_prior,cond_format(cond)) - 1;
        end
        
        if ~success
            break
        end
    end
    
    %done?
    if success
        break
    end
end