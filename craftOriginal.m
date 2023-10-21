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

Iout = insertShape(RGB, "rectangle", bbox, LineWidth=4);

grayImage = im2gray(RGB);
binaryImage = imbinarize(grayImage);
complementImage = imcomplement(binaryImage);

output = ocr(complementImage, bbox, LayoutAnalysis="Word");

recognizedWords = cat(1, output(:).Words);

% Display the original image with bounding boxes
figure;
imshow(Iout);
title('Original Image with Bounding Boxes');

%% ========================================================================
