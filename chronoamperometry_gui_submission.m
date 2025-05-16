
% Chronoamperometry GUI App
%Draisy Jakubowitz
%Liba Snyder
%Daniel B
%Moshe Kin
% Description: A GUI interface for data import, model fitting, plotting, and electrolyte recommendations
% Takes raw chronoamperometry data and then instantly fits it to a custom model from RC equation and cottrell equation
% in order to recommend the most suitable electrolyte and how much of it to
% use.
%  Next step: scale it tweak it and even add more to the model equation. 

function chronoamperometry_gui_submission
    % Create window dimensions
    f = figure('Name', 'Chronoamperometry GUI', 'Position', [100 100 700 400]);

    % UI Controls these are all the buttons and options in my Gui the
    % numbers are dimensions, and then the electrolytes i made as a string
    % so it can be a dropdown menue
    uicontrol(f, 'Style', 'pushbutton', 'String', 'Load .xlsx Data', 'Position', [50 340 120 30], 'Callback', @load_data);
    uicontrol(f, 'Style', 'pushbutton', 'String', 'Fit + Plot Model', 'Position', [200 340 120 30], 'Callback', @fit_plot);
    uicontrol(f, 'Style', 'pushbutton', 'String', 'Recommend Electrolyte', 'Position', [350 340 150 30], 'Callback', @recommend);

    uicontrol(f, 'Style', 'text', 'Position', [50 300 150 20], 'String', 'Select Electrolyte:');
    % i'm keeping because i know i need this to use this when i fix up my
    % model and i don't feel like having to rewrite this
    dropdown = uicontrol(f, 'Style', 'popupmenu', 'String', {'NADH', 'Ascorbate', 'Hydroquinone', 'CytochromeC', 'Glutathione', 'Dithionite'}, 'Position', [200 300 150 25]);

    uicontrol(f, 'Style', 'text', 'Position', [50 260 100 20], 'String', 'Volume (mL):');
    volume_input = uicontrol(f, 'Style', 'edit', 'Position', [160 260 60 25]);

    uicontrol(f, 'Style', 'text', 'Position', [250 260 140 20], 'String', 'Concentration (mol/L):');
    conc_input = uicontrol(f, 'Style', 'edit', 'Position', [400 260 60 25]);

    result_box = uicontrol(f, 'Style', 'text', 'Position', [50 200 600 40], 'String', '', 'FontSize', 10, 'HorizontalAlignment', 'left');

    % Data and parameters from the excel sheet, to initialize three empty
    % arrays that will be involved in the calculations
    
    fit_params = [];
    time = [];
    current = [];

    % Callback: Load Excel Data
    function load_data(~, ~)
        [file, path] = uigetfile('*.xlsx', 'Select data file');%Opens urfilewindow and u can choose any excel file
        if isequal(file, 0), return; end %if nothing is chosen this will end it
        T = readtable(fullfile(path, file));%Reads Excel file into a table then builds thepath.
        time = T{:,1};
        current = T{:,2};
        time = time(isfinite(time) & time > 0);%removes any bad data from time
        current = current(1:length(time));%now adjusts current to match time
        
        msgbox('Data loaded successfully');%will let u know if its loaded right
    end

    % Fit + Plot
    function fit_plot(~, ~)
        if isempty(time)
            msgbox('Please load data first'); return; %will stop loop if file empty
        end
        F = 96485; A = 0.0314; C = 2e-7;
        %defines a model using my two equations that'll predict current
        %over time with 5 different parameters where x0 is the initial
        %guess and ib is the lower bound and ub is upper bound
        model = @(p, t) p(2) + (p(1) - p(2)) .* exp(-t / p(3)) + (p(4) * F * A * C * sqrt(p(5))) ./ sqrt(pi * t);
        x0 = [1e-6, 0.2e-6, 0.002, 1, 1e-6];
        lb = [0, 0, 1e-5, 0.5, 1e-8];
        ub = [1e-5, 1e-4, 1, 2, 1e-2];
        options = optimset('Display','off');
       
        fit_params = lsqcurvefit(@(p,t) model(p,t), x0, time, current, lb, ub, options);
        %finds the best p that'll fit the data so the graph will show two
        %equations one of actual data and one of its model
        figure;
        plot(time, current * 1e6, 'b.', time, model(fit_params, time) * 1e6, 'r-');
        xlabel('Time (s)'); ylabel('Current (\muA)'); grid on;
        title('Fitted Model vs. Data'); legend('Data', 'Fit');
    end

    % Thhis is the recommend Electrolyte + Mass button
    function recommend(~, ~)
        if isempty(fit_params)
            msgbox('Fit the model first'); return;
        end 
        %this loop is important because it needs a fitted model for the diffusion coefficient
        %if i didnt fit something itll stop the code
        D_fit = fit_params(5);
        D_dict = struct('NADH', 6.7e-6, 'Ascorbate', 6.46e-6, 'Hydroquinone', 5.05e-4, 'CytochromeC', 2.5e-7, 'Glutathione', 3.1e-6, 'Dithionite', 2.9e-6);
        MW = struct('NADH', 663.43, 'Ascorbate', 176.12, 'Hydroquinone', 110.11, 'CytochromeC', 12000, 'Glutathione', 307.32, 'Dithionite', 174.12);
        %the 5th parameter in the equation is the diffusion coefficient in
        %the equation, so it pulls that out and compares that with my
        %dictionary above
        choices = fieldnames(D_dict);
        
        errs = cellfun(@(name) abs(D_dict.(name) - D_fit) / D_fit, choices); %computes the error for each electrolyte.
        [rel_err, idx] = min(errs); %finds the smallest error and its index.
        sel = choices{idx}; %grabs the best-matching electrolyte name that fits the parameter
       
        % find how much of the electrolyte i need using the standard mass
        % equation - so write a volume and concentration and then it'll
        % tell you the mass
        vol = str2double(volume_input.String);
        conc = str2double(conc_input.String);
        if isnan(vol) || isnan(conc)
            msgbox('Please enter valid numbers'); return;
        end
        mass = MW.(sel) * conc * vol / 1000;
        result = sprintf('Best Match: %s | Rel. Diff = %.2f%%\nRequired Mass: %.4f g', sel, rel_err*100, mass);

        
        result_box.String = result;
    end
end
