%% Get the timestamps
% Load photodiode and frame time stamps
[SYNCFilename,SYNCPathname] = uigetfile('*.txt', 'Select the SYNC file');
timeStamps = importdata(strcat(SYNCPathname,SYNCFilename));

% Pull out the time stamps for the frame grab signal
tFrameGrab = find(diff(timeStamps(:,1))>max(diff(timeStamps(:,1)))/2);
framerate = 5000/mean(diff(tFrameGrab));

% Pull out the time stamps for the VR refresh
clear tVR;
sampleData = 1;
upperLim = max(timeStamps(:,2));
offset = round(0.8/(360)*10000);
startVR = find(timeStamps(:,2) > 0.9*upperLim);
incDat = startVR(1)-2;
inct = 1;
while (sampleData)
    if (timeStamps(incDat+1,2) < 0.9*upperLim && timeStamps(incDat-2,2) < timeStamps(incDat+1,2))
        tVR(inct) = incDat+1;
        inct = inct +1;
        incDat = incDat + offset;
    end
    incDat=incDat+1;
    if incDat > length(timeStamps)
        break
    end
end

figure;
plot(timeStamps(:,2));
xlim([tVR(1)-200 tVR(1)+800]);
hold on;
scatter(tVR,upperLim*0.9+zeros(length(tVR),1),'r');

%% Load the positional info
[posFilename posPathname] = uigetfile('*.txt', 'Select the position file');
fileID = fopen(strcat(posPathname,posFilename));
tstamp = fgetl(fileID);
formatSpec = '%s %f %s %f %s %f %s %f %s %f %s %f %s %d %s %d %s %d %s %d';
N=400000;
C = textscan(fileID,formatSpec,N,'CommentStyle','Current','Delimiter','\t');
t = C{1,2}; % Time
OffsetRot = C{1,4}; % Stripe rotational offset
OffsetRot = mod(OffsetRot+180, 360)-180;
OffsetFor = C{1,6}; % Stripe forward offset
OffsetLat = C{1,8}; % Stripe lateral offset
dx0 = C{1,10}; % X position of the ball from camera 1 
dx1 = C{1,12}; % X position of the ball from camera 2
dy0 = C{1,14};
dy1 = C{1,16};
closed = C{1,18};
direction = C{1,20};
fclose(fileID);

%% Find the frames for the VR that correspond to the frames of the framegrab
% Set the start and stop times
tStart = input('Start time? ');
tStop = input('Stop time? ');

tSpan=find(tFrameGrab>tStart*10000 & tFrameGrab < tStop * 10000);
tifNum = floor(tFrameGrab(tSpan(1))/tFrameGrab(10000));
tifStart = tSpan(1)-10000*tifNum;
tifFrame = round(tifStart/10)*10;
tifEnd = floor(tFrameGrab(tSpan(end))/tFrameGrab(10000));
tifStop = tSpan(end)-10000*tifEnd;
tifLast = round(tifStop/10)*10;
fFrame = 10000*tifNum+tifFrame+1;
lFrame = 10000*tifEnd+tifLast;
numFrames = (lFrame-fFrame+1)/2;
framesVR = zeros(numFrames,1);
for i=1:numFrames
    getVR = find(tVR > tFrameGrab(fFrame+2*(i-1)));
    framesVR(i) = floor(getVR(1)/3);
end

%% Read in the stack
% Get the file info and # of planes and frames
numFiles = input('Number of tifs?');
num_planes = input('Number of planes?: ');
[imageFilename,imagePathname] = uigetfile('*.tif','Select the Two Photon Data');
fullpath = {};
num_images = 0;
num_images_ind = zeros(numFiles,1);
info = {};
for fID = 1:numFiles
    fullpath{fID} = strcat(imagePathname,imageFilename(1:end-5),num2str(fID),'.tif')
    info{fID} = imfinfo(fullpath{fID});
    num_images_ind(fID) = numel(info{fID});
    num_images = num_images + num_images_ind(fID);
end

width = info{1}(1).Width;
height = info{1}(1).Height;
numFrames = num_images/num_planes;

% Load the data
stack = double(zeros(height,width,numFrames));
h = waitbar(0.0,'Loading TIFF stack...');
set(h,'Position',[50 50 360 72]);
set(h,'Name','Loading TIFF stack...');
imOffset = 0;
for fID=1:numFiles
    for incIm = 1:num_images_ind(fID)
        if mod(incIm+imOffset,100)==0
            waitbar((incIm+imOffset)/num_images,h,['Loading frame# ' num2str(incIm+imOffset) ' out of ' num2str(num_images)]);
        end
        stack(:,:,ceil((incIm+imOffset)/num_planes)) = double(imread(fullpath{fID}, incIm, 'Info', info{fID}))+ stack(:,:,ceil((incIm+imOffset)/num_planes));
    end
    imOffset = imOffset+numel(info{fID});
