%% ========================================================================imageimaima
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

% Convert image to gray scale.
grayImage = rgb2gray(RGB);

%% ========================================================================

[mserRegions, mserConnComp] = detectMSERFeatures(grayImage, ...
    'RegionAreaRange', [200 8000], 'ThresholdDelta', 4);


%% ------------------------------------------------------------------------

% Step 2: Remove Non-Text Regions Based On Basic Geometric Properties
mserStats = regionprops(mserConnComp, 'BoundingBox', 'Eccentricity', ...
    'Solidity', 'Extent', 'Euler', 'Image');

bbox = vertcat(mserStats.BoundingBox);
w = bbox(:, 3);
h = bbox(:, 4);
aspectRatio = w ./ h;

filterIdx = aspectRatio' > 3;
filterIdx = filterIdx | [mserStats.Eccentricity] > .995;
filterIdx = filterIdx | [mserStats.Solidity] < .3;
filterIdx = filterIdx | [mserStats.Extent] < 0.2 | [mserStats.Extent] > 0.9;
filterIdx = filterIdx | [mserStats.EulerNumber] < -4;

mserStats(filterIdx) = [];
mserRegions(filterIdx) = [];

%% ------------------------------------------------------------------------

% Step 3: Remove Non-Text Regions Based On Stroke Width Variation
strokeWidthThreshold = 0.4;
for j = 1:numel(mserStats)
    regionImage = mserStats(j).Image;
    regionImage = padarray(regionImage, [1 1], 0);

    distanceImage = bwdist(~regionImage);
    skeletonImage = bwmorph(regionImage, 'thin', inf);

    strokeWidthValues = distanceImage(skeletonImage);

    strokeWidthMetric = std(strokeWidthValues) / mean(strokeWidthValues);

    strokeWidthFilterIdx(j) = strokeWidthMetric > strokeWidthThreshold;
end

mserRegions(strokeWidthFilterIdx) = [];
mserStats(strokeWidthFilterIdx) = [];

%% ------------------------------------------------------------------------

% Step 4: Merge Text Regions For Final Detection Result
bboxes = vertcat(mserStats.BoundingBox);
xmin = bboxes(:, 1);
ymin = bboxes(:, 2);
xmax = xmin + bboxes(:, 3) - 1;
ymax = ymin + bboxes(:, 4) - 1;

expansionAmount = 0.1;
xmin = (1 - expansionAmount) * xmin;
ymin = (1 - expansionAmount) * ymin;
xmax = (1 + expansionAmount) * xmax;
ymax = (1 + expansionAmount) * ymax;

xmin = max(xmin, 1);
ymin = max(ymin, 1);
xmax = min(xmax, size(grayImage, 2));
ymax = min(ymax, size(grayImage, 1));

expandedBBoxes = [xmin ymin xmax - xmin + 1 ymax - ymin + 1];
grayImageExpandedBBoxes = insertShape(RGB, 'rectangle', expandedBBoxes, 'LineWidth', 3, 'Color', 'green');

overlapRatio = bboxOverlapRatio(expandedBBoxes, expandedBBoxes);
n = size(overlapRatio, 1);
overlapRatio(1:n + 1:n^2) = 0;

g = graph(overlapRatio);
componentIndices = conncomp(g);

xmin = accumarray(componentIndices', xmin, [], @min);
ymin = accumarray(componentIndices', ymin, [], @min);
xmax = accumarray(componentIndices', xmax, [], @max);
ymax = accumarray(componentIndices', ymax, [], @max);

textBBoxes = [xmin ymin xmax - xmin + 1 ymax - ymin + 1];

numRegionsInGroup = histcounts(componentIndices);
textBBoxes(numRegionsInGroup == 1, :) = [];

grayImageTextRegion = insertShape(RGB, 'rectangle', textBBoxes, 'LineWidth', 3, 'Color', 'green');

%% ------------------------------------------------------------------------

% Step 5: Recognize Detected Text Using OCR
ocrtxt = ocr(grayImage, textBBoxes);
[ocrtxt.Text]

%% ========================================================================

figure;
set(gcf, 'WindowState', 'maximized');

subplot(2,3,1);
imshow(grayImage);
hold on;
plot(mserRegions, 'showPixelList', true, 'showEllipses', false);
title('MSER regions');
hold off;

subplot(2,3,2);
imshow(grayImage);
hold on;
plot(mserRegions, 'showPixelList', true, 'showEllipses', false);
title('After Removing Non-Text Regions Based On Geometric Properties');
hold off;

subplot(2,3,3);
imshow(grayImage);
hold on;
plot(mserRegions, 'showPixelList', true, 'showEllipses', false);
title('After Removing Non-Text Regions Based On Stroke Width Variation');
hold off;

subplot(2,3,4);
imshow(grayImageExpandedBBoxes);
title('Expanded Bounding Boxes Text');

subplot(2,3,5);
imshow(grayImageTextRegion);
title('Detected Text');

%% ========================================================================
