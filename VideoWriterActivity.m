%% Find the frame time stamps
% Load photodiode and frame time stamps
[SYNCFilename,SYNCPathname] = uigetfile('*.txt', 'Select the SYNC file');
timeStamps = importdata(strcat(SYNCPathname,SYNCFilename));

% Pull out the time stamps for the frame grab signal
tFrameGrab = find(diff(timeStamps(:,1))>max(diff(timeStamps(:,1)))/2);
framerate = 5000/mean(diff(tFrameGrab));

% Calculate the time stamps for the fly video
tFlyVid = tFrameGrab(1:2:end);

% Pull out the time stamps for the VR refresh
clear tVR;
sampleData = 1;
incDat = 1;
inct = 1;
upperLim = max(timeStamps(:,2));
offset = round(0.8/(360)*10000);
while (sampleData)
    if (timeStamps(incDat+1,2) > 0.25*upperLim)
        tVR(inct) = incDat+1;
        inct = inct +1;
        incDat = incDat + offset;
    end
    incDat=incDat+1;
    if incDat > length(timeStamps)
        break
    end
end


%% Get the .tif info
numFiles = input('Number of tifs?');
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


%% Load the trajectory data
rArena = 200;
% Load the position information
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


%% Set the start and stop times
tStart = input('Start time? ');
tStop = input('Stop time? ');
figure;
viscircles([0 10], 1,'EdgeColor','b');
viscircles([0 -10], 1,'EdgeColor','b');
hold on;
c=linspace(1, 10, 10000*(tStop-tStart));
scatter(OffsetFor(10000*tStart:10000*tStop),OffsetLat(10000*tStart:10000*tStop),2,c);
axis equal;


%% Write the activity video
writerObj = VideoWriter('Fly2-7-ImagingData.avi')
writerObj.FrameRate = framerate;
open(writerObj);

close all;
figure('Color','k');
h = fspecial('gaussian', [3 3], 0.5);

map = zeros(51,3);
for git = 1:51
    map(git,2) = (git-1)/50;
end
colormap(map);
axis off;
A = imread(fullpath{1}, 1, 'Info', info{1});
contourf(imfilter(A,h));
axis equal;
xlim([0 128]);

tSpan = find(tFrameGrab>tStart*10000 & tFrameGrab<tStop*10000);
for fID=ceil(tFrameGrab(tSpan(1))/tFrameGrab(10000)):ceil(tFrameGrab(tSpan(end))/tFrameGrab(10000))
    clear inStart;clear incStop; clear A;
    if fID == ceil(tFrameGrab(tSpan(1))/tFrameGrab(10000))
        incStart = tSpan(1)-(fID-1)*10000;
    else
        incStart=1;
    end
    if fID == ceil(tFrameGrab(tSpan(end))/tFrameGrab(10000))
        incStop = tSpan(end) - (fID-1)*10000;
    else
        incStop = num_images_ind(fID);
    end
    for incIm = max(round(incStart/10),1):min(round(incStop/10)-1,num_images_ind(fID)/10-1)
        A = imread(fullpath{fID}, 1+incIm*10, 'Info', info{fID});
        for sumIm = 2:10
            A = imread(fullpath{fID}, sumIm + incIm*10, 'Info', info{fID})+ A;
        end
        A = imresize(A,0.5);
        contourf(flipud(imfilter(A,h)));
        axis off;
        axis equal;
        xlim([0 128]);
        drawnow;
        for rep = 1:5
            frame = getframe;
            writeVideo(writerObj,frame);
        end
    end
end

close(writerObj);

