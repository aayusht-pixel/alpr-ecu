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

% Extract regions from grayscale image corresponding to clearBlobs locations.

% Find connected components in the binary image
cc = bwconncomp(clearBlobs);

% Extract regions from the RGB image
blobs = cell(1, cc.NumObjects);
for i = 1:cc.NumObjects
    % Create a binary mask for each blob
    mask = false(size(clearBlobs));
    mask(cc.PixelIdxList{i}) = true;
    
    % Extract the corresponding region from the RGB image
    blobRGB = RGB;
    for c = 1:3
        channel = blobRGB(:,:,c);
        channel(~mask) = 0;
        blobRGB(:,:,c) = channel;
    end
    
    blobs{i} = blobRGB;
end

% Display the extracted regions
figure;
set(gcf, 'WindowState', 'maximized');
for i = 1:length(blobs)
    subplot(ceil(sqrt(length(blobs))), ceil(sqrt(length(blobs))), i);
    imshow(blobs{i});
    title(['Blob ' num2str(i)]);
end
title ('Probable Plate Areas in the RGB Image')


%% ========================================================================

figure;
set(gcf, 'WindowState', 'maximized');

subplot(2,2,1);
imshow(differenceImage);
title('Difference Image');

subplot(2,2,2);
imshow(binaryImage);
title('Binarized Image');

subplot(2,2,3);
imshow(clearedImage);
title('Removed Border Components');

subplot(2,2,4);
imshow(clearBlobs);
title('Removed Small Blobs');

%% ========================================================================