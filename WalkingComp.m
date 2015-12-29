%% Get the timestamps for the different flies
% Load photodiode and frame time stamps
[SYNCFilename1,SYNCPathname1] = uigetfile('*.txt', 'Select the first SYNC file');
timeStamps1 = importdata(strcat(SYNCPathname1,SYNCFilename1));

[SYNCFilename2,SYNCPathname2] = uigetfile('*.txt', 'Select the second SYNC file');
timeStamps2 = importdata(strcat(SYNCPathname2,SYNCFilename2));

[SYNCFilename3,SYNCPathname3] = uigetfile('*.txt', 'Select the third SYNC file');
timeStamps3 = importdata(strcat(SYNCPathname3,SYNCFilename3));

% Pull out the time stamps for the frame grab signal
tFrameGrab1 = find(diff(timeStamps1(:,1))>max(diff(timeStamps1(:,1)))/2);
tFrameGrab2 = find(diff(timeStamps2(:,1))>max(diff(timeStamps2(:,1)))/2);
tFrameGrab3 = find(diff(timeStamps3(:,1))>max(diff(timeStamps3(:,1)))/2);
framerate = 5000/mean(diff(tFrameGrab1));

% Pull out the time stamps for the VR refresh
sampleData = 1;
upperLim1 = max(timeStamps1(:,2));
upperLim2 = max(timeStamps2(:,2));
upperLim3 = max(timeStamps3(:,2));
offset = round(0.6/(360)*10000);
startVR1 = find(timeStamps1(:,2) > 0.85*upperLim1);
startVR2 = find(timeStamps2(:,2) > 0.85*upperLim2);
startVR3 = find(timeStamps3(:,2) > 0.85*upperLim3);
incDat1 = startVR1(1)-2;
incDat2 = startVR2(1)-2;
incDat3 = startVR3(1)-2;
inct1 = 1;
inct2 = 1;
inct3 = 1;
while (sampleData)
    if (timeStamps1(incDat1+1,2) < 0.85*upperLim1 && (timeStamps1(incDat1-1,2) < timeStamps1(incDat1+1,2) || timeStamps1(incDat1,2) < timeStamps1(incDat1+1,2)))
        tVR1(inct1) = incDat1+1;
        inct1 = inct1 +1;
        incDat1 = incDat1 + offset;
    end
    if (timeStamps2(incDat2+1,2) < 0.85*upperLim2 && (timeStamps2(incDat2-1,2) < timeStamps2(incDat2+1,2) || timeStamps2(incDat2,2) < timeStamps2(incDat2+1,2)))
        tVR2(inct2) = incDat2+1;
        inct2 = inct2 +1;
        incDat2 = incDat2 + offset;
    end
    if (timeStamps3(incDat3+1,2) < 0.85*upperLim3 && (timeStamps3(incDat3-1,2) < timeStamps3(incDat3+1,2) || timeStamps3(incDat3,2) < timeStamps3(incDat3+1,2)))
        tVR3(inct3) = incDat3+1;
        inct3 = inct3 +1;
        incDat3 = incDat3 + offset;
    end
    incDat1=incDat1+1;
    incDat2=incDat2+1;
    incDat3=incDat3+1;
    if incDat1 > length(timeStamps1)-1 && incDat2 > length(timeStamps2)-1 && incDat3 > length(timeStamps3)-1
        break
    end
end

numFrames = length(tFrameGrab1)/2;

% Get the VR points that correspond to the Framegrab points
framesVR1 = zeros(numFrames,1);
framesVR2 = zeros(numFrames,1);
framesVR3 = zeros(numFrames,1);
for i=1:numFrames
    getVR1 = find(tVR1 > tFrameGrab1(2*i));
    framesVR1(i) = ceil(getVR1(1)/3);
    getVR2 = find(tVR2 > tFrameGrab2(2*i));
    framesVR2(i) = ceil(getVR2(1)/3);
    getVR3 = find(tVR3 > tFrameGrab3(2*i));
    framesVR3(i) = ceil(getVR3(1)/3);
end

%% Get the position information
formatSpec = '%s %f %s %f %s %f %s %f %s %f %s %f %s %d %s %d %s %d %s %d';
N=400000;

