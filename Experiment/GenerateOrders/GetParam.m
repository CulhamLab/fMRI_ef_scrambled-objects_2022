%%
names_category = {'object-solid' 'object-scrambled' 'face' 'body-part' 'scene'};
names_format = {'2D' '3D'};

%% auto
number_category = length(names_category);
number_format = length(names_format);
number_cond = number_category * number_format;
[cond_format,cond_category] = meshgrid(1:number_format,1:number_category);


