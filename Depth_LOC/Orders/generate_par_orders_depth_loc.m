function generate_par_orders_depth_loc

DIR_OUT = ['C:\Users\evade\Documents\GitHub\fMRI_DepthLocalizer_2021\Orders' filesep];

for par = 2:30
  
    
for run = 1:2 
    
    orderfilepath = sprintf('%sPAR%02d_RUN%02d.xlsx', DIR_OUT, par-1, run);
    
    [~, ~, xls] = xlsread(orderfilepath); 

    order_filepath_save = sprintf('%sPAR%02d_RUN%02d.xlsx', DIR_OUT, par, run);
    
    fprintf('Writing: %s\n', order_filepath_save);
    
    xlswrite(order_filepath_save, xls)
end
end