[posFilename1 posPathname1] = uigetfile('*.txt', 'Select the first position file');
fileID1 = fopen(strcat(posPathname1,posFilename1));
tstamp1 = fgetl(fileID1);
C = textscan(fileID1,formatSpec,N,'CommentStyle','Current','Delimiter','\t');
t1 = C{1,2}; % Time
OffsetRot1 = C{1,4}; % Stripe rotational offset
OffsetRot1 = mod(OffsetRot1+180, 360)-180;
OffsetFor1 = C{1,6}; % Stripe forward offset
OffsetLat1 = C{1,8}; % Stripe lateral offset
fclose(fileID1);

[posFilename2 posPathname2] = uigetfile('*.txt', 'Select the second position file');
fileID2 = fopen(strcat(posPathname2,posFilename2));
tstamp2 = fgetl(fileID2);
C = textscan(fileID2,formatSpec,N,'CommentStyle','Current','Delimiter','\t');
t2 = C{1,2}; % Time
OffsetRot2 = C{1,4}; % Stripe rotational offset
OffsetRot2 = mod(OffsetRot2+180, 360)-180;
OffsetFor2 = C{1,6}; % Stripe forward offset
OffsetLat2 = C{1,8}; % Stripe lateral offset
fclose(fileID2);

[posFilename3 posPathname3] = uigetfile('*.txt', 'Select the third position file');
fileID3 = fopen(strcat(posPathname3,posFilename3));
tstamp3 = fgetl(fileID3);
C = textscan(fileID3,formatSpec,N,'CommentStyle','Current','Delimiter','\t');
t3 = C{1,2}; % Time
OffsetRot3 = C{1,4}; % Stripe rotational offset
OffsetRot3 = mod(OffsetRot1+180, 360)-180;
OffsetFor3 = C{1,6}; % Stripe forward offset
OffsetLat3 = C{1,8}; % Stripe lateral offset
fclose(fileID3);

%% Write the movie

writerObj = VideoWriter('WalkingExamples.avi')
writerObj.FrameRate= framerate;
open(writerObj);

close all;

h = waitbar(0.0,'Making movie...');
set(h,'Position',[800 50 360 72]);
set(h,'Name','Making movie...');

vidFig = figure('Color','k');
set(vidFig,'Position',[50 50 800 1200])

subplot(3,2,1);
walkVid1 = VideoReader('D:\StripeTracking\WalkingExamples\Fly6-1-Fast.avi');
vidWidth1 = walkVid1.Width;
vidHeight1 = walkVid1.Height;
mov1 = struct('cdata',zeros(vidHeight1,vidWidth1,3,'uint8'),...
    'colormap',[]);
mov1(1).cdata = readFrame(walkVid1);
imshow(mov1(1).cdata(:,:,1));

subplot(3,2,2);
viscircles([0 0], 1, 'EdgeColor', 'b');
hold on;
scatter(-OffsetLat1(framesVR1(1)),OffsetFor1(framesVR1(1)),2,'k');
quiver(-OffsetLat1(framesVR1(1)),OffsetFor1(framesVR1(1)),-sin(pi/180*OffsetRot1(framesVR1(1))),cos(pi/180*OffsetRot1(framesVR1(1))),'r');
axis equal;
set(gca,'XColor','w','YColor','w','FontSize',20);
hold off;
ylim([-15 15]);
xlim([-15 15]);

subplot(3,2,3);
walkVid2 = VideoReader('D:\StripeTracking\WalkingExamples\Fly1-4-Good.avi');
vidWidth2 = walkVid2.Width;
vidHeight2 = walkVid2.Height;
mov2 = struct('cdata',zeros(vidHeight2,vidWidth2,3,'uint8'),...
    'colormap',[]);
mov2(1).cdata = readFrame(walkVid2);
imshow(mov2(1).cdata(:,:,1));

subplot(3,2,4);
viscircles([0 0], 1, 'EdgeColor', 'b');
hold on;
scatter(-OffsetLat2(framesVR2(1)),OffsetFor2(framesVR2(1)),2,'k');
quiver(-OffsetLat2(framesVR2(1)),OffsetFor2(framesVR2(1)),-sin(pi/180*OffsetRot2(framesVR2(1))),cos(pi/180*OffsetRot2(framesVR2(1))),'r');
axis equal;
set(gca,'XColor','w','YColor','w','FontSize',20);
hold off;
ylim([-15 15]);
xlim([-15 15]);

