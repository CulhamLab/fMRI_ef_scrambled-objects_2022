close all
clear all

% Read stereo image pair - change as needed
I1 = imread("face_01_l.png"); % left
I2 = imread("face_01_r.png"); % right

% Convert to grayscale
I1gray = rgb2gray(I1);
I2gray = rgb2gray(I2);

% Create pair
figure(1);
imshowpair(I1, I2,"montage");
title("I1 (left); I2 (right)");

% Create anaglyph
figure(2); 
imshow(stereoAnaglyph(I1,I2));
title("Composite Image (Red - Left Image, Cyan - Right Image)");