framerate =  5000/mean(diff(tFrameGrab))/num_planes;
baseline = mean(GstackXYTfiltBGsub,3);
writerObj = VideoWriter('Fly2-2-Both.avi')
writerObj.FrameRate = framerate;
open(writerObj);

close all;
vidFig = figure('Color','k');

subplot(1,2,1)
map = zeros(153,3);
for git = 1:51
    map(git,1) = (git-1)/51;
end
for git = 103:153
    map(git,2) = (git-103)/51;
end
colormap(map);
axis off;

tStack = find(tFrameGrab > tStart*10000 & tFrameGrab < tStop*10000);
[cd,hc] = contourf(flipud(squeeze(RstackXYTfiltBGsub(:,:,round(tStack(1)/num_planes))-0)));
axis equal;
xlim([0 256]);
set(hc,'EdgeColor','none');
caxis([0 6000]);


subplot(1,2,2)
axis off;

[cd,hc] = contourf(4000+flipud(squeeze(GstackXYTfiltBGsub(:,:,round(tStack(1)/num_planes))-0)));
axis equal;
xlim([0 256]);
set(hc,'EdgeColor','none');
caxis([0 6000]);


for frameNum = round(tStack(1)/num_planes):round(tStack(end)/num_planes)
    subplot(1,2,1)
    [cd,hc] = contourf(flipud(squeeze(RstackXYTfiltBGsub(:,:,frameNum))-0));
    axis equal;
    xlim([0 256]);
    set(hc,'EdgeColor','none');
    caxis([0 6000]);
    
    subplot(1,2,2)
    [cd,hc] = contourf(4000+flipud(squeeze(GstackXYTfiltBGsub(:,:,frameNum))-0));
    axis equal;
    xlim([0 256]);
    set(hc,'EdgeColor','none');
    caxis([0 6000]);
    
    drawnow;
    frame = getframe(vidFig);
    writeVideo(writerObj,frame);
end

close(writerObj);