end
delete(h);

%% Gaussian Filter, Background Subtraction, and Savitzky-Golay Filter
% Gaussian Filter
gaussianSize = [2 2];
gaussianSigma = 0.5;
Gxy = fspecial('gaussian',gaussianSize,gaussianSigma);
stackXYfilt = double(zeros(height,width,numFrames));

h = waitbar(0.0,'Gaussian filtering stack...');
set(h,'Position',[50 50 360 72]);
set(h,'Name','Gaussian filtering TIFF stack...');
for i = 1:numFrames
    if mod(i,100)==0
        waitbar(i/numFrames,h,['Filtering frame# ' num2str(i) ' out of ' num2str(numFrames)]);
    end
    stackXYfilt(:,:,i) = imfilter(stack(:,:,i),Gxy,'replicate','conv');
end
delete(h);

% Background subtraction
A = mean(stackXYfilt,3);
h = figure;
ROIREF = roipoly(A/max(max(A)));
delete(h);

stackXYfiltBGsub = double(zeros(height,width,numFrames));

h = waitbar(0.0,'Background subtract...');
set(h,'Position',[50 50 360 72]);
set(h,'Name','Background subtract...');
for i = 1:numFrames
    if mod(i,100)==0
        waitbar(i/numFrames,h,['Filtering frame# ' num2str(i) ' out of ' num2str(numFrames)]);
    end
    A = stackXYfilt(:,:,i);
    ROI = A(logical(ROIREF));
    stackXYfiltBGsub(:,:,i) = stackXYfilt(:,:,i) - mean2(ROI);
end
delete(h);

% Savitzky-Golay Filter
sgolayOrder = 3;
sgolayWindow = 7;
stackXYTfiltBGsub = sgolayfilt(stackXYfiltBGsub,sgolayOrder,sgolayWindow,[],3);

%% Write the movie

writerObj = VideoWriter('Fly3-1-Composite.avi')
writerObj.FrameRate = framerate;
open(writerObj);

close all;
vidFig = figure('Color','k');
set(vidFig,'Position',[50 50 800 1200])

subplot(3,1,1);
tSpan = find(tFrameGrab>tStart*10000 & tFrameGrab<tStop*10000);
fFrame = tFrameGrab(tSpan(1));
contourf(stackXYTfiltBGsub(:,:,1));
caxis([200 250]);
axis equal;
xlim([0 128]);
axis off;

subplot(3,1,2);
filename = ['Z:\DATA\Dan\Imaging\60D05\OneCyl\20150522\Videos\Fly3_1',num2str(framesVR(1)),'.bmp'];
B = imread(filename);
edge = nan(640,1080*0.25);
fullPatt = [edge, squeeze(B(:,:,3)), edge];
colormap([0 0 0; 0 0 1]);
contourf(fliplr(flipud(fullPatt)),'edgecolor','none');
axis off;

subplot(3,1,3);
walkVid = VideoReader('C:\Users\turnerevansd\Documents\MATLAB\Fly3-1-Walking.avi');
vidWidth = walkVid.Width;
vidHeight = walkVid.Height;
mov = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
    'colormap',[]);
mov(1).cdata = readFrame(walkVid);
imshow(mov(1).cdata(:,:,1));


for frameNum = 1:length(framesVR)
    subplot(3,1,1);
    A = imread(fullpath{fID}, incStart+(frameNum-1)*2, 'Info', info{fID});
    for sumIm = 2:10
        A = imread(fullpath{fID}, sumIm + incStart+(frameNum-1)*2-1, 'Info', info{fID})+ A;
    end
    A = imresize(A,0.5);
    contourf(flipud(imfilter(A,h)));
    caxis([50 400]);
    axis equal;
    xlim([0 128]);
    axis off;
    
    subplot(3,1,2);
    filename = ['Z:\DATA\Dan\Imaging\60D05\OneCyl\20150522\Videos\Fly3_1',num2str(framesVR(frameNum)),'.bmp'];
    B = imread(filename);
    colormap([0 0 0; 0 0 1]);
    contourf(flipud(squeeze(B(:,:,3))),'edgecolor','none');
    axis off;
    caxis([0 150]);
    
    subplot(3,1,3);
    mov = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
        'colormap',[]);
    mov(frameNum).cdata = readFrame(walkVid);
    imshow(mov(frameNum).cdata(:,:,1));
    
    frame = getframe(vidFig);
    writeVideo(writerObj,frame);
end
    
close(writerObj);