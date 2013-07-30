function [ BWleak ] = leak_detection( varargin )
%BWleak = leak_detection(I, [Diskmin Diskmax], tolerance)
%Takes in grayscaled FA image as input I and returns binary image BWleak consisting solely of
%the leak being extracted. Uses morphological techniques to eliminate
%vessels, optic disks, and other unwanted objects before segmenting out
%area of leakage.  
%Diskmin and Diskmax are optional variables specifying an approximate pixel
%range for the radius of the optic disk
%Tolerance is an optional variable in the range [0 1] that determines
%threshold deviation (higher tolerance = lower threshold)

I = varargin{1};
figure, imshow(I)
if nargin >= 2 
    if numel(varargin{2}) == 2
         Diskmin = min(varargin{2});
         Diskmax = max(varargin{2});
    elseif numel(varargin{2}) == 1
         Diskmin = 100;
         Diskmax = 200;
        tolerance = varargin{2};
    elseif nargin == 3
        tolerance = varargin{3};
    end
else
    Diskmin = 100;
    Diskmax = 200;
    tolerance = .25;
end


%Get rid of vessels
se=strel('disk',round(size(I,1)/100));
Iopen=imopen(I,se);


%Find optic disc, if present
%split findcircles algorithm into 4 iterations to improve speed
step = (Diskmax - Diskmin)/4;
centerStrongest = [];
radiusStrongest = [];
maxMetric = 0;
for i = 1:4
    [centers,radii,metrics] = imfindcircles(Iopen,[Diskmin + step*(i-1), Diskmin + step*i],'sensitivity', .97);
    if isempty(metrics)
        continue
    end
    if  metrics(1) > maxMetric
        maxMetric = metrics(1);
        centerStrongest = centers(1,:);
        radiusStrongest = radii(1);
    end
end


if ~isempty(centerStrongest)
        %mask optic disc 
        leeway = 1;
        r = radiusStrongest*(1+leeway);
        [xgrd, ygrd] = meshgrid(1:size(Iopen,2), 1:size(Iopen,1));   
        x = xgrd - centerStrongest(1);  
        y = ygrd - centerStrongest(2);
        omask = x.^2 + y.^2 >= r^2;  
        Inodsc = Iopen.*uint8(omask);
else
    Inodsc = Iopen;
    omask = zeros(size(Iopen));
end
figure, imshow(Inodsc)


%apply threshold using Otsu's method 
thresh = graythresh(Iopen(~omask))*255;
clear Iopen
thresh = thresh * (1-tolerance);
BWthresh1 = Inodsc >= thresh;
Ithresh1 = I .* uint8(BWthresh1);
figure, imshow(Ithresh1)


%apply second threshold to further refine leak mask using original
%image 
thresh = graythresh(Ithresh1(Ithresh1>0))*255;
thresh = thresh * (1-tolerance);
BWleak = Ithresh1 >= thresh;

%clean up final leak mask
BWleak = imfill(BWleak, 'holes');
BWleak = bwmorph(BWleak,'majority');
BWleak = bwmorph(BWleak, 'clean');

%only keep biggest connected region
CC = bwconncomp(BWleak);
numPixels = cellfun(@numel,CC.PixelIdxList);
[~,idx] = max(numPixels);
BWleak = zeros(size(BWleak));
BWleak(CC.PixelIdxList{idx}) = 1;

%show tinted leak
[Iind,map] = gray2ind(I,256);
Irgb=ind2rgb(Iind,map);
Ihsv = rgb2hsv(Irgb);
hueImage = Ihsv(:,:,1);
hueImage(BWleak>0) = 0.011; %red
Ihsv(:,:,1) = hueImage;
satImage = Ihsv(:,:,2);
satImage(BWleak>0) = .8; %semi transparent
Ihsv(:,:,2) = satImage;
Irgb = hsv2rgb(Ihsv);

figure, imshow(Irgb)

end





