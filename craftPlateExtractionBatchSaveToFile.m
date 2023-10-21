%% ========================================================================
% START UP

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

% Define the name of the text file where the results will be stored
resultsFile = 'testing_front_incorrect_extractions.txt';

for k = 1:totalImages
    try
        % Load image
        filename = imageFiles(k).name;
        RGB = imread(fullfile(folderpath, filename));
        %% ========================================================================

        RGB = imresize(RGB,[650 nan]);

        %% ========================================================================

        bbox = detectTextCRAFT(RGB, CharacterThreshold=0.3);

        % Define distance threshold for merging bounding boxes
        distanceThreshold = 125;

        % Display the original image with original bounding boxes
        rgbOutOriginal = insertShape(RGB, "rectangle", bbox, LineWidth=4, Color="red");

        % Merge close bounding boxes
        mergedBbox = mergeBoundingBoxes(bbox, distanceThreshold);

        % Create gray and complement images
        grayImage = im2gray(RGB);
        binaryImage = imbinarize(grayImage);
        complementImage = imcomplement(binaryImage);

        % Perform OCR with merged bounding boxes
        output = ocr(complementImage, mergedBbox, LayoutAnalysis="Word");
        recognizedWords = cat(1, output(:).Words);

        % Display the original image with merged bounding boxes
        rgbOutMerged = insertShape(RGB, "rectangle", mergedBbox, LineWidth=4, Color="green");

        % Licence plate detection
        licencePlateBbox = detectLicencePlate(RGB, mergedBbox);

        % Display the original image with licence plate bounding box
        rgbOutLicencePlate = insertShape(RGB, "rectangle", licencePlateBbox, LineWidth=4, Color="blue");

        %% ========================================================================

        figure;
        set(gcf, 'WindowState', 'maximized');

        subplot(2,2,1);
        imshow(rgbOutOriginal);
        title('Original Image with Original Bounding Boxes');

        subplot(2,2,2);
        imshow(rgbOutMerged);
        title('Original Image with Merged Bounding Boxes');

        subplot(2,2,3);
        imshow(rgbOutLicencePlate);
        title('Original Image with Licence Plate Bounding Box');

        % Crop the final bounding box from the RGB image
        if ~isempty(licencePlateBbox)
            licencePlateImage = imcrop(RGB, licencePlateBbox);
            subplot(2,2,4);
            imshow(licencePlateImage);
            title('Extraced Licence Plate Region');
        end

        %% ========================================================================

        % Prompt user for confirmation
        button = questdlg('Was the plate area detected correctly?', ...
            'Confirmation', ...
            'Yes', 'No', 'Yes');
        switch button
            case 'Yes'
                correctGuesses = correctGuesses + 1;
            case 'No'

                % Open the text file in append mode
                fid = fopen(resultsFile, 'a');
                
                % Write the filename to the text file
                fprintf(fid, '%s\n', filename);
                
                % Close the text file
                fclose(fid);

        end

    catch ME
        % Error handling: display error message and move to next image
        warning(['Error processing image: ' filename '. Message: ' ME.message]);

        % Open the text file in append mode
        fid = fopen(resultsFile, 'a');
                
        % Write the filename to the text file
        fprintf(fid, '%s\n', filename);
        
        % Close the text file
        fclose(fid);

        continue;
    end

close all; % Close all open figures
end

% Display accuracy
accuracy = (correctGuesses / totalImages) * 100;
disp(['Accuracy: ' num2str(accuracy) '%']);

%% ========================================================================
% -------------------------------------------------------------------------

% Function to merge bounding boxes that are close to each other
function mergedBbox = mergeBoundingBoxes(bbox, threshold)
    mergedBbox = bbox;
    i = 1;
    while i <= size(mergedBbox, 1)
        merged = false;
        for j = 1:size(mergedBbox, 1)
            if i ~= j && isClose(mergedBbox(i, :), mergedBbox(j, :), threshold)
                mergedBbox(i, :) = mergeTwoBoundingBoxes(mergedBbox(i, :), mergedBbox(j, :));
                mergedBbox(j, :) = [];
                merged = true;
                break;
            end
        end
        if ~merged
            i = i + 1;
        end
    end
end

% -------------------------------------------------------------------------

% Function to check if two bounding boxes are close to each other
function isClose = isClose(bbox1, bbox2, threshold)
    x1 = bbox1(1) + bbox1(3) / 2;
    y1 = bbox1(2) + bbox1(4) / 2;
    x2 = bbox2(1) + bbox2(3) / 2;
    y2 = bbox2(2) + bbox2(4) / 2;
    distance = sqrt((x2 - x1)^2 + (y2 - y1)^2);
    isClose = distance < threshold;
end

% -------------------------------------------------------------------------

% Function to merge two bounding boxes
function mergedBbox = mergeTwoBoundingBoxes(bbox1, bbox2)
    x1 = min(bbox1(1), bbox2(1));
    y1 = min(bbox1(2), bbox2(2));
    x2 = max(bbox1(1) + bbox1(3), bbox2(1) + bbox2(3));
    y2 = max(bbox1(2) + bbox1(4), bbox2(2) + bbox2(4));
    mergedBbox = [x1, y1, x2 - x1, y2 - y1];
end

% -------------------------------------------------------------------------

% Function to detect licence plate
function licencePlateBbox = detectLicencePlate(RGB, bbox)
    numBboxes = size(bbox, 1);
    bestScore = 0;
    padding = 20;
    licencePlateBbox = [];
    for i = 1:numBboxes
        % Extract region of interest
        roi = imcrop(RGB, bbox(i,:));

        % Convert to grayscale
        gray = rgb2gray(roi);

        % Measure licence plate criteria
        score = measureLicencePlateCriteria(gray, bbox(i,:));

        % Update best matching bounding box
        if score > bestScore
            bestScore = score;
            licencePlateBbox = bbox(i,:);
        end
    end

    % Add padding to the final bounding box
    if ~isempty(licencePlateBbox)
        licencePlateBbox(1) = max(1, licencePlateBbox(1) - padding);
        licencePlateBbox(2) = max(1, licencePlateBbox(2) - padding);
        licencePlateBbox(3) = min(size(RGB, 2), licencePlateBbox(3) + 2 * padding);
        licencePlateBbox(4) = min(size(RGB, 1), licencePlateBbox(4) + 2 * padding);
    end
end

% -------------------------------------------------------------------------

% Function to measure licence plate criteria
function score = measureLicencePlateCriteria(gray, bbox)
    % Aspect Ratio
    aspectRatio = size(gray, 2) / size(gray, 1);
    expectedAspectRatio = 2;
    aspectRatioScore = 1 / (1 + abs(aspectRatio - expectedAspectRatio));
    
    % Character Recognition
    ocrResults = ocr(gray);
    numCharacters = length(ocrResults.Text);
    characterScore = numCharacters;
    
    % Size
    sizeScore = bbox(3) * bbox(4); % Area of the bounding box
    
    % Compute score based on criteria
    score = aspectRatioScore + characterScore + sizeScore;
end

% -------------------------------------------------------------------------

%% ========================================================================
