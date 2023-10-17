%% ========================================================================
% START UP

% General clear and close
clear; close all; clc;

% Get user to select input image
% List of desired extensions and their descriptions
extensions = {...
    '*.jpg;*.jpeg;*.JPG;*.JPEG', 'JPEG Files (*.jpg, *.jpeg)'; ...
    '*.png;*.PNG', 'PNG Files (*.png)';
    };

[filename, filepath] = uigetfile(extensions, 'Select input image');
if filename == 0
    return;  % Exit if no file is selected
end
RGB = imread(fullfile(filepath, filename));

% Identify target answer from file name
[~, target, ~] = fileparts(filename);

%% ========================================================================
RGB = imresize(RGB,[650 nan]);

%% ========================================================================
grayImage = rgb2gray(RGB);

% Blurred Image Subtraction
blurredImage = imgaussfilt(grayImage, 2); % Gaussian blur with sigma = 2
differenceImage = imsubtract(blurredImage, grayImage);

% Increase contrast of blurred and subtracted image.
differenceImage = imadjust(differenceImage);

% Erode the difference image.
erodedImage = imerode(differenceImage,[1;1;1]);

% Perform morphological closing.
closedImage = imclose(erodedImage,strel('rectangle',[30,30]));

% Fill holes in the closed image.
filledImage = imfill(closedImage, 'holes');

% Binarise the filled image.
binaryImage = imbinarize(filledImage);

% Use a small structuring element to erode the image further to disconnect border components from central blobs.
se = strel('disk', 3); 
binaryImage = imerode(binaryImage, se);
binaryImage = imdilate(binaryImage, se);

% Clear border blobs from binary image.
borderClearedImage = imclearborder(binaryImage);

% Extract bounding boxes from the border cleared image.
bboxStats = regionprops(borderClearedImage, "BoundingBox");
bboxes = vertcat(bboxStats.BoundingBox);

% Draw bounding boxes on the original image
outputImageNoFilter = insertShape(RGB, "Rectangle", bboxes, "LineWidth", 2, "Color", "green");

% Compute the aspect ratio for each bounding box
widths = bboxes(:,3);
heights = bboxes(:,4);
aspectRatios = widths ./ heights;

% Define acceptable aspect ratio range for license plates
minAspectRatio = 2;
maxAspectRatio = 5;

% Set size limits (area of bounding box)
minArea = 1000; % minimum area
maxArea = 30000; % maximum area

% Filter bounding boxes based on aspect ratio and size
filterIdx = (aspectRatios < minAspectRatio) | ...
    (aspectRatios > maxAspectRatio) | ...
    (bboxes(:,3) .* bboxes(:,4) < minArea) | ...
    (bboxes(:,3) .* bboxes(:,4) > maxArea);

% Filter out very thin bounding boxes (long and thin)
heightToWidthRatioThreshold = 0.3;
thinBoxesIdx = (bboxes(:,4) ./ bboxes(:,3)) < heightToWidthRatioThreshold;

% Combine filters
filterIdx = filterIdx | thinBoxesIdx;

% Remove undesired bounding boxes
bboxes(filterIdx, :) = [];

% Draw bounding boxes on the original image
outputImageWithFilter = insertShape(RGB, "Rectangle", bboxes, "LineWidth", 2, "Color", "green");

%% ========================================================================

figure;
set(gcf, 'WindowState', 'maximized');

subplot(2,4,1);
imshow(erodedImage);
title('Eroded Image');

subplot(2,4,2);
imshow(closedImage);
title('Morphologically Closed Image');

subplot(2,4,3);
imshow(filledImage);
title('Closed Image with Holes Filled In');

subplot(2,4,4);
imshow(binaryImage);
title('Binarised Filled Image');

subplot(2,4,5);
imshow(borderClearedImage);
title('Binary Image Cleared of Border Blobs');

subplot(2,4,6);
imshow(outputImageNoFilter);
title('Possible Plate Regions');

subplot(2,4,7);
imshow(outputImageWithFilter);
title('Possible Plate Regions based on Aspect Ratio');

%% ========================================================================

% Detect MSER regions.
[mserRegions, mserConnComp] = detectMSERFeatures(differenceImage, ...
    "RegionAreaRange",[200 8000],"ThresholdDelta",4);

% Extract bounding boxes from the MSER regions
mserStats = regionprops(mserConnComp, "BoundingBox");
bboxes = vertcat(mserStats.BoundingBox);

