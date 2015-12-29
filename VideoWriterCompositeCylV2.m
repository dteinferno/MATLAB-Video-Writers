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
offset = round(0.6/(360)*10000);
startVR = find(timeStamps(:,2) > 0.85*upperLim);
incDat = startVR(1)-2;
inct = 1;
while (sampleData)
    if (timeStamps(incDat+1,2) < 0.85*upperLim && (timeStamps(incDat-1,2) < timeStamps(incDat+1,2) || timeStamps(incDat,2) < timeStamps(incDat+1,2)))
        tVR(inct) = incDat+1;
        inct = inct +1;
        incDat = incDat + offset;
    end
    incDat=incDat+1;
    if incDat > length(timeStamps)-1
        break
    end
end

figure;
plot(timeStamps(:,2));
xlim([tVR(1)-200 tVR(1)+800]);
hold on;
scatter(tVR,upperLim*0.85+zeros(length(tVR),1),'r');

%% Load the positional info
[posFilename posPathname] = uigetfile('*.txt', 'Select the position file');
fileID = fopen(strcat(posPathname,posFilename));
tstamp = fgetl(fileID);
formatSpec = '%s %f %s %f %s %f %s %f %s %f %s %f %s %d %s %d %s %d %s %d %s %d %s %f';
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
gaussianSize = [4 4];
gaussianSigma = 1;
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

%% Find the frames for the VR that correspond to the frames of the framegrab
% Set the start and stop times
tStart = input('Start time? ');
tStop = input('Stop time? ');

tSpan=find(tFrameGrab>tStart*10000 & tFrameGrab < tStop * 10000);
tFlyMov = [round(tSpan(1)/2):round(tSpan(end)/2)];
numFrames = length(tFlyMov);

imageNum = zeros(numFrames,1);
framesVR = zeros(numFrames,1);
for i=1:numFrames
    imageNum(i) = ceil(2*tFlyMov(i)/num_planes);
    getVR = find(tVR > tFrameGrab(2*tFlyMov(i)));
    framesVR(i) = round(getVR(1)/5)-mod(round(getVR(1)/5),5)+1;
end

%% Write the activity movie
writerObj = VideoWriter('Fly1-9-Activity.avi')
writerObj.FrameRate= framerate;
open(writerObj);

close all;

h = waitbar(0.0,'Making movie...');
set(h,'Position',[800 50 360 72]);
set(h,'Name','Making movie...');

vidFig = figure('Color','k');
map = zeros(51,3);
for git = 1:51
    map(git,2) = (git-1)/51;
end
colormap(map);

 [cd,hc] = contourf(squeeze(stackXYTfiltBGsub(:,:,imageNum(1))));
axis equal;
xlim([0 256]);
set(hc,'EdgeColor','none');
axis off;
caxis([0 450])

for frameNum = 1:length(framesVR)
    
    waitbar(frameNum/length(framesVR),h,['Loading frame# ' num2str(frameNum) ' out of ' num2str(length(framesVR))]);
    
    [cd,hc] = contourf(squeeze(stackXYTfiltBGsub(:,:,imageNum(frameNum))));
    axis equal;
    xlim([0 256]);
    set(hc,'EdgeColor','none');
    axis off;
    caxis([0 450]);
    
    frame = getframe(vidFig);
    writeVideo(writerObj,frame);
end
delete(h);
delete(vidFig);
    
close(writerObj);

%% Write the VR movie
writerObj = VideoWriter('Fly1-9-VR.avi')
writerObj.FrameRate= framerate;
open(writerObj);

close all;

h = waitbar(0.0,'Making movie...');
set(h,'Position',[800 50 360 72]);
set(h,'Name','Making movie...');

vidFig = figure('Color','k');set(vidFig,'Position',[50 50 1080 640])
map = zeros(51,3);
for git = 1:51
    map(git,3) = (git-1)/51;
end
colormap(map);

filename = ['D:\OpenGL\ColladaViewer\ColladaViewer\Video\Fly1_Trail9_',num2str(framesVR(200)),'.bmp'];
B = imread(filename);
% [x, y, z] = cylinder(ones(1,640), 1080*1.5);
% edge = nan(640,1080*0.25);
% fullPatt = [edge, squeeze(B(:,:,3)), edge];
% surf(x,y,z,fliplr(fullPatt),'edgecolor','none');
% az = 90;
% el = 60;
% view(az,el);
% camproj('perspective');
% axis tight;
contourf(squeeze(B(:,:,3)),'edgecolor','none');
axis equal;
axis off;
caxis([0 150]);

for frameNum = 1:length(framesVR)
    
    waitbar(frameNum/length(framesVR),h,['Loading frame# ' num2str(frameNum) ' out of ' num2str(length(framesVR))]);
    
    filename = ['D:\OpenGL\ColladaViewer\ColladaViewer\Video\Fly1_Trail9_',num2str(framesVR(frameNum)),'.bmp'];
    B = imread(filename);
%     [x, y, z] = cylinder(ones(1,640), 1080*1.5);
%     edge = nan(640,1080*0.25);
%     fullPatt = [edge, squeeze(B(:,:,3)), edge];
%     surf(x,y,z,fliplr(fullPatt),'edgecolor','none');
%     az = 90;
%     el = 60;
%     view(az,el);
%     camproj('perspective');
%     axis tight;
    contourf(squeeze(B(:,:,3)),'edgecolor','none');
    axis equal;
    axis off;
    caxis([0 150]);
    
    frame = getframe(vidFig);
    writeVideo(writerObj,frame);
end
delete(h);
delete(vidFig);
    
close(writerObj);

%% Write the Fly Movement
writerObj = VideoWriter('Fly1-9-Walking.avi')
writerObj.FrameRate= framerate;
open(writerObj);

close all;

h = waitbar(0.0,'Making movie...');
set(h,'Position',[800 50 360 72]);
set(h,'Name','Making movie...');

vidFig = figure('Color','k');

walkVid = VideoReader('D:\Movies\Fly1-9.avi');
vidWidth = walkVid.Width;
vidHeight = walkVid.Height;
mov = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
    'colormap',[]);
mov(1).cdata = readFrame(walkVid);
imshow(mov(1).cdata(:,25:450,1));

for advmovie = 2:tFlyMov(1)-1
    mov(advmovie).cdata = readFrame(walkVid);
end

for frameNum = 1:length(framesVR)
    
    waitbar(frameNum/length(framesVR),h,['Loading frame# ' num2str(frameNum) ' out of ' num2str(length(framesVR))]);
    
    mov = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
        'colormap',[]);
    mov(tFlyMov(frameNum)).cdata = readFrame(walkVid);
    imshow(mov(tFlyMov(frameNum)).cdata(:,25:450,1));
    
    frame = getframe(vidFig);
    writeVideo(writerObj,frame);
end
delete(h);
delete(vidFig);
    
close(writerObj);