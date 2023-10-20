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

error = false;

% Find object with aspect ratio (ar) > 2, not on any 4 image boundaries,
% and has largest area
[height, width] = size(clearBlobs);
p1 = regionprops(clearBlobs, 'BoundingBox', 'Area', 'Orientation', 'Eccentricity');
number_of_objects = length(p1);
if number_of_objects > 0
    candidates = false(1, number_of_objects);
    for n = 1:number_of_objects
        ar = p1(n).BoundingBox(3) / p1(n).BoundingBox(4);
        orientation = abs(p1(n).Orientation);  % Absolute value to consider tilted plates
        eccentricity = p1(n).Eccentricity;
        candidates(n) = ar > 2 && ...
                        p1(n).BoundingBox(1) > 10 && ...
                        p1(n).BoundingBox(2) > 10 && ...
                        (width - p1(n).BoundingBox(1) - p1(n).BoundingBox(3)) > 10 && ...
                        (height - p1(n).BoundingBox(2) - p1(n).BoundingBox(4)) > 10 && ...
                        orientation < 50 && ...  
                        eccentricity < 0.95;
    end
    if sum(candidates) >= 1
        areas = candidates .* [p1.Area];
        index = find(areas == max(areas));
        plateRegion = imcrop(RGB, p1(index(1)).BoundingBox);
        % Use index(1) in case there are > 1 object with largest area
    else
        error = true;
        disp('No suitable candidates found.');
    end
else
    error = true;
    disp('No objects detected.');
end

% Display Results
if error == true
    disp('Vehicle number plate not found. Project terminated');
end


%% ========================================================================

figure;
set(gcf, 'WindowState', 'maximized');

subplot(1,2,1);
imshow(clearBlobs);
title('Filtered Binary Image');

subplot(1,2,2);
if error==true
    imshow(RGB)
else 
    imshow(plateRegion)
end
title('Plate Extraction');

%% ========================================================================