% Draw bounding boxes on the original image
outputImageNoFilter = insertShape(RGB, "Rectangle", bboxes, "LineWidth", 2, "Color", "green");

%% ========================================================================

% Compute the aspect ratio for each bounding box
widths = bboxes(:,3);
heights = bboxes(:,4);
aspectRatios = widths ./ heights;

% Define acceptable aspect ratio range for license plates
minAspectRatio = 2;
maxAspectRatio = 5;

% Set size limits (area of bounding box)
minArea = 2500; % minimum area
maxArea = 30000; % maximum area

% Filter bounding boxes based on aspect ratio and size
filterIdx = (aspectRatios < minAspectRatio) | ...
    (aspectRatios > maxAspectRatio) | ...
    (bboxes(:,3) .* bboxes(:,4) < minArea) | ...
    (bboxes(:,3) .* bboxes(:,4) > maxArea);

% Filter out very thin bounding boxes (long and thin)
heightToWidthRatioThreshold = 0.3;
thinBoxesIdx = (bboxes(:,4) ./ bboxes(:,3)) < heightToWidthRatioThreshold;

% Combine filters
filterIdx = filterIdx | thinBoxesIdx;

% Remove undesired bounding boxes
bboxes(filterIdx, :) = [];

% Find and merge nested or overlapping bounding boxes
i = 1;
while i <= size(bboxes, 1)
    j = i + 1;
    while j <= size(bboxes, 1)
        overlapRatio = bboxOverlapRatio(bboxes(i,:), bboxes(j,:));
        
        % Check for significant overlap or touching
        if overlapRatio > 0.2 || overlapRatio == 0 && any(rectint(bboxes(i,:), bboxes(j,:)))
            
            % Merge the bounding boxes
            xMin = min(bboxes(i,1), bboxes(j,1));
            yMin = min(bboxes(i,2), bboxes(j,2));
            xMax = max(bboxes(i,1) + bboxes(i,3), bboxes(j,1) + bboxes(j,3));
            yMax = max(bboxes(i,2) + bboxes(i,4), bboxes(j,2) + bboxes(j,4));
            
            bboxes(i,:) = [xMin, yMin, xMax - xMin, yMax - yMin];
            bboxes(j,:) = [];
        else
            j = j + 1;
        end
    end
    i = i + 1;
end

% Draw bounding boxes on the original image
outputImageWithFilter = insertShape(RGB, "Rectangle", bboxes, "LineWidth", 2, "Color", "red");

%% ========================================================================

filteredBboxes = [];  % Array to store bounding boxes that pass histogram analysis

for i = 1:size(bboxes,1)
    % Extract the region corresponding to the bounding box
    region = imcrop(differenceImage, bboxes(i,:));
    
    % Compute the vertical and horizontal histograms
    verticalHistogram = sum(region, 2);
    horizontalHistogram = sum(region, 1);
    
    % Analyze the histograms (you can set your own conditions based on your observations)
    % For example, let's set a condition that the top and bottom 10% should have
    % significantly higher values than the middle part for the vertical histogram.
    topBottomSum = sum(verticalHistogram(1:round(end*0.1))) + sum(verticalHistogram(round(end*0.9):end));
    middleSum = sum(verticalHistogram(round(end*0.1):round(end*0.9)));
    
    if topBottomSum > 1.5 * middleSum
        % This is a simple condition, and you might need more sophisticated analysis
        % depending on the characteristics of your images and license plates.
        filteredBboxes = [filteredBboxes; bboxes(i,:)];
    end
end

% Draw the filtered bounding boxes on the image
outputImageWithHistogramAnalysis = insertShape(RGB, "Rectangle", filteredBboxes, "LineWidth", 2, "Color", "yellow");

%% ========================================================================

figure

% Maximize the figure window
set(gcf, 'WindowState', 'maximized');

subplot(2,3,1);
imshow(RGB);
hold on;
plot(mserRegions, "showPixelList", true,"showEllipses",false);
title("MSER regions");
hold off;

subplot(2,3,2);
imshow(differenceImage);
title("Blurred and Subtracted Image");
hold off;

subplot(2,3,3);
imshow(outputImageNoFilter);
title("All Possible Plate Regions");
hold off;

subplot(2,3,4);
imshow(outputImageWithFilter);
title("Filtered Plate Regions");
hold off;

subplot(2,3,5);
imshow(outputImageWithHistogramAnalysis);
title("Filtered Plate Region With Histogram Analysis");
hold off;

%% ========================================================================