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

%% Write the movie

writerObj = VideoWriter('Fly1-6-Position.avi')
writerObj.FrameRate = framerate;
open(writerObj);
c = colormap(parula(length(framesVR)));
lag = 5;

close all;
h = figure('Color','k');

for frameNum = 1:length(framesVR)
    clf;
    viscircles([0 0], 1, 'EdgeColor', 'b');
    hold on;
%     scatter(-OffsetLat(framesVR(1:frameNum)),OffsetFor(framesVR(1:frameNum)),0.5,'k');
    scatter(-OffsetLat(framesVR(max(1,frameNum-round(framerate*lag)):frameNum)),OffsetFor(framesVR(max(1,frameNum-round(framerate*lag)):frameNum)),2,'k');
    quiver(-OffsetLat(framesVR(frameNum)),OffsetFor(framesVR(frameNum)),-sin(pi/180*OffsetRot(framesVR(frameNum))),cos(pi/180*OffsetRot(framesVR(frameNum))),'r');
    axis equal;
    set(gca,'XColor','w','YColor','w','FontSize',20);
    hold off;
    ylim([-10 15]);
    xlim([-25 25]);
    movegui(h, 'onscreen');
    frame = getframe;
    writeVideo(writerObj,frame);
end
    
close(writerObj);