subplot(3,2,5);
walkVid3 = VideoReader('D:\StripeTracking\WalkingExamples\Fly2-6-OK.avi');
vidWidth3 = walkVid3.Width;
vidHeight3 = walkVid3.Height;
mov3 = struct('cdata',zeros(vidHeight3,vidWidth3,3,'uint8'),...
    'colormap',[]);
mov3(1).cdata = readFrame(walkVid3);
imshow(mov3(1).cdata(:,:,1));

subplot(3,2,6);
viscircles([0 0], 1, 'EdgeColor', 'b');
hold on;
scatter(-OffsetLat3(framesVR3(1)),OffsetFor3(framesVR3(1)),2,'k');
quiver(-OffsetLat3(framesVR3(1)),OffsetFor3(framesVR3(1)),-sin(pi/180*OffsetRot3(framesVR3(1))),cos(pi/180*OffsetRot3(framesVR3(1))),'r');
axis equal;
set(gca,'XColor','w','YColor','w','FontSize',20);
hold off;
ylim([-15 15]);
xlim([-15 15]);

for frameNum = 1:length(framesVR1)
    
    waitbar(frameNum/length(framesVR1),h,['Loading frame# ' num2str(frameNum) ' out of ' num2str(length(framesVR1))]);

    clf;
    
    subplot(3,2,1);
    mov1 = struct('cdata',zeros(vidHeight1,vidWidth1,3,'uint8'),...
        'colormap',[]);
    mov1(frameNum).cdata = readFrame(walkVid1);
    imshow(mov1(frameNum).cdata(:,:,1));
    
    subplot(3,2,2);
    viscircles([0 0], 1, 'EdgeColor', 'b');
    hold on;
    scatter(-OffsetLat1(framesVR1(1:frameNum)),OffsetFor1(framesVR1(1:frameNum)),2,'k');
    quiver(-OffsetLat1(framesVR1(frameNum)),OffsetFor1(framesVR1(frameNum)),-sin(pi/180*OffsetRot1(framesVR1(frameNum))),cos(pi/180*OffsetRot1(framesVR1(frameNum))),'r');
    axis equal;
    set(gca,'XColor','w','YColor','w','FontSize',20);
    hold off;
    ylim([-15 15]);
    xlim([-15 15]);
    
    subplot(3,2,3);
    mov2 = struct('cdata',zeros(vidHeight2,vidWidth2,3,'uint8'),...
        'colormap',[]);
    mov2(frameNum).cdata = readFrame(walkVid2);
    imshow(mov2(frameNum).cdata(:,:,1));
    
    subplot(3,2,4);
    viscircles([0 0], 1, 'EdgeColor', 'b');
    hold on;
    scatter(-OffsetLat2(framesVR2(1:frameNum)),OffsetFor2(framesVR2(1:frameNum)),2,'k');
    quiver(-OffsetLat2(framesVR2(frameNum)),OffsetFor2(framesVR2(frameNum)),-sin(pi/180*OffsetRot2(framesVR2(frameNum))),cos(pi/180*OffsetRot2(framesVR2(frameNum))),'r');
    axis equal;
    set(gca,'XColor','w','YColor','w','FontSize',20);
    hold off;
    ylim([-15 15]);
    xlim([-15 15]);
    
    subplot(3,2,5);
    mov3 = struct('cdata',zeros(vidHeight3,vidWidth3,3,'uint8'),...
        'colormap',[]);
    mov3(frameNum).cdata = readFrame(walkVid3);
    imshow(mov3(frameNum).cdata(:,:,1));
    
    subplot(3,2,6);
    viscircles([0 0], 1, 'EdgeColor', 'b');
    hold on;
    scatter(-OffsetLat3(framesVR3(1:frameNum)),OffsetFor3(framesVR3(1:frameNum)),2,'k');
    quiver(-OffsetLat3(framesVR3(frameNum)),OffsetFor3(framesVR3(frameNum)),-sin(pi/180*OffsetRot3(framesVR3(frameNum))),cos(pi/180*OffsetRot3(framesVR3(frameNum))),'r');
    axis equal;
    set(gca,'XColor','w','YColor','w','FontSize',20);
    hold off;
    ylim([-15 15]);
    xlim([-15 15]);
    
%     movegui(vidFig, 'onscreen');
    frame = getframe(vidFig);
    writeVideo(writerObj,frame);
end

delete(h);
delete(vidFig);    
close(writerObj);