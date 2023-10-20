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

% Convert image to gray scale.
grayImage = rgb2gray(RGB);

% Using median filtering on grayscale image.
grayImage = medfilt2(grayImage);                                                                            

% Blurred Image Subtraction
blurredImage = imgaussfilt(grayImage, 2); % Gaussian blur with sigma = 2
differenceImage = imsubtract(blurredImage, grayImage);

% Increase contrast of blurred and subtracted image.
differenceImage = imadjust(differenceImage);

% Create a structuring element (SE).
se = strel('disk', 4);

% Dilate difference image using the SE.
dilatedImage = imdilate(differenceImage, se);

% Binarize the dilated image.
binaryImage = imbinarize(dilatedImage);

% Erode the dilated image.
erodedImage = imerode(binaryImage, se);

% Fill eroded images.
filledImage = imfill(erodedImage, 'holes');

% Remove border components.
clearedImage = imclearborder(filledImage);

% Clear small blobs.
clearBlobs = bwareaopen(clearedImage, 500);

%% ========================================================================

% Blob analysis
cc = bwconncomp(clearBlobs);
stats = regionprops(cc, 'Area');
areaThreshold = 500; % Adjust this value based on the expected size of meaningful blobs
idx = find([stats.Area] > areaThreshold);
filteredImage = ismember(labelmatrix(cc), idx);

% Apply edge detection on filtered image
edges = edge(clearBlobs, 'Canny');

% Use the Hough transform to detect lines
[H, theta, rho] = hough(edges);
peaks = houghpeaks(H, 50, 'Threshold', 0.3*max(H(:)));
lines = houghlines(edges, theta, rho, peaks);

% Analyze the orientation of lines to detect tilt
angles = [lines.theta];
mean_angle = mean(angles);

if abs(mean_angle) < 3  % Threshold for straight image
    disp('Image tile does not need to be corrected');
    tilt = "straight";
    correctedImage = RGB; % No tilt correction needed
elseif mean_angle > 0
    disp('Image is tilted to the right');
    tilt = "right-tilted";
    correctedImage = imrotate(RGB, -mean_angle, 'bicubic', 'crop'); % Rotate to correct tilt
else
    disp('Image is tilted to the left');
    tilt = "left-tilted";
    correctedImage = imrotate(RGB, -mean_angle, 'bicubic', 'crop'); % Rotate to correct tilt
end

%% ========================================================================

figure;
set(gcf, 'WindowState', 'maximized');

% Display the original and corrected images side by side
subplot(1, 2, 1);
imshow(RGB), hold on;
title('Original Image');

% Superimpose the detected lines on the original image
for k = 1:length(lines)
    xy = [lines(k).point1; lines(k).point2];
    line(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', [1 0 0]); % Red color for the lines
end
hold off;

subplot(1, 2, 2);
imshow(correctedImage);
title(sprintf('Corrected Image (%s)', tilt));

%% ========================================================================
