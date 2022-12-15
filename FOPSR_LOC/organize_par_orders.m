function generate_par_orders
DIR_IN = ['.' filesep 'Orders_LOC_old' filesep];
DIR_OUT = ['.' filesep 'Orders_LOC' filesep];

for par = 6:30
    for run = 1:2
        previousparticipant_filepath = sprintf('%sPAR%02d_RUN%02d.xlsx', DIR_IN, par, run);
        [~,~,xls] = xlsread(previousparticipant_filepath);
        
        order_filepath = sprintf('%sPAR%02d_RUN%02d.xlsx', DIR_OUT, par-4, run);
        fprintf('Writing: %s\n', order_filepath);
        xlswrite(order_filepath, xls)
    end
end
end