%% ========================================================================
% -------------------------------------------------------------------------
% START UP
% -------------------------------------------------------------------------
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

bbox = detectTextCRAFT(RGB, CharacterThreshold=0.3);

% Define distance threshold for merging bounding boxes
distanceThreshold = 100;

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

%% ========================================================================
figure;
set(gcf, 'WindowState', 'maximized');

subplot(1,2,1);
imshow(rgbOutOriginal);
title('Original Image with Original Bounding Boxes');

subplot(1,2,2);
imshow(rgbOutMerged);
title('Original Image with Merged Bounding Boxes');

%% ========================================================================

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


% Function to check if two bounding boxes are close to each other
function isClose = isClose(bbox1, bbox2, threshold)
    x1 = bbox1(1) + bbox1(3) / 2;
    y1 = bbox1(2) + bbox1(4) / 2;
    x2 = bbox2(1) + bbox2(3) / 2;
    y2 = bbox2(2) + bbox2(4) / 2;
    distance = sqrt((x2 - x1)^2 + (y2 - y1)^2);
    isClose = distance < threshold;
end

% Function to merge two bounding boxes
function mergedBbox = mergeTwoBoundingBoxes(bbox1, bbox2)
    x1 = min(bbox1(1), bbox2(1));
    y1 = min(bbox1(2), bbox2(2));
    x2 = max(bbox1(1) + bbox1(3), bbox2(1) + bbox2(3));
    y2 = max(bbox1(2) + bbox1(4), bbox2(2) + bbox2(4));
    mergedBbox = [x1, y1, x2 - x1, y2 - y1];
end

%% ========================================================================
