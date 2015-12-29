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
VRthresh = 0.8;
startVR = find(timeStamps(:,2) > VRthresh*upperLim);
incDat = startVR(1)-2;
inct = 1;
while (sampleData)
    if (timeStamps(incDat+1,2) < VRthresh*upperLim && (timeStamps(incDat-1,2) < timeStamps(incDat+1,2) || timeStamps(incDat,2) < timeStamps(incDat+1,2)))
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
scatter(tVR,upperLim*VRthresh+zeros(length(tVR),1),'r');

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

%% Read in the stack
% Get the file info and # of planes and frames
[imageFilename,imagePathname] = uigetfile('*.tif','Select the Two Photon Data');
numFiles = input('Number of tifs?');
fullpath = {};
num_images = 0;
num_images_ind = zeros(numFiles,1);
info = {};
for fID = 1:numFiles
    fullpath{fID} = strcat(imagePathname,imageFilename(1:end-5),num2str(fID),'.tif');
    info{fID} = imfinfo(fullpath{fID});
    num_images_ind(fID) = numel(info{fID});
    num_images = num_images + num_images_ind(fID);
end
recSpecs = info{1}(1).ImageDescription;
planeLoc = strfind(recSpecs, 'numSlices');
num_planes = str2num(recSpecs(planeLoc+12));

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

%% Gaussian Filter
% Gaussian Filter
gaussianSize = [5 5];
gaussianSigma = 2;
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

%% Set the start and stop times
tStart = input('Start time? ');
tStop = input('Stop time? ');

%% Write the activity video
framerate =  5000/mean(diff(tFrameGrab))/num_planes;
writerObj = VideoWriter('Fly1-6-ImagingData.avi')
writerObj.FrameRate = framerate;
open(writerObj);

close all;
figure('Color','k');

map = zeros(51,3);
for git = 1:51
    map(git,2) = (git-1)/51;
end
colormap(map);
axis off;

tStack = find(tFrameGrab > tStart*10000 & tFrameGrab < tStop*10000);
[cd,hc] = contourf(flipud(squeeze(stackXYfilt(:,:,round(tStack(1)/num_planes))-0)));
axis equal;
xlim([0 256]);
set(hc,'EdgeColor','none');
caxis([0 600]);


for frameNum = round(tStack(1)/num_planes):round(tStack(end)/num_planes)/10
    [cd,hc] = contourf(flipud(squeeze(stackXYfilt(:,:,frameNum))-0));
    axis equal;
    xlim([0 256]);
    set(hc,'EdgeColor','none');
    caxis([0 600]);
    drawnow;
    frame = getframe;
    writeVideo(writerObj,frame);
end

close(writerObj);

