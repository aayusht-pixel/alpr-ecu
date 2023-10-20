%% ================================================================================================================================================
% START UP

% Global command to turn figures off.
set(0, 'DefaultFigureVisible', 'off');

% General clear and close
clear; close all; clc;

% Get user to select input folder
folderpath = uigetdir('', 'Select the folder containing images');

% Specify the folder where the images are located
imageFolder = folderpath;

% Get a list of all image files in the folder with different extensions
extensions = {'*.jpeg', '*.jpg', '*.png', '*.JPEG', '*.JPG', '*.PNG'};
imageFiles = [];
for i = 1:length(extensions)
    newFiles = dir(fullfile(imageFolder, extensions{i}));
    for j = 1:length(newFiles)
        if isempty(imageFiles)
            imageFiles = newFiles(j);
        else
            lowerCaseNames = lower({imageFiles.name});
            if ~ismember(lower(newFiles(j).name), lowerCaseNames)
                imageFiles = [imageFiles; newFiles(j)];
            end
        end
    end
end

totalImages = length(imageFiles);
if totalImages == 0
    error('No images found in the specified directory.');
end

correctGuesses = 0;

for k = 1:totalImages
    try
        % Load image
        filename = imageFiles(k).name;
        RGB = imread(fullfile(folderpath, filename));

        % Identify target answer from file name
        [~, target, ~] = fileparts(filename);

        % Start timer
        tic;
                
        %% ================================================================================================================================================
        % STAGE 1 - PLATE EXTRACTION
        % Input Variable: RGB
        % --------------------------------------------------------------------------------------------------------------------------------------------------
        error = false;

        % Pre-process input image
        RGB = imresize(RGB,[650 nan]);                                
        I1 = rgb2gray(RGB);
        I2 = imadjust(I1,[0.3,0.7],[]);                          
        I3 = medfilt2(I2);                                                                            

        % Perform edge detection and then clean up using morphological operations
        I4 = edge(I3,'roberts',0.25,'both');                      
        I5 = imerode(I4,[1;1;1]);
        I6 = imclose(I5,strel('rectangle',[30,30]));
        I7 = bwareaopen(I6,1000); % To remove small objects
        I8 = imdilate(I7,ones(1,40));

        % Find object with aspect ratio (ar) > 2, not on any 4 image boundaries,
        % and has largest area
        [height,width] = size(I8);
        p1 = regionprops(I8,'BoundingBox','Area');
        number_of_objects = length(p1);
        if number_of_objects>0
            candidates = false(1,number_of_objects);
            for n = 1:number_of_objects
                ar = p1(n).BoundingBox(3) / p1(n).BoundingBox(4);
                candidates(n) = ar>2 && p1(n).BoundingBox(1)>10 && ...
                    p1(n).BoundingBox(2)>10 && ...
                    (width - p1(n).BoundingBox(1) - p1(n).BoundingBox(3)) > 10 ...
                    && (height - p1(n).BoundingBox(2) - p1(n).BoundingBox(4)) > 10;
            end
            if sum(candidates)>=1
                areas = candidates .* [p1.Area];
                index = find(areas==max(areas));
                RGB1 = imcrop(RGB,p1(index(1)).BoundingBox);
                % Use index(1) in case there are > 1 object with largest area
            else
                error = true;
                disp('No suitable candidates found.');
                continue;
            end
        else
            error = true;
            disp('No objects detected.');
            continue;
        end

        % Display Results
        if error==true
            disp('Vehicle number plate not found. Project terminated');
            return;
        end
        % figure(1),imshow(RGB1),title('Plate Extraction');

        % Stop timer
        time_taken = toc;
        disp(['Stage 1 - Total time taken = ' num2str(time_taken) ' seconds.']);

        tic;
        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % Output Variable: RGB1

        %% ================================================================================================================================================
        % STAGE 2 - CHARACTER SEGMENTATION
        % Input Variable: RGB1
        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % Pre-process the input from Stage 1 by removing any small writings and
        % other objects that wrap around the plate, and then crop image.
        J1 = im2bw(RGB1,graythresh(RGB1));
        J2 = bwareaopen(J1, floor(0.15*numel(J1)) );
        p2 = regionprops(J2,'BoundingBox');
        RGB2 = imcrop(RGB1,p2.BoundingBox);
        J3 = imcrop(J2,p2.BoundingBox);

        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % Crop plate area using horizontal projection
        [height,width] = size(J3);
        Black_y = sum(J3==0,2);

        % Calculate mid-point in y direction
        mid_height = fix(height/2);

        % Move upwards from mid-point until it reaches a row that is all black
        % (i.e. top boundary of plate)
        PY1 = mid_height;
        while ( Black_y(PY1,1)>=1 && (PY1>1) )
            PY1 = PY1 - 1;
        end

        % Move downwards from mid-point until it reaches a row that is all black
        % (i.e. bottom boundary of plate)
        PY2 = mid_height;
        while ( Black_y(PY2,1)>=1 && (PY2<height) )
            PY2 = PY2 + 1;
        end

        % If the last row is all black, then convert it to all white
        if Black_y(PY2,1)==width
            J3(PY2,:) = 1;
        end             

        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % Crop plate area using vertical project with peak detection
        White_x = sum(J3); 
        [pks, locs] = findpeaks(White_x);
        PX1 = locs(1);

        % Find the falling edge of the first peak
        while(White_x(PX1)==White_x(PX1+1))
            PX1 = PX1 + 1;
        end
        % Find the last peak
        PX2 = locs(end);

        % Crop the plate area further
        RGB2 = RGB2(PY1:PY2,PX1:PX2,:);
        RGB2 = imresize(RGB2,[120 nan]);

        % Binarise plate area
        J4 = im2bw(RGB2,graythresh(RGB2));

        % Obtain dimensions
        [height,width] = size(J4);
        mid_height = fix(height/2);
        threshold = 0.8*width;

        % Create horizontal and vertical boundaries
        J4(1,:) = 1;
        J4(height,:) = 1;
        J4(:,1) = 1;
        J4(:,width) = 1;
        J4(:,width-1) = 1; % Extra boundary on right side

        % Noise Clean Up in horizontal direction
        Black_y = sum(J4==0,2);

        % Move upwards from mid-point until there are <= 10 black pixels
        PY1 = mid_height;
        while ( PY1>1 && Black_y(PY1,1)>10 )
            PY1 = PY1 - 1;
            if Black_y(PY1,1)>=threshold
                J4(PY1,:) = 1;
            end
        end
        % Convert all rows above PY1 to white
        J4(1:PY1,:) = 1;

        % Move downwards from mid-point until there are <= 10 black pixels
        PY2 = mid_height;
        while ( PY2<height && Black_y(PY2,1)>10 )
            PY2 = PY2 + 1;
            if Black_y(PY2,1)>=threshold
                J4(PY2,:) = 1;
            end
        end
        % Convert all rows below PY2 to white
        J4(PY2:end,:) = 1;

        % Noise clean up vertically in x-direction by converting any columns with
        % <= 7 black pixels to entirely white
        Black_x = sum(J4==0);
        mask = (Black_x<=7);
        J4(:,mask) = 1;

        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % Outline characters
        J4 = ~bwareaopen(~J4,500); 
        se = strel('disk',1); 
        hi = imdilate(J4,se);
        he = imerode(J4,se); 
        hdiff = imsubtract(hi,he);
        hdiff = imadjust(hdiff,[0.2 0.8],[0 1],0.1);
        J4 = logical(hdiff); 

        % Character Isolation Process
        er = imerode(J4,strel('line',70,0));
        J4 = imsubtract(J4,er);
        J4 = imfill(J4,'holes');
        J4 = bwmorph(J4,'thin',1);
        J4 = imerode(J4,strel('line',3,90));
        J4 = bwareaopen(J4,500);

        % Character Detection
        p3 = regionprops(J4,'BoundingBox');
        number_of_characters = length(p3);
        Ch = cell(1,number_of_characters); % uint8
        CH = cell(1,number_of_characters); % logical
        for n=1:number_of_characters
            Ch{n} = imresize(imcrop(RGB2,p3(n).BoundingBox),[100 50]);
            CH{n} = im2bw(Ch{n},graythresh(Ch{n}));
            CH{n} = ~CH{n};
        %   figure(2); subplot(1,number_of_characters,n),imshow(CH{n})
        end

        % Stop timer
        time_taken = toc;
        disp(['Stage 2 - Total time taken = ' num2str(time_taken) ' seconds.']);

        tic
        %% ================================================================================================================================================
        % STAGE 3 - CHARACTER RECOGNITION
        % Input Variable: CH
        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % Read Character Templates
        load Templates.mat

        % Initialise
        answers = blanks(number_of_characters); 

        % Correlation Coefficients Comparison
        for m = 1:number_of_characters
            pair = zeros(1,36);
            for n = 1:36
                pair(n) = corr2( CH{m}, Templates.Image{n} );
            end
            index = find(pair==max(pair));
                
            % Distinguish Ambiguous Characters
            % Between O (15), Q (17) and 0 (36)
            if ( index==15 || index==17 || index==36 )
                %Bottom Right Half Part
                OBH = Templates.Image{15}(67:99,26:50);
                QBH = Templates.Image{17}(67:99,26:50);
                ZEROBH = Templates.Image{36}(67:99,26:50);
                CHARBH = {OBH, QBH, ZEROBH};
                charbh = CH{m}(67:99,26:50);
                pair1 = zeros(1,3);
                for n = 1:3
                    pair1(n) = corr2(charbh,CHARBH{n});
                end
                no1 = find(pair1==max(pair1));
                if no1==2
                    index = 17; % Character is Q
                else
        %             OM = Templates.Image{15}(33:66,:);
        %             ZEROM = Templates.Image{36}(33:66,:);
                    OM = Templates.Image{15};
                    ZEROM = Templates.Image{36};
                    
                    Schar={OM, ZEROM};
                    %CHARM = CH{m}(33:66,:);
                    CHARM = CH{m};
                    pair11 = zeros(1,2);
                    for n = 1:2
                        pair11(n) = corr2(CHARM,Schar{n});
                    end
                    no11 = find(pair11==max(pair11));
                    if no11==1
                        index = 15;
                    else
                        index = 36;
                    end
                end
            end
            
            % Distinguish Ambiguous Characters
            % Between I (9), T (20) and 1 (27)
            if ( index==9 || index==20 || index==27 )
                IH = Templates.Image{9}(1:33,1:25);
                TH = Templates.Image{20}(1:33,1:25);
                ONEH = Templates.Image{27}(1:33,1:25);
                CHARH = {IH, TH, ONEH};
                charth = CH{m}(1:33,1:25);
                pair2 = zeros(1,3);
                for n = 1:3
                    pair2(n) = corr2(charth,CHARH{n});
                end
                no2 = find(pair2==max(pair2));
                if no2==3
                    index = 27;
                else
                    IB = Templates.Image{9}(67:99,:);
                    TB = Templates.Image{20}(67:99,:);
                    CHARB = {IB, TB};
                    charb = CH{m}(67:99,:);
                    pair22 = zeros(1,2);
                    for n = 1:2
                        pair22(n) = corr2(charb,CHARB{n});
                    end
                    no22 = find(pair22==max(pair22));
                    if no22==1
                        index = 9;
                    else
                        index = 20;
                    end
                end
            end
            
            % Distinguish Ambiguous Characters
            % Between Z (26) and 2 (28)
            if ( index==26 || index==28 )
                ZH = Templates.Image{26}(1:33,1:25);
                TWOH = Templates.Image{28}(1:33,1:25);
                CHARH = {ZH, TWOH};
                charth = CH{m}(1:33,1:25);
                pair3 = zeros(1,2);
                for n = 1:2
                    pair3(n) = corr2(charth,CHARH{n});
                end
                no3 = find(pair3==max(pair3));
                if no3==1
                    index = 26;
                else
                    index = 28;
                end
            end
            
            % Distinguish Ambiguous Characters
            % Between C (3) and E (5)
            if ( index==3 || index==5 )
                CM = Templates.Image{3}(1:50,:);
                EM = Templates.Image{5}(1:50,:);
                CHARH = {CM, EM};
                charth = CH{m}(1:50,:);
                pair4 = zeros(1,2);
                for n = 1:2
                    pair4(n) = corr2(charth,CHARH{n});
                end
                no4 = find(pair4==max(pair4));
                if no4==1
                    index = 3;
                else
                    index = 5;
                end
            end
            
            answers(m) = char(Templates.Name(index));
            
        % --------------------------------------------------------------------------------------------------------------------------------------------------
        % Output Variable: answers
            
        end

        %% ================================================================================================================================================
        % Stop timer
        time_taken = toc;

        disp(['Stage 3 - Total time taken = ' num2str(time_taken) ' seconds.']);

        % Display results
        disp(['Answer: ' answers]);
        disp(['Target: ' target]);

        if strcmp(answers,target)
            disp('Recognition is correct.');
            correctGuesses = correctGuesses + 1;
        else
            disp('Recognition is incorrect.');
        end

        %% ================================================================================================================================================
        % Print answer to file

        % result = fopen('FinalCharacters.txt', 'wt'); 
        % fprintf(result,'%s\n',fc);      
        % fclose(result);                      
        % winopen('FinalCharacters.txt')

        %% ================================================================================================================================================
    catch ME
        % Error handling: display error message and move to next image
        warning(['Error processing image: ' filename '. Message: ' ME.message]);
        continue;
    end
end

%% ================================================================================================================================================

% Calculate and display accuracy
accuracy = (correctGuesses / totalImages) * 100;
disp(['Accuracy: ' num2str(accuracy) '%']);

%% ================================================================================================================================================