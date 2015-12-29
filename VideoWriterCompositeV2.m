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
exTypeStr = strsplit(tstamp,'_');
exType = exTypeStr{end}(1:end-4);
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
trans = C{1,22};
gain = C{1,24};
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
    tPt = (tFrameGrab(2*tFlyMov(i))-tVR(1))/10000+t(1);
    getVR = find(t > tPt);
    framesVR(i) = getVR(1)-mod(getVR(1),5)+1;
%     getVR = find(tVR > tFrameGrab(2*tFlyMov(i)));
%     framesVR(i) = round(getVR(1)/3)-mod(round(getVR(1)/3),5)+1;
end

%% Write the movie

writerObj = VideoWriter('Fly2-5-Composite.avi')
writerObj.FrameRate= framerate;
open(writerObj);

close all;

h = waitbar(0.0,'Making movie...');
set(h,'Position',[800 50 360 72]);
set(h,'Name','Making movie...');

vidFig = figure('Color','k');
% set(vidFig,'Position',[50 50 1000 600])
set(vidFig,'Position',[50 50 600 1000])

% subplot(2,2,3);
subplot(3,1,1);
[cd, hc] = contourf(squeeze(stackXYfilt(:,:,imageNum(1))));
axis equal;
xlim([0 256]);
set(hc,'EdgeColor','none');
caxis([0 450]);
axis off;

% subplot(2,2,1:2);
subplot(3,1,2);
filename = ['D:\OpenGL\ColladaViewer\ColladaViewer\Video\Fly2_Trial5_',num2str(framesVR(700)),'.bmp'];
B = imread(filename);
edge = nan(640,1080*0.25);
fullPatt = [edge, squeeze(B(:,:,3)), edge];
contourf(fullPatt,'edgecolor','none');
axis equal;
axis off;

% subplot(2,2,4);
subplot(3,1,3);
walkVid = VideoReader('D:\Movies\20151103_Fly2_Sine\Fly2-5.avi');
vidWidth = walkVid.Width;
vidHeight = walkVid.Height;
mov = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
    'colormap',[]);
mov(1).cdata = readFrame(walkVid);
imshow(mov(1).cdata(:,25:445,1));

lag = 10;
% ins1 = axes('position', [0.4 0.3 0.25 0.25]);
% hold on;
% frameNum = 700;
% rectangle('Position',[-16 -16 32 32],'Curvature',[1 1],'FaceColor',[0.15 0.15 0.15],'EdgeColor','k');
% rectangle('Position',[-1 -1 2 2],'Curvature',[1 1],'FaceColor','w');
% scatter(15*cos(pi/6), 15*sin(pi/6), 20,'wd','filled');
% scatter(-15*cos(pi/6), 15*sin(pi/6), 20,'wv','filled');
% scatter(15*cos(pi/6-pi/2), 15*sin(pi/6-pi/2), 20,'w+','LineWidth',2);
% scatter(OffsetLat(framesVR(max(1,frameNum-round(framerate*lag)):frameNum)),OffsetFor(framesVR(max(1,frameNum-round(framerate*lag)):frameNum)),1,'k','MarkerEdgeColor','w');
% quiver(OffsetLat(framesVR(frameNum)),OffsetFor(framesVR(frameNum)),2*sin(pi/180*OffsetRot(framesVR(frameNum))),2*cos(pi/180*OffsetRot(framesVR(frameNum))),'r','LineWidth',1.5);
% axis equal;
% axis off;
% hold off;
% ylim([-16 16]);
% xlim([-16 16]);
% set(ins1, 'box', 'off');
    

for advmovie = 2:tFlyMov(1)-1
    mov(advmovie).cdata = readFrame(walkVid);
end

for frameNum = 1:length(framesVR)
    
    waitbar(frameNum/length(framesVR),h,['Loading frame# ' num2str(frameNum) ' out of ' num2str(length(framesVR))]);
    
%     subplot(2,2,3);
    subplot(3,1,1);
    [cd,hc] = contourf(squeeze(stackXYfilt(:,:,imageNum(frameNum))));
    axis equal;
    xlim([0 256]);
    axis off;
    axis equal;
    xlim([0 256]);
    set(hc,'EdgeColor','none');
    caxis([0 450]);
    axis off;
    
%     subplot(2,2,1:2);
    subplot(3,1,2);
    filename = ['D:\OpenGL\ColladaViewer\ColladaViewer\Video\Fly2_Trial5_',num2str(framesVR(frameNum)),'.bmp'];
    B = imread(filename);
    contourf(squeeze(B(:,:,3)),'edgecolor','none');
    axis equal;
    axis off;
    caxis([0 150]);
    
%     subplot(2,2,4);
    subplot(3,1,3);
    mov = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
        'colormap',[]);
    mov(tFlyMov(frameNum)).cdata = readFrame(walkVid);
    imshow(mov(tFlyMov(frameNum)).cdata(:,25:445,1));
    
%     ins1 = axes('position', [0.4 0.3 0.25 0.25]);
%     hold on;
%     rectangle('Position',[-16 -16 32 32],'Curvature',[1 1],'FaceColor',[0.15 0.15 0.15],'EdgeColor','k');
%     rectangle('Position',[-1 -1 2 2],'Curvature',[1 1],'FaceColor','w');
%     scatter(15*cos(pi/6), 15*sin(pi/6), 20,'wd','filled');
%     scatter(-15*cos(pi/6), 15*sin(pi/6), 20,'wv','filled');
%     scatter(15*cos(pi/6-pi/2), 15*sin(pi/6-pi/2), 20,'w+','LineWidth',2);
%     scatter(OffsetLat(framesVR(max(1,frameNum-round(framerate*lag)):frameNum)),OffsetFor(framesVR(max(1,frameNum-round(framerate*lag)):frameNum)),1,'k','MarkerEdgeColor','w');
%     quiver(OffsetLat(framesVR(frameNum)),OffsetFor(framesVR(frameNum)),2*sin(pi/180*OffsetRot(framesVR(frameNum))),2*cos(pi/180*OffsetRot(framesVR(frameNum))),'r','LineWidth',1.5);
%     axis equal;
%     axis off;
%     hold off;
%     ylim([-16 16]);
%     xlim([-16 16]);
%     set(ins1, 'box', 'off');
    
    frame = getframe(vidFig);
    writeVideo(writerObj,frame);
end
delete(h);
delete(vidFig);
    
close(writerObj);